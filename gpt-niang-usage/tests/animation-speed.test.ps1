param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
function Measure-Landing($speed){
  $m=[GptGravityModel]::new();$m.SetAnimationSpeed($speed);$m.DropFrom(240)
  for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,900)}
  $steps=0
  while(!$m.Rebounds -and $steps-lt 1000){$m.Advance(1.0/240,900);$steps++}
  Assert ($m.Rebounds-eq 1) 'Landing must eventually release rebound'
  return @{Steps=$steps;Velocity=$m.Velocity;Model=$m}
}
$slow=Measure-Landing .25;$normal=Measure-Landing 1;$fast=Measure-Landing 3
Assert ([Math]::Abs($slow.Steps-4*$normal.Steps)-le 4) 'Quarter speed takes four times the contact duration'
Assert ([Math]::Abs(3*$fast.Steps-$normal.Steps)-le 4) 'Triple speed takes a third of the contact duration'
Assert ([Math]::Abs($slow.Velocity-$fast.Velocity)-lt 1e-6) 'Speed does not change rebound energy'
$m=$normal.Model;$m.Reset();Assert ($m.AnimationSpeed-eq 1) 'Reset retains animation tuning'
$m.SetAnimationSpeed(2);$m.Reset();Assert ($m.AnimationSpeed-eq 2) 'Nondefault tuning retained'
foreach($value in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetAnimationSpeed($value);Assert ($m.AnimationSpeed-eq 1) 'Invalid tuning defaults safely'}
$m.SetAnimationSpeed(0);Assert ($m.AnimationSpeed-eq .25) 'Cannot freeze animation'
$m.SetAnimationSpeed(99);Assert ($m.AnimationSpeed-eq 3) 'Upper bound'
$a=[GptGravityModel]::new();$b=[GptGravityModel]::new();$a.SetAnimationSpeed(.25);$b.SetAnimationSpeed(3)
foreach($m in @($a,$b)){$m.BeginPress();$m.Advance(.1,900)}
Assert ($a.ScaleY-eq $b.ScaleY -and $a.Charge-eq $b.Charge) 'Press and charge timing stays real time'
foreach($m in @($a,$b)){$m.FlingFrom(240,200,-50);$m.Advance(.05,900)}
Assert ($a.Height-eq $b.Height -and $a.Velocity-eq $b.Velocity -and $a.HorizontalPosition-eq $b.HorizontalPosition) 'Free flight physics stays real time'
while(!$a.FloorImpacts){$a.Advance(1.0/240,900)}
$a.Advance(.02,900);$x=$a.ScaleX;$y=$a.ScaleY;$a.SetAnimationSpeed(3)
Assert ($a.ScaleX-eq $x -and $a.ScaleY-eq $y) 'Changing speed preserves current pose'
'PASS: animation duration, rebound energy, bounds, reset, input/flight independence and live adjustment'
function Import-TestFunction($file,$name){
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Source syntax'
  return $ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true).Extent.Text
}
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'runtime/gravity.ps1') 'Set-WidgetPhysicsTuning')))
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'widget.ps1') 'Save-Settings')))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1')),[ref]$tokens,[ref]$errors)
$load=$ast.Find({param($n)$n-is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith('if($null-ne $settings.animationSpeed)')},$true)
Assert ($null-ne $load) 'Startup loads animation speed'
foreach($value in @($null,0,.25,.75,3,4,'broken',[double]::NaN,[double]::PositiveInfinity)){
  $settings=@{animationSpeed=$value};$script:animationSpeed=1.0
  . ([scriptblock]::Create($load.Extent.Text))
  $expected=if($null-ne $value -and $value-is [ValueType] -and $value-ge .25 -and $value-le 3){[double]$value}else{1.0}
  Assert ($script:animationSpeed-eq $expected) 'Old and invalid settings retain default'
}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('animation-setting-'+[Guid]::NewGuid().ToString('N'))
$script:settingsFile=Join-Path $temporary 'settings.json'
function Write-WidgetJson($file,$data){[IO.Directory]::CreateDirectory($temporary)|Out-Null;[IO.File]::WriteAllText($file,($data|ConvertTo-Json))}
try{
  $script:gravity=[GptGravityModel]::new();$script:gravityStrength=1.6;$script:elasticStrength=1;$script:squishStrength=1;$script:animationSpeed=.75
  Set-WidgetPhysicsTuning
  $saved=Get-Content -LiteralPath $script:settingsFile -Raw|ConvertFrom-Json
  Assert ($script:gravity.AnimationSpeed-eq .75 -and $saved.animationSpeed-eq .75) 'Production bridge applies and saves speed'
  $settings=$saved;$script:animationSpeed=1.0
  . ([scriptblock]::Create($load.Extent.Text))
  Assert ($script:animationSpeed-eq .75) 'Production loader restores preference'
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
'PASS: production tuning bridge, persistence and startup validation'
