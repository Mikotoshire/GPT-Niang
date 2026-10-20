param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
. (Join-Path $AppDir 'runtime\supervisor-task.ps1')
. (Join-Path $AppDir 'runtime\update-common.ps1')
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $AppDir 'runtime\update-ui.ps1'),[Text.Encoding]::UTF8)))
$script:appDir=$AppDir
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('gpt-niang-fork-ui-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $script:dataDir
$script:settingsMenuUi=@{}
try {
  Write-WidgetSupervisorJson (Join-Path $script:dataDir 'update-preferences.json') @{automatic=$true}
  Initialize-WidgetUpdater
  if(!$script:releaseUpdatesDisabled -or $script:autoUpdate){throw 'Fork must override an enabled preference.'}
  Set-WidgetAutomaticUpdate $true
  if($script:autoUpdate -or (Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-preferences.json')).automatic){throw 'Fork toggle must remain off.'}
  Start-WidgetUpdate 'manual'
  $status=Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-status.json')
  if($status.phase-ne 'source' -or $status.message-notmatch 'Mikotoshire/GPT-Niang' -or $script:updateProcess){throw 'Manual update must explain Git maintenance without starting a process.'}
  $script:config=@{version='1.3.4'}
  $script:settingsMenuUi=@{
    UpdateVersion=[pscustomobject]@{Header=''}
    AutoUpdate=[pscustomobject]@{IsChecked=$true;IsEnabled=$true}
    UpdateStatus=[pscustomobject]@{Header=[pscustomobject]@{Text=''};ToolTip=''}
  }
  Update-WidgetUpdateMenu
  if($script:settingsMenuUi.AutoUpdate.IsEnabled -or $script:settingsMenuUi.AutoUpdate.IsChecked){throw 'Fork menu must show disabled automatic updates.'}
  $script:context=[pscustomobject]@{IsOpen=$false}
  $script:startedModes=New-Object 'Collections.Generic.List[string]'
  function Start-WidgetUpdate([string]$Mode){$script:startedModes.Add($Mode)}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $script:updateStartedAt=$now-60000;$script:updateLastTick=0
  Tick-WidgetUpdater $now
  if(Test-Path -LiteralPath (Join-Path $script:dataDir 'update-idle.json')){throw 'An inactive disabled release updater must not write idle telemetry every second.'}
  if($script:startedModes.Count){throw 'Fork must not start release updater processes in the background.'}
  Write-Output 'PASS: personal fork disables automatic/manual release updates, persists the disabled preference, and explains Git maintenance.'
} finally {
  Assert-WidgetUpdateChildPath $script:dataDir ([IO.Path]::GetTempPath())
  Remove-Item -LiteralPath $script:dataDir -Recurse -Force
}
