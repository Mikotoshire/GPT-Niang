param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
function Contact($elasticity){
  $m=[GptGravityModel]::new();$m.SetTuning(1.6,$elasticity);$m.DropFrom(240)
  for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,1000)}
  Assert ($m.FloorImpacts-eq 1) 'Fixture reaches floor'
  return $m
}
$velocities=@();$compressions=@()
foreach($elasticity in @(.25,1,3)){
  $m=Contact $elasticity;$energy=$m.StoredElasticEnergy;$x=$m.SpringCompression
  Assert ($m.ImpactEnergy-gt 0 -and $energy-gt 0) 'Impact must store a positive elastic energy reservoir'
  $ratio=[Math]::Min(.85,[GptGravityModel]::Restitution*[GptGravityModel]::Restitution*$elasticity)
  Assert ([Math]::Abs($energy/$m.ImpactEnergy-$ratio)-lt 1e-8) 'Impact retains configured fraction of kinetic energy'
  Assert ([Math]::Abs(.5*[GptGravityModel]::SpringStiffness*$x*$x-$energy)-lt 1e-6) 'Stored energy determines logical compression'
  Assert ([Math]::Abs($m.SpringForce-[GptGravityModel]::SpringStiffness*$x)-lt 1e-6) 'Spring force proportional to logical compression'
  $compressions+=,$x
  for($i=0;$i-lt 100 -and !$m.Rebounds;$i++){$m.Advance(1.0/240,1000)}
  Assert ($m.Rebounds-eq 1 -and [Math]::Abs(.5*$m.Velocity*$m.Velocity-$energy)-lt 1e-6) 'Recovery releases stored energy into upward velocity'
  Assert ($m.ScaleY-eq 1 -and $m.StoredElasticEnergy-eq 0 -and $m.SpringForce-eq 0) 'Energy consumed and spring unloaded after neutral recovery'
  $velocities+=,$m.Velocity
}
Assert ($velocities[0]-lt $velocities[1] -and $velocities[1]-lt $velocities[2]) 'Elasticity raises rebound speed'
Assert ($compressions[0]-lt $compressions[1] -and $compressions[1]-lt $compressions[2]) 'Elasticity raises compression with force'
foreach($cancel in @('Reset','BeginPress','BeginDrag')){
  $m=Contact 3;$m.$cancel()
  Assert ($m.StoredElasticEnergy-eq 0 -and $m.SpringCompression-eq 0) 'Cancellation clears stored spring energy'
}
$m=Contact 3;$previous=$m.ImpactEnergy;$hit=1
for($i=0;$i-lt 6000 -and $m.Active;$i++){
  $m.Advance(1.0/240,1000)
  if($m.FloorImpacts-gt $hit){Assert ($m.ImpactEnergy-lt $previous) 'Energy decreases on every successive collision';$previous=$m.ImpactEnergy;$hit=$m.FloorImpacts}
}
Assert (!$m.Active -and $m.StoredElasticEnergy-eq 0 -and $m.ScaleY-eq 1) 'Bounded retention settles completely'
'PASS: impact energy retention, linear spring force, compression, delayed release, cancellation and decay'
