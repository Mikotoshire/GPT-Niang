if(!('GptGravityModel' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'gravity-model.cs')}

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
  if($script:gravityEnabled){$script:gravity.DropFrom([Math]::Max(0,$script:offsetBottom/[Math]::Max(0.1,$script:displayScale)))}
  $script:gravityClock=[Diagnostics.Stopwatch]::StartNew()
  $script:gravityTimer=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Render)
  $script:gravityTimer.Interval=[TimeSpan]::FromMilliseconds(16)
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
  $script:gravityEnabled=$Enabled
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
  $script:gravityTimer.Stop();$script:gravity.BeginDrag();Set-WidgetGravityPose
}
function Release-WidgetGravityDrop {
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  $rect=New-Object GptWidgetNative+Rect
  [GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
  $geometry=Get-WidgetGravityGeometry
  $height=($frame.Bottom-$rect.Bottom+$geometry.Padding)/$geometry.Unit
  $script:gravity.DropFrom([Math]::Max(0,$height))
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
  $script:gravity.Advance($elapsed,$ceiling);Set-WidgetGravityPose
  $script:offsetBottom=$script:gravity.Height*$script:displayScale
  if($script:followHost){
    $nativeFrame=[GptWidgetNative]::Frame($script:hostHandle)
    $script:hostFollower.Configure($script:hostHandle,$nativeFrame.Left,$nativeFrame.Top,$nativeFrame.Right,$nativeFrame.Bottom,$w,$h,[int]($script:offsetLeft*$dpi),[int]($script:offsetRight*$dpi),[int]($script:gravity.Height*$unit-$padding),$script:anchor,$true)
  }else{
    $rect=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
    $y=[int][Math]::Round($frame.Bottom-$h+$padding-$script:gravity.Height*$unit)
    $script:desktopTop=$y
    [GptWidgetNative]::SetWindowPos($script:widgetHandle,[IntPtr]::Zero,$rect.Left,$y,0,0,0x15)|Out-Null
  }
  $script:lastPosition=$null
  if($script:context.IsOpen){Set-WidgetMenuBounds;Position-WidgetMenuToHost}
  if(!$script:gravity.Active){$script:gravityTimer.Stop();Save-Settings}
}
