param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
$natural=[GptGravityModel]::new()
Assert ($natural.CompressionCurve-eq 1.5) 'Natural default uses gentle initial braking'
$maxError=0.0
for($i=0;$i-le 1000;$i++){
  $t=$i/1000.0
  $maxError=[Math]::Max($maxError,[Math]::Abs($natural.GetCompressionProgress($t)-[Math]::Sin([Math]::PI*$t/2)))
}
Assert ($maxError-lt .021) 'Natural cubic stays within 2.1 percent of quarter-sine displacement'
Assert ([Math]::Abs($natural.GetCompressionProgress(.5)-.6875)-lt 1e-12) 'Natural midpoint avoids premature near-full squash'
foreach($curve in @(1.5,1.6,2.25,3)){
  $m=[GptGravityModel]::new();$m.SetCompressionCurve($curve)
  Assert ($m.GetCompressionProgress(0)-eq 0 -and $m.GetCompressionProgress(1)-eq 1) 'Curve endpoints stay fixed'
  $previous=0.0;$previousSpeed=10.0
  for($i=1;$i-le 100;$i++){
    $next=$m.GetCompressionProgress($i/100.0);$speed=$next-$previous
    Assert ($next-ge 0 -and $next-le 1 -and $speed-ge -1e-10 -and $speed-le $previousSpeed+1e-10) 'Compression moves forward with decreasing vertical speed'
    $previous=$next;$previousSpeed=$speed
  }
  Assert ((1-$m.GetCompressionProgress(.999))-lt .00001) 'Compression brakes to zero speed at peak'
  $m.DropFrom(240)
  for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,1000)}
  $previousY=$m.ScaleY;$previousSpeed=10.0
  for($i=0;$i-lt 100;$i++){
    $m.Advance(1.0/240,1000);$speed=$previousY-$m.ScaleY
    if($speed-lt 0){break}
    Assert ($speed-le $previousSpeed+1e-8) 'Actual vertical squash including incoming stretch must decelerate'
    $previousY=$m.ScaleY;$previousSpeed=$speed
  }
}
$a=[GptGravityModel]::new();$b=[GptGravityModel]::new();$a.SetCompressionCurve(1.5);$b.SetCompressionCurve(3)
Assert ($b.GetCompressionProgress(.25)-gt $a.GetCompressionProgress(.25)+.1) 'Slider changes front loading visibly'
foreach($m in @($a,$b)){$m.DropFrom(240)}
$different=$false
for($i=0;$i-lt 1500;$i++){
  foreach($m in @($a,$b)){$m.Advance(1.0/240,1000)}
  Assert ($a.Height-eq $b.Height -and $a.Velocity-eq $b.Velocity -and $a.StoredElasticEnergy-eq $b.StoredElasticEnergy -and $a.Rebounds-eq $b.Rebounds) 'Curve changes shape only, not energy or takeoff timing'
  if([Math]::Abs($a.ScaleY-$b.ScaleY)-gt .02){$different=$true}
}
Assert ($different -and !$a.Active -and !$b.Active) 'Different curves visibly animate and settle'
$m=[GptGravityModel]::new();$m.DropFrom(240)
for($i=0;$i-lt 1000 -and !$m.FloorImpacts;$i++){$m.Advance(1.0/240,1000)}
$m.Advance(.02,1000);$y=$m.ScaleY;$m.SetCompressionCurve(3);$m.Advance(0,1000)
Assert ($m.ScaleY-eq $y) 'Mid-contact adjustment does not jump the active pose'
$m.Reset();Assert ($m.CompressionCurve-eq 3) 'Reset keeps curve setting'
foreach($invalid in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity)){$m.SetCompressionCurve($invalid);Assert ($m.CompressionCurve-eq 1.6) 'Invalid values use the default'}
$m.SetCompressionCurve(0);Assert ($m.CompressionCurve-eq 1.5) 'Lower bound preserves monotonic deceleration'
$m.SetCompressionCurve(10);Assert ($m.CompressionCurve-eq 3) 'Upper bound preserves monotonic deceleration'
'PASS: curve shape, decreasing vertical speed, endpoints, braking, pose-only tuning, no mid-contact jump and validation'
function Import-TestFunction($file,$name){
  $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText($file),[ref]$tokens,[ref]$errors)
  Assert (!$errors.Count) 'Production source parses'
  return $ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true).Extent.Text
}
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'runtime/gravity.ps1') 'Set-WidgetPhysicsTuning')))
. ([scriptblock]::Create((Import-TestFunction (Join-Path $AppDir 'widget.ps1') 'Save-Settings')))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1')),[ref]$tokens,[ref]$errors)
$load=$ast.Find({param($n)$n-is [Management.Automation.Language.IfStatementAst] -and $n.Extent.Text.StartsWith('if($null-ne $settings.compressionCurve)')},$true)
Assert ($null-ne $load) 'Startup loads saved compression curve'
foreach($value in @($null,0,1.5,1.6,2.25,3,4,'broken',[double]::NaN,[double]::PositiveInfinity)){
  $settings=@{compressionCurve=$value};$script:compressionCurve=1.6
  . ([scriptblock]::Create($load.Extent.Text))
  $expected=if($null-ne $value -and $value-is [ValueType] -and $value-ge 1.5 -and $value-le 3){[double]$value}else{1.6}
  Assert ($script:compressionCurve-eq $expected) 'Old and invalid curve preferences retain default'
}
$temporary=Join-Path ([IO.Path]::GetTempPath()) ('compression-curve-'+[Guid]::NewGuid().ToString('N'))
$script:settingsFile=Join-Path $temporary 'settings.json'
function Write-WidgetJson($file,$data){[IO.Directory]::CreateDirectory($temporary)|Out-Null;[IO.File]::WriteAllText($file,($data|ConvertTo-Json))}
try{
  $script:gravity=[GptGravityModel]::new();$script:gravityStrength=1.6;$script:elasticStrength=1;$script:squishStrength=1;$script:animationSpeed=1;$script:tapCompression=1;$script:energyConversion=40.96;$script:compressionCurve=2.25
  Set-WidgetPhysicsTuning
  $saved=Get-Content -LiteralPath $script:settingsFile -Raw|ConvertFrom-Json
  Assert ($script:gravity.CompressionCurve-eq 2.25 -and $saved.compressionCurve-eq 2.25) 'Production tuning bridge applies and persists curve'
  $settings=$saved;$script:compressionCurve=1.6
  . ([scriptblock]::Create($load.Extent.Text))
  Assert ($script:compressionCurve-eq 2.25) 'Production startup loader restores the same curve'
}finally{if(Test-Path -LiteralPath $temporary){Remove-Item -LiteralPath $temporary -Recurse -Force}}
'PASS: production curve tuning, preference persistence and startup validation'
