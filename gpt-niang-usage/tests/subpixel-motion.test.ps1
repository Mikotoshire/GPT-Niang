param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $AppDir 'runtime/gravity.ps1')
function Assert($value,$message){if(!$value){throw $message}}
$source=[IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1'))
$native=[regex]::Match($source,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
Add-Type -TypeDefinition $native.Groups[1].Value
$null=[GptWidgetNative]::SetProcessDpiAwarenessContext([IntPtr](-4))
$null=[GptWidgetNative]::SetThreadDpiAwarenessContext([IntPtr](-4))
$window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $AppDir 'widget.xaml')))
$window.ShowActivated=$false;$window.Show()
try {
  $handle=([Windows.Interop.WindowInteropHelper]::new($window)).Handle
  $scene=[GptGravityScene]::new();$scene.Model=[GptGravityModel]::new();$scene.Scale=$window.FindName('GravityScale');$scene.Offset=$window.FindName('MotionOffset')
  Assert ($null-ne $scene.Offset) 'Production XAML exposes the subpixel transform'
  $scene.Widget=$handle;$scene.FrameLeft=0;$scene.FrameTop=0;$scene.FrameRight=3000;$scene.FrameBottom=2001;$scene.Width=378;$scene.Height=378;$scene.Padding=14;$scene.Dpi=1;$scene.Free=$true
  $loop=[GptGravityRenderLoop]::new();$loop.Scene=$scene
  $step=$loop.GetType().GetMethod('Step',[Reflection.BindingFlags]'NonPublic,Instance')
  foreach($unit in @(.8,1,1.25,1.5,2)){
    $window.Width=378*$unit;$window.Height=378*$unit;$window.UpdateLayout()
    $size=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($handle,[ref]$size)|Out-Null
    $scene.Width=$size.Right-$size.Left;$scene.Height=$size.Bottom-$size.Top
    $scene.Unit=[Math]::Min($scene.Width/378.0,$scene.Height/378.0);$scene.Padding=14*$scene.Unit
    $unit=$scene.Unit
    foreach($height in @(0,10.5,120.25,240.3)){
      $scene.Model.SetHorizontalPosition(200.35);$scene.Model.FlingFrom($height,0,0)
      $null=$step.Invoke($loop,@(0.0))
      $rect=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($handle,[ref]$rect)|Out-Null
      $exactX=$scene.FrameLeft+$scene.Model.HorizontalPosition*$unit
      $exactY=$scene.FrameBottom-$scene.Height+$scene.Padding-$scene.Model.Height*$unit
      Assert ([Math]::Abs($rect.Left+$scene.Offset.X*$unit-$exactX)-lt .01) 'Native position plus residual preserves horizontal model motion'
      Assert ([Math]::Abs($rect.Top+$scene.Offset.Y*$unit-$exactY)-lt .01) 'Residual preserves height including half-pixel floor coordinates'
      Assert ([Math]::Abs($scene.Offset.X*$unit)-le .500001 -and [Math]::Abs($scene.Offset.Y*$unit)-le .500001) 'Residual is bounded to half a physical pixel'
      Assert ($rect.Top-eq $scene.Y -and $rect.Left-eq $scene.X) 'Stored native pose matches actual HWND'
    }
  }
  $scene.Model.SetHorizontalPosition(50);$scene.Model.FlingFrom(60,200,0)
  foreach($i in 1..12){
    $null=$step.Invoke($loop,@(1.0/180))
    $rect=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($handle,[ref]$rect)|Out-Null
    $shownX=$rect.Left+$scene.Offset.X*$unit;$shownY=$rect.Top+$scene.Offset.Y*$unit
    Assert ([Math]::Abs($shownX-($scene.FrameLeft+$scene.Model.RenderHorizontalPosition*$unit))-lt .01) 'Native renderer must consume interpolated X rather than the newer solver X'
    Assert ([Math]::Abs($shownY-($scene.FrameBottom-$scene.Height+$scene.Padding-$scene.Model.RenderHeight*$unit))-lt .01) 'Native renderer must consume interpolated height'
  }
  $scene.Model.BeginPress();$null=$step.Invoke($loop,@(0.0))
  $rect=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($handle,[ref]$rect)|Out-Null
  Assert ([Math]::Abs($rect.Left+$scene.Offset.X*$unit-$shownX)-lt .01 -and [Math]::Abs($rect.Top+$scene.Offset.Y*$unit-$shownY)-lt .01) 'Airborne press must preserve the actual rendered position'
  $scene.Model.BeginDrag();$scene.Drag=[GptDragMotion]::new(200,300);$scene.Drag.SetTarget(400,500)
  for($i=0;$i-lt 30;$i++){$null=$step.Invoke($loop,@(1.0/120))}
  Assert ($scene.Model.Dragging -and $scene.Model.Velocity-eq 0 -and $scene.Model.HorizontalVelocity-eq 0) 'Rendered drag tracks its target without integrating gravity or inventing momentum'
  Assert ([Math]::Abs($scene.X+$scene.Offset.X*$unit-400)-lt .1 -and [Math]::Abs($scene.Y+$scene.Offset.Y*$unit-500)-lt .1) 'Managed drag reaches the requested real native/visual position'
} finally {$window.Close()}
'PASS: actual native positions plus bounded subpixel residual preserve model geometry across scales'
