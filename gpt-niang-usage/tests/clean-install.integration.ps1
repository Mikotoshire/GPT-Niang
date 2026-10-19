param([Parameter(Mandatory=$true)][string]$Archive)
# AI-generated, limited Windows integration test; see AI-NOTICE.md.
# Real Codex CLI, COM shortcut, Task Scheduler and WPF. No account is copied.
# Run interactively on Windows with Codex/Node already installed, before publishing.
$ErrorActionPreference='Stop'
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('gpt-niang-clean-'+[Guid]::NewGuid().ToString('N'))
$taskName='GPT Niang Clean Test - '+[Guid]::NewGuid().ToString('N')
$agent=Join-Path $testRoot 'agent';$data=Join-Path $testRoot 'state'
$startup=Join-Path $testRoot 'startup';$codexHome=Join-Path $testRoot 'codex-home'
$powerShell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$children=New-Object Collections.Generic.List[Diagnostics.Process]
$app=$null;$helpersLoaded=$false
function Assert($condition,[string]$label){if(!$condition){throw ('Assertion failed: '+$label)};Write-Output ('PASS '+$label)}
function Replace-TestText([string]$File,[string]$Before,[string]$After){
  $text=[IO.File]::ReadAllText($File)
  if(!$text.Contains($Before)){throw 'Isolation instrumentation anchor missing.'}
  [IO.File]::WriteAllText($File,$text.Replace($Before,$After),[Text.UTF8Encoding]::new($false))
}
function Quote-TestPath([string]$Path){return "'"+$Path.Replace("'","''")+"'"}
function Run-TestInstaller([string]$Script){
  $info=New-Object Diagnostics.ProcessStartInfo
  $info.FileName=$powerShell;$info.Arguments='-NoProfile -STA -ExecutionPolicy Bypass -File "'+$Script+'"'
  $info.UseShellExecute=$false;$info.CreateNoWindow=$true
  $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
  $info.EnvironmentVariables['CODEX_HOME']=$codexHome
  $process=New-Object Diagnostics.Process;$process.StartInfo=$info;$children.Add($process)
  $null=$process.Start();$out=$process.StandardOutput.ReadToEndAsync();$err=$process.StandardError.ReadToEndAsync()
  if(!$process.WaitForExit(60000)){$process.Kill();throw 'Isolated installer timed out; local test files retained until cleanup.'}
  # Raw output includes private temporary paths. Report only the exit code.
  if($process.ExitCode-ne 0){
    $detail=if($err.Wait(2000)){$err.Result.Replace($testRoot,'[isolated-test]').Replace($env:USERPROFILE,'[profile]')}else{'Output unavailable.'}
    throw ('Isolated installer failed with exit code '+$process.ExitCode+': '+$detail)
  }
  Assert ($out.Wait(2000) -and $err.Wait(2000)) 'installer output drained'
}
function Wait-TestHealth {
  $deadline=[DateTime]::UtcNow.AddSeconds(45)
  do{
    $health=Read-WidgetUpdateJson (Join-Path $data 'supervisor-status.json')
    $presence=Read-WidgetUpdateJson (Join-Path $data 'presence.json')
    if($health -and $health.taskName-eq $taskName -and $health.widgetRunning -and $presence -and $presence.visible -and ([DateTime]::UtcNow-[DateTime]$health.at).TotalSeconds-lt 10){
      Assert ([CleanInstallNative]::IsWindowVisible([IntPtr][long]$presence.widget)) 'real WPF window is visible'
      return
    }
    if([DateTime]::UtcNow-ge $deadline){throw 'Isolated supervisor/visible widget did not become healthy.'}
    Start-Sleep -Milliseconds 500
  }while($true)
}
try{
  foreach($directory in @($testRoot,$startup,$data,$codexHome)){$null=New-Item -ItemType Directory -Path $directory -Force}
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  [IO.Compression.ZipFile]::ExtractToDirectory([IO.Path]::GetFullPath($Archive),$testRoot)
  $root=Join-Path $testRoot 'GPT-Niang-Mikotoshire';$app=Join-Path $root 'gpt-niang-usage'
  $manifest=Get-Content -LiteralPath (Join-Path $root 'FILE-MANIFEST.json') -Raw -Encoding UTF8|ConvertFrom-Json
  foreach($entry in $manifest.PSObject.Properties){
    $path=[IO.Path]::GetFullPath((Join-Path $root $entry.Name))
    if(!$path.StartsWith($root+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Manifest escapes extracted package.'}
    if((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash-ne $entry.Value){throw ('Archive hash mismatch: '+$entry.Name)}
  }
  Assert $true 'all committed archive file hashes match'
  Assert (!(Test-Path -LiteralPath (Join-Path $app 'installation.json'))) 'no machine installation config in archive'
  Assert (!(Test-Path -LiteralPath (Join-Path $codexHome 'auth.json'))) 'isolated Codex home has no copied credentials'
  # Only environment bindings are instrumented. Installer and verification logic are unchanged.
  Replace-TestText (Join-Path $app 'runtime\update-common.ps1') "(Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'GPTNiangUsage\update-agent')" (Quote-TestPath $agent)
  Replace-TestText (Join-Path $app 'runtime\install-preflight.ps1') "[Environment]::GetFolderPath('Startup')" (Quote-TestPath $startup)
  Replace-TestText (Join-Path $app 'runtime\install-preflight.ps1') "Join-Path `$localData 'GPTNiangUsage\state'" (Quote-TestPath $data)
  Replace-TestText (Join-Path $app 'runtime\supervisor-task.ps1') "('GPT Niang Usage - '+`$sid)" (Quote-TestPath $taskName)
  Replace-TestText (Join-Path $app 'runtime\supervisor.ps1') 'Local\GPTNiangSupervisor-' ('Local\'+$taskName+'-')
  Replace-TestText (Join-Path $app 'runtime\update-agent.ps1') "`$ErrorActionPreference='Stop'" ("`$ErrorActionPreference='Stop'"+[Environment]::NewLine+'$env:CODEX_HOME='+(Quote-TestPath $codexHome))
  . (Join-Path $app 'runtime\supervisor-task.ps1')
  . (Join-Path $app 'runtime\update-common.ps1')
  $helpersLoaded=$true
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class CleanInstallNative {
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
}
'@
  Write-WidgetSupervisorJson (Join-Path $data 'settings.json') @{followHost=$false}
  $installedVersion=(Get-Content -LiteralPath (Join-Path $app 'package.json') -Raw -Encoding UTF8|ConvertFrom-Json).version
  Run-TestInstaller (Join-Path $app 'Install.ps1')
  $config=Read-WidgetUpdateJson (Join-Path $app 'installation.json')
  Assert ($config.dataDir-eq (Resolve-WidgetPhysicalPath $data) -and $config.updateAgent-eq (Resolve-WidgetPhysicalPath $agent)) 'installation state and agent are isolated'
  $diagnostic=Read-WidgetUpdateJson (Join-Path $data 'installation-verification.json')
  Assert ($diagnostic.status-eq 'verified' -and $diagnostic.version-eq $installedVersion) 'real Codex registration verified'
  $task=Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
  Assert-WidgetSupervisorTaskIdentity $task (Get-WidgetSupervisorInfo $app)
  $link=(New-Object -ComObject WScript.Shell).CreateShortcut($config.startupShortcut)
  Assert (Test-WidgetStartupShortcutIdentity $link $app) 'real COM startup shortcut points to isolated launcher'
  Wait-TestHealth
  Assert $true 'clean archive installs and starts a healthy supervisor and visible widget'
  Run-TestInstaller (Join-Path $app 'Install.ps1')
  Wait-TestHealth
  Assert $true 'rerunning installation safely repairs an existing registration'
  Run-TestInstaller (Join-Path $app 'Uninstall.ps1')
  Assert (!(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) 'uninstall removes test task'
  Assert (!(Test-Path -LiteralPath $config.startupShortcut)) 'uninstall removes test shortcut'
  $expectedWidget='"'+(Join-Path $app 'widget.ps1')+'"'
  $remaining=@(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object{$_.CommandLine -and $_.CommandLine.IndexOf($expectedWidget,[StringComparison]::OrdinalIgnoreCase)-ge 0})
  Assert ($remaining.Count-eq 0) 'uninstall stops isolated widget'
  Assert (!(Test-Path -LiteralPath (Join-Path $codexHome 'auth.json'))) 'test used no saved account credentials'
  Write-Output 'PASS clean archive installation, repair, live startup and uninstall (no account/quota validation)'
}finally{
  foreach($process in $children){try{if(!$process.HasExited){$process.Kill();$null=$process.WaitForExit(2000)}}finally{$process.Dispose()}}
  $task=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if($task){
    if($task.Actions[0].Arguments-ine ('"'+(Join-Path $agent 'agent-supervisor.vbs')+'"') -or [IO.Path]::GetFullPath($task.Actions[0].Execute)-ine (Join-Path $env:WINDIR 'System32\wscript.exe') -or (Resolve-WidgetSupervisorSid $task.Principal.UserId)-ne $sid){throw 'Refusing cleanup of a foreign task.'}
    Stop-ScheduledTask -TaskName $taskName
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  }
  if($helpersLoaded){Stop-WidgetGui -AppDir $app -DataDir $data}
  $expected='"'+(Join-Path $agent 'update-agent.ps1')+'"'
  foreach($child in @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'"|Where-Object{$_.ProcessId-ne $PID -and $_.CommandLine -and $_.CommandLine.IndexOf($expected,[StringComparison]::OrdinalIgnoreCase)-ge 0})){
    $current=Get-CimInstance Win32_Process -Filter ('ProcessId='+$child.ProcessId)
    if($current -and $current.CreationDate-eq $child.CreationDate){Stop-Process -Id $child.ProcessId -Force -ErrorAction SilentlyContinue}
  }
  $resolved=[IO.Path]::GetFullPath($testRoot);$prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
  if(!$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or !(Split-Path $resolved -Leaf).StartsWith('gpt-niang-clean-')){throw 'Unsafe integration cleanup path.'}
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
