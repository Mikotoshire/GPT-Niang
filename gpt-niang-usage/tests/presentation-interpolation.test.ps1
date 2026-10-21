param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
. (Join-Path $AppDir 'runtime/gravity.ps1')
function Assert($value,$message){if(!$value){throw $message}}
$failedCases=@()
foreach($rate in @(60,144,180,240)){
 $m=[GptGravityModel]::new();$m.SetHorizontalPosition(200);$m.FlingFrom(5000,600,0)
 $property=$m.GetType().GetProperty('RenderHorizontalPosition')
 $last=200.0;$errorSquared=0.0;$repeats=0;$count=0
 foreach($i in 0..([int]($rate*.5)-1)){
  $dt=if($rate-eq 240){if($i%2-eq 0){.002}else{2.0/240-.002}}else{1.0/$rate}
  $m.Advance($dt,10000,10000)
  $x=if($property){$property.GetValue($m,$null)}else{$m.HorizontalPosition}
  if($i-ge 5){
   $delta=$x-$last;if([Math]::Abs($delta)-lt .000001){$repeats++}
   $relative=($delta/$dt-600)/600;$errorSquared+=$relative*$relative;$count++
  }
  $last=$x
 }
 $rms=[Math]::Sqrt($errorSquared/$count)
 "MEASURE: displayHz=$rate repeatedPoses=$repeats relativeSpeedRms=$rms"
 if($repeats-ne 0 -or $rms-ge .005){$failedCases+=,$rate}
}
if($failedCases.Count){throw ('Fixed-step display judder at rates: '+($failedCases-join ','))}
$layout=[GptGravityModel]::new();$layout.FlingFrom(300,0,-200);$layout.Advance(1.0/180,1000,2000)
$layoutHeight=$layout.RenderHeight;$layout.SetHorizontalPosition($layout.HorizontalPosition+.00001)
Assert ($layout.RenderHeight-eq $layoutHeight) 'Horizontal layout refresh must not reset vertical presentation phase'
$m=[GptGravityModel]::new();$m.SetHorizontalPosition(100);$m.FlingFrom(300,600,-200);$m.Advance(1.0/180,1000,2000)
$x=$m.RenderHorizontalPosition;$y=$m.RenderHeight
Assert ([Math]::Abs($m.HorizontalPosition-$x)-gt .001) 'Fixture must have a real residual phase'
$m.BeginPress()
Assert ([Math]::Abs($m.Height-$y)-lt .000001 -and [Math]::Abs($m.HorizontalPosition-$x)-lt .000001) 'Press must freeze the displayed pose rather than jump ahead'
Assert ($m.Velocity-eq 0 -and $m.HorizontalVelocity-eq 0) 'Press must not invent momentum'
$m.BeginDrag();$m.SetHorizontalPosition(222);$m.DragTo(333)
Assert ($m.RenderHeight-eq 333 -and $m.RenderHorizontalPosition-eq 222) 'Direct drag must bypass interpolation history'
$m.DropFrom(40)
foreach($i in 1..1000){
 $m.Advance(1.0/180,1000,2000)
 Assert ($m.RenderHeight-ge 0 -and $m.RenderHeight-le 1000) 'Presentation escaped physical bounds'
 if($m.Height-eq 0){Assert ($m.RenderHeight-eq 0) 'Landing must show the exact floor without residual hover'}
 if(!$m.Active){break}
}
Assert (!$m.Active) 'Interpolation must not keep a settled body active'
'PASS: uniform high-refresh presentation, immediate press/drag, exact floor and finite settling'
