// Production-export browser checks against the actual Solidity on an isolated Anvil chain.
// No external transaction is possible: all public RPC traffic is intercepted and served locally.
import assert from 'node:assert/strict';
import { spawn, execFileSync } from 'node:child_process';
import { once } from 'node:events';
import { readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { createServer } from 'node:http';
import { resolve, extname } from 'node:path';
import { pathToFileURL } from 'node:url';
import net from 'node:net';
import { randomUUID } from 'node:crypto';
import { gameAbi } from '../web/game-abi.mjs';
import { network } from '../web/network.mjs';
import { Kt as encodeFunctionData } from '../web/assets-future-v1/call-Bm9w5nme.js';
import { i as createPublicClient } from '../web/assets-future-v1/_esm-5FcxR2A7.js';
import { t as custom } from '../web/assets-future-v1/custom-BKvn-pdL.js';

const playwright = process.env.IMD_PLAYWRIGHT
  ? await import(pathToFileURL(process.env.IMD_PLAYWRIGHT).href) : await import('playwright');
mkdirSync('test/scratch/browser-checks', { recursive: true });
const engine = process.env.IMDPOT_BROWSER ?? 'chromium';
const output = `test/scratch/browser-checks/${engine}`;
mkdirSync(output, { recursive: true });
const deployment = JSON.parse(readFileSync('web/deployment.json'));
const gameArtifact = JSON.parse(readFileSync('out/IMDPot.sol/IMDPot.json'));
const tokenArtifact = JSON.parse(readFileSync('out/MockToken.sol/MockToken.json'));
const pot = deployment.contract;
const token = network.token;
// This is the constructor owner from the existing local integration fixture, never a key.
const owner = '0x34284c5c4c54d5f8e7e14e2d1a3dcd48899928ea';
const socketPath = `test/scratch/browser-${randomUUID()}.ipc`;
const anvil = spawn('anvil', ['--ipc', socketPath, '--port', '0', '--chain-id', '1', '--accounts', '0', '--silent'], { stdio: ['ignore', 'ignore', 'pipe'] });
const anvilExit = once(anvil, 'exit');
let anvilError = '';
anvil.stderr.on('data', (data) => { anvilError += data; });
let rpcId = 0;
const delay = (ms) => new Promise((done) => setTimeout(done, ms));
function rpc(method, params = []) {
  return new Promise((done, reject) => {
    const connection = net.createConnection({ path: socketPath });
    let body = '';
    connection.setTimeout(15000, () => connection.destroy(new Error('Local RPC timeout')));
    connection.on('connect', () => connection.write(JSON.stringify({ jsonrpc: '2.0', id: ++rpcId, method, params }) + '\n'));
    connection.on('data', (data) => {
      body += data;
      let response;
      try { response = JSON.parse(body); } catch { return; }
      connection.end();
      if (response.error) reject(Object.assign(new Error(response.error.message), response.error));
      else done(response.result);
    });
    connection.on('error', reject);
  });
}
async function send(to, data) {
  const hash = await rpc('eth_sendTransaction', [{ from: owner, ...(to ? { to } : {}), data, gas: '0x989680' }]);
  for (let i = 0; i < 100; ++i) {
    const receipt = await rpc('eth_getTransactionReceipt', [hash]);
    if (receipt) { assert.equal(receipt.status, '0x1'); return receipt; }
    await delay(20);
  }
  throw new Error('Local transaction was not mined');
}
const checks = [];
const pass = (label) => { checks.push(label); console.log(`PASS: ${label}`); };
let browser;
let server;
let remoteDown = false;
const errors = [];
const failedLocalResources = [];
const browserConsole = [];
const accessibility = [];
async function audit(page, state) {
  if (!process.env.IMDPOT_AXE) return;
  await page.addScriptTag({ path: process.env.IMDPOT_AXE });
  const result = await page.evaluate(async () => {
    const scan = await window.axe.run(document, { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'] } });
    return { violations: scan.violations.map((v) => ({ id: v.id, impact: v.impact, nodes: v.nodes.map((n) => n.target) })), incomplete: scan.incomplete.map((v) => v.id), passes: scan.passes.length };
  });
  accessibility.push({ state, ...result });
  assert.deepEqual(result.violations, [], `Accessibility violations in ${state}`);
}
try {
  for (let i = 0; ; ++i) {
    try { await rpc('eth_chainId'); break; }
    catch (e) { if (i > 50 || anvil.exitCode !== null) throw new Error(anvilError || e.message); await delay(100); }
  }
  await rpc('anvil_impersonateAccount', [owner]);
  await rpc('anvil_setBalance', [owner, '0x3635c9adc5dea00000']);
  // Run the real constructors, then relocate their code and initial storage to the public
  // handoff addresses in this LOCAL chain so the production site needs no test configuration.
  const localGame = (await send(undefined, gameArtifact.bytecode.object + owner.slice(2).padStart(64, '0'))).contractAddress;
  const localToken = (await send(undefined, tokenArtifact.bytecode.object + '12'.padStart(64, '0'))).contractAddress;
  await rpc('anvil_setCode', [pot, await rpc('eth_getCode', [localGame, 'latest'])]);
  await rpc('anvil_setCode', [token, await rpc('eth_getCode', [localToken, 'latest'])]);
  const layout = JSON.parse(execFileSync('forge', ['inspect', 'IMDPot', 'storage-layout', '--json'], { encoding: 'utf8' }));
  for (const entry of layout.storage) {
    const slot = `0x${BigInt(entry.slot).toString(16)}`;
    await rpc('anvil_setStorageAt', [pot, slot, await rpc('eth_getStorageAt', [localGame, slot, 'latest'])]);
  }
  await rpc('anvil_setStorageAt', [token, '0x0', await rpc('eth_getStorageAt', [localToken, '0x0', 'latest'])]);
  await send(token, encodeFunctionData({ abi: tokenArtifact.abi, functionName: 'mint', args: [owner, 10n ** 21n] }));
  const client = createPublicClient({ cacheTime: 0, transport: custom({ request: ({ method, params }) => rpc(method, params) }) });
  const read = (functionName, args = []) => client.readContract({ address: pot, abi: gameAbi, functionName, args });

  const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.css': 'text/css', '.svg': 'image/svg+xml', '.woff2': 'font/woff2', '.png': 'image/png' };
  server = createServer(async (request, response) => {
    if (request.url === '/wallet-rpc' && request.method === 'POST') {
      let body = ''; for await (const data of request) body += data;
      const payload = JSON.parse(body);
      try {
        if (payload.method === 'eth_sendTransaction') {
          assert.equal(payload.params[0].from.toLowerCase(), owner);
          payload.params[0].gas ??= '0x989680';
        }
        response.setHeader('Content-Type', 'application/json');
        response.end(JSON.stringify({ result: await rpc(payload.method, payload.params) }));
      } catch (e) { response.end(JSON.stringify({ error: { message: e.message, code: e.code ?? -32603 } })); }
      return;
    }
    const relative = decodeURIComponent(new URL(request.url, 'http://local').pathname).replace(/^\/preview\//, '');
    const path = resolve('dist', relative || 'index.html');
    if (!path.startsWith(resolve('dist') + '/') || !existsSync(path)) { response.writeHead(404); response.end('Not found'); return; }
    response.setHeader('Content-Type', mime[extname(path)] ?? 'application/octet-stream');
    response.end(readFileSync(path));
  });
  server.listen(0, '127.0.0.1'); await once(server, 'listening');
  const url = `http://127.0.0.1:${server.address().port}/preview/`;
  browser = await playwright[engine].launch({ headless: true, ...(engine === 'chromium' ? { args: ['--no-sandbox'] } : {}) });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 1 });
  const interceptRPC = async (route) => {
    if (remoteDown) { await route.abort('failed'); return; }
    const payload = route.request().postDataJSON();
    async function local(item) {
      try { return { jsonrpc: '2.0', id: item.id, result: await rpc(item.method, item.params) }; }
      catch (e) { return { jsonrpc: '2.0', id: item.id, error: { code: e.code ?? -32603, message: e.message } }; }
    }
    await route.fulfill({ contentType: 'application/json', body: JSON.stringify(Array.isArray(payload) ? await Promise.all(payload.map(local)) : await local(payload)) });
  };
  await context.route(/^https:\/\/(ethereum-rpc\.publicnode\.com|eth\.drpc\.org)/, interceptRPC);
  await context.addInitScript(({ account }) => {
    const listeners = new Map();
    let connected = sessionStorage.getItem('imdpot-test-connected') === 'yes';
    window.testWallet = { chainId: '0x1', rejectNext: false, rejectConnect: false, requests: [] };
    const emit = (name, data) => (listeners.get(name) ?? []).forEach((fn) => fn(data));
    const provider = {
      on(name, fn) { listeners.set(name, [...(listeners.get(name) ?? []), fn]); },
      removeListener(name, fn) { listeners.set(name, (listeners.get(name) ?? []).filter((candidate) => candidate !== fn)); },
      async request({ method, params = [] }) {
        window.testWallet.requests.push({ method, params });
        if (method === 'eth_accounts') return connected ? [account] : [];
        if (method === 'eth_chainId') return window.testWallet.chainId;
        if (method === 'eth_requestAccounts') {
          if (window.testWallet.rejectConnect) { window.testWallet.rejectConnect = false; throw Object.assign(new Error('User rejected request'), { code: 4001 }); }
          connected = true; sessionStorage.setItem('imdpot-test-connected', 'yes'); return [account];
        }
        if (method === 'wallet_switchEthereumChain') { window.testWallet.chainId = params[0].chainId; emit('chainChanged', params[0].chainId); return null; }
        if (method === 'wallet_revokePermissions') { connected = false; sessionStorage.removeItem('imdpot-test-connected'); return null; }
        if (method === 'wallet_getCapabilities') return {};
        if (method === 'eth_sendTransaction' && window.testWallet.rejectNext) { window.testWallet.rejectNext = false; throw Object.assign(new Error('User rejected request'), { code: 4001 }); }
        const result = await (await fetch('/wallet-rpc', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ method, params }) })).json();
        if (result.error) throw Object.assign(new Error(result.error.message), result.error);
        return result.result;
      },
    };
    window.testWallet.setChain = (id) => { window.testWallet.chainId = id; emit('chainChanged', id); };
    window.ethereum = provider;
    const announce = () => window.dispatchEvent(new CustomEvent('eip6963:announceProvider', { detail: { provider, info: { uuid: '7d68a001-071e-423f-ab82-d345160fc531', name: 'Local test wallet', rdns: 'test.imdpot', icon: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20"><circle fill="lime" cx="10" cy="10" r="10"/></svg>' } } }));
    window.addEventListener('eip6963:requestProvider', announce); announce();
  }, { account: owner });
  const page = await context.newPage();
  page.on('console', (message) => {
    if (['error', 'warning'].includes(message.type())) browserConsole.push({ type: message.type(), text: message.text(), location: message.location().url, intentionalRpcOutage: remoteDown });
  });
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('response', (r) => { if (r.url().startsWith(url) && r.status() >= 400) failedLocalResources.push(`${r.status()} ${r.url()}`); });
  page.setDefaultTimeout(12000);
  await page.goto(url);
  await page.getByText('Awaiting setup', { exact: true }).waitFor();
  const buy = page.locator('.buy-button');
  const box = await buy.boundingBox();
  assert.ok(box && box.y + box.height <= 844, 'Primary action must fit on the first 390px screen');
  assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true);
  await page.screenshot({ path: `${output}/390-initial.png` });
  await audit(page, '390px initial game');
  pass('390px first screen contains the game and Buy tickets; unconfigured chain state is honest');
  await page.getByLabel('Number of tickets').fill('1.5');
  await buy.click();
  assert.equal(await page.getByLabel('Number of tickets').getAttribute('aria-invalid'), 'true');
  assert.equal(await page.getByLabel('Number of tickets').evaluate((e) => e === document.activeElement), true);
  await page.getByRole('button', { name: '10 tickets', exact: true }).click();
  assert.equal(await page.getByLabel('Number of tickets').inputValue(), '10');
  await buy.click();
  const dialog = page.getByRole('dialog');
  await dialog.getByRole('button', { name: 'Local test wallet' }).waitFor();
  assert.equal(await dialog.getByRole('button', { name: 'Browser wallet', exact: true }).count(), 0);
  await page.keyboard.press('Escape');
  assert.equal(await dialog.count(), 0);
  assert.equal(await buy.evaluate((e) => e === document.activeElement), true);
  pass('Quantity validation, presets, named EIP-6963 discovery, Escape and focus return');

  await page.getByRole('button', { name: 'Connect wallet', exact: true }).click();
  await page.evaluate(() => { window.testWallet.rejectConnect = true; });
  await dialog.getByRole('button', { name: 'Local test wallet' }).click();
  await dialog.getByText('Request declined in your wallet. You can try again.').waitFor();
  await dialog.getByRole('button', { name: 'Local test wallet' }).click();
  await page.getByRole('heading', { name: 'Owner controls', exact: true }).waitFor();
  assert.equal(await buy.isDisabled(), true);
  await page.locator('.owner-panel').getByRole('button', { name: 'Configure IMD token', exact: true }).click();
  await dialog.getByRole('button', { name: 'Set IMD token permanently', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  assert.equal((await read('token')).toLowerCase(), token);
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  pass('Rejected connection recovers; owner panel configures the pinned token through a confirmed local transaction');

  await page.evaluate(() => window.testWallet.setChain('0xa'));
  await page.getByRole('button', { name: 'Switch to Ethereum', exact: true }).first().waitFor();
  await page.getByRole('button', { name: 'Switch to Ethereum', exact: true }).first().click();
  await page.waitForFunction(() => window.testWallet.chainId === '0x1');
  await page.waitForFunction(() => !document.querySelector('.buy-button').disabled);
  await page.waitForFunction(() => document.querySelector('.ticket-hint').textContent.includes('Balance:'));
  pass('Wrong-network state switches the wallet back to Ethereum');

  await page.getByLabel('Number of tickets').fill('3');
  await buy.click();
  await dialog.getByRole('heading', { name: 'Review your tickets', exact: true }).waitFor();
  assert.ok((await dialog.innerText()).includes(pot), 'Review shows the full verified game address');
  assert.equal(await dialog.evaluate((e) => e.scrollWidth <= e.clientWidth), true, 'Review does not clip the address');
  await page.screenshot({ path: `${output}/390-purchase-review.png` });
  await audit(page, '390px purchase review');
  await dialog.getByRole('button', { name: 'Approve & buy tickets', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  assert.equal(await read('ticketsOf', [1n, owner]), 3n);
  const calls = await page.evaluate(() => window.testWallet.requests.filter((r) => r.method === 'eth_sendTransaction'));
  assert.equal(calls.at(-2).params[0].to.toLowerCase(), token);
  assert.equal(calls.at(-1).params[0].to.toLowerCase(), pot);
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  await page.getByText('Round live', { exact: true }).waitFor();
  pass('Review, exact ERC20 approval, buyTicketsForRound and receipt confirmation purchase three real local tickets');

  await page.evaluate(() => { window.testWallet.rejectNext = true; });
  await buy.click();
  await dialog.getByRole('button', { name: 'Approve & buy tickets', exact: true }).click();
  await dialog.getByText('Action not completed', { exact: true }).waitFor();
  await dialog.getByText('Request declined in your wallet. You can try again.').waitFor();
  assert.equal(await read('ticketsOf', [1n, owner]), 3n);
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  pass('Rejected transaction is recoverable and does not add tickets');

  let round = await read('getRound', [1n]);
  await rpc('evm_setNextBlockTimestamp', [Number(round.endTime)]); await rpc('evm_mine');
  await page.reload();
  await page.getByText('Ready to draw', { exact: true }).waitFor();
  await page.getByRole('button', { name: 'Finalize round', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  assert.equal((await read('getRound', [1n])).status, 2);
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  await rpc('anvil_mine', ['0x4', '0x1']);
  await page.reload();
  await page.getByRole('button', { name: 'Settle winners', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  assert.equal(await read('currentRoundId'), 2n);
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  await page.getByRole('button', { name: 'Claim prizes', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  assert.equal(await read('claimable', [owner]), 0n);
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  pass('Chain deadline closes entries; commit, target-block settlement and claim work through the production UI');

  await page.getByLabel('Number of tickets').fill('1');
  await buy.click();
  await dialog.getByRole('button', { name: 'Approve & buy tickets', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  await page.locator('.owner-panel').getByRole('button', { name: 'Pause contract', exact: true }).click();
  await dialog.getByRole('button', { name: 'Pause contract', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  assert.equal(await read('paused'), true);
  await page.locator('.buy-button').getByText('Entries paused', { exact: true }).waitFor();
  assert.equal(await buy.isDisabled(), true);
  await page.locator('.owner-panel').getByRole('button', { name: 'Unpause contract', exact: true }).click();
  await dialog.getByRole('button', { name: 'Unpause contract', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  assert.equal(await read('paused'), false);
  pass('Owner pause and resume confirmations change the actual local contract and entry availability');

  round = await read('getRound', [2n]);
  await rpc('evm_setNextBlockTimestamp', [Number(round.endTime)]); await rpc('evm_mine');
  await page.reload();
  await page.getByText('Ready to draw', { exact: true }).waitFor();
  await page.getByRole('button', { name: 'Finalize round', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  await rpc('anvil_mine', ['0x105', '0x1']);
  await page.reload();
  await page.getByText('Draw expired', { exact: true }).first().waitFor();
  await page.getByText('Round tools & refunds', { exact: true }).click();
  await page.getByRole('button', { name: 'Cancel round for refunds', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  await page.getByLabel('Check a cancelled round for a refund').fill('2');
  await page.getByRole('button', { name: 'Check refund', exact: true }).click();
  await page.getByRole('button', { name: 'Claim refund', exact: true }).click();
  await dialog.getByText('Confirmed on Ethereum', { exact: true }).waitFor();
  await dialog.getByRole('button', { name: 'Back to the table', exact: true }).click();
  assert.equal(await read('totalRefundable'), 0n);
  assert.equal((await read('getPlayer', [owner]))[0], 3n);
  pass('Expired draw cancellation, refund lookup and full refund work; cancelled tickets earn no loyalty points');

  await page.evaluate(() => { window.actualNow = Date.now; Date.now = () => window.actualNow() + 61000; });
  await page.getByText('Live reads are unavailable', { exact: true }).waitFor();
  assert.equal(await buy.isDisabled(), true);
  await page.evaluate(() => { Date.now = window.actualNow; });
  pass('Stale chain data disables transactions after 60 seconds (clock advanced in test)');

  remoteDown = true;
  await page.reload();
  await page.getByText('Live reads are unavailable', { exact: true }).waitFor();
  remoteDown = false;
  await page.getByRole('button', { name: 'Retry connection', exact: true }).click();
  await page.getByText('Table open', { exact: true }).waitFor();
  pass('Unavailable RPC shows a recovery action; retry restores actual contract data');

  const mobile = await browser.newContext({ viewport: { width: 390, height: 844 }, isMobile: true, userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148' });
  await mobile.route(/^https:\/\/(ethereum-rpc\.publicnode\.com|eth\.drpc\.org)/, interceptRPC);
  const phone = await mobile.newPage();
  phone.on('pageerror', (e) => errors.push(e.message));
  phone.on('console', (message) => {
    if (['error', 'warning'].includes(message.type())) browserConsole.push({ type: message.type(), text: message.text(), location: message.location().url, intentionalRpcOutage: remoteDown });
  });
  await phone.goto(url);
  await phone.getByRole('button', { name: 'Connect wallet', exact: true }).click();
  for (const name of ['MetaMask', 'Coinbase Wallet', 'Rabby', 'Phantom']) {
    const link = phone.getByRole('link', { name: `Open in ${name}`, exact: true });
    assert.ok((await link.getAttribute('href')).includes(encodeURIComponent(url)) || (await link.getAttribute('href')).includes(url.replace(/^https?:\/\//, '')));
  }
  await phone.getByRole('button', { name: 'Coinbase Smart Wallet', exact: true }).waitFor();
  assert.equal(await phone.getByRole('button', { name: 'Browser wallet', exact: true }).count(), 0);
  assert.equal(await phone.locator('dialog').evaluate((e) => e.scrollWidth <= e.clientWidth), true);
  for (let stop = 0; stop < 10; ++stop) {
    await phone.keyboard.press('Tab');
    assert.equal(await phone.evaluate(() => !!document.activeElement.closest('dialog') ||
      (document.activeElement === document.body && document.querySelector('dialog').matches(':modal'))), true,
    'Keyboard focus stays in the native modal or browser chrome, never background controls');
  }
  await audit(phone, '390px phone wallet sheet');
  await phone.screenshot({ path: `${output}/390-phone-wallet-sheet.png` });
  await mobile.close();
  pass('Phone without injection offers four current-page wallet links and Coinbase Smart Wallet in a bottom sheet');

  for (const width of [320, 390, 768, 1440]) {
    await page.setViewportSize({ width, height: width === 1440 ? 1000 : 844 });
    await page.evaluate(() => scrollTo(0, 0));
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, `Overflow at ${width}px`);
    await page.screenshot({ path: `${output}/${width}-configured.png`, fullPage: true });
  }
  pass('No horizontal overflow at 320, 390, 768 and 1440px with a connected owner and real local data');
  assert.deepEqual(errors, []); assert.deepEqual(failedLocalResources, []);
  pass('No browser exceptions or failed local asset requests at the /preview/ hosting subpath');
  if (accessibility.length) pass('axe-core WCAG A/AA audit has no violations in initial game, purchase review and phone wallet sheet');
  writeFileSync(`${output}/results.json`, JSON.stringify({ checks, errors, failedLocalResources, browserConsole, accessibility }, null, 2));
} catch (error) {
  console.error(error);
  if (browser) {
    const pages = browser.contexts().flatMap((context) => context.pages());
    if (pages[0]) {
      await pages[0].screenshot({ path: `${output}/failure.png`, fullPage: true }).catch(() => {});
      writeFileSync(`${output}/failure.txt`, await pages[0].locator('body').innerText().catch(() => 'Page unavailable'));
    }
  }
  process.exitCode = 1;
} finally {
  if (browser) await browser.close();
  if (server) { server.closeAllConnections(); await new Promise((done) => server.close(done)); }
  anvil.kill('SIGTERM'); await anvilExit;
}
