param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
function Assert($value,$message){if(!$value){throw $message}}
function Import-TestFunction($file,$name){
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Production source parses'
  $node=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
  Assert ($null-ne $node) ('Missing production function: '+$name)
  return $node.Extent.Text
}
$widget=Join-Path $AppDir 'widget.ps1'
foreach($name in @('Get-WidgetEnergyConversionPreference','Get-WidgetReboundStrengthPreference','Save-Settings')){. ([scriptblock]::Create((Import-TestFunction $widget $name)))}
foreach($value in @(0,5,40,50,65,95,100)){
  Assert ((Get-WidgetReboundStrengthPreference @{reboundStrength=$value} 1)-eq $value) 'Exact 5-percent steps persist'
}
foreach($case in @(@(40.96,40),@(42.5,45),@(63,65),@(97,95))){
  Assert ((Get-WidgetReboundStrengthPreference @{reboundStrength=$case[0]} 1)-eq $case[1]) 'Fractional UI preferences snap to nearest five with upward midpoint'
}
Assert ((Get-WidgetReboundStrengthPreference @{energyConversion=40.96} 1)-eq 50) 'Legacy default migrates to an integer rebound step'
Assert ((Get-WidgetReboundStrengthPreference @{energyConversion=85} 1)-eq 100) 'Legacy maximum becomes maximum rebound'
Assert ((Get-WidgetReboundStrengthPreference @{energyConversion=0} 1)-eq 0) 'Legacy zero still disables rebound'
Assert ((Get-WidgetReboundStrengthPreference @{reboundStrength=0;energyConversion=85} 1)-eq 0) 'Explicit new zero takes priority'
foreach($invalid in @(-1,101,'broken',[double]::NaN,[double]::PositiveInfinity)){
  Assert ((Get-WidgetReboundStrengthPreference @{reboundStrength=$invalid;energyConversion=85} 1)-eq 100) 'Invalid new values fall back to a safe legacy step'
}
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'runtime/gravity.ps1') 'Set-WidgetPhysicsTuning')))
$script:gravity=[GptGravityModel]::new();$script:gravityStrength=1.6;$script:elasticStrength=1;$script:squishStrength=1;$script:animationSpeed=1;$script:tapCompression=1;$script:compressionCurve=1.6
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('rebound-steps-'+[Guid]::NewGuid().ToString('N'))
$script:settingsFile=Join-Path $temporary 'settings.json'
function Write-WidgetJson($file,$data){[IO.Directory]::CreateDirectory($temporary)|Out-Null;[IO.File]::WriteAllText($file,($data|ConvertTo-Json))}
try{
  foreach($step in @(0,50,100)){
    $script:reboundStrength=$step;Set-WidgetPhysicsTuning
    $saved=Get-Content -LiteralPath $script:settingsFile -Raw|ConvertFrom-Json
    Assert ($saved.reboundStrength-eq $step -and [Math]::Abs($script:gravity.EnergyConversion-.85*$step)-lt 1e-8) 'Production bridge saves integer UI step and maps to bounded retained energy'
    Assert ((Get-WidgetReboundStrengthPreference $saved 3)-eq $step) 'New preference round-trip independent of launch strength'
  }
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
'PASS: rebound steps, integer migration, zero/max, preference priority, safe energy mapping and save/load'
