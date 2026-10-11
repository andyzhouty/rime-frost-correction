#!/bin/sh
set -eu
task_root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
command -v python3 >/dev/null 2>&1 || { echo '请先安装 Python 3.10 或更新版本。' >&2; exit 1; }
if [ ! -x "$task_root/.venv/bin/python" ]; then
  python3 -m venv "$task_root/.venv"
fi
"$task_root/.venv/bin/python" -m pip install -r "$task_root/requirements.txt"
exec "$task_root/.venv/bin/python" "$task_root/scripts/install.py" "$@"
