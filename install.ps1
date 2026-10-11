param([string]$UserDir, [string]$PackageDir)
$ErrorActionPreference = 'Stop'
$taskRoot = $PSScriptRoot
$taskPython = Get-Command python -ErrorAction SilentlyContinue
if (-not $taskPython) { throw '请先安装 Python 3.10 或更新版本，并加入 PATH。' }
$venvPython = Join-Path $taskRoot '.venv/Scripts/python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) {
    & $taskPython.Source -m venv (Join-Path $taskRoot '.venv')
    if ($LASTEXITCODE -ne 0) { throw '创建安装器环境失败。' }
}
& $venvPython -m pip install -r (Join-Path $taskRoot 'requirements.txt')
if ($LASTEXITCODE -ne 0) { throw '安装依赖失败。' }
$taskArgs = @((Join-Path $taskRoot 'scripts/install.py'))
if ($UserDir) { $taskArgs += @('--user-dir', $UserDir) }
if ($PackageDir) { $taskArgs += @('--package-dir', $PackageDir) }
& $venvPython @taskArgs
if ($LASTEXITCODE -ne 0) { throw '安装未完成，请检查上方错误。' }
