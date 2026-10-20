param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
$models=@()
foreach($strength in @(0,1,3)){
  $m=[GptGravityModel]::new();$m.SetTapCompression($strength);$m.BeginPress();$m.Advance(.22,900);$models+=,$m
  Assert ([Math]::Abs($m.ScaleY-(1-.12*$strength))-lt 1e-8) 'Slider controls tap vertical compression'
  Assert ([Math]::Abs($m.ScaleX-(1+.05*$strength))-lt 1e-8) 'Slider controls tap lateral expansion'
}
foreach($m in $models){$m.ReleasePress();$m.Advance(.02,900)}
Assert ($models[0].Velocity-eq $models[2].Velocity -and $models[0].PeakHeight-eq $models[2].PeakHeight) 'Tap compression does not change launch energy'
foreach($m in $models){$m.BeginPress();$m.Advance(.5,900)}
Assert ($models[0].Charge-eq $models[2].Charge) 'Long press charge timing unchanged'
Assert ([Math]::Abs(($models[0].ScaleY-$models[2].ScaleY)-.36)-lt 1e-8) 'Long press retains independent additional compression'
foreach($m in $models){$m.ReleasePress();$m.Advance(.02,900)}
Assert ($models[0].Velocity-eq $models[2].Velocity) 'Charged launch energy remains unchanged'
foreach($m in $models){$m.DropFrom(240)}
for($i=0;$i-lt 500;$i++){
  foreach($m in $models){$m.Advance(1.0/240,900)}
  Assert ($models[0].Height-eq $models[2].Height -and $models[0].ScaleY-eq $models[2].ScaleY -and $models[0].ScaleX-eq $models[2].ScaleX) 'Drop and landing squash independent of tap setting'
}
$m.SetTapCompression(2.25);$m.Reset();Assert ($m.TapCompression-eq 2.25) 'Reset retains tap setting'
foreach($invalid in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetTapCompression($invalid);Assert ($m.TapCompression-eq 1) 'Nonfinite value defaults to one'}
$m.SetTapCompression(-1);Assert ($m.TapCompression-eq 0) 'Lower bound'
$m.SetTapCompression(100);Assert ($m.TapCompression-eq 3) 'Upper bound'
$m.BeginPress();$m.Advance(.1,900);$m.SetTapCompression(0)
Assert ($m.ScaleX-eq 1 -and $m.ScaleY-eq 1 -and $m.IsPressed) 'Live tuning updates pose without cancelling press'
'PASS: tap compression, expansion, live update, validation, charge/energy and landing independence'
