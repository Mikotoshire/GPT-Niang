param([switch]$CheckOnly,[string]$UpdateToken)
$ErrorActionPreference='Stop'
Write-Warning 'AI NOTICE: Maintenance changes and added/rewritten docs are AI-generated and insufficiently validated. Tests are limited and do not guarantee correctness, stability or security. See the included AI-NOTICE.md before use.'
$appDir=$PSScriptRoot
. (Join-Path $appDir 'runtime\supervisor-task.ps1')
. (Join-Path $appDir 'runtime\update-common.ps1')
. (Join-Path $appDir 'runtime\install-preflight.ps1')
$config=Get-WidgetInstallPreflight -SourceDir $appDir -AppDir $appDir
if($CheckOnly){@{ok=$true;appDir=$appDir;codex=$config.codexPath;startupShortcut=$config.startupShortcut}|ConvertTo-Json;return}
$lock=Enter-WidgetUpdateLock -Token $UpdateToken
try {
  $journal=Read-WidgetUpdateJson (Join-Path (Get-WidgetUpdateAgentDir) 'update-transaction.json')
  if(!$UpdateToken -and $journal -and $journal.phase-notin @('committed','rolled-back')){throw 'Recover the unfinished update before installing.'}
  $config=Get-WidgetInstallPreflight -SourceDir $appDir -AppDir $appDir
  $null=New-Item -ItemType Directory -Path $config.dataDir -Force
  $config.dataDir=Resolve-WidgetPhysicalPath $config.dataDir
  Stop-WidgetSupervisorTask -AppDir $appDir -Configuration $config
  Stop-WidgetGui -AppDir $appDir -DataDir $config.dataDir
  Install-WidgetUpdateAgent $appDir $config.dataDir
  $config.updateAgent=Get-WidgetUpdateAgentDir
  Write-WidgetSupervisorJson (Join-Path $appDir 'installation.json') $config
  Write-WidgetSupervisorJson (Join-Path $appDir '.mcp.json') @{mcpServers=@{'gpt-niang-usage'=@{command=$config.nodePath;args=@((Join-Path $appDir 'runtime\mcp.mjs'))}}}
  & $config.codexPath plugin marketplace add $config.marketplaceRoot --json
  if($LASTEXITCODE-ne 0){throw 'Codex rejected the local marketplace.'}
  & $config.codexPath plugin add 'gpt-niang-usage@gpt-niang-local' --json
  if($LASTEXITCODE-ne 0){throw 'Codex rejected the GPT Niang plugin.'}
  Assert-WidgetPluginRegistration $config.codexPath $config.version
  $link=(New-Object -ComObject WScript.Shell).CreateShortcut($config.startupShortcut)
  $link.TargetPath=Join-Path $env:WINDIR 'System32\wscript.exe'
  $link.Arguments='"'+(Join-Path $config.updateAgent 'agent-launch.vbs')+'"'
  $link.WorkingDirectory=Join-Path $env:WINDIR 'System32'
  $link.Description='GPT Niang: Codex subscription quota widget'
  $link.Save()
  $task=Register-WidgetSupervisorTask -AppDir $appDir
  Write-Output ('GPT Niang '+$config.version+' registered; supervisor started: '+$task.TaskName)
} finally {Exit-WidgetUpdateLock $lock}
