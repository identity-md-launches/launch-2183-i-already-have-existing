// Verify the shipped ABI and handoff; --live also reads Ethereum. This tool never signs.
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { a as keccak256, c as stringToHex } from '../web/assets-future-v1/getAddress-yOC5k4Wk.js';
import { gameAbi } from '../web/game-abi.mjs';
import { validateDeployment } from '../web/config-schema.mjs';
import { network } from '../web/network.mjs';

const root = new URL('../', import.meta.url);
const read = (path) => JSON.parse(readFileSync(new URL(path, root), 'utf8'));
const canonical = (value) => Array.isArray(value) ? value.map(canonical)
  : value && typeof value === 'object'
    ? Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonical(value[key])])) : value;
const deployment = validateDeployment(read('web/deployment.json'));
const release = read('web/release.json');
const hash = keccak256(stringToHex(JSON.stringify(canonical(gameAbi))));
assert.equal(hash.slice(2), release.abiHash, 'ABI does not match the pinned launch');
assert.equal(deployment.chainId, network.chainId);
assert.equal(deployment.contract, release.address);
assert.equal(deployment.deploymentBlock, String(release.blockNumber));
assert.equal(deployment.runtimeCodeHash, release.runtimeCodeHash);

// Check against the pinned source whenever a Foundry artifact is available.
const artifactPath = new URL('out/IMDPot.sol/IMDPot.json', root);
if (existsSync(artifactPath)) {
  const artifact = read('out/IMDPot.sol/IMDPot.json');
  assert.deepEqual(gameAbi, artifact.abi, 'ABI differs from the compiled source');
  assert.equal(keccak256(artifact.bytecode.object).slice(2), release.creationCodeHash, 'Creation code differs from the pinned launch');
  assert.equal(keccak256(artifact.deployedBytecode.object), deployment.runtimeCodeHash, 'Compiled runtime differs from the launch');
}
console.log(`PASS: pinned ABI ${hash}, deployment, chain${existsSync(artifactPath) ? ', compiled runtime' : ''}`);

if (process.argv.includes('--live')) {
  // curl avoids the worker's restricted Node/Python HTTPS transport. Public, read-only RPC only.
  const rpc = (method, params) => {
    const errors = [];
    for (const url of network.rpcUrls) {
      try {
        const data = JSON.parse(execFileSync('curl', ['-sS', '--max-time', '25', url,
          '-H', 'Content-Type: application/json', '--data-binary', '@-'], {
          input: JSON.stringify({ jsonrpc: '2.0', id: 1, method, params }), encoding: 'utf8',
        }));
        if (data.error) throw new Error(JSON.stringify(data.error));
        assert.ok('result' in data, 'RPC returned no result');
        return data.result;
      } catch (error) { errors.push(`${url}: ${error.message}`); }
    }
    throw new Error(errors.join('\n'));
  };
  assert.equal(Number(BigInt(rpc('eth_chainId', []))), deployment.chainId);
  const code = rpc('eth_getCode', [deployment.contract, 'latest']);
  assert.equal(keccak256(code), deployment.runtimeCodeHash, 'Live runtime mismatch');
  const block = BigInt(deployment.deploymentBlock);
  assert.equal(rpc('eth_getCode', [deployment.contract, `0x${block.toString(16)}`]), code);
  assert.equal(rpc('eth_getCode', [deployment.contract, `0x${(block - 1n).toString(16)}`]), '0x');
  const receipt = rpc('eth_getTransactionReceipt', [release.txHash]);
  assert.equal(receipt.status, '0x1');
  // The launch factory may create the game internally; then contractAddress is null.
  if (receipt.contractAddress) assert.equal(receipt.contractAddress.toLowerCase(), deployment.contract);
  else assert.ok(receipt.logs.some((log) => log.address.toLowerCase() === deployment.contract), 'Deployment receipt has no game events');
  assert.equal(BigInt(receipt.blockNumber), block);
  const state = {};
  for (const signature of ['isConfigured()', 'token()', 'currentRoundId()', 'paused()']) {
    const selector = keccak256(stringToHex(signature)).slice(0, 10);
    state[signature] = rpc('eth_call', [{ to: deployment.contract, data: selector }, 'latest']);
  }
  console.log('PASS: live chain, latest runtime, first code block and deployment receipt');
  console.log(JSON.stringify({ address: deployment.contract, head: rpc('eth_blockNumber', []), state }, null, 2));
}
