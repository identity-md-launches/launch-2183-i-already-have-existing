import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { CHAIN_ID, PREVIOUS_CONTRACT, validateDeployment, loadDeployment } from '../web/config-schema.mjs';
import { verifyGame } from '../web/contract-verification.mjs';
import { roundClock, parseTicketCount, drawState } from '../web/game-rules.mjs';
import { buyReviewedTickets } from '../web/purchase.mjs';
import { gameAbi } from '../web/game-abi.mjs';

// Local fixtures only. No fixture is shipped as a deployment setting.
const testAddress = '0x' + '12'.repeat(20);
const testHash = '0x' + '34'.repeat(32);
const config = () => ({ chainId: CHAIN_ID, contract: testAddress, deploymentBlock: '42', runtimeCodeHash: testHash });

test('configuration accepts a complete handoff and rejects missing, stale or invalid settings', () => {
  assert.deepEqual(validateDeployment(config()), config());
  for (const change of [
    { chainId: 10 }, { contract: PREVIOUS_CONTRACT }, { contract: '0x' + '0'.repeat(40) },
    { contract: '0x' + '0'.repeat(36) + 'dead' }, { contract: 'pending' },
    { deploymentBlock: '0' }, { deploymentBlock: 42 }, { deploymentBlock: '-1' },
    { runtimeCodeHash: '0x' }, { runtimeCodeHash: '0x' + '0'.repeat(64) },
  ]) assert.throws(() => validateDeployment({ ...config(), ...change }));
  assert.throws(() => validateDeployment(null));
});

test('deployment fetch bypasses cache and failures disable the game', async () => {
  let options;
  assert.deepEqual(await loadDeployment(async (url, opts) => {
    assert.ok(url.href.endsWith('/deployment.json'));
    options = opts;
    return { ok: true, json: async () => config() };
  }), config());
  assert.equal(options.cache, 'no-store');
  await assert.rejects(loadDeployment(async () => ({ ok: false })), /not been connected/);
  await assert.rejects(loadDeployment(async () => ({ ok: true, json: async () => ({}) })), /chain 1/);
});

test('runtime verification rejects another chain, missing code and another build', async () => {
  const client = { getChainId: async () => 1, getCode: async ({ address }) => { assert.equal(address, testAddress); return '0x1234'; } };
  await verifyGame(client, config(), () => testHash);
  await assert.rejects(verifyGame({ ...client, getChainId: async () => 10 }, config(), () => testHash), /verification failed/);
  await assert.rejects(verifyGame({ ...client, getCode: async () => '0x' }, config(), () => testHash), /verification failed/);
  await assert.rejects(verifyGame(client, config(), () => 'another build'), /verification failed/);
});

test('timer starts with the first entry and stops exactly at the chain deadline', () => {
  assert.equal(roundClock(undefined, 1000).text, '--:--');
  assert.equal(roundClock({ status: 0 }, 1000).text, '15:00');
  const active = { status: 1, endTime: 1900n };
  assert.equal(roundClock(active, 1000).text, '15:00');
  assert.equal(roundClock(active, 1899).text, '00:01');
  assert.equal(roundClock(active, 1900).seconds, 0);
  assert.equal(roundClock(active, 2000).seconds, 0);
  assert.equal(roundClock({ status: 2 }, 2000).label, 'Waiting for the draw');
});

test('draw controls match the contract at all target and expiry boundaries', () => {
  const drawing = { status: 2, drawBlock: 100n };
  assert.equal(drawState({ status: 1 }, 90n).label, 'Finalize round');
  assert.equal(drawState(drawing, 100n).ready, false);
  assert.equal(drawState(drawing, 101n).ready, true);
  assert.equal(drawState(drawing, 356n).ready, true);
  assert.equal(drawState(drawing, 357n).expired, true);
});

test('ticket input matches the onchain limit and rejects fractional or malformed values', () => {
  assert.equal(parseTicketCount(' 1 ').count, 1n);
  assert.equal(parseTicketCount('1000000').count, 1_000_000n);
  for (const value of ['0', '-1', '1.5', '1e3', '', '1000001', '9'.repeat(1000)]) assert.ok(parseTicketCount(value).error);
});

