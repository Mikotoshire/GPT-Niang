param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
function Measure-Landing($height,$conversion,$speed=1,$q=1,[bool]$editAfterContact=$false){
  $m=[GptGravityModel]::new();$m.SetEnergyConversion($conversion);$m.SetAnimationSpeed($speed);$m.SetImpactSquish($q);$m.DropFrom($height)
  for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,1000)}
  Assert ($m.FloorImpacts-eq 1) 'Fixture reaches actual contact'
  $energy=$m.StoredElasticEnergy
  if($editAfterContact){$m.SetEnergyConversion(0)}
  $steps=0
  while($m.Active -and !$m.Rebounds -and $steps-lt 2000){$m.Advance(1.0/240,1000);$steps++}
  Assert ($steps-lt 2000 -and $m.ScaleY-eq 1 -and $m.StoredElasticEnergy-eq 0) 'Contact ends after recovery and consumes storage'
  return @{Seconds=$steps/240.0;Energy=$energy;Velocity=$m.Velocity;Model=$m}
}
$weak=Measure-Landing 240 4.25;$normal=Measure-Landing 240 42.5;$strong=Measure-Landing 240 85
Assert ($weak.Seconds-lt $normal.Seconds-.04 -and $normal.Seconds-lt $strong.Seconds-.01) 'Lower rebound setting must visibly shorten contact animation at the same impact speed'
$low=Measure-Landing 12 42.5;$high=Measure-Landing 900 42.5
Assert ($low.Seconds-lt $normal.Seconds -and $normal.Seconds-lt $high.Seconds) 'Less incoming energy also shortens contact animation'
$zero=Measure-Landing 900 0
Assert ($zero.Seconds-ge .055 -and $zero.Seconds-le .07 -and !$zero.Model.Active) 'Zero retained energy recovers briefly and settles'
Assert ($weak.Seconds-ge .06 -and $strong.Seconds-le .305 -and $high.Seconds-le .305) 'Default-speed duration remains bounded'
foreach($result in @($weak,$normal,$strong)){
  Assert ([Math]::Abs(.5*$result.Velocity*$result.Velocity-$result.Energy)-lt 1e-6) 'Changing dwell time does not add or remove vertical rebound energy'
}
$fast=Measure-Landing 240 42.5 2
Assert ([Math]::Abs(2*$fast.Seconds-$normal.Seconds)-le 2.0/240 -and $fast.Velocity-eq $normal.Velocity) 'Global animation speed still scales duration without changing rebound speed'
$off=Measure-Landing 240 42.5 1 0;$extra=Measure-Landing 240 42.5 1 3
Assert ($off.Seconds-eq $extra.Seconds -and $off.Velocity-eq $extra.Velocity) 'Q affects appearance rather than energy-driven duration'
$edited=Measure-Landing 240 85 1 1 $true
Assert ($edited.Seconds-eq $strong.Seconds -and $edited.Velocity-eq $strong.Velocity) 'Editing rebound during contact preserves captured duration and energy'
$m=[GptGravityModel]::new();$m.DropFrom(900);$hit=0;$start=-1;$durations=@()
for($i=0;$i-lt 4000 -and $m.Active;$i++){
  $m.Advance(1.0/240,1000)
  if($m.FloorImpacts-gt $hit){$hit=$m.FloorImpacts;$start=$i}
  if($start-ge 0 -and $m.StoredElasticEnergy-eq 0){$durations+=,($i-$start);$start=-1}
}
Assert ($durations.Count-ge 3 -and $durations[0]-gt $durations[1] -and $durations[1]-gt $durations[2] -and !$m.Active) 'Successive weaker bounces animate faster and eventually stop'
('PASS: energy-dependent duration, bounded zero/strong response, unchanged energy, Q independence and decay; weak={0:F0}ms normal={1:F0}ms strong={2:F0}ms' -f (1000*$weak.Seconds),(1000*$normal.Seconds),(1000*$strong.Seconds))
