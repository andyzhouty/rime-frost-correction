import copy
import hashlib
import importlib.util
import json
import tempfile
import unittest
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('installer',ROOT/'scripts/install.py')
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallationTests(unittest.TestCase):
    def test_lua_dependency_closure(self):
        for path in (ROOT/'rime/lua').rglob('*.lua'):
            content=path.read_text(encoding='utf-8')
            for module in re.findall(r"require\s*\(?\s*['\"]([^'\"]+)['\"]",content):
                self.assertTrue((ROOT/'rime/lua'/(module.replace('.','/')+'.lua')).is_file(),module)

    def test_menu_preserves_values_and_is_idempotent(self):
        original={'patch': {'menu/page_size':9, 'schema_list':[{'schema':'existing'}]},'other':42}
        result=installer.add_menu(copy.deepcopy(original))
        self.assertEqual(result['other'],42)
        self.assertEqual(result['patch']['menu/page_size'],9)
        self.assertEqual(result['patch']['schema_list'],[{'schema':'existing'},{'schema':'frost_correction'}])
        self.assertEqual(installer.add_menu(result),result)

    def test_additive_menu_and_invalid_input(self):
        self.assertEqual(installer.add_menu(None)['patch']['schema_list/+'],[{'schema':'frost_correction'}])
        with self.assertRaises(ValueError):
            installer.add_menu({'patch':{'schema_list':'wrong'}})

    def test_install_restore_and_preserve_learning(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); stage=root/'stage'; user=root/'user'
            stage.mkdir(); user.mkdir()
            (stage/'zh-moqi.gram').write_bytes(b'model')
            (stage/'frost_correction.schema.yaml').write_text('new',encoding='utf-8')
            (user/'frost_correction.schema.yaml').write_text('old',encoding='utf-8')
            (user/'default.custom.yaml').write_text('patch:\n  menu/page_size: 9\n',encoding='utf-8')
            original=(user/'default.custom.yaml').read_bytes()
            (user/'frost_correction_selection.tsv').write_bytes(b'private learning')
            record=installer.install(stage,user)
            self.assertEqual((user/'frost_correction.schema.yaml').read_text(),'new')
            installer.rollback(record)
            self.assertEqual((user/'frost_correction.schema.yaml').read_text(),'old')
            self.assertEqual((user/'default.custom.yaml').read_bytes(),original)
            self.assertEqual((user/'frost_correction_selection.tsv').read_bytes(),b'private learning')
            self.assertFalse((user/'zh-moqi.gram').exists())

    def test_rollback_refuses_later_edits(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); stage=root/'stage'; user=root/'user'; stage.mkdir()
            (stage/'zh-moqi.gram').write_bytes(b'model')
            record=installer.install(stage,user)
            (user/'zh-moqi.gram').write_bytes(b'edited')
            with self.assertRaises(ValueError): installer.rollback(record)
            self.assertEqual((user/'zh-moqi.gram').read_bytes(),b'edited')

    def test_offline_integrity(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); (root/'resource').write_bytes(b'abc')
            digest=hashlib.sha1(b'blob 3\0abc').hexdigest()
            lock={'files':{'resource':{'size':3,'git_blob_sha1':digest}}}
            self.assertEqual(installer.verified_resource(lock,'resource',root/'cache',root),b'abc')
            (root/'resource').write_bytes(b'xyz')
            with self.assertRaises(ValueError): installer.verified_resource(lock,'resource',root/'cache',root)

    def test_foreign_model_not_overwritten(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp); stage=root/'stage'; user=root/'user'; stage.mkdir(); user.mkdir()
            (stage/'zh-moqi.gram').write_bytes(b'new')
            (user/'zh-moqi.gram').write_bytes(b'old')
            with self.assertRaises(ValueError): installer.install(stage,user)
            self.assertEqual((user/'zh-moqi.gram').read_bytes(),b'old')


if __name__=='__main__': unittest.main()
