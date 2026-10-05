"""Local setup regression checks; use the configured Python 3.12 runtime."""
import importlib.util
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fetch_model',ROOT/'spikes/m0/fetch_model.py')
fetch=importlib.util.module_from_spec(spec)
spec.loader.exec_module(fetch)

class SetupChecks(unittest.TestCase):
    def test_corruption_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder)
            for name in fetch.CHECKSUMS:(root/name).write_bytes(b'damaged model')
            with self.assertRaisesRegex(RuntimeError,'Checksum mismatch'):
                fetch.verify(root)

    def test_missing_asset_is_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            with self.assertRaises(FileNotFoundError):fetch.verify(Path(folder))

    def test_download_is_pinned_and_provenance_follows_validation(self):
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(fetch,'snapshot_download') as download, patch.object(fetch,'verify',side_effect=RuntimeError('bad checksum')):
                with patch('sys.argv',['fetch_model','--output',folder]):
                    with self.assertRaisesRegex(RuntimeError,'bad checksum'):fetch.main()
            self.assertEqual(download.call_args.kwargs['revision'],fetch.REVISION)
            self.assertFalse((Path(folder)/'provenance.json').exists())

    def test_verify_only_never_downloads(self):
        with tempfile.TemporaryDirectory() as folder:
            with patch.object(fetch,'snapshot_download') as download:
                with patch('sys.argv',['fetch_model','--output',folder,'--verify-only']):
                    with self.assertRaises(FileNotFoundError):fetch.main()
            download.assert_not_called()

if __name__=='__main__':unittest.main()
