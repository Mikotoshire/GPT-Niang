param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
. (Join-Path $AppDir 'runtime/gravity.ps1')
function Assert($v,$message){if(!$v){throw $message}}
$m=[GptFrameGapMetrics]::new()
for($i=0;$i-le 100;$i++){$m.Record($i*10.0)}
$m.Record(1100);$m.Record(1110)
Assert ($m.Count-eq 102 -and $m.P95Ms-eq 10 -and $m.MaxMs-eq 100 -and $m.Over50Ms-eq 1) 'One hitch is detected despite high average cadence'
$before=$m.Count;$m.Record(1110);$m.Record(1000);$m.Record([double]::NaN)
Assert ($m.Count-eq $before) 'Duplicate, backwards and invalid times do not invent gaps'
$m.Break();$m.Record(5000);$m.Record(5010)
Assert ($m.Count-eq $before+1 -and $m.MaxMs-eq 100) 'Explicit pauses do not count as stalls'
$m.Reset();Assert ($m.Count-eq 0 -and $m.P95Ms-eq 0) 'Metrics reset completely'
$p=[GptFrameProbe]::new(5)
try{
  for($i=0;$i-lt 100;$i++){$p.RecordWork('quota',5)}
  $p.RecordWork('private value must be rejected',100)
  Assert ($p.WorkEvents.Length-eq 32 -and $p.WorkCount-eq 100) 'Work history is bounded and rejects arbitrary labels'
  Assert ($p.MaxWorkMs-eq 5) 'Numeric work summaries are accurate'
}finally{$p.Dispose()}
Assert (!$p.IsRunning) 'Probe detaches on disposal'
Add-Type -TypeDefinition @'
using System;
using System.Threading;
public static class WorkerCheckFixture {
  public static readonly ManualResetEvent Gate = new ManualResetEvent(false);
  public static bool Check() { Gate.WaitOne(2000); return true; }
}
'@
$check=[GptWorkerHealthCheck]::new([Delegate]::CreateDelegate([Func[bool]],[WorkerCheckFixture].GetMethod('Check')))
try{Assert (!$check.IsCompleted) 'Slow process inspection must not block the UI caller'}finally{[WorkerCheckFixture]::Gate.Set()|Out-Null}
$deadline=[DateTime]::UtcNow.AddSeconds(3)
while(!$check.IsCompleted -and [DateTime]::UtcNow-lt $deadline){Start-Sleep -Milliseconds 10}
Assert ($check.IsCompleted -and $check.Healthy) 'Asynchronous worker health result is consumed safely'
$current=[Diagnostics.Process]::GetCurrentProcess()
try{
  $valid=[GptWorkerHealthCheck]::new($PID,$current.MainModule.FileName,[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(),0)
  $invalid=[GptWorkerHealthCheck]::new($PID,'fictional-mismatched-runtime.exe',[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds(),0)
  $deadline=[DateTime]::UtcNow.AddSeconds(3)
  while((!$valid.IsCompleted -or !$invalid.IsCompleted) -and [DateTime]::UtcNow-lt $deadline){Start-Sleep -Milliseconds 10}
  Assert ($valid.Healthy -and !$invalid.Healthy) 'Background inspection preserves executable identity validation'
}finally{$current.Dispose()}
function Write-WidgetJson($file,$data){$script:report=$data}
$script:dataDir=[IO.Path]::GetTempPath()
Start-WidgetFrameProbe 999
Assert ($script:report.seconds-eq 120) 'Diagnostic duration is bounded'
$script:frameProbeDeadline=[DateTime]::UtcNow.AddSeconds(-1)
Complete-WidgetFrameProbe
Assert ($null-eq $script:frameProbe -and $script:report.state-eq 'complete') 'Deadline finalizes a report even without new rendering events'
Add-Type -AssemblyName PresentationFramework
$window=[Windows.Window]::new();$window.Width=100;$window.Height=100;$window.Opacity=0;$window.ShowActivated=$false
$window.Show();$p=[GptFrameProbe]::new(5)
$pump=[Windows.Threading.DispatcherFrame]::new()
$delay=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Send)
$delay.Interval=[TimeSpan]::FromMilliseconds(20)
$delay.Add_Tick({param($sender,$event)if($p.Delivery.Count-ge 3){$sender.Stop();[Threading.Thread]::Sleep(100)}})
$finish=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Send)
$finish.Tag=$pump;$finish.Interval=[TimeSpan]::FromMilliseconds(1500)
$finish.Add_Tick({param($sender,$event)$sender.Stop();$sender.Tag.Continue=$false})
try{
  $delay.Start();$finish.Start();[Windows.Threading.Dispatcher]::PushFrame($pump)
  Assert ($p.Delivery.Over50Ms-ge 1) 'Real UI-thread blockage is visible in delivery gaps'
}finally{$delay.Stop();$finish.Stop();$p.Dispose();$window.Close()}
'PASS: isolated hitch detection, pause/duplicate handling, reset, bounded privacy-safe work history and disposal'
