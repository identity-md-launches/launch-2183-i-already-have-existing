#!/usr/bin/env python3
"""Build the existing, captured IMDPot application as a self-contained static export."""
import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / 'web'
DIST = ROOT / 'dist'


def main():
    # Never let a missing or mismatched deployment silently produce a publishable export.
    subprocess.run(['node', str(ROOT / 'tools/verify_deployment.mjs'), '--offline'], cwd=ROOT, check=True)
    if DIST.exists():
        shutil.rmtree(DIST)
    DIST.mkdir()
    files = [p for p in WEB.iterdir() if p.suffix in ('.html', '.mjs', '.svg', '.png')]
    files += [WEB / name for name in ('deployment.json', 'site-config.json', 'release.json')]
    for path in files:
        shutil.copy2(path, DIST / path.name)
    shutil.copytree(WEB / 'assets-future-v1', DIST / 'assets-future-v1')
    if (WEB / 'wallets').is_dir():
        shutil.copytree(WEB / 'wallets', DIST / 'wallets')
    size = sum(p.stat().st_size for p in DIST.rglob('*') if p.is_file())
    print(json.dumps({'export': 'dist/', 'files': sum(p.is_file() for p in DIST.rglob('*')), 'bytes': size}))


if __name__ == '__main__':
    main()
