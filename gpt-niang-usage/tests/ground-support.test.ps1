param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$dll=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $dll
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $dll
function Assert($value,$message){if(!$value){throw $message}}
# Synthetic flings that leave a persistent Aether floor contact at the last bounce.
# Use the real engine and public interactions, without editing internal support flags.
foreach($case in @(
  @{Height=571;Vy=-70;Gravity=1.4;Energy=76.5;MinBounces=2},
  @{Height=571;Vy=-70;Gravity=2.875;Energy=55.25;MinBounces=2},
  @{Height=33;Vy=543;Gravity=1.4;Energy=55.25;MinBounces=0}
)){
  foreach($direction in @(1,-1)){
    $m=[GptGravityModel]::new();$m.SetTuning($case.Gravity,1.64)
    $m.SetEnergyConversion($case.Energy);$m.SetGroundFriction(.2)
    $m.SetHorizontalPosition(10000);$m.FlingFrom($case.Height,600*$direction,$case.Vy)
    for($i=0;$i-lt 300;$i++){$m.Advance(.1,1047,30000)}
    Assert ($m.Rebounds-ge $case.MinBounces) 'Fixture must include the requested repeated rebounds'
    Assert ([Math]::Abs($m.HorizontalVelocity)-lt 2 -and !$m.Active) ('Floor support must eventually stop sliding after repeated rebounds; vx='+$m.HorizontalVelocity+' rebounds='+$m.Rebounds)
    Assert ($m.Height-eq 0 -and $m.Velocity-eq 0) 'Stopped body rests exactly on the floor'
  }
}
# A zero slider intentionally allows sliding; real upward motion must still launch.
$zero=[GptGravityModel]::new();$zero.SetTuning(1.4,1.64)
$zero.SetGroundFriction(0);$zero.SetEnergyConversion(76.5)
$zero.SetHorizontalPosition(10000);$zero.FlingFrom(571,600,-70)
for($i=0;$i-lt 200;$i++){$zero.Advance(.1,1047,100000)}
$before=$zero.HorizontalVelocity;$hits=$zero.FloorImpacts
for($i=0;$i-lt 100;$i++){$zero.Advance(.1,1047,100000)}
Assert ([Math]::Abs($zero.HorizontalVelocity-$before)-lt .01 -and $zero.FloorImpacts-eq $hits) 'Zero friction preserves sliding without inventing impacts'
foreach($step in @((1.0/60),(1.0/120))){
  $air=[GptGravityModel]::new();$air.SetGroundFriction(3)
  $air.SetHorizontalPosition(10000);$air.FlingFrom(0,600,300)
  for($i=0;$i-lt 6;$i++){$air.Advance($step,1047,30000)}
  Assert ($air.Height-gt 0 -and $air.FloorImpacts-eq 0 -and [Math]::Abs($air.HorizontalVelocity-600)-lt .01) 'True upward launch is airborne and receives no ground drag'
}
'PASS: cached floor contact and solver velocity noise cannot bypass sliding friction'