function purchaseFixture({ allowance = 0n, balance = 100n, after = {} } = {}) {
  let calls = [];
  let loads = 0;
  const game = { mode: 'future-blockhash', token: testAddress, configured: true, paused: false, roundId: 7n, ticketPrice: 10n, chainTime: 100, round: { status: 1, endTime: 1000n } };
  return {
    calls, game,
    args: {
      count: 2n, roundId: 7n, cost: 20n,
      loadGame: async () => ({ ...game, ...(loads++ ? after : {}) }),
      loadBalance: async () => balance,
      loadAllowance: async () => allowance,
      approve: async (token, amount) => calls.push(['approve', token, amount]),
      buy: async (round, count) => calls.push(['buy', round, count]),
    },
  };
}

test('purchase approves exactly the reviewed cost, then buys against the reviewed round', async () => {
  const fixture = purchaseFixture();
  assert.match(await buyReviewedTickets(fixture.args), /2 tickets are confirmed in round #7/);
  assert.deepEqual(fixture.calls, [['approve', testAddress, 20n], ['buy', 7n, 2n]]);
  const covered = purchaseFixture({ allowance: 20n });
  await buyReviewedTickets(covered.args);
  assert.deepEqual(covered.calls, [['buy', 7n, 2n]]);
});

test('purchase rejection and failed approvals cannot enter the lottery', async () => {
  const insufficient = purchaseFixture({ balance: 19n });
  await assert.rejects(buyReviewedTickets(insufficient.args), /Not enough IMD/);
  assert.deepEqual(insufficient.calls, []);
  const denied = purchaseFixture();
  denied.args.approve = async () => { throw new Error('wallet denied'); };
  await assert.rejects(buyReviewedTickets(denied.args), /wallet denied/);
  assert.deepEqual(denied.calls, []);
  const reverted = purchaseFixture({ allowance: 20n });
  reverted.args.buy = async () => { throw new Error('onchain revert'); };
  await assert.rejects(buyReviewedTickets(reverted.args), /onchain revert/);
});

test('a round change, pause, draw or deadline during approval stops the purchase', async () => {
  for (const after of [{ roundId: 8n }, { paused: true }, { round: { status: 2 } }, { chainTime: 1000 }, { ticketPrice: 11n }]) {
    const fixture = purchaseFixture({ after });
    await assert.rejects(buyReviewedTickets(fixture.args));
    assert.equal(fixture.calls.length, 1);
    assert.equal(fixture.calls[0][0], 'approve');
  }
});

test('unconfigured or previous deployments never request token approval', async () => {
  for (const change of [{ configured: false }, { mode: 'legacy-vrf' }, { token: undefined }]) {
    const fixture = purchaseFixture(); Object.assign(fixture.game, change);
    await assert.rejects(buyReviewedTickets(fixture.args));
    assert.deepEqual(fixture.calls, []);
  }
});

test('the shipped ABI matches the pinned contract build, including the round tuple', () => {
  const artifact = JSON.parse(readFileSync(new URL('../out/IMDPot.sol/IMDPot.json', import.meta.url)));
  assert.deepEqual(gameAbi, artifact.abi);
  assert.ok(gameAbi.some((entry) => entry.name === 'buyTicketsForRound'));
});

test('all static imports and preload chunks of the preserved website are vendored', () => {
  const root = resolve(import.meta.dirname, '../web');
  function walk(path) {
    for (const entry of readdirSync(path, { withFileTypes: true })) {
      const file = resolve(path, entry.name);
      if (entry.isDirectory()) { walk(file); continue; }
      if (!/\.(js|mjs)$/.test(file)) continue;
      // JSDoc type imports are erased by the browser, so they are not runtime assets.
      const text = readFileSync(file, 'utf8').replace(/\/\*\*[\s\S]*?\*\//g, '');
      const imports = [...text.matchAll(/(?:\bfrom\s*|\bimport\s*\(\s*)["'`]([^"'`]+)["'`]/g)].map((match) => match[1]);
      const preload = text.match(/m\.f=\[(.*?)\]/)?.[1] || '';
      imports.push(...[...preload.matchAll(/["'](\.\/[^"']+)["']/g)].map((match) => match[1]));
      for (const reference of imports) {
        if (!reference.startsWith('.')) continue;
        assert.ok(existsSync(resolve(dirname(file), reference)), `Missing dependency ${reference} in ${file}`);
      }
    }
  }
  walk(root);
});
