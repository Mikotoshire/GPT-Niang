param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated maintenance tests; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
function Assert($value,$message){if(!$value){throw $message}}
function First-Landing($model){
  for($i=0;$i-lt 1000 -and $model.FloorImpacts-eq 0;$i++){$model.Advance(1.0/240,900,20000)}
  Assert ($model.FloorImpacts-eq 1) 'Fixture must reach real floor contact'
}
$m=[GptGravityModel]::new();$m.SetHorizontalPosition(1000);$m.FlingFrom(240,350,0);First-Landing $m
Assert ($m.Height-eq 0 -and $m.Velocity-eq 0) 'Contact must begin compression before any upward bounce'
$initialX=$m.HorizontalPosition;$squashed=$false;$recovered=$false;$launched=$false
for($i=0;$i-lt 100;$i++){
  $m.Advance(1.0/240,900,20000)
  if($m.ScaleY-lt 0.98){$squashed=$true}
  if($squashed -and $m.ScaleY-ge 0.995){$recovered=$true}
  if(!$recovered){Assert ($m.Height-eq 0 -and $m.Velocity-eq 0) 'Stay on floor until shape recovery completes'}
  if($m.Velocity-gt 0){Assert $recovered 'Only a recovered shape can launch';$launched=$true;break}
}
Assert ($squashed -and $launched) 'Landing must visibly compress, recover and launch within a bounded time'
Assert ($m.HorizontalPosition-gt $initialX -and $m.HorizontalVelocity-gt 0) 'Horizontal inertia continues throughout compression'
Assert ($m.FloorImpacts-eq 1 -and $m.Rebounds-eq 1) 'Compression is one collision and one delayed rebound'
$peak=0.0
for($i=0;$i-lt 200 -and $m.FloorImpacts-eq 1;$i++){$m.Advance(1.0/240,900,20000);$peak=[Math]::Max($peak,$m.Height)}
Assert ($peak-gt 80 -and $peak-le 240*[GptGravityModel]::Restitution*[GptGravityModel]::Restitution+2) 'Delayed takeoff retains bounded solver rebound energy'
$depths=@()
foreach($speed in @(100,600,1200)){
  $m=[GptGravityModel]::new();$m.FlingFrom(1,0,-$speed);First-Landing $m
  $depth=0.0
  for($i=0;$i-lt 60;$i++){$m.Advance(1.0/240,900);$depth=[Math]::Max($depth,1-$m.ScaleY)}
  $depths+=,$depth
}
Assert ($depths[0]-gt 0 -and $depths[1]-gt $depths[0] -and $depths[2]-gt $depths[1]) 'Faster downward impacts must produce progressively more compression'
$m=[GptGravityModel]::new();$m.SetImpactSquish(3);$m.FlingFrom(1,0,-1600);First-Landing $m
for($i=0;$i-lt 50;$i++){$m.Advance(1.0/240,900);Assert ($m.ScaleY-ge 0.44 -and $m.ScaleX-le 1.30) 'Strong impacts must stay within safe scale bounds'}
foreach($cancel in @('Reset','BeginPress','BeginDrag')){
  $m=[GptGravityModel]::new();$m.DropFrom(240);First-Landing $m
  $m.$cancel()
  for($i=0;$i-lt 100;$i++){$m.Advance(1.0/240,900)}
  Assert ($m.Rebounds-eq 0 -and $m.Velocity-eq 0) 'Interrupting a landing cancels stored rebound'
}
'PASS: speed-linked compression, floor dwell, recovery before takeoff, sliding, bounded energy and cancellation'
