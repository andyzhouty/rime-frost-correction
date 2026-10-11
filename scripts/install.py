"""Install only this schema and clean pinned upstream resources; preserve user data."""
import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SCHEMA = 'frost_correction'


def default_user_dir(frontend=None):
    if sys.platform == 'win32':
        return Path(os.environ['APPDATA']) / 'Rime'
    if sys.platform == 'darwin':
        return Path.home() / 'Library/Rime'
    if frontend == 'ibus':
        return Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config')) / 'ibus/rime'
    if frontend == 'fcitx':
        return Path(os.environ.get('XDG_CONFIG_HOME', Path.home()/'.config')) / 'fcitx/rime'
    return Path(os.environ.get('XDG_DATA_HOME', Path.home()/'.local/share')) / 'fcitx5/rime'


def add_menu(data):
    if data is None:
        data = {}
    if not isinstance(data, dict):
        raise ValueError('default.custom.yaml must contain a mapping')
    patch = data.setdefault('patch', {})
    if not isinstance(patch, dict):
        raise ValueError('patch must contain a mapping')
    # Explicit menu replacement wins over additive patch; append directly there.
    key = 'schema_list' if 'schema_list' in patch else 'schema_list/+'
    rows = patch.setdefault(key, [])
    if not isinstance(rows, list):
        raise ValueError('schema_list must be a list; configure the menu manually')
    present = any(isinstance(r, dict) and r.get('schema') == SCHEMA for r in rows)
    if not present:
        rows.append({'schema': SCHEMA})
    return data


def verified_resource(lock, name, cache, source=None):
    info = lock['files'][name]
    cached = cache/name
    def valid(path):
        if not path.is_file() or path.stat().st_size != info['size']:
            return False
        content = path.read_bytes()
        blob = b'blob ' + str(len(content)).encode() + b'\0' + content
        return hashlib.sha1(blob).hexdigest() == info['git_blob_sha1']
    if source:
        path = source/name
        if not valid(path):
            raise ValueError('Offline source does not match pinned upstream: '+name)
        return path.read_bytes()
    if not valid(cached):
        url = f"https://raw.githubusercontent.com/{lock['repository']}/{lock['revision']}/{name}"
        cached.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(url, timeout=120) as response:
            data = response.read()
        candidate = cached.with_suffix(cached.suffix+'.download')
        candidate.write_bytes(data)
        if not valid(candidate):
            candidate.unlink()
            raise ValueError('Upstream integrity check failed: '+name)
        candidate.replace(cached)
    return cached.read_bytes()


def assemble(stage, source=None):
    lock = json.loads((ROOT/'scripts/upstream-lock.json').read_text(encoding='utf-8'))
    shutil.copytree(ROOT/'rime', stage, dirs_exist_ok=True)
    for name in lock['files']:
        content = verified_resource(lock, name, ROOT/'.cache/upstream', source)
        target = stage/name if name == 'zh-moqi.gram' else stage/'frost_correction_upstream'/name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    imports = ['frost_correction_upstream/cn_dicts/'+n for n in ('8105','base','ext','others')]
    dictionary = {'name': 'frost_correction_base', 'version': lock['revision'], 'sort': 'by_weight', 'use_preset_vocabulary': False, 'import_tables': imports}
    (stage/'frost_correction_base.dict.yaml').write_text('# Generated from clean pinned upstream dictionaries.\n---\n'+yaml.safe_dump(dictionary,allow_unicode=True,sort_keys=False)+'...\n',encoding='utf-8')


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def install(stage, user_dir, menu=True):
    user_dir = user_dir.resolve()
    user_dir.mkdir(parents=True, exist_ok=True)
    if menu:
        config = user_dir/'default.custom.yaml'
        existing = yaml.safe_load(config.read_text(encoding='utf-8-sig')) if config.exists() else {}
        updated = add_menu(existing)
        (stage/'default.custom.yaml').write_text(yaml.safe_dump(updated,allow_unicode=True,sort_keys=False),encoding='utf-8')
    files = sorted(p.relative_to(stage) for p in stage.rglob('*') if p.is_file())
    # Never replace a differently versioned model already shared by other schemas.
    model = user_dir/'zh-moqi.gram'
    if model.exists() and sha(model) != sha(stage/'zh-moqi.gram'):
        raise ValueError('Existing zh-moqi.gram differs; use --package-dir and configure a separate model name')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = user_dir/'.frost-correction-backups'/stamp
    backup.mkdir(parents=True)
    manifest = {'user_dir': str(user_dir), 'files': {}}
    for rel in files:
        dest = user_dir/rel
        if dest.is_symlink() or any(p.is_symlink() for p in dest.parents if p != user_dir.parent):
            raise ValueError('Refusing symlink installation path: '+str(dest))
        had = dest.is_file()
        if dest.exists() and not had:
            raise ValueError('Destination is not a file: '+str(dest))
        if had:
            old = backup/'files'/rel
            old.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(dest, old)
        manifest['files'][rel.as_posix()] = {'existed': had, 'installed_sha256': sha(stage/rel)}
    # Backup metadata is written before modification; a failed partial install is recoverable.
    record = backup/'restore.json'
    record.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    try:
        for rel in files:
            dest = user_dir/rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(stage/rel, dest)
    except Exception:
        rollback(record, force=True)
        raise
    return record


def rollback(record, force=False):
    record = record.resolve()
    manifest = json.loads(record.read_text(encoding='utf-8'))
    user = Path(manifest['user_dir']).resolve()
    targets = []
    for relative, info in manifest['files'].items():
        rel = Path(relative)
        dest = (user/rel).resolve()
        if rel.is_absolute() or not dest.is_relative_to(user):
            raise ValueError('Invalid restore path')
        if dest.exists() and not force and sha(dest) != info['installed_sha256']:
            raise ValueError('File changed after installation; preserve your edits before rollback: '+str(dest))
        targets.append((rel, dest, info))
    for rel, dest, info in targets:
        if info['existed']:
            dest.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(record.parent/'files'/rel,dest)
        elif dest.is_file():
            dest.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--user-dir',type=Path)
    parser.add_argument('--frontend',choices=['ibus','fcitx','fcitx5'])
    parser.add_argument('--source-dir',type=Path,help='Offline clean upstream checkout at locked revision')
    parser.add_argument('--package-dir',type=Path,help='Prepare an import folder instead of installing (Android)')
    parser.add_argument('--no-menu',action='store_true')
    parser.add_argument('--rollback',type=Path,help='restore.json printed by installation')
    args=parser.parse_args()
    if args.rollback:
        rollback(args.rollback)
        print('已回退配置。请重新部署；本地学习数据保留。')
        return
    with tempfile.TemporaryDirectory(prefix='frost-correction-') as temporary:
        stage=Path(temporary)/'rime'
        assemble(stage,args.source_dir)
        if args.package_dir:
            # Import must not overwrite Android's existing menu or other customization.
            if args.package_dir.exists():
                raise ValueError('Package directory must not already exist')
            shutil.copytree(stage,args.package_dir)
            print('导入目录：'+str(args.package_dir.resolve())+'；导入后在前端启用 frost_correction 并部署。')
        else:
            record=install(stage,args.user_dir or default_user_dir(args.frontend),not args.no_menu)
            print('安装完成。请在输入法中重新部署并选择“白霜纠错增强”。')
            print('回退记录：'+str(record))


if __name__ == '__main__':
    main()
