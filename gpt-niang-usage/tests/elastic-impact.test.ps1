param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
function Measure-Impact($height,$elasticity,$squish=1){
  $m=[GptGravityModel]::new();$m.SetTuning(1.6,$elasticity);$m.SetImpactSquish($squish);$m.DropFrom($height)
  for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,1000)}
  Assert ($m.FloorImpacts-eq 1) 'Fixture reaches first floor contact'
  $depth=0.0;$width=1.0
  for($i=0;$i-lt 100 -and !$m.Rebounds;$i++){
    $m.Advance(1.0/240,1000)
    $depth=[Math]::Max($depth,1-$m.ScaleY);$width=[Math]::Max($width,$m.ScaleX)
  }
  Assert ($m.Rebounds-eq 1 -and [Math]::Abs($m.ScaleY-1)-lt 1e-9) 'Recover to neutral before launch'
  return @{Depth=$depth;Width=$width;LaunchVelocity=$m.Velocity;Model=$m}
}
$low=Measure-Impact 240 .25;$normal=Measure-Impact 240 1;$high=Measure-Impact 240 3
Assert ($normal.Depth-gt $low.Depth*1.5 -and $high.Depth-gt $normal.Depth*1.3) 'Same impact speed compresses more with higher elastic energy setting'
Assert ($normal.Depth-ge .36) 'Default high drop visibly compresses by at least 36 percent'
$ceiling=Measure-Impact 900 1
Assert ($ceiling.Depth-ge .44 -and $ceiling.Depth-gt $normal.Depth) 'Higher drop produces stronger visible compression'
Assert ($low.LaunchVelocity-lt $normal.LaunchVelocity -and $normal.LaunchVelocity-lt $high.LaunchVelocity) 'Elasticity raises the retained energy and rebound speed'
$strong=Measure-Impact 900 3 3
Assert ($strong.Depth-ge .65 -and $strong.Depth-le .720000001 -and $strong.Width-le 1.385) 'Maximum setting has strong but bounded squash'
$off=Measure-Impact 900 3 0
Assert ($off.Depth-eq 0) 'Zero Q setting still disables impact squash'
Assert ([Math]::Abs($off.LaunchVelocity-$strong.LaunchVelocity)-lt 1e-6) 'Q amplitude remains physically independent'
$m=$strong.Model
for($i=0;$i-lt 4000 -and $m.Active;$i++){$m.Advance(1.0/240,1000);Assert ($m.ScaleY-ge .279999999 -and $m.ScaleX-le 1.385) 'Repeated bounces stay bounded'}
Assert (!$m.Active -and $m.ScaleX-eq 1 -and $m.ScaleY-eq 1) 'Repeated bounces recover and settle'
'PASS: elastic energy linked impact squash, stronger high drops, safe limits, neutral takeoff and controlled rebound energy'
