param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
. (Join-Path $AppDir 'runtime/gravity.ps1')
function Assert($ok,$message){if(!$ok){throw $message}}
Add-Type -TypeDefinition @'
using System;using System.Threading;
public sealed class SlowPresenceSink {
 public readonly ManualResetEvent Started=new ManualResetEvent(false),Release=new ManualResetEvent(false);
 public int Writes;public string Last;
 public void Write(string text){Started.Set();Release.WaitOne(3000);Last=text;Interlocked.Increment(ref Writes);}
 public static bool CanClaim(string name){return System.Threading.Tasks.Task.Run(delegate {
  using(var mutex=new Mutex(false,name)){bool own=false;try{try{own=mutex.WaitOne(0);}catch(AbandonedMutexException){own=true;}return own;}finally{if(own)mutex.ReleaseMutex();}}
 }).Result;}
}
'@
$sink=[SlowPresenceSink]::new()
$writer=[GptLatestFileWriter]::new([Delegate]::CreateDelegate([Action[string]],$sink,'Write'))
try{
  $watch=[Diagnostics.Stopwatch]::StartNew();$writer.Submit('first')|Out-Null;$watch.Stop()
  Assert ($watch.ElapsedMilliseconds-lt 500) 'Submit must not wait for slow disk'
  Assert ($sink.Started.WaitOne(1000)) 'Background write starts'
  foreach($i in 1..100){$writer.Submit('latest-'+$i)|Out-Null}
  Assert ($writer.PendingCount-eq 1) 'Only one newest pending snapshot is retained'
  Assert (!$writer.Close(0)) 'Shutdown wait is bounded even when a disk operation is blocked'
  Assert (!$writer.Submit('rejected')) 'Closing rejects new work while accepted work drains'
  $sink.Release.Set()|Out-Null
  Assert ($writer.Drain(2000)) 'Queued writes finish within bounded test wait'
  Assert ($sink.Writes-eq 2 -and $sink.Last-eq 'latest-100') 'Latest heartbeat replaces stale pending work'
}finally{$sink.Release.Set()|Out-Null;$writer.Close(2000)|Out-Null;$sink.Started.Dispose();$sink.Release.Dispose()}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('presence-write-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tmp)|Out-Null
try{
  $path=Join-Path $tmp 'presence.json';$writer=[GptLatestFileWriter]::new($path)
  $writer.Submit('{"at":1}')|Out-Null;Assert ($writer.Drain(2000)) 'First native write completes'
  $writer.Submit('{"at":2}')|Out-Null;Assert ($writer.Drain(2000)) 'Atomic replacement completes'
  Assert (([IO.File]::ReadAllText($path)|ConvertFrom-Json).at-eq 2) 'Readers see complete latest JSON'
  Assert (!(Test-Path ($path+'.async.tmp'))) 'Atomic temp does not remain'
  Assert ($writer.Close(2000)) 'Shutdown drains active write before removing heartbeat'
  Assert (!$writer.Submit('late')) 'Closed writer rejects late heartbeat'
  $broken=[GptLatestFileWriter]::new((Join-Path $tmp 'missing/presence.json'))
  $broken.Submit('{}')|Out-Null;Assert ($broken.Drain(2000)) 'I/O failure does not leave an active worker'
  Assert ($broken.LastError -and $broken.Failures-eq 1) 'I/O failure is observable without retries'
  [IO.Directory]::CreateDirectory((Join-Path $tmp 'missing'))|Out-Null
  $broken.Submit('{"at":3}')|Out-Null;Assert ($broken.Drain(2000)) 'Next normal heartbeat can retry'
  Assert (!$broken.LastError -and $broken.Writes-eq 1) 'A subsequent successful heartbeat clears error'
  $broken.Close(2000)|Out-Null
  # Exercise the production bridge and owned-record cleanup, not only the sink.
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1')),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Production widget parses'
  foreach($name in @('Write-WidgetPresence','Stop-WidgetRuntime')){
    $node=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
    . ([scriptblock]::Create($node.Extent.Text))
  }
  $script:dataDir=$tmp;$script:presenceWriter=$null;$script:runtimeClosed=$false
  Write-WidgetPresence @{pid=$PID;visible=$true;at=1}
  Assert ($script:presenceWriter.Drain(2000)) 'Production heartbeat finishes asynchronously'
  Assert (([IO.File]::ReadAllText($path)|ConvertFrom-Json).pid-eq $PID) 'Production payload keeps ownership'
  Stop-WidgetRuntime
  Assert (!(Test-Path -LiteralPath $path)) 'Shutdown drains before deleting its owned heartbeat'
  Assert (!$script:presenceWriter.Submit('late')) 'No late writes can recreate a removed heartbeat'
  $mutexName='Local\GptPresenceTest-'+[Guid]::NewGuid().ToString('N')
  $script:mutex=[Threading.Mutex]::new($true,$mutexName);$script:mutexOwned=$true
  try {
    $script:presenceWriter=[pscustomobject]@{}
    $script:presenceWriter|Add-Member ScriptMethod Close {param($milliseconds)return $false}
    $script:runtimeClosed=$false
    [IO.File]::WriteAllText($path,('{"pid":'+$PID+'}'))
    Stop-WidgetRuntime
    Assert ($script:mutexOwned -and ![SlowPresenceSink]::CanClaim($mutexName)) 'Timed-out writer retains ownership until process exit'
    Assert (Test-Path -LiteralPath $path) 'A timed-out heartbeat is left for PID/freshness validation'
    $script:mutex.ReleaseMutex();$script:mutexOwned=$false
    Assert ([SlowPresenceSink]::CanClaim($mutexName)) 'Ownership can be claimed after explicit test cleanup'
  } finally {if($script:mutexOwned){$script:mutex.ReleaseMutex();$script:mutexOwned=$false};$script:mutex.Dispose();$script:mutex=$null}
}finally{
  if($writer){$writer.Close(2000)|Out-Null}
  $resolved=[IO.Path]::GetFullPath($tmp)
  Assert ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)) 'Cleanup stays within temporary workspace'
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
'PASS: nonblocking latest-only writes, bounded queue, atomic replacement, observable failure/recovery and shutdown'
