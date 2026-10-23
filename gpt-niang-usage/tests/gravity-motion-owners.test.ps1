param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
# AI-generated compatibility regression; insufficiently validated. See AI-NOTICE.md.
# Load actual ownership helpers and the Aether-backed model. UI placement and
# render scheduling alone are deterministic seams; no mouse/audio input occurs.
. (Join-Path $AppDir 'runtime/gravity.ps1')
Add-Type -TypeDefinition @'
using System;
public static class GptWidgetNative {
 public struct Rect { public int Left,Top,Right,Bottom; }
 public static Rect Next;
 public static bool Available=true;
 public static int Reads;
 public static bool GetWindowRect(IntPtr window,out Rect rect){Reads++;rect=Next;return Available;}
}
'@
$script:checks=0
$script:failures=[Collections.Generic.List[string]]::new()
function Assert($Condition,[string]$Label){if(!$Condition){throw $Label};$script:checks++}
function Near([double]$Actual,[double]$Expected,[string]$Label){Assert ([Math]::Abs($Actual-$Expected)-lt 0.00001) $Label}
function Case([string]$Label,[scriptblock]$Body){
  try{& $Body;Write-Output ('PASS '+$Label)}catch{$script:failures.Add($Label+': '+$_.Exception.Message);Write-Output ('FAIL '+$Label+': '+$_.Exception.Message)}
}
function Set-AnimatedValue($Target,$Property,$Value){$Target.SetValue($Property,[double]$Value)}
function Get-WidgetPlacementFrame {return $script:frame}
function Get-WidgetPlacementDpi {return 1.5}
function Test-WidgetPlacementFrame($Frame,$Dpi){return $script:placementValid}
function Get-WidgetGravityGeometry {return [pscustomobject]@{Width=240;Height=300;Padding=20;Unit=2.0}}
function Start-WidgetGravityTimer {$script:starts++;$script:gravityTimer.IsEnabled=$true}
function Reset-Fixture {
  $script:gravity=[GptGravityModel]::new()
  $script:gravityMotionOwners=[Collections.Generic.HashSet[string]]::new()
  $script:gravityResumePending=$false
  $script:gravityEnabled=$true;$script:runtimeClosed=$false;$script:gravityInertia=$true
  $script:starts=0;$script:placementValid=$true
  $script:gravityTimer=[pscustomobject]@{Stops=0;IsEnabled=$true}
  $script:gravityTimer|Add-Member ScriptMethod Stop {$this.Stops++;$this.IsEnabled=$false}
  $script:gravitySampler=[pscustomobject]@{Stops=0}
  $script:gravitySampler|Add-Member ScriptMethod Stop {$this.Stops++}
  $script:ui=@{MotionOffset=[Windows.Media.TranslateTransform]::new(3,-4);PressScale=[Windows.Media.ScaleTransform]::new(1.3,0.7);GravityScale=[Windows.Media.ScaleTransform]::new(1.2,0.8)}
  $script:frame=[pscustomobject]@{Left=100;Top=50;Right=1300;Bottom=1000}
  $script:widgetHandle=[IntPtr]1;$script:displayScale=0.8
  $script:anchor='right';$script:offsetLeft=-1;$script:offsetRight=-1;$script:offsetBottom=-1;$script:lastPosition='previous'
  [GptWidgetNative]::Next=[GptWidgetNative+Rect]@{Left=300;Top=500;Right=540;Bottom=800}
  [GptWidgetNative]::Available=$true;[GptWidgetNative]::Reads=0
}
function Assert-Recovered {
  Near $script:gravity.Height 110 'Native top was not converted to real model drop height'
  Near $script:gravity.HorizontalPosition 100 'Native X was not converted to real model horizontal position'
  Near $script:offsetLeft (200/1.5) 'Left offset did not use placement DPI'
  Near $script:offsetRight (760/1.5) 'Right offset did not use placement DPI'
  Near $script:offsetBottom 88 'Bottom offset did not use display scale'
  Assert ($script:gravity.Active -and $script:gravityInertia) 'Recovered model was not active with inertia'
  Assert ($script:anchor-eq 'free' -and $null-eq $script:lastPosition) 'Recovery retained old anchor/cache'
  Assert (!$script:gravityResumePending) 'Successful recovery retained pending retry'
}
Case 'Nested music/completion ownership and duplicate calls' {
  Reset-Fixture
  $script:gravity.DropFrom(80);$script:gravity.BeginPress()
  Suspend-WidgetGravityForTransientMotion 'music'
  Assert (Test-WidgetGravityMotionSuspended) 'Music did not suspend ownership'
  Assert ($script:gravityMotionOwners.Count-eq 1) 'Music owner was not acquired'
  Assert (!$script:gravity.Active -and !$script:gravity.IsPressed -and !$script:gravityInertia) 'Suspend did not reset the real model'
  Assert ($script:gravityTimer.Stops-eq 1 -and $script:gravitySampler.Stops-eq 1) 'Suspend did not stop producers'
  Near $script:ui.MotionOffset.X 0 'Suspend retained X remainder';Near $script:ui.MotionOffset.Y 0 'Suspend retained Y remainder'
  Near $script:ui.PressScale.ScaleX 1 'Suspend retained press X';Near $script:ui.PressScale.ScaleY 1 'Suspend retained press Y'
  Near $script:ui.GravityScale.ScaleX 1 'Actual reset pose X was not applied';Near $script:ui.GravityScale.ScaleY 1 'Actual reset pose Y was not applied'
  Suspend-WidgetGravityForTransientMotion 'music'
  Assert ($script:gravityTimer.Stops-eq 1 -and $script:gravityMotionOwners.Count-eq 1) 'Duplicate acquire was not idempotent'
  Suspend-WidgetGravityForTransientMotion 'completion'
  Assert ($script:gravityMotionOwners.Count-eq 2) 'Nested owner replaced music'
  Resume-WidgetGravityFromNativePosition 'music'
  Assert ((Test-WidgetGravityMotionSuspended) -and $script:starts-eq 0 -and [GptWidgetNative]::Reads-eq 0) 'Nonfinal release resumed/read native motion'
  Resume-WidgetGravityFromNativePosition 'music';Resume-WidgetGravityFromNativePosition 'unknown'
  Assert ($script:gravityMotionOwners.Count-eq 1 -and $script:starts-eq 0) 'Duplicate/unowned release altered ownership'
  Resume-WidgetGravityFromNativePosition 'completion'
  Assert (!(Test-WidgetGravityMotionSuspended)) 'Final owner was retained'
  Assert ($script:starts-eq 1) 'Final owner did not restart exactly once'
  Assert-Recovered
  Resume-WidgetGravityFromNativePosition 'completion';Resume-WidgetGravityFromNativePosition ''
  Assert ($script:starts-eq 1) 'Duplicate release restarted again'
}
foreach($reason in @('invalid host','minimized host','native rectangle unavailable')){
  Case ($reason+' defers recovery and retries after placement returns') {
    Reset-Fixture
    Suspend-WidgetGravityForTransientMotion 'completion'
    if($reason-eq 'native rectangle unavailable'){[GptWidgetNative]::Available=$false}else{$script:placementValid=$false}
    Resume-WidgetGravityFromNativePosition 'completion'
    Assert ($script:starts-eq 0 -and !$script:gravity.Active) 'Unavailable placement restarted motion'
    Assert ($script:gravityResumePending) 'Unavailable placement lost pending recovery'
    Resume-WidgetGravityFromNativePosition ''
    Assert ($script:starts-eq 0 -and $script:gravityResumePending) 'Failed retry lost recovery or restarted'
    $script:placementValid=$true;[GptWidgetNative]::Available=$true
    Resume-WidgetGravityFromNativePosition ''
    Assert ($script:starts-eq 1) 'Maintenance retry did not restart after placement returned'
    Assert-Recovered
    Resume-WidgetGravityFromNativePosition 'completion'
    Assert ($script:starts-eq 1) 'Late original release restarted after retry'
  }
}
foreach($reason in @('disabled','closed')){
  Case ($reason+' before final release suppresses native recovery') {
    Reset-Fixture
    Suspend-WidgetGravityForTransientMotion 'completion'
    if($reason-eq 'disabled'){$script:gravityEnabled=$false}else{$script:runtimeClosed=$true}
    Resume-WidgetGravityFromNativePosition 'completion'
    Assert ($script:starts-eq 0 -and [GptWidgetNative]::Reads-eq 0) 'Disabled/closed final release read/restarted motion'
    Assert (!(Test-WidgetGravityMotionSuspended) -and !$script:gravityResumePending) 'Disabled/closed final release retained ownership/retry'
  }
  Case ($reason+' gravity does not restart or retain a stale retry') {
    Reset-Fixture
    Suspend-WidgetGravityForTransientMotion 'music'
    $script:placementValid=$false
    Resume-WidgetGravityFromNativePosition 'music'
    Assert ($script:gravityResumePending) 'Fixture did not defer recovery'
    if($reason-eq 'disabled'){$script:gravityEnabled=$false}else{$script:runtimeClosed=$true}
    Resume-WidgetGravityFromNativePosition ''
    Assert ($script:starts-eq 0 -and !$script:gravityResumePending) 'Disabled/closed runtime restarted or retained retry'
    $script:placementValid=$true;Resume-WidgetGravityFromNativePosition ''
    Assert ($script:starts-eq 0) 'Disabled/closed late retry restarted'
  }
}
Case 'Completion may release before music without restarting physics' {
  Reset-Fixture
  Suspend-WidgetGravityForTransientMotion 'music';Suspend-WidgetGravityForTransientMotion 'completion'
  Resume-WidgetGravityFromNativePosition 'completion'
  Assert ($script:starts-eq 0 -and $script:gravityMotionOwners.Contains('music')) 'Completion release bypassed music ownership'
  Resume-WidgetGravityFromNativePosition 'music'
  Assert ($script:starts-eq 1) 'Music final release did not restart'
  Assert-Recovered
}
Case 'A new transient owner supersedes pending recovery' {
  Reset-Fixture
  Suspend-WidgetGravityForTransientMotion 'music'
  $script:placementValid=$false;Resume-WidgetGravityFromNativePosition 'music'
  Assert ($script:gravityResumePending) 'Fixture did not defer recovery'
  Suspend-WidgetGravityForTransientMotion 'completion'
  Assert (!$script:gravityResumePending) 'New owner retained obsolete retry'
  $script:placementValid=$true;Resume-WidgetGravityFromNativePosition ''
  Assert ($script:starts-eq 0 -and (Test-WidgetGravityMotionSuspended)) 'Maintenance bypassed current owner'
  Resume-WidgetGravityFromNativePosition 'completion'
  Assert ($script:starts-eq 1) 'New final owner did not recover'
  Assert-Recovered
}
if($script:failures.Count){throw (($script:failures.Count.ToString()+' actual gravity ownership case(s) failed: ')+($script:failures -join '; '))}
Write-Output ("All $script:checks actual gravity ownership assertions passed.")
