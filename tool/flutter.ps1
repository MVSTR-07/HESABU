# Use the normal SDK when installed, or the local SDK prepared for this machine.
# Run from any directory: .\tool\flutter.ps1 run -d windows
$ErrorActionPreference = 'Stop'
$taskProjectRoot = Split-Path -Parent $PSScriptRoot
$taskFlutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$taskFlutter = if ($taskFlutterCommand) { $taskFlutterCommand.Source } else {
    Join-Path $env:USERPROFILE 'Tools\flutter\bin\flutter.bat'
}
if (-not (Test-Path -LiteralPath $taskFlutter)) {
    throw 'Install Flutter first: https://docs.flutter.dev/install'
}
Push-Location -LiteralPath $taskProjectRoot
try {
    & $taskFlutter @args
    $taskExitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $taskExitCode
