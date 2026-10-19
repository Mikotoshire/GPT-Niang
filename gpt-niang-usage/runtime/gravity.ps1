$gravityLibrary=Join-Path $PSScriptRoot 'vendor/aether/Aether.Physics2D.dll'
# The stable launcher may have no PowerShell module autoload path.
$gravityHasher=[Security.Cryptography.SHA256]::Create()
$gravityStream=[IO.File]::OpenRead($gravityLibrary)
try{$gravityHash=[BitConverter]::ToString($gravityHasher.ComputeHash($gravityStream)).Replace('-','')}
finally{$gravityStream.Dispose();$gravityHasher.Dispose()}
if($gravityHash -ne '56F511BAADEF2C521D7DE983418813B075B3C2194825C7E17C06B59F267F2A78'){throw 'Physics library hash mismatch'}
if(!('nkast.Aether.Physics2D.Dynamics.World' -as [type])){Add-Type -Path $gravityLibrary}
if(!('GptGravityModel' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'gravity-model.cs') -ReferencedAssemblies $gravityLibrary}

Add-Type -AssemblyName PresentationCore,WindowsBase
if(!('GptGravityRenderLoop' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'gravity-render.cs') -ReferencedAssemblies @([Windows.Media.CompositionTarget].Assembly.Location,[Windows.DependencyObject].Assembly.Location)}

