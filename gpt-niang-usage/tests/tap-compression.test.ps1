param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
$models=@()
foreach($strength in @(0,1,3)){
  $m=[GptGravityModel]::new();$m.SetTapCompression($strength);$m.BeginPress();$m.Advance(.1,900);$m.Advance(.1,900);$models+=,$m
  Assert ([Math]::Abs($m.ScaleY-(1-.12*$strength*((.2/.22)*(.2/.22)*(3-2*.2/.22))))-lt 1e-8) 'Slider controls tap vertical compression'
  Assert ([Math]::Abs($m.ScaleX-(1+.05*$strength*((.2/.22)*(.2/.22)*(3-2*.2/.22))))-lt 1e-8) 'Slider controls tap lateral expansion'
}
foreach($m in $models){$m.ReleasePress();$m.Advance(.02,900)}
Assert ($models[0].Velocity-eq $models[2].Velocity -and $models[0].PeakHeight-eq $models[2].PeakHeight) 'Tap compression does not change launch energy'
foreach($m in $models){$m.BeginPress();for($j=0;$j-lt 120;$j++){$m.Advance(1.0/240,900)}}
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
foreach($invalid in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetTapCompression($invalid);Assert ($m.TapCompression-eq 2) 'Nonfinite value uses chosen default'}
$m.SetTapCompression(-1);Assert ($m.TapCompression-eq 0) 'Lower bound'
$m.SetTapCompression(100);Assert ($m.TapCompression-eq 3) 'Upper bound'
$m.BeginPress();$m.Advance(.1,900);$m.SetTapCompression(0)
Assert ($m.ScaleX-eq 1 -and $m.ScaleY-eq 1 -and $m.IsPressed) 'Live tuning updates pose without cancelling press'
'PASS: tap compression, expansion, live update, validation, charge/energy and landing independence'
function Import-TestFunction($file,$name){
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Source syntax'
  return $ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true).Extent.Text
}
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'runtime/gravity.ps1') 'Set-WidgetPhysicsTuning')))
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'widget.ps1') 'Save-Settings')))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1')),[ref]$tokens,[ref]$errors)
$load=$ast.Find({param($n)$n-is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith('if($null-ne $settings.tapCompression)')},$true)
Assert ($null-ne $load) 'Startup loads tap compression'
foreach($value in @($null,0,.25,.75,3,4,'broken',[double]::NaN,[double]::PositiveInfinity)){
  $settings=@{tapCompression=$value};$script:tapCompression=1.0
  . ([scriptblock]::Create($load.Extent.Text))
  $expected=if($null-ne $value -and $value-is [ValueType] -and $value-ge 0 -and $value-le 3){[double]$value}else{1.0}
  Assert ($script:tapCompression-eq $expected) 'Old and invalid settings retain default'
}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('tap-setting-'+[Guid]::NewGuid().ToString('N'))
$script:settingsFile=Join-Path $temporary 'settings.json'
function Write-WidgetJson($file,$data){[IO.Directory]::CreateDirectory($temporary)|Out-Null;[IO.File]::WriteAllText($file,($data|ConvertTo-Json))}
try{
  $script:animationSpeed=1.0;$script:gravity=[GptGravityModel]::new();$script:gravityStrength=1.6;$script:elasticStrength=1;$script:squishStrength=1;$script:tapCompression=.75
  Set-WidgetPhysicsTuning
  $saved=Get-Content -LiteralPath $script:settingsFile -Raw|ConvertFrom-Json
  Assert ($script:gravity.TapCompression-eq .75 -and $saved.tapCompression-eq .75) 'Production bridge applies and saves speed'
  $settings=$saved;$script:tapCompression=1.0
  . ([scriptblock]::Create($load.Extent.Text))
  Assert ($script:tapCompression-eq .75) 'Production loader restores preference'
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
'PASS: production tuning bridge, persistence and startup validation'
Add-Type -AssemblyName PresentationCore,WindowsBase
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'widget.ps1') 'Animate-Press')))
$script:ui=@{PressScale=[Windows.Media.ScaleTransform]::new(1,1);GravityScale=[Windows.Media.ScaleTransform]::new(1,1)};$script:gravityEnabled=$false
function Animate-Value($target,$property,$value,$milliseconds,$delay,$ease){$target.SetValue($property,$value)}
foreach($strength in @(0,1,3)){
  $script:tapCompression=$strength;Animate-Press $true
  Assert ([Math]::Abs($script:ui.PressScale.ScaleX*$script:ui.GravityScale.ScaleX-(1+.05*$strength))-lt 1e-8 -and [Math]::Abs($script:ui.PressScale.ScaleY*$script:ui.GravityScale.ScaleY-(1-.12*$strength))-lt 1e-8) 'Tap slider also applies with gravity disabled'
  Assert ($script:ui.PressScale.ScaleX-le 1.05) 'Shared bubble pulse remains within its original horizontal budget'
  Animate-Press $false
  Assert ($script:ui.PressScale.ScaleX-eq 1 -and $script:ui.PressScale.ScaleY-eq 1 -and $script:ui.GravityScale.ScaleX-eq 1 -and $script:ui.GravityScale.ScaleY-eq 1) 'Ordinary release returns to neutral'
}
$m=[GptGravityModel]::new();$m.SetTapCompression(3);$m.BeginPress()
for($i=0;$i-lt 400;$i++){$m.Advance(1.0/240,900)}
Assert ($m.Charge-eq 1 -and $m.ScaleY-ge .239999999 -and $m.ScaleX-le 1.550000001) 'Full charge at maximum setting remains bounded'
'PASS: ordinary click animation and maximum charged deformation'
