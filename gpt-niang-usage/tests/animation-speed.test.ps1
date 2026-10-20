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
