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
$m=Contact 85 .25
for($i=0;$i-lt 12000 -and $m.Active;$i++){$m.Advance(1.0/240,1000)}
Assert (!$m.Active -and $m.StoredElasticEnergy-eq 0 -and $m.ScaleY-eq 1) 'Maximum efficiency and minimum stop threshold eventually settle'
'PASS: independent conversion slider, zero/max/default, launch separation, retention and responsive Q range'
function Import-TestFunction($file,$name){
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Production source parses'
  return $ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true).Extent.Text
}
$widget=Join-Path $AppDir 'widget.ps1'
foreach($name in @('Get-WidgetEnergyConversionPreference','Save-Settings')){. ([scriptblock]::Create((Import-TestFunction $widget $name)))}
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'runtime/gravity.ps1') 'Set-WidgetPhysicsTuning')))
foreach($legacy in @(.25,1,1.5,3)){
  Assert ([Math]::Abs((Get-WidgetEnergyConversionPreference @{} $legacy)-[Math]::Min(85.0,40.96*$legacy))-lt 1e-8) 'Missing conversion setting migrates old retention exactly'
}
foreach($value in @(0,40.96,65,85)){
  Assert ((Get-WidgetEnergyConversionPreference @{energyConversion=$value} 3)-eq $value) 'Explicit efficiency including zero overrides migration'
}
foreach($value in @(-1,86,'broken',[double]::NaN,[double]::PositiveInfinity)){
  Assert ([Math]::Abs((Get-WidgetEnergyConversionPreference @{energyConversion=$value} 1.5)-61.44)-lt 1e-8) 'Invalid preference falls back to safe legacy conversion'
}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($widget),[ref]$tokens,[ref]$errors)
Assert ($null-ne $ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Extent.Text-eq '$script:energyConversion=Get-WidgetEnergyConversionPreference $settings $script:elasticStrength'},$true)) 'Startup calls the tested migration'
$settings=@{gravityStrength='broken';elasticStrength='broken';energyConversion=65};$script:gravityStrength=1.6;$script:elasticStrength=1
foreach($name in @('gravityStrength','elasticStrength')){
  $node=$ast.Find({param($n)$n-is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith('if($null-ne $settings.'+$name+')')},$true)
  . ([scriptblock]::Create($node.Extent.Text))
}
Assert ($script:gravityStrength-eq 1.6 -and $script:elasticStrength-eq 1 -and (Get-WidgetEnergyConversionPreference $settings $script:elasticStrength)-eq 65) 'Invalid old physics fields cannot prevent new settings loading'
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('energy-controls-'+[Guid]::NewGuid().ToString('N'))
$script:settingsFile=Join-Path $temporary 'settings.json'
function Write-WidgetJson($file,$data){[IO.Directory]::CreateDirectory($temporary)|Out-Null;[IO.File]::WriteAllText($file,($data|ConvertTo-Json))}
try{
  $script:gravity=[GptGravityModel]::new();$script:energyConversion=65;$script:elasticStrength=1.5;$script:squishStrength=1;$script:animationSpeed=1;$script:tapCompression=1
  Set-WidgetPhysicsTuning
  $saved=Get-Content -LiteralPath $script:settingsFile -Raw|ConvertFrom-Json
  Assert ($script:gravity.EnergyConversion-eq 65 -and $saved.energyConversion-eq 65) 'Production bridge applies and saves conversion'
  $script:elasticStrength=3;Set-WidgetPhysicsTuning
  Assert ($script:gravity.EnergyConversion-eq 65 -and $script:gravity.Elasticity-eq 3) 'Changing launch slider leaves collision efficiency unchanged'
  Assert ((Get-WidgetEnergyConversionPreference $saved 3)-eq 65) 'Saved conversion restores independently'
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
'PASS: legacy migration, explicit zero, invalid settings isolation and production save/load'
