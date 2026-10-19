param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($Value,$Message){if(!$Value){throw $Message}}
foreach($direction in @(1,-1)){
  $m=[GptGravityModel]::new();$m.SetHorizontalPosition(5000);$m.FlingFrom(240,300*$direction,0)
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
$ground=[GptGravityModel]::new();$ground.SetHorizontalPosition(5000);$ground.FlingFrom(0,300,0)
$ground.Advance(1.0/240,900,20000)
Assert ($ground.FloorImpacts-eq 0 -and $ground.HorizontalVelocity-gt 299) 'Starting a slide on the floor is not a new falling collision'
Write-Output 'PASS: floor impacts retain horizontal speed in both directions; one loss per impact; vertical stop preserves sliding; ground friction settles.'
