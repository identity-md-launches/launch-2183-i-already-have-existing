// Starts its own isolated Anvil chain. No keys, external RPC, production transactions or environment settings.
import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { readFileSync, mkdirSync } from 'node:fs';
import net from 'node:net';
import { once } from 'node:events';
import { i as createPublicClient } from '../web/assets-future-v1/_esm-5FcxR2A7.js';
import { t as custom } from '../web/assets-future-v1/custom-BKvn-pdL.js';
import { Kt as encodeFunctionData, zn as erc20Abi } from '../web/assets-future-v1/call-Bm9w5nme.js';
import { a as keccak256 } from '../web/assets-future-v1/getAddress-yOC5k4Wk.js';
import { gameAbi } from '../web/game-abi.mjs';
import { validateDeployment } from '../web/config-schema.mjs';
import { verifyGame } from '../web/contract-verification.mjs';
import { roundClock, drawState } from '../web/game-rules.mjs';
import { buyReviewedTickets } from '../web/purchase.mjs';

mkdirSync('test/scratch', { recursive: true });
const socketPath = `test/scratch/smoke-${process.pid}.ipc`;
const rpcUrl = `ipc:${socketPath}`;
const anvil = spawn('anvil', ['--ipc', socketPath, '--host', '127.0.0.1', '--port', '0', '--chain-id', '1', '--accounts', '0', '--silent'], { stdio: ['ignore', 'ignore', 'pipe'] });
const anvilExit = once(anvil, 'exit');
let anvilError = '';
anvil.stderr.on('data', (chunk) => { anvilError += chunk; });
let requestId = 0;
async function rpc(method, params = []) {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify({ jsonrpc: '2.0', id: ++requestId, method, params });
    const connection = net.createConnection({ path: socketPath });
    let body = '';
    connection.setTimeout(30_000, () => connection.destroy(new Error('IPC timeout')));
    connection.on('connect', () => connection.write(payload + '\n'));
    connection.on('data', (chunk) => {
      body += chunk;
      let data;
      try { data = JSON.parse(body); } catch { return; }
      connection.end();
      data.error ? reject(new Error(JSON.stringify(data.error))) : resolve(data.result);
    });
    connection.on('error', reject);
  });
}

