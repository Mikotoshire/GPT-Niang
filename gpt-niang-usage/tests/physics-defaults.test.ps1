param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
. (Join-Path $AppDir 'runtime/gravity.ps1')
function Assert($ok,$message){if(!$ok){throw $message}}
function Import-Function($path,$name){
  $tokens=$null;$errors=$null
  $ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($path),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Production source parses'
  return $ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true).Extent.Text
}
$expected=@{GravityMultiplier=1.4;Elasticity=2.5;TapCompression=2;ImpactSquish=1.5;AnimationSpeed=1;EnergyConversion=55.25;CompressionCurve=1.5;GroundFrictionMultiplier=.2}
function Assert-Defaults($model){foreach($key in $expected.Keys){Assert ([Math]::Abs($model.$key-$expected[$key])-lt 1e-8) ('Default mismatch: '+$key)}}
$model=[GptGravityModel]::new();Assert-Defaults $model
$model.SetTuning([double]::NaN,[double]::PositiveInfinity)
$model.SetTapCompression([double]::NaN);$model.SetImpactSquish([double]::NaN)
$model.SetEnergyConversion([double]::NaN);$model.SetGroundFriction([double]::NaN)
$model.SetAnimationSpeed([double]::NaN);$model.SetCompressionCurve([double]::NaN)
Assert-Defaults $model
$widget=Join-Path $AppDir 'widget.ps1'
foreach($name in @('Get-WidgetEnergyConversionPreference','Get-WidgetReboundStrengthPreference')){. ([scriptblock]::Create((Import-Function $widget $name)))}
foreach($settings in @(@{},@{reboundStrength='broken'},@{reboundStrength=-1;energyConversion='bad'})){
  Assert ((Get-WidgetReboundStrengthPreference $settings 2.5)-eq 65) 'Absent/invalid rebound uses chosen default without legacy data'
}
Assert ((Get-WidgetReboundStrengthPreference @{elasticStrength=1} 1)-eq 50) 'Legacy shared control migrates independently of new defaults'
Assert ((Get-WidgetReboundStrengthPreference @{energyConversion=0} 1)-eq 0) 'Legacy zero is retained'
Assert ((Get-WidgetReboundStrengthPreference @{reboundStrength=0} 1)-eq 0) 'Explicit zero is retained'
Assert ((Get-WidgetReboundStrengthPreference @{reboundStrength=75} 1)-eq 75) 'Valid stored preferences are preserved'
function Save-Settings {}
$fields=@{gravityStrength='GravityMultiplier';elasticStrength='Elasticity';tapCompression='TapCompression';squishStrength='ImpactSquish';animationSpeed='AnimationSpeed';energyConversion='EnergyConversion';compressionCurve='CompressionCurve';groundFriction='GroundFrictionMultiplier'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($widget),[ref]$tokens,[ref]$errors)
foreach($field in @($fields.Keys)+@('reboundStrength')){
  $node=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq ('$script:'+$field)},$true)
  . ([scriptblock]::Create($node.Extent.Text))
  $value=Get-Variable -Name $field -Scope Script -ValueOnly
  $want=if($field-eq 'reboundStrength'){65}else{$expected[$fields[$field]]}
  Assert ([Math]::Abs($value-$want)-lt 1e-8) ('Widget initialization default: '+$field)
}
foreach($field in @($fields.Keys)+@('reboundStrength')){Set-Variable -Name $field -Scope Script -Value $null}
$script:gravity=[GptGravityModel]::new()
Set-WidgetPhysicsTuning
Assert-Defaults $script:gravity
$script:gravityStrength=3;$script:elasticStrength=.5;$script:tapCompression=0;$script:squishStrength=0;$script:animationSpeed=2;$script:reboundStrength=0;$script:groundFriction=0;$script:compressionCurve=3
Set-WidgetPhysicsTuning
Assert ($script:gravity.GravityMultiplier-eq 3 -and $script:gravity.Elasticity-eq .5 -and $script:gravity.TapCompression-eq 0 -and $script:gravity.ImpactSquish-eq 0 -and $script:gravity.GroundFrictionMultiplier-eq 0 -and $script:gravity.EnergyConversion-eq 0) 'Bridge preserves explicit custom and zero settings'
'PASS: model, widget, bridge, nonfinite fallbacks and legacy/custom preference defaults'
