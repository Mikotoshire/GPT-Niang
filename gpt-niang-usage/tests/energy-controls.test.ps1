param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
function Contact($efficiency,$launch=1,$q=1){
  $m=[GptGravityModel]::new();$m.SetTuning(1.6,$launch);$m.SetEnergyConversion($efficiency);$m.SetImpactSquish($q);$m.DropFrom(900)
  for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,1000)}
  Assert ($m.FloorImpacts-eq 1) 'Fixture reaches floor'
  return $m
}
$m=[GptGravityModel]::new();$m.SetEnergyConversion(65);$m.Reset()
Assert ($m.EnergyConversion-eq 65 -and $m.EnergyRetention-eq .65) 'Reset retains independent efficiency percentage'
$a=Contact 65 .25;$b=Contact 65 3
Assert ($a.StoredElasticEnergy-eq $b.StoredElasticEnergy -and $a.SpringCompression-eq $b.SpringCompression) 'Manual launch tuning does not change collision conversion'
$a=[GptGravityModel]::new();$b=[GptGravityModel]::new();$a.SetEnergyConversion(10);$b.SetEnergyConversion(85)
foreach($m in @($a,$b)){$m.BeginPress();for($i=0;$i-lt 100;$i++){$m.Advance(1.0/240,1000)};$m.ReleasePress()}
Assert ($a.Velocity-eq $b.Velocity -and $a.PeakHeight-eq $b.PeakHeight) 'Conversion slider does not change manual launch'
$low=Contact 10;$high=Contact 85
Assert ($low.StoredElasticEnergy-lt $high.StoredElasticEnergy -and $low.SpringCompression-lt $high.SpringCompression) 'Higher efficiency retains more energy and compresses further'
$m=Contact 0
for($i=0;$i-lt 1000 -and $m.Active;$i++){$m.Advance(1.0/240,1000)}
Assert (!$m.Active -and $m.Rebounds-eq 0 -and $m.StoredElasticEnergy-eq 0 -and $m.ScaleY-eq 1) 'Zero conversion dissipates impact without bouncing or freezing'
foreach($invalid in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetEnergyConversion($invalid);Assert ([Math]::Abs($m.EnergyConversion-40.96)-lt 1e-8) 'Invalid efficiency defaults safely'}
$m.SetEnergyConversion(-1);Assert ($m.EnergyConversion-eq 0) 'Lower efficiency bound'
$m.SetEnergyConversion(100);Assert ($m.EnergyConversion-eq 85) 'Upper efficiency bound retains losses'
$depths=@()
foreach($q in @(1,2,3)){
  $m=Contact 85 1 $q;$depth=0.0
  for($i=0;$i-lt 100 -and !$m.Rebounds;$i++){$m.Advance(1.0/240,1000);$depth=[Math]::Max($depth,1-$m.ScaleY)}
  $depths+=,$depth
}
Assert ($depths[1]-gt $depths[0]+.02 -and $depths[2]-gt $depths[1]+.01 -and $depths[2]-lt .72) 'Q keeps a visible response at high energy without a hard plateau'
'PASS: independent conversion slider, zero/max/default, launch separation, retention and responsive Q range'
