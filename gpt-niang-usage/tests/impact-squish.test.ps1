param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
$models=@()
foreach($strength in @(0,1,3)){
  $m=[GptGravityModel]::new();$m.SetImpactSquish($strength);$m.DropFrom(12);$models+=,$m
}
$maxDefault=0.0;$maxStrong=0.0
for($i=0;$i-lt 300;$i++){
  foreach($m in $models){$m.Advance(1.0/240,900,1000)}
  Assert ($models[0].Height-eq $models[2].Height -and $models[0].Velocity-eq $models[2].Velocity -and $models[0].HorizontalVelocity-eq $models[2].HorizontalVelocity) 'Squish must not change physics'
  if($models[0].FloorImpacts-gt 0){
    Assert ($models[0].ScaleX-le 1.000000001 -and $models[0].ScaleY-ge 0.999999999) 'Zero adds no landing squash while incoming stretch settles'
    $maxDefault=[Math]::Max($maxDefault,$models[0].ScaleY-$models[1].ScaleY)
    $maxStrong=[Math]::Max($maxStrong,$models[0].ScaleY-$models[2].ScaleY)
  }
}
Assert ($maxDefault-gt 0.04 -and $maxStrong-gt $maxDefault -and $maxStrong-lt 3*$maxDefault) 'Slider increases compression with smooth saturation'
foreach($m in $models){Assert ($m.ScaleX-eq 1 -and $m.ScaleY-eq 1 -and !$m.Active) 'Landing pulse must fully recover'}
$m.SetImpactSquish(2.25);$m.Reset();Assert ($m.ImpactSquish-eq 2.25) 'Reset retains the setting'
foreach($invalid in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetImpactSquish($invalid);Assert ($m.ImpactSquish-eq 1) 'Nonfinite tuning uses default'}
$m.SetImpactSquish(-10);Assert ($m.ImpactSquish-eq 0) 'Lower bound'
$m.SetImpactSquish(99);Assert ($m.ImpactSquish-eq 3) 'Upper bound'
$models=@([GptGravityModel]::new(),[GptGravityModel]::new());$models[0].SetImpactSquish(0);$models[1].SetImpactSquish(3)
foreach($m in $models){$m.BeginPress();$m.Advance(0.1,900)}
Assert ($models[0].ScaleY-eq $models[1].ScaleY -and $models[0].ScaleX-eq $models[1].ScaleX) 'Press compression remains independent'
foreach($m in $models){$m.FlingFrom(250,500,-100)}
for($i=0;$i-lt 1000;$i++){
  foreach($m in $models){$m.Advance(1.0/240,900,1000)}
  Assert ($models[0].Height-eq $models[1].Height -and $models[0].HorizontalPosition-eq $models[1].HorizontalPosition -and $models[0].Rebounds-eq $models[1].Rebounds) 'Bounce height, inertia and collision count remain independent'
}
function Import-TestFunction($file,$name){
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Source syntax'
  $definition=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
  return $definition.Extent.Text
}
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'runtime/gravity.ps1') 'Set-WidgetPhysicsTuning')))
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'widget.ps1') 'Save-Settings')))
$tokens=$null;$errors=$null
$widgetAst=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1')),[ref]$tokens,[ref]$errors)
$loadPreference=$widgetAst.Find({param($n)$n-is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith('if($null-ne $settings.squishStrength)')},$true)
Assert ($null-ne $loadPreference) 'Startup loads the saved setting'
foreach($value in @($null,0,2.25,-1,4,'broken',[double]::NaN,[double]::PositiveInfinity)){
  $settings=@{squishStrength=$value};$script:squishStrength=1.0
  . ([scriptblock]::Create($loadPreference.Extent.Text))
  $expected=if($null-ne $value -and $value-is [ValueType] -and $value-ge 0 -and $value-le 3){[double]$value}else{1.0}
  Assert ($script:squishStrength-eq $expected) 'Old and invalid preferences safely default; zero is preserved'
}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('squish-setting-'+[Guid]::NewGuid().ToString('N'))
$script:settingsFile=Join-Path $temporary 'settings.json'
function Write-WidgetJson($file,$data){[IO.Directory]::CreateDirectory($temporary)|Out-Null;[IO.File]::WriteAllText($file,($data|ConvertTo-Json))}
try{
  $script:tapCompression=1.0;$script:gravity=[GptGravityModel]::new();$script:gravityStrength=1.6;$script:elasticStrength=1;$script:squishStrength=2.25;$script:animationSpeed=1
  Set-WidgetPhysicsTuning
  $saved=Get-Content -LiteralPath $script:settingsFile -Raw|ConvertFrom-Json
  Assert ($script:gravity.ImpactSquish-eq 2.25 -and $saved.squishStrength-eq 2.25) 'Production bridge applies and persists slider'
  $restored=[GptGravityModel]::new();$restored.SetImpactSquish($saved.squishStrength)
  Assert ($restored.ImpactSquish-eq 2.25) 'Preference JSON can restore the same value'
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
'PASS: landing amplitude, zero/default/max, recovery, validation, physics independence and preference persistence'
