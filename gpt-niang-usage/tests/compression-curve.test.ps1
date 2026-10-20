param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
foreach($curve in @(1.5,1.6,2.25,3)){
  $m=[GptGravityModel]::new();$m.SetCompressionCurve($curve)
  Assert ($m.GetCompressionProgress(0)-eq 0 -and $m.GetCompressionProgress(1)-eq 1) 'Curve endpoints stay fixed'
  $previous=0.0;$previousSpeed=10.0
  for($i=1;$i-le 100;$i++){
    $next=$m.GetCompressionProgress($i/100.0);$speed=$next-$previous
    Assert ($next-ge 0 -and $next-le 1 -and $speed-ge -1e-10 -and $speed-le $previousSpeed+1e-10) 'Compression moves forward with decreasing vertical speed'
    $previous=$next;$previousSpeed=$speed
  }
  Assert ((1-$m.GetCompressionProgress(.999))-lt .00001) 'Compression brakes to zero speed at peak'
}
$a=[GptGravityModel]::new();$b=[GptGravityModel]::new();$a.SetCompressionCurve(1.5);$b.SetCompressionCurve(3)
Assert ($b.GetCompressionProgress(.25)-gt $a.GetCompressionProgress(.25)+.1) 'Slider changes front loading visibly'
foreach($m in @($a,$b)){$m.DropFrom(240)}
$different=$false
for($i=0;$i-lt 1500;$i++){
  foreach($m in @($a,$b)){$m.Advance(1.0/240,1000)}
  Assert ($a.Height-eq $b.Height -and $a.Velocity-eq $b.Velocity -and $a.StoredElasticEnergy-eq $b.StoredElasticEnergy -and $a.Rebounds-eq $b.Rebounds) 'Curve changes shape only, not energy or takeoff timing'
  if([Math]::Abs($a.ScaleY-$b.ScaleY)-gt .02){$different=$true}
}
Assert ($different -and !$a.Active -and !$b.Active) 'Different curves visibly animate and settle'
$m=[GptGravityModel]::new();$m.DropFrom(240)
for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,1000)}
$m.Advance(.02,1000);$y=$m.ScaleY;$m.SetCompressionCurve(3);$m.Advance(0,1000)
Assert ($m.ScaleY-eq $y) 'Mid-contact adjustment does not jump the active pose'
$m.Reset();Assert ($m.CompressionCurve-eq 3) 'Reset keeps curve setting'
foreach($invalid in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetCompressionCurve($invalid);Assert ($m.CompressionCurve-eq 1.6) 'Invalid values use the default'}
$m.SetCompressionCurve(0);Assert ($m.CompressionCurve-eq 1.5) 'Lower bound preserves monotonic deceleration'
$m.SetCompressionCurve(10);Assert ($m.CompressionCurve-eq 3) 'Upper bound preserves monotonic deceleration'
'PASS: curve shape, decreasing vertical speed, endpoints, braking, pose-only tuning, no mid-contact jump and validation'
