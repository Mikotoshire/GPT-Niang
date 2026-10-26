param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
$flags=[Reflection.BindingFlags]'NonPublic,Instance'
$grounded=[GptGravityModel].GetField('grounded',$flags)
$landing=[GptGravityModel].GetField('landing',$flags)
foreach($direction in @(1,-1)){
 foreach($friction in @(0,.2,3)){
  $m=[GptGravityModel]::new();$m.SetGroundFriction(0);$m.SetHorizontalPosition(5000);$m.FlingFrom(600,600*$direction,0)
  for($i=0;$i-lt 5000;$i++){
   $m.Advance(1.0/240,900,100000)
   if($m.Rebounds-gt 0 -and $m.Height-eq 0 -and $m.Velocity-eq 0 -and !$landing.GetValue($m)){break}
  }
  Assert ($i-lt 5000 -and $grounded.GetValue($m)) 'Fixture reaches supported sliding after actual rebounds'
  $m.SetGroundFriction($friction);$hits=$m.FloorImpacts;$speed=[Math]::Abs($m.HorizontalVelocity)
  # Fault injection: lose only the support latch, retaining the engine contact and final landing state.
  $grounded.SetValue($m,$false)
  for($repairStep=0;$repairStep-lt 12 -and !$grounded.GetValue($m);$repairStep++){$m.Advance(1.0/240,900,100000)}
  Assert ($grounded.GetValue($m)) ("Confirmed floor support did not recover direction=$direction friction=$friction height=$($m.Height) vy=$($m.Velocity)")
  Assert ($m.Height-eq 0 -and $m.Velocity-eq 0) 'Recovery does not create a bounce'
  Assert ($m.FloorImpacts-eq $hits) 'Persistent support never adds a collision penalty'
  $before=[Math]::Abs($m.HorizontalVelocity)
  $m.Advance(.1,900,100000)
  $expected=[Math]::Max(0.0,$before-[GptGravityModel]::GroundFriction*$friction*$m.EffectiveGravity*.1)
  Assert ([Math]::Abs([Math]::Abs($m.HorizontalVelocity)-$expected)-lt .02) ("Recovered slide friction mismatch strength=$friction before=$before actual=$($m.HorizontalVelocity) expected=$expected")
  if($friction-eq 0){Assert ([Math]::Abs([Math]::Abs($m.HorizontalVelocity)-$speed)-lt .02) 'Zero friction continues sliding intentionally'}
  else{
   for($i=0;$i-lt 3000 -and $m.Active;$i++){$m.Advance(1.0/120,900,100000)}
   Assert (!$m.Active -and $m.HorizontalVelocity-eq 0) 'Recovered positive-friction slide eventually stops'
  }
 }
}
'PASS: floor-support latch recovery after real rebounds; both directions; zero/default/high friction; no fake impacts; finite stopping'
