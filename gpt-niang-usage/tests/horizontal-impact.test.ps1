param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($Value,$Message){if(!$Value){throw $Message}}
foreach($direction in @(1,-1)){
  # Isolate the once-per-impact loss; stronger supported drag is tested separately.
  $m=[GptGravityModel]::new();$m.SetGroundFriction(0);$m.SetHorizontalPosition(5000);$m.FlingFrom(240,300*$direction,0)
  $hits=0
  for($i=0;$i-lt 2000 -and $hits-lt 3;$i++){
    $before=$m.HorizontalVelocity;$previousHits=$m.FloorImpacts
    $m.Advance(1.0/240,900,20000)
    if($m.FloorImpacts-gt $previousHits){
      $hits++
      Assert ($m.HorizontalVelocity*$direction-gt 0) 'Floor impact must preserve direction and nonzero horizontal momentum'
      Assert ([Math]::Abs($m.HorizontalVelocity/$before-[GptGravityModel]::HorizontalRetention)-lt 0.005) 'Each impact must remove only the configured fraction of horizontal speed'
    }
  }
  Assert ($hits-ge 3) 'The test must exercise at least three distinct landings'
}
$m=[GptGravityModel]::new();$m.SetHorizontalPosition(5000);$m.FlingFrom(10,500,0)
for($i=0;$i-lt 200 -and $m.FloorImpacts-eq 0;$i++){$m.Advance(1.0/240,900,20000)}
Assert ($m.Velocity-eq 0 -and $m.HorizontalVelocity-gt 350 -and $m.Active) 'Vertical stop must leave the body sliding'
$speed=$m.HorizontalVelocity;$m.Advance(1.0/240,900,20000)
Assert ($m.FloorImpacts-eq 1 -and $m.HorizontalVelocity/$speed-gt 0.98) 'Continuous contact must not repeatedly apply the collision penalty'
for($i=0;$i-lt 4000 -and $m.Active;$i++){$m.Advance(1.0/240,900,20000)}
Assert (!$m.Active -and $m.HorizontalVelocity-eq 0) 'Engine ground friction must eventually settle the remaining slide'
$ground=[GptGravityModel]::new();$ground.SetGroundFriction(1);$ground.SetHorizontalPosition(5000);$ground.FlingFrom(0,300,0)
$ground.Advance(1.0/240,900,20000)
Assert ($ground.FloorImpacts-eq 0 -and [Math]::Abs($ground.HorizontalVelocity-(300-[GptGravityModel]::GroundFriction*$ground.EffectiveGravity/240))-lt .01) 'Starting a slide only applies time-based friction, not a falling collision penalty'
Write-Output 'PASS: floor impacts retain horizontal speed in both directions; one loss per impact; vertical stop preserves sliding; ground friction settles.'
# AI-generated maintenance checks; insufficiently validated. See AI-NOTICE.md.
foreach($direction in @(1,-1)){
  $slide=[GptGravityModel]::new();$slide.SetTuning(1.6,1);$slide.SetGroundFriction(1);$slide.SetHorizontalPosition(5000);$slide.FlingFrom(0,600*$direction,0)
  $slide.Advance(1.0/60,900,20000);$initial=[Math]::Abs($slide.HorizontalVelocity)
  $slide.Advance(.1,900,20000);$after=[Math]::Abs($slide.HorizontalVelocity)
  $expected=[GptGravityModel]::GroundFriction*$slide.EffectiveGravity*.1
  Assert ([Math]::Abs(($initial-$after)-$expected)-lt 1) 'Ground slide must lose a predictable amount of horizontal speed over time'
  Assert ($after-lt $initial-40 -and $slide.HorizontalVelocity*$direction-gt 0) 'Ground friction is noticeable and does not reverse sliding'
  for($i=0;$i-lt 120 -and $slide.Active;$i++){$slide.Advance(1.0/60,900,20000)}
  Assert (!$slide.Active -and $slide.HorizontalVelocity-eq 0) 'Ordinary ground flings settle within two seconds'
}
$a=[GptGravityModel]::new();$b=[GptGravityModel]::new()
foreach($m in @($a,$b)){$m.SetHorizontalPosition(5000);$m.FlingFrom(0,600,0)}
for($i=0;$i-lt 60;$i++){$a.Advance(1.0/60,900,20000)}
for($i=0;$i-lt 144;$i++){$b.Advance(1.0/144,900,20000)}
Assert ([Math]::Abs($a.HorizontalVelocity-$b.HorizontalVelocity)-lt .1 -and [Math]::Abs($a.HorizontalPosition-$b.HorizontalPosition)-lt .1) 'Ground friction is independent of display frame rate'
$air=[GptGravityModel]::new();$air.SetHorizontalPosition(5000);$air.FlingFrom(500,600,0);$air.Advance(.1,900,20000)
Assert ([Math]::Abs($air.HorizontalVelocity-600)-lt .01) 'Ground friction does not slow airborne flight'
'PASS: predictable ground deceleration, both directions, finite settling, frame-rate independence and no airborne drag'
