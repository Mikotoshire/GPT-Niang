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
}
'@
$sink=[SlowPresenceSink]::new()
$writer=[GptLatestFileWriter]::new([Action[string]]$sink.Write)
try{
  $watch=[Diagnostics.Stopwatch]::StartNew();$writer.Submit('first');$watch.Stop()
  Assert ($watch.ElapsedMilliseconds-lt 100) 'Submit must not wait for slow disk'
  Assert ($sink.Started.WaitOne(1000)) 'Background write starts'
  foreach($i in 1..100){$writer.Submit('latest-'+$i)}
  Assert ($writer.PendingCount-eq 1) 'Only one newest pending snapshot is retained'
  $sink.Release.Set()|Out-Null
  Assert ($writer.Drain(2000)) 'Queued writes finish within bounded test wait'
  Assert ($sink.Writes-eq 2 -and $sink.Last-eq 'latest-100') 'Latest heartbeat replaces stale pending work'
}finally{$sink.Release.Set()|Out-Null;$writer.Close(2000);$sink.Started.Dispose();$sink.Release.Dispose()}
$tmp=Join-Path ([IO.Path]::GetTempPath()) ('presence-write-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($tmp)|Out-Null
try{
  $path=Join-Path $tmp 'presence.json';$writer=[GptLatestFileWriter]::new($path)
  $writer.Submit('{"at":1}');Assert ($writer.Drain(2000)) 'First native write completes'
  $writer.Submit('{"at":2}');Assert ($writer.Drain(2000)) 'Atomic replacement completes'
  Assert (([IO.File]::ReadAllText($path)|ConvertFrom-Json).at-eq 2) 'Readers see complete latest JSON'
  Assert (!(Test-Path ($path+'.async.tmp'))) 'Atomic temp does not remain'
  Assert ($writer.Close(2000)) 'Shutdown drains active write before removing heartbeat'
  Assert (!$writer.Submit('late')) 'Closed writer rejects late heartbeat'
  $broken=[GptLatestFileWriter]::new((Join-Path $tmp 'missing/presence.json'))
  $broken.Submit('{}');Assert ($broken.Drain(2000)) 'I/O failure does not leave an active worker'
  Assert ($broken.LastError -and $broken.Failures-eq 1) 'I/O failure is observable without retries'
  [IO.Directory]::CreateDirectory((Join-Path $tmp 'missing'))|Out-Null
  $broken.Submit('{"at":3}');Assert ($broken.Drain(2000)) 'Next normal heartbeat can retry'
  Assert (!$broken.LastError -and $broken.Writes-eq 1) 'A subsequent successful heartbeat clears error'
  $broken.Close(2000)|Out-Null
}finally{
  if($writer){$writer.Close(2000)|Out-Null}
  $resolved=[IO.Path]::GetFullPath($tmp)
  Assert ($resolved.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)) 'Cleanup stays within temporary workspace'
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
'PASS: nonblocking latest-only writes, bounded queue, atomic replacement, observable failure/recovery and shutdown'
