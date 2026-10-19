param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$lib=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $lib
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $lib
foreach($height in @(0.5,1,2,4,8,16)){
  $m=[GptGravityModel]::new();$m.DropFrom($height)
  $m.Advance(1.0/240,700)
  if($m.Height-le 0 -or $m.Height-ge $height -or $m.Velocity-ge 0){throw "Near-floor release snapped instead of accelerating: height=$height"}
}
$m=[GptGravityModel]::new();$m.DropFrom(16)
$speed=0.0
for($i=0;$i-lt 5;$i++){
  $m.Advance(1.0/240,700)
  if($m.Height-le 0 -or $m.Velocity-ge $speed){throw 'Falling speed must keep increasing before actual contact'}
  $speed=$m.Velocity
}
for($i=0;$i-lt 1000 -and $m.Active;$i++){$m.Advance(1.0/240,700)}
if($m.Active -or $m.Height-ne 0 -or $m.Velocity-ne 0){throw 'A low drop must still stop after real contact'}
Write-Output 'PASS: near-floor releases accelerate continuously; speculative contacts do not snap; actual landing stops.'
