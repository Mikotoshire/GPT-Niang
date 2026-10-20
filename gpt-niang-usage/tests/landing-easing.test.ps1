param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
$m=[GptGravityModel]::new();$m.DropFrom(240)
$beforeY=1.0
for($i=0;$i-lt 1000 -and $m.FloorImpacts-eq 0;$i++){$beforeY=$m.ScaleY;$m.Advance(1.0/240,900)}
Assert ($m.FloorImpacts-eq 1) 'Fixture must hit the floor'
Assert ([Math]::Abs($m.ScaleY-$beforeY)-lt 0.01) 'Incoming flight stretch must not snap away on contact'
$samples=New-Object Collections.Generic.List[double]
$samples.Add($m.ScaleY)
$launched=$false
for($i=0;$i-lt 150;$i++){
  $m.Advance(1.0/240,900);$samples.Add($m.ScaleY)
  if($m.Velocity-gt 0){$launched=$true;break}
}
Assert $launched 'Landing must launch within a bounded time'
$minimum=1.0;$peak=0
for($i=0;$i-lt $samples.Count;$i++){if($samples[$i]-lt $minimum){$minimum=$samples[$i];$peak=$i}}
$recovery=$samples.Count-1-$peak
Assert ($peak-gt 0 -and $recovery-ge $peak*1.3) 'Recovery must last appreciably longer than compression'
Assert ([Math]::Abs($samples[$samples.Count-1]-1)-lt 1e-8) 'Takeoff must begin at neutral shape, without a stretch jump'
$early=[Math]::Abs($samples[$peak+2]-$samples[$peak+1])
$middleIndex=$peak+[int][Math]::Floor($recovery/2)
$middle=[Math]::Abs($samples[$middleIndex+1]-$samples[$middleIndex])
$late=[Math]::Abs($samples[$samples.Count-2]-$samples[$samples.Count-3])
Assert ($early-lt $middle -and $late-lt $middle) 'Recovery must accelerate from maximum compression and brake near neutral'
$maximumStep=0.0
for($i=$peak+1;$i-lt $samples.Count;$i++){$maximumStep=[Math]::Max($maximumStep,[Math]::Abs($samples[$i]-$samples[$i-1]))}
Assert ($maximumStep-lt 0.03) 'Recovery must not contain a single-frame shape jump'
$m.Advance(1.0/240,900)
Assert ([Math]::Abs($m.ScaleY-1)-lt 0.005) 'Airborne stretch must ease in after recovery'
'PASS: continuous contact, longer recovery, nonuniform recovery speed, neutral takeoff and eased airborne stretch'