function Get-WidgetGravityPadding {
  # Ground is the visible character's feet, excluding the transparent canvas margin.
  return [Math]::Max(0,$script:designHeight-([Windows.Controls.Canvas]::GetTop($script:ui.Root)+[Windows.Controls.Canvas]::GetTop($script:ui.Girl)+$script:ui.Girl.Height))
}
function Get-WidgetGravityGeometry {
  $rect=New-Object GptWidgetNative+Rect
  [GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
  $w=[Math]::Max(1,$rect.Right-$rect.Left);$h=[Math]::Max(1,$rect.Bottom-$rect.Top)
  # WPF rounds the native window at fractional DPI. Use its real client size
  # for the Viewbox mapping so transparent padding never shifts the floor.
  $unit=[Math]::Min($w/$script:designWidth,$h/$script:designHeight)
  return [pscustomobject]@{Width=$w;Height=$h;Unit=$unit;Padding=($h-$script:designHeight*$unit)/2+(Get-WidgetGravityPadding)*$unit}
}
function Initialize-WidgetGravity {
  $script:gravity=[GptGravityModel]::new()
  $script:gravityInertia=$false
  $script:gravitySampler=[GptDragVelocity]::new()
  if($null-eq $script:gravityStrength){$script:gravityStrength=1.6}
  if($null-eq $script:elasticStrength){$script:elasticStrength=1.0}
  $script:gravity.SetTuning($script:gravityStrength,$script:elasticStrength)
  if($script:gravityEnabled){$script:gravity.DropFrom([Math]::Max(0,$script:offsetBottom/[Math]::Max(0.1,$script:displayScale)))}
  $script:gravityClock=[Diagnostics.Stopwatch]::StartNew()
  $script:gravityTimer=[GptGravityRenderLoop]::new()
  $script:gravityTimer.Add_Tick({try{Update-WidgetGravity}catch{
    $script:gravityTimer.Stop()
    [IO.File]::WriteAllText((Join-Path $script:dataDir 'gravity-error.txt'),$_.Exception.ToString(),[Text.UTF8Encoding]::new($false))
  }})
}
function Start-WidgetGravityTimer {
  if($script:gravityEnabled -and $script:gravity.Active -and !$script:gravityTimer.IsEnabled){$script:gravityClock.Restart();$script:gravityTimer.Start()}
}
function Set-WidgetGravityPose {
  $script:ui.GravityScale.ScaleX=$script:gravity.ScaleX
  $script:ui.GravityScale.ScaleY=$script:gravity.ScaleY
}
function Set-WidgetGravityMode([bool]$Enabled) {
  $script:gravitySampler.Stop()
  $script:gravityEnabled=$Enabled
  $script:gravityInertia=$false
  $script:gravityTimer.Stop()
  Set-AnimatedValue $script:ui.PressScale ([Windows.Media.ScaleTransform]::ScaleXProperty) 1
  Set-AnimatedValue $script:ui.PressScale ([Windows.Media.ScaleTransform]::ScaleYProperty) 1
  $rect=New-Object GptWidgetNative+Rect
  [GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  if(Test-WidgetPlacementFrame $frame $dpi){
    $geometry=Get-WidgetGravityGeometry
    $padding=$geometry.Padding/$dpi
    $height=($frame.Bottom-$rect.Bottom)/$dpi
    if($Enabled){$script:gravity.DropFrom([Math]::Max(0,($height+$padding)*$dpi/$geometry.Unit));$script:offsetBottom=$script:gravity.Height*$script:displayScale}
    else{$script:offsetBottom=[Math]::Max(0,$height);$script:gravity.Reset()}
  }else{$script:gravity.Reset()}
  Set-WidgetGravityPose
  $script:lastPosition=$null;Save-Settings;Tick-Widget;Start-WidgetGravityTimer
}
function Begin-WidgetGravityDrag {
  $script:gravityInertia=$false
  $script:gravitySampler.Start()
  $script:gravityTimer.Stop();$script:gravity.BeginDrag();Set-WidgetGravityPose
}
function Set-WidgetPhysicsTuning {
  $script:gravity.SetTuning($script:gravityStrength,$script:elasticStrength)
  Save-Settings
}
function Release-WidgetGravityDrop([switch]$Cancel) {
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  $rect=New-Object GptWidgetNative+Rect
  [GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
  $geometry=Get-WidgetGravityGeometry
  $height=($frame.Bottom-$rect.Bottom+$geometry.Padding)/$geometry.Unit
  $velocity=$script:gravitySampler.Finish($geometry.Unit)
  if($Cancel){$velocity=@(0.0,0.0)}
  $vx=$velocity[0];$vy=$velocity[1]
  $script:gravity.SetHorizontalPosition([Math]::Max(0,($rect.Left-$frame.Left)/$geometry.Unit))
  $script:gravity.FlingFrom([Math]::Max(0,$height),$vx,$vy)
  $script:gravityInertia=$true;$script:anchor='free'
  $script:offsetBottom=$script:gravity.Height*$script:displayScale
  Set-WidgetGravityPose;Start-WidgetGravityTimer
}
function Update-WidgetGravity {
  $elapsed=$script:gravityClock.Elapsed.TotalSeconds;$script:gravityClock.Restart()
  if(!$script:gravityEnabled -or $script:runtimeClosed){$script:gravityTimer.Stop();return}
  if(!$script:window.IsVisible){$script:gravityTimer.Stop();return}
  if($script:followHost -and ($script:hostHandle-eq [IntPtr]::Zero -or [GptWidgetNative]::IsIconic($script:hostHandle) -or ![GptWidgetNative]::IsWindowVisible($script:hostHandle))){$script:gravityTimer.Stop();return}
  if($script:drag -and $script:drag.moved){return}
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  if(!(Test-WidgetPlacementFrame $frame $dpi)){return}
  $geometry=Get-WidgetGravityGeometry;$unit=$geometry.Unit
  $w=$geometry.Width;$h=$geometry.Height;$padding=$geometry.Padding
  $ceiling=[Math]::Max(0,($frame.Bottom-$frame.Top-$h+$padding)/$unit)
  $rect=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
  if(!$script:gravityInertia){$script:gravity.SetHorizontalPosition([Math]::Max(0,($rect.Left-$frame.Left)/$unit))}
  $width=[Math]::Max(0,($frame.Right-$frame.Left-$w)/$unit)
  $script:gravity.Advance($elapsed,$ceiling,$width);Set-WidgetGravityPose
  $x=[int][Math]::Round($frame.Left+$script:gravity.HorizontalPosition*$unit)
  if($script:gravityInertia){
    $script:offsetLeft=($x-$frame.Left)/$dpi;$script:offsetRight=($frame.Right-$x-$w)/$dpi
    $script:anchor='free';$script:desktopLeft=$x
  }
  $script:offsetBottom=$script:gravity.Height*$script:displayScale
  if($script:followHost){
    $script:hostFollower.MovePose([int]($script:offsetLeft*$dpi),[int]($script:offsetRight*$dpi),[int]($script:gravity.Height*$unit-$padding),$script:anchor)
  }else{
    $rect=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
    $y=[int][Math]::Round($frame.Bottom-$h+$padding-$script:gravity.Height*$unit)
    $script:desktopTop=$y
    [GptWidgetNative]::SetWindowPos($script:widgetHandle,[IntPtr]::Zero,$x,$y,0,0,0x15)|Out-Null
  }
  $script:lastPosition=$null
  if($script:context.IsOpen){Set-WidgetMenuBounds;Position-WidgetMenuToHost}
  if(!$script:gravity.Active){$script:gravityTimer.Stop();Save-Settings}
}
