param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
$m=[GptGravityModel]::new()
Assert ($m.GroundFrictionMultiplier-eq 1) 'Existing ground drag remains the default'
foreach($strength in @(0,.5,1,3)){
  $m.SetGroundFriction($strength);$m.Reset();$m.SetHorizontalPosition(5000);$m.FlingFrom(0,600,0)
  $m.Advance(1.0/60,900,20000);$before=$m.HorizontalVelocity
  $m.Advance(.1,900,20000)
  $expected=[Math]::Max(0,$before-[GptGravityModel]::GroundFriction*$strength*$m.EffectiveGravity*.1)
  Assert ([Math]::Abs($m.HorizontalVelocity-$expected)-lt 1) 'Slider scales time-based ground drag'
  $speed=$m.HorizontalVelocity;$m.SetGroundFriction(2)
  Assert ($m.HorizontalVelocity-eq $speed) 'Changing drag does not instantaneously change speed'
}
$m.SetGroundFriction(0);$m.Reset();$m.SetHorizontalPosition(5000);$m.FlingFrom(0,600,0)
for($i=0;$i-lt 60;$i++){$m.Advance(1.0/60,900,20000)}
Assert ([Math]::Abs($m.HorizontalVelocity-600)-lt .01) ('Zero disables sliding drag: speed='+$m.HorizontalVelocity+' impacts='+$m.FloorImpacts+' multiplier='+$m.GroundFrictionMultiplier)
Assert ($m.FloorImpacts-eq 0) 'Persistent floor support never invents a new falling impact'
$m.FlingFrom(0,0,0)
for($tap=0;$tap-lt 2;$tap++){
  $m.BeginPress();$m.ReleasePress();$m.Advance(.1,900,20000);$m.Advance(.1,900,20000);$m.Advance(.1,900,20000)
  Assert ($m.Height-gt 0) 'A supported body can launch again after pressing'
  for($i=0;$i-lt 500 -and $m.Active;$i++){$m.Advance(1.0/120,900,20000)}
}
foreach($strength in @(0,3)){
  $m.SetGroundFriction($strength);$m.FlingFrom(500,600,0);$m.Advance(.1,900,20000)
  Assert ([Math]::Abs($m.HorizontalVelocity-600)-lt .01) 'Ground drag never slows airborne motion'
}
foreach($value in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetGroundFriction($value);Assert ($m.GroundFrictionMultiplier-eq 1) 'Invalid drag uses default'}
$m.SetGroundFriction(-1);Assert ($m.GroundFrictionMultiplier-eq 0) 'Lower bound'
$m.SetGroundFriction(9);Assert ($m.GroundFrictionMultiplier-eq 3) 'Upper bound'
function Import-Function($file,$name){
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Production source parses'
  return $ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true).Extent.Text
}
. ([scriptblock]::Create((Import-Function (Join-Path $AppDir 'runtime/gravity.ps1') 'Set-WidgetPhysicsTuning')))
. ([scriptblock]::Create((Import-Function (Join-Path $AppDir 'widget.ps1') 'Save-Settings')))
function Write-WidgetJson($file,$data){$script:saved=$data}
$script:gravity=$m;$script:groundFriction=2.3;$script:gravityStrength=1.6;$script:elasticStrength=1;$script:energyConversion=42.5
Set-WidgetPhysicsTuning
Assert ($m.GroundFrictionMultiplier-eq 2.3 -and $script:saved.groundFriction-eq 2.3) 'Production bridge applies and saves drag'
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1')),[ref]$tokens,[ref]$errors)
$load=$ast.Find({param($n)$n-is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith('if($null-ne $settings.groundFriction)')},$true)
Assert ($null-ne $load) 'Startup loads ground drag'
foreach($value in @($null,0,.5,1,2.3,3,-1,4,'broken',[double]::NaN,[double]::PositiveInfinity)){
  $settings=@{groundFriction=$value};$script:groundFriction=1
  . ([scriptblock]::Create($load.Extent.Text))
  $expected=if($null-ne $value -and $value-is [ValueType] -and $value-ge 0 -and $value-le 3){[double]$value}else{1}
  Assert ($script:groundFriction-eq $expected) 'Startup preserves valid zero and defaults invalid/old settings'
}
'PASS: adjustable ground friction, zero/live/reset/bounds, airborne independence and production save/load'
