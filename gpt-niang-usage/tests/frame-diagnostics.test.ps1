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
'PASS: isolated hitch detection, pause/duplicate handling, reset, bounded privacy-safe work history and disposal'
