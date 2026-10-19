import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { execFileSync } from 'node:child_process';

test('the production build verifies the attested ABI and deployment before copying', () => {
  const output = execFileSync('node', ['tools/verify_deployment.mjs', '--offline'], { encoding: 'utf8', cwd: resolve(import.meta.dirname, '..') });
  assert.match(output, /PASS: pinned ABI/);
});

test('the export contains the same deployment and complete runtime as the editable site', () => {
  const root = resolve(import.meta.dirname, '..');
  for (const name of ['deployment.json', 'site-config.json', 'release.json', 'index.html', 'network.mjs', 'purchase.mjs', 'game-rules.mjs', 'contract-verification.mjs']) {
    assert.deepEqual(readFileSync(resolve(root, 'dist', name)), readFileSync(resolve(root, 'web', name)), name);
  }
  for (const folder of ['assets-future-v1', 'wallets']) {
    for (const name of readdirSync(resolve(root, 'web', folder))) {
      assert.deepEqual(readFileSync(resolve(root, 'dist', folder, name)), readFileSync(resolve(root, 'web', folder, name)), `${folder}/${name}`);
    }
  }
});

test('static entry assets and share metadata resolve relative to a hosting subpath', () => {
  const root = resolve(import.meta.dirname, '..');
  const html = readFileSync(resolve(root, 'dist/index.html'), 'utf8');
  for (const match of html.matchAll(/(?:src|href)="([^"]+)"/g)) {
    assert.ok(match[1].startsWith('./'), `Absolute local asset ${match[1]}`);
    assert.ok(readFileSync(resolve(root, 'dist', match[1])).length > 0);
  }
  const image = html.match(/property="og:image" content="([^"]+)"/)[1];
  assert.ok(readFileSync(resolve(root, 'dist', image)).length > 1000);
  assert.match(html, /<title>IMDPot/);
  assert.match(html, /name="description"/);
  assert.match(html, /property="og:title"/);
});
