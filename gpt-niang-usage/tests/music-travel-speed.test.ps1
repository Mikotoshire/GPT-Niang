param([string]$ResultFile)
# AI-generated maintenance regression; insufficiently validated or independently reviewed.
$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
Initialize-WidgetMusicTypes

function New-TravelMotion([double]$dpi=1,[int]$direction=1){
 $m=[GptMusicMotion]::new(2500*$dpi,650*$dpi,5000*$dpi,650*$dpi,132*$dpi,$dpi)
 $m.Phase=2;$m.Props=1;$m.Direction=$direction
 return $m
}
function Assert-Near([double]$actual,[double]$expected,[double]$tolerance,[string]$message){
 if([double]::IsNaN($actual) -or [double]::IsInfinity($actual) -or [Math]::Abs($actual-$expected)-gt $tolerance){throw ($message+': expected '+$expected+', got '+$actual)}
}
$default=New-TravelMotion
if(!$default.PSObject.Properties['TravelSpeedMultiplier']){throw 'Missing public TravelSpeedMultiplier property'}
Assert-Near $default.TravelSpeedMultiplier 1 0 'Default travel multiplier'
$cases=0
foreach($dpi in @(1.0,1.5,2.0)){
 foreach($hz in @(30,60,120,144)){
  foreach($direction in @(-1,1)){
   foreach($multiplier in @(0,.5,1,2)){
    $m=New-TravelMotion $dpi $direction;$m.TravelSpeedMultiplier=$multiplier
    for($i=0;$i-lt 3*$hz;$i++){$m.Step((1.0/$hz),$false,$true,($i/$hz/.5),.5,1)}
    $start=$m.X
    for($i=0;$i-lt 2*$hz;$i++){$m.Step((1.0/$hz),$false,$true,(6+$i/$hz/.5),.5,1)}
    $speed=($m.X-$start)*$direction/$dpi/2
    Assert-Near $speed (35*$multiplier) .04 ('Travel speed at '+$multiplier+', DPI '+$dpi+', Hz '+$hz+', direction '+$direction)
    $cases++
   }
  }
 }
}

# Live updates use the same motion instance and retain the existing acceleration/decay.
$dynamic=New-TravelMotion
foreach($multiplier in @(2,.5,0,1)){
 $dynamic.TravelSpeedMultiplier=$multiplier
 for($i=0;$i-lt 4*60;$i++){$dynamic.Step((1.0/60),$false,$true,($dynamic.Time/.5),.5,1)}
 Assert-Near $dynamic.Vx (35*$multiplier) .001 ('Live multiplier '+$multiplier)
 $start=$dynamic.X
 for($i=0;$i-lt 60;$i++){$dynamic.Step((1.0/60),$false,$true,($dynamic.Time/.5),.5,1)}
 Assert-Near ($dynamic.X-$start) (35*$multiplier) .001 'Live travel distance'
}

# Disabling travel leaves the entire beat pose and vertical state unchanged.
$moving=New-TravelMotion;$stationary=New-TravelMotion;$stationary.TravelSpeedMultiplier=0
foreach($locked in @($true,$false,$true)){
 for($i=0;$i-lt 240;$i++){
  foreach($m in @($moving,$stationary)){$m.Step((1.0/60),$false,$locked,($m.Time/.5),.5,1)}
  foreach($property in @('Y','Vy','Bend','BendSpeed','Rock','RockSpeed','Lamp','LampSpeed','Pulse','Energy','Cycle','Time','Props','Phase','Impacts')){
   Assert-Near $stationary.$property $moving.$property 1e-10 ('Zero travel preserves '+$property)
  }
 }
}
Assert-Near $stationary.X 2500 0 'Zero travel remains stationary from rest'

# Follow the same pointer flick through air, wall reflection and floor contacts.
# Compare only while throw momentum remains dominant, before auto travel resumes.
$throwCases=0;$wallBounces=0;$floorContacts=0;$glideSamples=0
foreach($dpi in @(1.0,1.5,2.0)){
 foreach($hz in @(30,60,144)){
  foreach($multiplier in @(0,.5,2)){
   $motions=@()
   foreach($factor in @(1,$multiplier)){
    $m=[GptMusicMotion]::new(600*$dpi,610*$dpi,900*$dpi,650*$dpi,132*$dpi,$dpi)
    $m.Phase=2;$m.TravelSpeedMultiplier=$factor;$m.BeginHold(600*$dpi,610*$dpi)
    for($i=1;$i-le [Math]::Ceiling(.20*$hz);$i++){$m.SamplePointer((600+1000*$i/$hz)*$dpi,610*$dpi,(1.0/$hz))}
    $m.Release();$motions+=,$m
   }
   $seenWall=$false;$seenFloor=$false;$seenGlide=$false
   for($i=0;$i-lt 2*$hz;$i++){
    $oldVelocity=$motions[0].Vx
    foreach($m in $motions){$m.Step((1.0/$hz),$false,$true,($i/$hz/.5),.5,1)}
    if($oldVelocity-gt 0 -and $motions[0].Vx-lt 0){$seenWall=$true}
    if($motions[0].Impacts-gt 0){$seenFloor=$true}
    if($motions[0].Phase-eq 2 -and [Math]::Abs($motions[0].Vx)-gt 35*$dpi){$seenGlide=$true;$glideSamples++}
    foreach($property in @('X','Y','Vx','Vy','Impacts','Phase','Bend','Rock','Lamp','Cycle')){
     Assert-Near $motions[1].$property $motions[0].$property 1e-10 ('Throw preserves '+$property+' at multiplier '+$multiplier)
    }
   }
   if(!$seenWall -or !$seenFloor -or !$seenGlide){throw 'Throw fixture missed wall, floor or post-landing inertia'}
   $wallBounces++;$floorContacts++;$throwCases++
  }
 }
}

# Finite out-of-range settings clamp; non-finite inputs safely restore the default.
$validation=New-TravelMotion
foreach($case in @(@(-1,0),@(3,2),@([double]::MinValue,0),@([double]::MaxValue,2),@([double]::NaN,1),@([double]::PositiveInfinity,1),@([double]::NegativeInfinity,1))){
 $validation.TravelSpeedMultiplier=.5;$validation.TravelSpeedMultiplier=$case[0]
 Assert-Near $validation.TravelSpeedMultiplier $case[1] 0 'Safe multiplier normalization'
 $validation.Step((1.0/60),$false,$true,($validation.Time/.5),.5,1)
 foreach($property in @('X','Y','Vx','Bend','Cycle')){
  if([double]::IsNaN($validation.$property) -or [double]::IsInfinity($validation.$property)){throw ('Unsafe motion state after invalid multiplier: '+$property)}
 }
}
$result=@{passed=$true;travelCases=$cases;dynamicUpdates=4;zeroPreservesBeatPose=$true;throwCases=$throwCases;wallBounces=$wallBounces;floorContacts=$floorContacts;postLandingGlideSamples=$glideSamples;safeInvalidInputs=7}
if($ResultFile){[IO.File]::WriteAllText($ResultFile,($result|ConvertTo-Json),[Text.UTF8Encoding]::new($false))}
Write-Output ('PASS: music travel multiplier '+$cases+' speed cases; live changes, unchanged beat pose, '+$throwCases+' throw cases and safe invalid inputs')
