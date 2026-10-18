#!/usr/bin/env python3
"""Build the existing website against a confirmed fresh deployment. Read-only RPC; never signs."""
import argparse
import json
import re
import shutil
import socket
import subprocess
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PREVIOUS = '0x37cb0333a2fea358ae057bd85c4437803e5bcbfa'
LAUNCH_OWNER = '0x34284c5c4c54d5f8e7e14e2d1a3dcd48899928ea'


def rpc(url, method, params):
    payload = json.dumps({
        'jsonrpc': '2.0', 'id': 1, 'method': method, 'params': params,
    }).encode()
    if url.startswith('ipc:'):
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as connection:
            connection.settimeout(30)
            connection.connect(url[4:])
            connection.sendall(payload + b'\n')
            body = b''
            while True:
                chunk = connection.recv(65536)
                if not chunk:
                    raise ValueError('IPC closed without a complete JSON response')
                body += chunk
                try:
                    data = json.loads(body)
                    break
                except json.JSONDecodeError:
                    if len(body) > 1_000_000:
                        raise ValueError('IPC response exceeds one megabyte')
    else:
        request = urllib.request.Request(url, data=payload, headers={'Content-Type': 'application/json'})
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        with opener.open(request, timeout=30) as response:
            data = json.load(response)
    if 'error' in data:
        raise ValueError(f"RPC {method} failed: {data['error']}")
    if 'result' not in data:
        raise ValueError(f'RPC {method} returned no result')
    return data['result']


def build(address, block, url, destination):
    address = address.lower()
    if not re.fullmatch(r'0x[0-9a-f]{40}', address):
        raise ValueError('Use the confirmed fresh contract address from the launch handoff.')
    if address in (PREVIOUS, '0x' + '0' * 40, '0x' + '0' * 36 + 'dead'):
        raise ValueError('The previous contract or an unset/burn address cannot be used.')
    if block < 1:
        raise ValueError('Use the actual positive deployment block from the launch handoff.')
    if int(rpc(url, 'eth_chainId', []), 16) != 1:
        raise ValueError('The deployment must be on Ethereum, chain 1.')
    artifact = json.loads((ROOT / 'out/IMDPot.sol/IMDPot.json').read_text())
    runtime = artifact['deployedBytecode']['object'].lower()
    if artifact['deployedBytecode'].get('immutableReferences'):
        raise ValueError('The release tool expects the reviewed contract with no runtime immutables.')
    latest_code = rpc(url, 'eth_getCode', [address, 'latest']).lower()
    if latest_code != runtime or runtime == '0x':
        raise ValueError('Deployed bytecode differs from the local pinned Foundry build.')
    # Prove that the supplied deployment block is the first block containing this runtime.
    if rpc(url, 'eth_getCode', [address, hex(block)]).lower() != runtime:
        raise ValueError('No matching deployment at the supplied deployment block.')
    if rpc(url, 'eth_getCode', [address, hex(block - 1)]) != '0x':
        raise ValueError('The address already had code before the supplied deployment block.')
    # TREASURY is fixed to the launch owner, even after a legitimate ownership transfer.
    selector = subprocess.check_output(['cast', 'sig', 'TREASURY()'], text=True).strip()
    treasury = rpc(url, 'eth_call', [{'to': address, 'data': selector}, 'latest'])
    if treasury.lower() != '0x' + '0' * 24 + LAUNCH_OWNER[2:]:
        raise ValueError('The fee beneficiary differs from the specified launch owner.')
    runtime_hash = subprocess.check_output(['cast', 'keccak', runtime], text=True).strip()
    config = {'chainId': 1, 'contract': address, 'deploymentBlock': str(block), 'runtimeCodeHash': runtime_hash}
    # Prevent accidental deletion, path escape, or overwriting repository source/configuration.
    destination = Path(destination).resolve()
    try:
        relative = destination.relative_to(ROOT)
    except ValueError as error:
        raise ValueError('Output must be inside this repository.') from error
    if not relative.parts or relative.parts[0] not in ('web-release', 'test') or (relative.parts[0] == 'test' and relative.parts[1:2] != ('scratch',)):
        raise ValueError('Output must be web-release/ or inside test/scratch/.')
    if destination.exists():
        raise ValueError('Output already exists; choose a new directory to preserve the previous release.')
    shutil.copytree(ROOT / 'web', destination)
    (destination / 'deployment.json').write_text(json.dumps(config, indent=2) + '\n')
    return config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--address', required=True)
    parser.add_argument('--block', required=True, type=int)
    parser.add_argument('--rpc', required=True, help='Read-only Ethereum RPC URL (or ipc:path); historical code access at the deployment block is needed.')
    parser.add_argument('--out', default=str(ROOT / 'web-release'))
    args = parser.parse_args()
    try:
        config = build(args.address, args.block, args.rpc, args.out)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        parser.exit(1, f'Site release refused: {error}\n')
    print(json.dumps(config, indent=2))
    print(f'Release written to {args.out}; publish its contents to the existing site.')


if __name__ == '__main__':
    main()
