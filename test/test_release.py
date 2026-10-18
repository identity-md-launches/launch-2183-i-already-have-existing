"""Offline release-tool refusal tests; all addresses below are local test fixtures."""
import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('build_site', ROOT / 'tools/build_site.py')
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTest(unittest.TestCase):
    def setUp(self):
        (ROOT / 'test/scratch').mkdir(exist_ok=True)
        self.temporary = tempfile.TemporaryDirectory(dir=ROOT / 'test/scratch')
        self.addCleanup(self.temporary.cleanup)
        self.destination = Path(self.temporary.name) / 'release'
        self.address = '0x' + '12' * 20
        self.runtime = json.loads((ROOT / 'out/IMDPot.sol/IMDPot.json').read_text())['deployedBytecode']['object']

    def responses(self, url, method, params):
        if method == 'eth_chainId': return '0x1'
        if method == 'eth_call': return '0x' + '0' * 24 + release.LAUNCH_OWNER[2:]
        if method == 'eth_getCode': return '0x' if params[1] == '0x29' else self.runtime
        raise AssertionError(method)

    def test_confirmed_release_writes_verified_handoff(self):
        with patch.object(release, 'rpc', side_effect=self.responses):
            result = release.build(self.address, 42, 'local-test-only', self.destination)
        self.assertEqual(result['contract'], self.address)
        self.assertEqual(result['deploymentBlock'], '42')
        self.assertEqual(json.loads((self.destination / 'deployment.json').read_text()), result)
        self.assertTrue((self.destination / 'assets-future-v1/index-IgEJPNDv.js').exists())

    def test_old_missing_or_burn_address_and_zero_block_rejected_before_rpc(self):
        with patch.object(release, 'rpc') as rpc:
            for address, block in [(release.PREVIOUS, 42), ('pending', 42), ('0x' + '0' * 40, 42), ('0x' + '0' * 36 + 'dead', 42), (self.address, 0)]:
                with self.assertRaises(ValueError): release.build(address, block, 'local-test-only', self.destination)
            rpc.assert_not_called()
        self.assertFalse(self.destination.exists())

    def test_wrong_chain_runtime_block_and_beneficiary_never_write_release(self):
        cases = [
            ('eth_chainId', lambda params: True, '0xa'),
            ('eth_getCode', lambda params: params[1] == 'latest', '0x1234'),
            ('eth_getCode', lambda params: params[1] == '0x2a', '0x'),
            ('eth_getCode', lambda params: params[1] == '0x29', '0x1234'),
            ('eth_call', lambda params: True, '0x' + '0' * 64),
        ]
        for target, matches, response in cases:
            def altered(url, method, params):
                return response if method == target and matches(params) else self.responses(url, method, params)
            with self.subTest(target=target, response=response), patch.object(release, 'rpc', side_effect=altered):
                with self.assertRaises(ValueError): release.build(self.address, 42, 'local-test-only', self.destination)
                self.assertFalse(self.destination.exists())

    def test_source_directory_cannot_be_overwritten(self):
        with patch.object(release, 'rpc', side_effect=self.responses):
            with self.assertRaisesRegex(ValueError, 'web-release'):
                release.build(self.address, 42, 'local-test-only', ROOT / 'web')


if __name__ == '__main__':
    unittest.main()
