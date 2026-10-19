$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime\supervisor-task.ps1')
$root=Join-Path ([IO.Path]::GetTempPath()) ('gpt-startup-test-'+[Guid]::NewGuid().ToString('N'))
$checks=0
function Assert($Value,[string]$Message){if(!$Value){throw $Message};$script:checks++}
try {
  $app=Join-Path $root 'program with spaces';$agent=Join-Path $root 'agent with spaces';$data=Join-Path $root 'state'
  [IO.Directory]::CreateDirectory($app)|Out-Null;[IO.Directory]::CreateDirectory($agent)|Out-Null
  function Get-WidgetUpdateAgentDir {return $agent}
  $config=@{appDir=$app;dataDir=$data;updateAgent=$agent}
  $info=Get-WidgetSupervisorInfo $app $config
  $systemDir=Join-Path $env:WINDIR 'System32'
  $native=& node -e "console.log(require('node:fs').realpathSync.native(process.argv[1]))" $agent
  Assert ((Resolve-WidgetPhysicalPath $agent)-ieq $native) 'Physical path agrees with the OS canonical path'
  Assert ((Resolve-WidgetQuotedPath ('"'+$agent+'" extra'))-eq '') 'Additional launcher arguments are rejected'
  Assert ((Resolve-WidgetPhysicalPath (Join-Path $root 'not-created'))-eq (Join-Path $root 'not-created')) 'Preflight may inspect nonexistent targets without creating them'

  Assert ($info.TaskWorkingDirectory-eq $systemDir) 'Task must use the existing Windows system directory'
  Write-WidgetSupervisorJson (Join-Path $agent 'binding.json') @{appDir=$app;dataDir=$data;sid=$info.Sid}
  Write-WidgetSupervisorJson (Join-Path $app 'installation.json') $config
  foreach($directory in @($agent,$systemDir)){
    $task=[pscustomobject]@{TaskName=$info.TaskName;TaskPath=$info.TaskPath;Principal=@{UserId=$info.Sid;LogonType='Interactive';RunLevel='Limited'};Actions=@(@{Execute=$info.Execute;Arguments=$info.Arguments;WorkingDirectory=$directory});State='Ready'}
    Assert-WidgetSupervisorTaskIdentity $task $info
    Assert $true 'Recognize original stable registration and repaired working directory'
  }
  $task.Actions[0].WorkingDirectory=$root
  $rejected=$false;try{Assert-WidgetSupervisorTaskIdentity $task $info}catch{$rejected=$true}
  Assert $rejected 'Reject unrelated working directories'
  $task.Actions[0].WorkingDirectory=$agent
  $script:task=$task;$script:registered=0;$script:started=0
  function Get-WidgetSupervisorTask($Info){return $script:task}
  function Resume-WidgetSupervisor($AppDir){}
  function New-ScheduledTaskAction($Execute,$Argument,$WorkingDirectory){return @{Execute=$Execute;Arguments=$Argument;WorkingDirectory=$WorkingDirectory}}
  function New-ScheduledTaskPrincipal($UserId,$LogonType,$RunLevel){return @{UserId=$UserId;LogonType=$LogonType;RunLevel=$RunLevel}}
  function New-ScheduledTaskTrigger([switch]$AtLogOn,$User){}
  function New-ScheduledTaskSettingsSet([switch]$AllowStartIfOnBatteries,[switch]$DontStopIfGoingOnBatteries,$ExecutionTimeLimit,$MultipleInstances,[switch]$StartWhenAvailable,[switch]$Hidden){}
  function New-ScheduledTask($Action,$Principal,$Trigger,$Settings,$Description){return @{Actions=@($Action);Principal=$Principal}}
  function Register-ScheduledTask($TaskName,$TaskPath,$InputObject,[switch]$Force,$ErrorAction){$script:registered++;$script:task.Actions=$InputObject.Actions}
  function Start-ScheduledTask($TaskName,$TaskPath,$ErrorAction){$script:started++}
  foreach($file in @('supervisor.vbs','runtime\supervisor.ps1','widget.ps1')){
    $target=Join-Path $app $file;[IO.Directory]::CreateDirectory((Split-Path $target -Parent))|Out-Null;[IO.File]::WriteAllText($target,'fixture')
  }
  Start-WidgetSupervisorTask $app
  Assert ($script:registered-eq 1 -and $script:started-eq 1) 'Starting an old registration repairs and launches it once'
  Assert ($script:task.Actions[0].WorkingDirectory-eq $systemDir) 'Repaired task uses system directory'
  Start-WidgetSupervisorTask $app
  Assert ($script:registered-eq 1 -and $script:started-eq 2) 'Starting a current registration does not replace it'
  Write-Output "All $checks startup-directory assertions passed."
}finally{
  $full=[IO.Path]::GetFullPath($root);$prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
  if(!$full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)-or (Split-Path $full -Leaf)-notlike 'gpt-startup-test-*'){throw 'Unsafe fixture cleanup path'}
  Remove-Item -LiteralPath $full -Recurse -Force
}
