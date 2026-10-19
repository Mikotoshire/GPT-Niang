param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($Value,$Message){if(!$Value){throw $Message}}
$samples=[GptDragVelocity]::new()
$samples.Record(0,0,0);$samples.Record(0.02,40,-20);$samples.Record(0.04,80,-40)
$v=$samples.ReleaseAt(0.045,80,-40,1)
Assert ($v[0]-gt 1000 -and $v[1]-gt 500) 'Immediate release must keep two-axis momentum'
foreach($pause in @(0.1,0.5,1.0)){
  $samples=[GptDragVelocity]::new()
  $samples.Record(0,0,0);$samples.Record(0.02,100,-100);$samples.Record(0.04,200,-200)
  $v=$samples.ReleaseAt(0.04+$pause,200,-200,1)
  Assert ($v[0]-eq 0 -and $v[1]-eq 0) 'Stopped cursor must discard old speed before release'
}
$a=[GptGravityModel]::new();$b=[GptGravityModel]::new()
$a.SetTuning(1,1);$b.SetTuning(2.5,1);$a.DropFrom(400);$b.DropFrom(400)
$a.Advance(0.1,900);$b.Advance(0.1,900)
Assert ($b.Height-lt $a.Height -and $b.Velocity-lt $a.Velocity) 'More gravity must produce a heavier fall'
$a.SetTuning(1.6,0.5);$b.SetTuning(1.6,2)
foreach($m in @($a,$b)){$m.Reset();$m.BeginPress();for($i=0;$i-lt 120;$i++){$m.Advance(1.0/120,900)};$m.ReleasePress()}
Assert ($b.PeakHeight-gt $a.PeakHeight*3) 'Equal compression must respond to the elasticity slider'
$b.Reset();Assert ($b.GravityMultiplier-eq 1.6 -and $b.Elasticity-eq 2) 'Reset must retain tuning'
$source=[IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1'))
Assert ($source.Contains('if($script:mirrorCharacter)')) 'Facing must depend on explicit mirror preference'
Assert (!$source.Contains("if(`$script:side-eq 'left'){-1.0}")) 'Dragging left must not mirror the character'
Write-Output 'PASS: motion sampling stop/release, gravity/elasticity independence, tuning retention and manual mirror policy.'
