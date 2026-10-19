param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
$library=Join-Path $AppDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $AppDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
$checks=0
function Assert($Condition,[string]$Label){if(!$Condition){throw $Label};$script:checks++}
function Step($Model,[double]$Seconds,[double]$Hz=120,[double]$Ceiling=700){
  $left=$Seconds
  while($left-gt 0.0000001){$dt=[Math]::Min(1/$Hz,$left);$Model.Advance($dt,$Ceiling);$left-=$dt}
}
function Finish($Model){
  $peak=0.0
  for($i=0;$i-lt 3000 -and $Model.Active;$i++){$Model.Advance(1.0/120,700);$peak=[Math]::Max($peak,$Model.Height);Assert ($Model.Height-ge 0) 'Body penetrated floor'}
  Assert (!$Model.Active -and $Model.Height-eq 0 -and $Model.Velocity-eq 0) 'Motion must finish at rest on the floor'
  return $peak
}
$tap=[GptGravityModel]::new();$tap.BeginPress();Step $tap 0.04;$tap.ReleasePress()
Assert ($tap.ReleasePending -and $tap.Velocity-eq 0) 'Quick tap must finish compression before launching'
Step $tap 0.185
Assert ($tap.Velocity-gt 0) 'Completed compression must launch upward'
$tapPeak=Finish $tap
Assert ([Math]::Abs($tapPeak-[GptGravityModel]::TapHeight)-lt 0.5) 'Tap jump must have the configured small apex'
Assert ($tap.Rebounds-eq 0) 'Tap must stop at its first floor contact'
$charged=[GptGravityModel]::new();$charged.BeginPress();Step $charged 0.22
$baseY=$charged.ScaleY;$baseX=$charged.ScaleX
Step $charged 0.8
Assert ($charged.ScaleY-lt $baseY -and $charged.ScaleX-gt $baseX -and $charged.Charge-gt 0) 'Long hold must flatten, widen and accumulate energy'
$compressedY=$charged.ScaleY
$charged.ReleasePress()
Assert ([Math]::Abs($charged.ScaleY-$compressedY)-lt 0.000001) 'Release must not instantly snap the compressed image to full height'
Step $charged 0.06
Assert ($charged.ScaleY-gt $compressedY -and $charged.ScaleY-lt 1.1) 'Shape must recover smoothly during takeoff'
$chargedPeak=Finish $charged
Assert ($chargedPeak-gt $tapPeak*3 -and $charged.Rebounds-ge 2) 'Charged jump must be higher and rebound repeatedly'
Assert ($charged.PeakHeight-le [GptGravityModel]::TapHeight+0.0001) 'Final landing must follow a jump at or below tap height'
Assert ([Math]::Abs($charged.ScaleX-1)-lt 0.0001 -and [Math]::Abs($charged.ScaleY-1)-lt 0.0001) 'Shape must return to rest'
$small=[GptGravityModel]::new();$small.BeginPress();Step $small 0.4;$small.ReleasePress();$smallPeak=Finish $small
Assert ($smallPeak-gt $tapPeak -and $smallPeak-lt $chargedPeak) 'Jump height must increase with compression'
$drop=[GptGravityModel]::new();$drop.BeginDrag();$drop.DragTo(240);$drop.DropFrom(240)
Step $drop 0.1
Assert ($drop.Height-lt 240 -and $drop.Velocity-lt 0) 'Released drag must fall under gravity'
$null=Finish $drop;Assert ($drop.Rebounds-ge 1) 'Dropping from height must rebound'
$low=[GptGravityModel]::new();$low.DropFrom(10);$null=Finish $low
Assert ($low.Rebounds-eq 0) 'A drop below tap threshold must stop on contact'
$cancel=[GptGravityModel]::new();$cancel.BeginPress();Step $cancel 0.7;$cancel.BeginDrag();$cancel.DragTo(180)
Assert ($cancel.Charge-eq 0 -and $cancel.ScaleX-eq 1 -and $cancel.ScaleY-eq 1) 'Dragging must cancel charge and restore shape'
$cancel.DropFrom(180);$cancel.Reset()
Assert (!$cancel.Active -and $cancel.Velocity-eq 0 -and $cancel.ScaleY-eq 1) 'Disabling mode must stop physics and reset shape'
$a=[GptGravityModel]::new();$b=[GptGravityModel]::new();$a.DropFrom(300);$b.DropFrom(300)
Step $a 1.3 30;Step $b 1.3 144
Assert ([Math]::Abs($a.Height-$b.Height)-lt 0.01 -and [Math]::Abs($a.Velocity-$b.Velocity)-lt 0.01) 'Physics must be independent of rendering rate'
$cap=[GptGravityModel]::new();$cap.BeginPress();Step $cap 9;$cap.ReleasePress();Step $cap 0.4 120 40
Assert ($cap.Height-le 40 -and $cap.Height-ge 0) 'Small windows must cap the jump safely'
$cap.Advance(10,0);Assert ($cap.Height-eq 0 -and $cap.Velocity-eq 0) 'Zero available height must settle safely'
$fling=[GptGravityModel]::new();$fling.SetHorizontalPosition(200);$fling.FlingFrom(240,600,300)
$fling.Advance(0.05,700,800)
Assert ($fling.HorizontalPosition-gt 220 -and $fling.HorizontalVelocity-gt 500 -and $fling.Height-gt 240) 'Fling must preserve both drag velocity components'
$wall=[GptGravityModel]::new();$wall.SetHorizontalPosition(790);$wall.FlingFrom(240,800,0)
for($i=0;$i-lt 30;$i++){$wall.Advance(1.0/240,700,800)}
Assert ($wall.HorizontalPosition-le 800 -and $wall.HorizontalVelocity-lt 0) 'Wall collision must reflect horizontal inertia'
$slide=[GptGravityModel]::new();$slide.SetHorizontalPosition(200);$slide.FlingFrom(0,500,0)
for($i=0;$i-lt 3000 -and $slide.Active;$i++){$slide.Advance(1.0/240,700,10000)}
Assert (!$slide.Active -and $slide.HorizontalVelocity-eq 0 -and $slide.HorizontalPosition-gt 200) 'Ground friction must slow sliding to exact rest'
$slide.Reset();Assert ($slide.HorizontalVelocity-eq 0) 'Mode reset must clear inertia'
Write-Output "PASS: $checks gravity assertions (tap, charge, decay, drag/drop, cancellation, bounds and frame-rate invariance)."
