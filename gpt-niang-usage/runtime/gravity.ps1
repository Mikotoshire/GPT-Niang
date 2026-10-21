$gravityLibrary=Join-Path $PSScriptRoot 'vendor/aether/Aether.Physics2D.dll'
# The stable launcher may have no PowerShell module autoload path.
$gravityHasher=[Security.Cryptography.SHA256]::Create()
$gravityStream=[IO.File]::OpenRead($gravityLibrary)
try{$gravityHash=[BitConverter]::ToString($gravityHasher.ComputeHash($gravityStream)).Replace('-','')}
finally{$gravityStream.Dispose();$gravityHasher.Dispose()}
if($gravityHash -ne '56F511BAADEF2C521D7DE983418813B075B3C2194825C7E17C06B59F267F2A78'){throw 'Physics library hash mismatch'}
if(!('nkast.Aether.Physics2D.Dynamics.World' -as [type])){Add-Type -Path $gravityLibrary}
Add-Type -AssemblyName PresentationCore,WindowsBase
if(!('GptGravityRenderLoop' -as [type])){
  Add-Type -Path @((Join-Path $PSScriptRoot 'gravity-model.cs'),(Join-Path $PSScriptRoot 'gravity-render.cs')) -ReferencedAssemblies @($gravityLibrary,[Windows.Media.CompositionTarget].Assembly.Location,[Windows.DependencyObject].Assembly.Location)
}

