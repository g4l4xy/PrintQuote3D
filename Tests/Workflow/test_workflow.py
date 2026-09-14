import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

spec = importlib.util.spec_from_file_location('workflow', Path(__file__).resolve().parents[2] / 'tools/workflow.py')
w = importlib.util.module_from_spec(spec)
spec.loader.exec_module(w)

class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = Path(self.tmp.name)
        self.repo = self.base / 'local'
        self.remote = self.base / 'remote.git'
        self.oldroot = w.ROOT
        self.cmd('git', 'init', '--bare', str(self.remote))
        self.cmd('git', 'clone', str(self.remote), str(self.repo))
        w.ROOT = self.repo
        self.g('config', 'user.name', 'Workflow test')
        self.g('config', 'user.email', 'test@example.invalid')
        self.g('checkout', '-b', 'main')
        (self.repo / 'initial').write_text('initial')
        self.g('add', '.'); self.g('commit', '-m', 'initial'); self.g('push', '-u', 'origin', 'main')
    def tearDown(self):
        w.ROOT = self.oldroot
        self.tmp.cleanup()
    def cmd(self, *args, cwd=None):
        return subprocess.run(args, cwd=cwd, text=True, capture_output=True, check=True).stdout.strip()
    def g(self, *args): return self.cmd('git', *args, cwd=self.repo)
    def test_selected_push_leaves_other_files_uncommitted(self):
        (self.repo / 'apple').write_text('a'); (self.repo / 'android').write_text('b')
        w.publish('Apple change', ['apple'], False)
        self.assertEqual(self.g('rev-parse', 'HEAD'), self.g('rev-parse', 'origin/main'))
        self.assertIn('?? android', self.g('status', '--porcelain'))
        self.assertEqual(self.g('show', '--format=', '--name-only', 'HEAD'), 'apple')
    def test_dirty_pull_does_not_discard(self):
        (self.repo / 'initial').write_text('local edit')
        with self.assertRaises(ValueError): w.sync_pull()
        self.assertEqual((self.repo / 'initial').read_text(), 'local edit')
    def test_staged_selection_is_protected(self):
        (self.repo / 'initial').write_text('staged'); self.g('add', 'initial')
        with self.assertRaises(ValueError): w.publish('no', [], True)
        self.assertEqual(self.g('diff', '--cached', '--name-only'), 'initial')
    def test_feature_creates_both_platform_checklist(self):
        w.feature('example-feature', 'Example')
        self.assertEqual(self.g('branch', '--show-current'), 'feature/example-feature')
        text = (self.repo / 'docs/features/example-feature.md').read_text()
        self.assertIn('Apple:', text); self.assertIn('Android:', text)
        self.assertIn('SharedSchemas/', text)
    def test_invalid_slug_does_not_switch_branch(self):
        with self.assertRaises(ValueError): w.feature('../bad', 'Bad')
        self.assertEqual(self.g('branch', '--show-current'), 'main')
    def test_pull_gets_both_platform_updates(self):
        other = self.base / 'other'
        self.cmd('git', 'clone', '-b', 'main', str(self.remote), str(other))
        self.cmd('git', 'config', 'user.name', 'Test', cwd=other)
        self.cmd('git', 'config', 'user.email', 'test@example.invalid', cwd=other)
        for name in ['apple', 'android']: (other / name).write_text('updated')
        self.cmd('git', 'add', '.', cwd=other); self.cmd('git', 'commit', '-m', 'both', cwd=other)
        self.cmd('git', 'push', cwd=other)
        w.sync_pull()
        self.assertEqual((self.repo / 'apple').read_text(), 'updated')
        self.assertEqual((self.repo / 'android').read_text(), 'updated')

if __name__ == '__main__': unittest.main()