try {
  for (let attempt = 0; ; ++attempt) {
    try { await rpc('eth_chainId'); break; }
    catch (error) {
      if (attempt >= 50 || anvil.exitCode !== null) throw new Error(`Anvil did not start: ${anvilError || error.message}`);
      await new Promise((resolve) => setTimeout(resolve, 100));
    }
  }
  const owner = '0x34284c5c4c54d5f8e7e14e2d1a3dcd48899928ea';
  const alice = '0x' + keccak256(new TextEncoder().encode('local smoke alice')).slice(-40);
  const bob = '0x' + keccak256(new TextEncoder().encode('local smoke bob')).slice(-40);
  for (const account of [owner, alice, bob]) {
    await rpc('anvil_impersonateAccount', [account]);
    await rpc('anvil_setBalance', [account, '0x3635c9adc5dea00000']);
  }
  async function send(from, to, data) {
    const tx = { from, data, gas: '0x989680' };
    if (to) tx.to = to;
    const hash = await rpc('eth_sendTransaction', [tx]);
    let receipt;
    for (let attempt = 0; attempt < 100; ++attempt) {
      receipt = await rpc('eth_getTransactionReceipt', [hash]);
      if (receipt) break;
      await new Promise((resolve) => setTimeout(resolve, 20));
    }
    assert.ok(receipt, `transaction ${hash} was not mined`);
    assert.equal(receipt.status, '0x1', `transaction ${hash} reverted`);
    return receipt;
  }
  const artifact = JSON.parse(readFileSync('out/IMDPot.sol/IMDPot.json'));
  const tokenArtifact = JSON.parse(readFileSync('out/MockToken.sol/MockToken.json'));
  const receipt = await send(owner, undefined, artifact.bytecode.object + owner.slice(2).padStart(64, '0'));
  const pot = receipt.contractAddress;
  const token = (await send(owner, undefined, tokenArtifact.bytecode.object + '12'.padStart(64, '0'))).contractAddress;
  const destination = `test/scratch/site-smoke-${process.pid}`;
  mkdirSync('test/scratch', { recursive: true });
  const release = spawnSync('python3', ['tools/build_site.py', '--address', pot, '--block', String(parseInt(receipt.blockNumber, 16)), '--rpc', rpcUrl, '--out', destination], { encoding: 'utf8' });
  assert.equal(release.status, 0, release.stderr);
  const deployment = validateDeployment(JSON.parse(readFileSync(`${destination}/deployment.json`)));
  const client = createPublicClient({ cacheTime: 0, transport: custom({ request: ({ method, params }) => rpc(method, params) }) });
  await verifyGame(client, deployment, keccak256);
  const read = (functionName, args = []) => client.readContract({ address: pot, abi: gameAbi, functionName, args });
  const write = (from, functionName, args = []) => send(from, pot, encodeFunctionData({ abi: gameAbi, functionName, args }));
  const writeToken = (from, functionName, args = []) => send(from, token, encodeFunctionData({ abi: tokenArtifact.abi, functionName, args }));
  assert.equal(await read('isConfigured'), false);
  await write(owner, 'setToken', [token]);
  assert.equal(await read('ticketPrice'), 100_000_000_000_000_000n);
  for (const account of [alice, bob]) await writeToken(owner, 'mint', [account, 10n ** 20n]);
  async function loadGame() {
    const roundId = await read('currentRoundId');
    const block = await client.getBlock();
    return {
      mode: 'future-blockhash', roundId, token, configured: await read('isConfigured'),
      paused: await read('paused'), ticketPrice: await read('ticketPrice'),
      chainTime: Number(block.timestamp), round: await read('getRound', [roundId]), block: block.number,
    };
  }
  async function purchase(account, count) {
    const game = await loadGame();
    return buyReviewedTickets({
      count, roundId: game.roundId, cost: count * game.ticketPrice, loadGame,
      loadBalance: () => client.readContract({ address: token, abi: erc20Abi, functionName: 'balanceOf', args: [account] }),
      loadAllowance: () => client.readContract({ address: token, abi: erc20Abi, functionName: 'allowance', args: [account, pot] }),
      approve: (_, amount) => writeToken(account, 'approve', [pot, amount]),
      buy: (id, quantity) => write(account, 'buyTicketsForRound', [id, quantity]),
    });
  }
  await purchase(alice, 3n); await purchase(bob, 2n);
  assert.equal(await read('ticketsOf', [1n, alice]), 3n);
  let game = await loadGame();
  assert.ok(roundClock(game.round, game.chainTime).seconds > 0);
  await rpc('evm_setNextBlockTimestamp', [Number(game.round.endTime)]); await rpc('evm_mine');
  game = await loadGame(); assert.equal(roundClock(game.round, game.chainTime).seconds, 0);
  await assert.rejects(purchase(alice, 1n), /Tickets are closed/);
  await write(bob, 'finalizeRound');
  game = await loadGame(); assert.equal(drawState(game.round, game.block).ready, false);
  for (let i = 0; i < 4; ++i) await rpc('evm_mine');
  game = await loadGame(); assert.equal(drawState(game.round, game.block).ready, true);
  await write(alice, 'finalizeRound');
  assert.equal(await read('currentRoundId'), 2n);
  assert.equal(await read('totalClaimable'), 350_000_000_000_000_000n);
  for (const account of [alice, bob]) if (await read('claimable', [account]) > 0n) await write(account, 'claim');
  assert.equal(await read('totalClaimable'), 0n);
  await purchase(alice, 1n);
  game = await loadGame();
  await rpc('evm_setNextBlockTimestamp', [Number(game.round.endTime)]); await rpc('evm_mine');
  await write(bob, 'finalizeRound');
  await rpc('anvil_mine', ['0x105', '0x1']);
  game = await loadGame(); assert.equal(drawState(game.round, game.block).expired, true);
  await write(bob, 'cancelRound'); await write(alice, 'refund', [2n]);
  assert.equal(await read('totalRefundable'), 0n);
  const balance = await client.readContract({ address: token, abi: erc20Abi, functionName: 'balanceOf', args: [pot] });
  assert.equal(balance, await read('totalLocked'));
  assert.equal(balance, await read('totalObligations'));
  assert.equal((await read('getPlayer', [alice]))[0], 3n);
  console.log('PASS: real Anvil deployment, verified website release, approve/buy, chain timer, both finalize steps, claims, expiry cancellation and refund.');
} finally {
  anvil.kill('SIGTERM');
  await anvilExit;
}