function Start-WidgetFrameProbe([int]$Seconds=60) {
  if($script:frameProbe){Complete-WidgetFrameProbe -Force}
  $script:frameProbe=[GptFrameProbe]::new($Seconds)
  $script:frameProbeDeadline=[DateTime]::UtcNow.AddSeconds([Math]::Max(5,[Math]::Min(120,$Seconds)))
  try{Write-WidgetJson (Join-Path $script:dataDir 'frame-diagnostics.json') @{schema=1;session=$script:frameProbe.SessionId;state='recording';seconds=[Math]::Max(5,[Math]::Min(120,$Seconds))}}
  catch{$script:frameProbe.Dispose();$script:frameProbe=$null;throw}
}
function Complete-WidgetFrameProbe([switch]$Force) {
  $probe=$script:frameProbe
  if(!$probe){return}
  if($Force -or [DateTime]::UtcNow-ge $script:frameProbeDeadline){$probe.Dispose()}
  if($probe.IsRunning){return}
  try{
    Write-WidgetJson (Join-Path $script:dataDir 'frame-diagnostics.json') @{schema=1;session=$probe.SessionId;state='complete';elapsedMs=$probe.ElapsedMs;presentation=$probe.Presentation;delivery=$probe.Delivery;workCount=$probe.WorkCount;maxWorkMs=$probe.MaxWorkMs;summary=$probe.WorkSummary;work=$probe.WorkEvents;stalls=$probe.Stalls}
  }finally{$script:frameProbe=$null}
}
function Get-WidgetGravityPadding {
  # Ground is the visible character's feet, excluding the transparent canvas margin.
  return [Math]::Max(0,$script:designHeight-([Windows.Controls.Canvas]::GetTop($script:ui.Root)+[Windows.Controls.Canvas]::GetTop($script:ui.Girl)+$script:ui.Girl.Height))
}
function Get-WidgetGravityGeometry {
  $rect=[GptWidgetNative+Rect]::new()
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
  if($null-eq $script:gravityStrength){$script:gravityStrength=1.4}
  if($null-eq $script:elasticStrength){$script:elasticStrength=2.5}
  if($null-eq $script:tapCompression){$script:tapCompression=2.0}
  if($null-eq $script:animationSpeed){$script:animationSpeed=1.0}
  if($null-eq $script:squishStrength){$script:squishStrength=1.5}
  if($null-eq $script:energyConversion){$script:energyConversion=[GptGravityModel]::DefaultEnergyConversion}
  if($null-eq $script:reboundStrength){$script:reboundStrength=$script:energyConversion/0.85}
  $script:reboundStrength=[int]([Math]::Min(100.0,[Math]::Max(0.0,[Math]::Round($script:reboundStrength/5,0,[MidpointRounding]::AwayFromZero)*5)))
  $script:energyConversion=0.85*$script:reboundStrength
  if($null-eq $script:compressionCurve){$script:compressionCurve=1.5}
  if($null-eq $script:groundFriction){$script:groundFriction=0.2}
  $script:gravity.SetGroundFriction($script:groundFriction)
  $script:gravity.SetCompressionCurve($script:compressionCurve)
  $script:gravity.SetEnergyConversion($script:energyConversion)
  $script:gravity.SetTuning($script:gravityStrength,$script:elasticStrength)
  $script:gravity.SetImpactSquish($script:squishStrength)
  $script:gravity.SetAnimationSpeed($script:animationSpeed)
  $script:gravity.SetTapCompression($script:tapCompression)
  if($script:gravityEnabled){$script:gravity.DropFrom([Math]::Max(0,$script:offsetBottom/[Math]::Max(0.1,$script:displayScale)))}
  $script:gravityClock=[Diagnostics.Stopwatch]::StartNew()
  $script:gravityTimer=[GptGravityRenderLoop]::new()
  $script:gravityTimer.Add_Tick({
    Sync-WidgetGravityPosition
    if($script:gravityTimer.LastError){
      [IO.File]::WriteAllText((Join-Path $script:dataDir 'gravity-error.txt'),$script:gravityTimer.LastError,[Text.UTF8Encoding]::new($false))
    }
    if($script:context.IsOpen){Set-WidgetMenuBounds;Position-WidgetMenuToHost}
    if(!$script:gravityTimer.IsEnabled -and !$script:gravity.Active){Save-Settings}
  })
}
function Start-WidgetGravityTimer {
  if($script:gravityEnabled -and $script:gravity.Active -and !$script:gravityTimer.IsEnabled){
    if(!(Set-WidgetGravityScene)){return}
    $script:gravityClock.Restart();$script:gravityTimer.Start()
  }
}
function Set-WidgetGravityScene {
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  if(!(Test-WidgetPlacementFrame $frame $dpi)){return $false}
  $geometry=Get-WidgetGravityGeometry
  $scene=[GptGravityScene]::new()
  $scene.Model=$script:gravity;$scene.Scale=$script:ui.GravityScale;$scene.Offset=$script:ui.MotionOffset
  $scene.Widget=$script:widgetHandle;$scene.Host=if($script:hostHandle){$script:hostHandle}else{[IntPtr]::Zero};$scene.Follow=$script:followHost;$scene.Free=$script:gravityInertia
  $scene.Width=$geometry.Width;$scene.Height=$geometry.Height;$scene.Unit=$geometry.Unit;$scene.Padding=$geometry.Padding;$scene.Dpi=$dpi
  $scene.FrameLeft=$frame.Left;$scene.FrameTop=$frame.Top;$scene.FrameRight=$frame.Right;$scene.FrameBottom=$frame.Bottom
  $scene.Left=$script:offsetLeft;$scene.Right=$script:offsetRight;$scene.Anchor=$script:anchor
  if($script:followHost -and $script:hostFollower -and $script:hostFollower.GetType().GetMethod('AnimationFrame')){
    $scene.ReadFrame=[Delegate]::CreateDelegate([Func[int[]]],$script:hostFollower,'AnimationFrame')
    $scene.Move=[Delegate]::CreateDelegate([Action[int,int,int,string]],$script:hostFollower,'MovePose')
  }
  if(!$script:gravityInertia){
    $rect=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
    $script:gravity.SetHorizontalPosition([Math]::Max(0,($rect.Left-$frame.Left)/$geometry.Unit))
  }
  if($script:drag -and $script:gravity.Dragging -and $script:gravityTimer.Scene -and $script:gravityTimer.Scene.Drag){
    $scene.Drag=$script:gravityTimer.Scene.Drag;$scene.Free=$true;$scene.Move=$null
  }
  $script:gravityTimer.Scene=$scene
  return $true
}
function Sync-WidgetGravityPosition {
  if(!$script:gravityTimer -or !$script:gravityTimer.Scene -or !$script:gravityTimer.Scene.HasPose){return}
  $scene=$script:gravityTimer.Scene
  $script:offsetBottom=$script:gravity.Height*$script:displayScale
  if($scene.Free){$script:offsetLeft=$scene.PoseLeft;$script:offsetRight=$scene.PoseRight;$script:anchor='free'}
  if(!$script:followHost){$script:desktopLeft=$scene.X;$script:desktopTop=$scene.Y}
  if($scene.Drag){$script:side=if($scene.X+$scene.Width/2-lt ($scene.FrameLeft+$scene.FrameRight)/2){'left'}else{'right'}}
  $script:lastPosition=$null
}
function Set-WidgetGravityPose {
  $script:ui.GravityScale.ScaleX=$script:gravity.ScaleX
  $script:ui.GravityScale.ScaleY=$script:gravity.ScaleY
}
function Set-WidgetGravityMode([bool]$Enabled) {
  if($script:ui.MotionOffset){$script:ui.MotionOffset.X=0;$script:ui.MotionOffset.Y=0}
  $script:gravitySampler.Stop()
  $script:gravityEnabled=$Enabled
  $script:gravityInertia=$false
  $script:gravityTimer.Stop()
  Set-AnimatedValue $script:ui.PressScale ([Windows.Media.ScaleTransform]::ScaleXProperty) 1
  Set-AnimatedValue $script:ui.PressScale ([Windows.Media.ScaleTransform]::ScaleYProperty) 1
  Set-AnimatedValue $script:ui.GravityScale ([Windows.Media.ScaleTransform]::ScaleXProperty) 1
  Set-AnimatedValue $script:ui.GravityScale ([Windows.Media.ScaleTransform]::ScaleYProperty) 1
  $rect=[GptWidgetNative+Rect]::new()
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
  if($script:ui.MotionOffset){$script:ui.MotionOffset.X=0;$script:ui.MotionOffset.Y=0}
  $script:gravityInertia=$false
  $script:gravitySampler.Start()
  $script:gravityTimer.Stop();$script:gravity.BeginDrag();Set-WidgetGravityPose
  if(Set-WidgetGravityScene){
    $rect=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
    $script:gravityTimer.Scene.Drag=[GptDragMotion]::new($rect.Left,$rect.Top)
    $script:gravityTimer.Scene.Free=$true;$script:gravityTimer.Scene.Move=$null
    $script:gravityTimer.Start()
  }
}
function Set-WidgetPhysicsTuning {
  if($null-eq $script:gravityStrength){$script:gravityStrength=1.4}
  if($null-eq $script:elasticStrength){$script:elasticStrength=2.5}
  if($null-eq $script:tapCompression){$script:tapCompression=2.0}
  if($null-eq $script:squishStrength){$script:squishStrength=1.5}
  if($null-eq $script:animationSpeed){$script:animationSpeed=1.0}
  if($null-eq $script:energyConversion){$script:energyConversion=[GptGravityModel]::DefaultEnergyConversion}
  if($null-eq $script:reboundStrength){$script:reboundStrength=$script:energyConversion/0.85}
  $script:reboundStrength=[int]([Math]::Min(100.0,[Math]::Max(0.0,[Math]::Round($script:reboundStrength/5,0,[MidpointRounding]::AwayFromZero)*5)))
  $script:energyConversion=0.85*$script:reboundStrength
  if($null-eq $script:compressionCurve){$script:compressionCurve=1.5}
  if($null-eq $script:groundFriction){$script:groundFriction=0.2}
  $script:gravity.SetGroundFriction($script:groundFriction)
  $script:gravity.SetCompressionCurve($script:compressionCurve)
  $script:gravity.SetEnergyConversion($script:energyConversion)
  $script:gravity.SetTuning($script:gravityStrength,$script:elasticStrength)
  $script:gravity.SetImpactSquish($script:squishStrength)
  $script:gravity.SetAnimationSpeed($script:animationSpeed)
  $script:gravity.SetTapCompression($script:tapCompression)
  Save-Settings
}
function Release-WidgetGravityDrop([switch]$Cancel) {
  $script:gravityTimer.Stop()
  $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
  $rect=[GptWidgetNative+Rect]::new()
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
  $rect=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
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
    $rect=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
    $y=[int][Math]::Round($frame.Bottom-$h+$padding-$script:gravity.Height*$unit)
    $script:desktopTop=$y
    [GptWidgetNative]::SetWindowPos($script:widgetHandle,[IntPtr]::Zero,$x,$y,0,0,0x15)|Out-Null
  }
  $script:lastPosition=$null
  if($script:context.IsOpen){Set-WidgetMenuBounds;Position-WidgetMenuToHost}
  if(!$script:gravity.Active){$script:gravityTimer.Stop();Save-Settings}
}
