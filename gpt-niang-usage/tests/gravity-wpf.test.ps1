param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
function Get-FileHash {throw 'Module-based hash must not be required by the stable launcher'}
. (Join-Path $AppDir 'runtime\gravity.ps1')
Remove-Item Function:\Get-FileHash
$source=[IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1'),[Text.Encoding]::UTF8)
$native=[regex]::Match($source,"(?s)Add-Type -TypeDefinition @'\r?\n(.*?)\r?\n'@")
Add-Type -TypeDefinition $native.Groups[1].Value
$null=[GptWidgetNative]::SetProcessDpiAwarenessContext([IntPtr](-4))
$null=[GptWidgetNative]::SetThreadDpiAwarenessContext([IntPtr](-4))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Set-WidgetPixelSize','Set-AnimatedValue','Save-Settings')){
  $node=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
  . ([scriptblock]::Create($node.Extent.Text))
}
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $AppDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{}
foreach($name in @('MotionOffset','Root','Girl','GravityScale','CharacterMirror','PressScale','FacingScale')){$script:ui[$name]=$script:window.FindName($name)}
$script:ui.Girl.Source=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $AppDir 'assets\gpt-dragon-niang-bust.png'))
$script:designWidth=378;$script:designHeight=378;$script:displayScale=1
$script:followHost=$false;$script:gravityEnabled=$false;$script:runtimeClosed=$false;$script:offsetBottom=0
$script:drag=$null;$script:context=[pscustomobject]@{IsOpen=$false};$script:saves=0
function Write-WidgetJson($File,$Value){$script:saves++;$script:savedSettings=$Value}
function Tick-Widget {}
function Test-WidgetPlacementFrame($Frame,$Dpi){return $true}
function Get-WidgetPlacementFrame {return [pscustomobject]@{Left=100;Top=100;Right=1500;Bottom=1200}}
function Get-WidgetPlacementDpi {return $script:testDpi}
$script:testDpi=1
Initialize-WidgetGravity
$script:window.Opacity=0;$script:window.ShowActivated=$false;$script:window.Show()
$script:widgetHandle=([Windows.Interop.WindowInteropHelper]::new($script:window)).Handle
$checks=0
try {
  if((Get-WidgetGravityPadding)-ne 14){throw 'Visible feet must exclude the 14-DIP transparent footer.'}
  foreach($dpi in @(1.0,1.25,1.5)){
    foreach($scale in @(0.6,1.0,2.5)){
      $script:testDpi=$dpi;$script:displayScale=$scale
      $null=Set-WidgetPixelSize $dpi
      $pump=[Windows.Threading.DispatcherFrame]::new()
      $pumpTimer=[Windows.Threading.DispatcherTimer]::new();$pumpTimer.Tag=$pump
      $pumpTimer.Interval=[TimeSpan]::FromMilliseconds(20)
      $pumpTimer.Add_Tick({param($sender,$event)$sender.Stop();$sender.Tag.Continue=$false})
      $pumpTimer.Start();[Windows.Threading.Dispatcher]::PushFrame($pump)
      $script:gravityEnabled=$true;$script:gravity.DropFrom(0)
      Update-WidgetGravity
      $rect=New-Object GptWidgetNative+Rect
      [GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$rect)|Out-Null
      $foot=$rect.Bottom-14*($rect.Bottom-$rect.Top)/378
      if([Math]::Abs($foot-1200)-gt 1.1){throw "Visible feet missed floor: DPI=$dpi scale=$scale foot=$foot"}
      $checks++
    }
  }
  $script:displayScale=1;$script:testDpi=1;$null=Set-WidgetPixelSize 1
  $view=$script:window.Content
  $view.Measure([Windows.Size]::new(378,378));$view.Arrange([Windows.Rect]::new(0,0,378,378));$view.UpdateLayout()
  $script:gravity.SetTapCompression(3)
  $script:gravity.BeginPress()
  for($i=0;$i-lt 180;$i++){$script:gravity.Advance(1.0/120,700)}
  Set-WidgetGravityPose;$script:window.UpdateLayout()
  foreach($facing in @(1,-1)){
    $script:ui.FacingScale.ScaleX=$facing;$script:window.UpdateLayout()
    $bounds=$script:ui.Girl.TransformToAncestor($script:window.FindName('AnimationStage')).TransformBounds([Windows.Rect]::new(0,0,208,208))
    if($bounds.Left-lt -0.1 -or $bounds.Right-gt 378.1 -or $bounds.Bottom-gt 364.1){throw 'Charged character is clipped or feet shift during squash.'}
    $checks++
  }
  $script:gravity.ReleasePress();Start-WidgetGravityTimer
  $script:ui.GravityScale.BeginAnimation([Windows.Media.ScaleTransform]::ScaleXProperty,[Windows.Media.Animation.DoubleAnimation]::new(1.2,[Windows.Duration]::new([TimeSpan]::FromSeconds(1))))
  Set-WidgetGravityMode $false
  if($script:ui.GravityScale.HasAnimatedProperties){throw 'Switching gravity mode must remove ordinary click animation clocks.'}
  if($script:gravity.Active -or $script:gravityTimer.IsEnabled -or $script:ui.GravityScale.ScaleX-ne 1 -or $script:ui.GravityScale.ScaleY-ne 1){throw 'Disabling must stop timer and reset transforms.'}
  if($script:saves-lt 1){throw 'Mode setting must be persisted.'}
  if($script:savedSettings.gravityEnabled-ne $false){throw 'Disabled gravity preference was not serialized.'}
  Set-WidgetGravityMode $true
  if($script:savedSettings.gravityEnabled-ne $true){throw 'Enabled gravity preference was not serialized.'}
  Begin-WidgetGravityDrag
  if(!$script:gravityTimer.IsEnabled -or !$script:gravity.Dragging -or !$script:gravityTimer.Scene.Drag){throw 'Drag must render cursor tracking while gravity integration remains suspended.'}; if($script:gravity.Velocity-ne 0){throw 'Dragging must not acquire gravitational velocity.'}
  $moveNode=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq '$pressMove'},$true)
  $moveText=$moveNode.Right.Extent.Text.Trim();$moveText=$moveText.Substring(1,$moveText.Length-2)
  $moveText=$moveText.Replace('[GptWidgetNative]::GetCursorPos([ref]$cursor)|Out-Null','$cursor.X=[int](120+10*$script:testDpi);$cursor.Y=[int](140+10*$script:testDpi)')
  $moveHandler=[scriptblock]::Create($moveText)
  $script:drag=@{x=0;y=0;left=300;top=300;moved=$true}
  foreach($testScale in @(1,1.5,2)){
    $script:testDpi=$testScale;$script:gravityTimer.Start()
    & $moveHandler $null ([pscustomobject]@{Handled=$false})
    $script:gravityTimer.Stop()
    if(!$script:gravityTimer.Scene.Drag){throw 'DPI refresh discarded the coalesced drag target.'}
    $step=$script:gravityTimer.GetType().GetMethod('Step',[Reflection.BindingFlags]'NonPublic,Instance')
    for($i=0;$i-lt 30;$i++){$null=$step.Invoke($script:gravityTimer,@(1.0/120))}
    $size=[GptWidgetNative+Rect]::new();[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$size)|Out-Null
    if([Math]::Abs(($size.Right-$size.Left)-378*$testScale)-gt 1){throw 'Managed drag resized the character incorrectly across DPI.'}
    if($script:gravity.Velocity-ne 0 -or !$script:gravity.Dragging){throw 'DPI drag integrated gravity before release.'}
  }
  $script:drag=$null;$script:testDpi=1;$null=Set-WidgetPixelSize 1
  Release-WidgetGravityDrop
  if($script:gravity.Dragging){throw 'Release must leave drag state.'}
  # Native pointer sampling is tested deterministically in motion-tuning.test.ps1.
  # Here verify that model momentum is applied to the real native window.
  [GptWidgetNative]::SetWindowPos($script:widgetHandle,[IntPtr]::Zero,490,630,0,0,0x15)|Out-Null
  $geometry=Get-WidgetGravityGeometry
  $script:gravity.SetHorizontalPosition((490-100)/$geometry.Unit)
  $script:gravity.FlingFrom(200,600,300);$script:gravityInertia=$true
  $script:gravityClock.Restart();Start-Sleep -Milliseconds 25;Update-WidgetGravity
  $flung=New-Object GptWidgetNative+Rect
  [GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$flung)|Out-Null
  if($flung.Left-le 490){throw 'Controller did not apply horizontal inertia to the real HWND.'}
  Begin-WidgetGravityDrag;Release-WidgetGravityDrop -Cancel
  if($script:gravity.HorizontalVelocity-ne 0 -or $script:gravity.Velocity-ne 0){throw 'Capture cancellation must clear momentum.'}
  $script:ui.CharacterMirror.ScaleX=-1;$script:ui.FacingScale.ScaleX=1
  $script:gravity.BeginPress();for($i=0;$i-lt 200;$i++){$script:gravity.Advance(1.0/120,700)}
  Set-WidgetGravityPose;$script:window.UpdateLayout()
  $bounds=$script:ui.Girl.TransformToAncestor($script:window.FindName('AnimationStage')).TransformBounds([Windows.Rect]::new(0,0,208,208))
  if($bounds.Left-lt -0.1 -or $bounds.Right-gt 378.1){throw 'Manual mirror must stay inside the canvas during full compression.'}
  $checks+=3
  $script:followHost=$true;$script:hostHandle=[IntPtr]::Zero
  $script:gravity.BeginPress();Start-WidgetGravityTimer;Update-WidgetGravity
  if($script:gravityTimer.IsEnabled){throw 'Physics must pause when the followed host is unavailable.'}
  $checks++
  $script:hostHandle=$script:widgetHandle
  $script:hostFollower=[pscustomobject]@{}
  $script:hostFollower|Add-Member ScriptMethod MovePose {
    param($Left,$Right,$Bottom,$Anchor)
    $script:configuredGravityBottom=$Bottom
  }
  $script:gravity.DropFrom(0);Update-WidgetGravity
  $geometry=Get-WidgetGravityGeometry
  if([Math]::Abs($script:configuredGravityBottom+$geometry.Padding)-gt 0.6){throw 'Native host follower must use the same visible-floor offset as physics.'}
  $checks++
  . (Join-Path $AppDir 'runtime/host-follow.ps1')
  $hostWindow=[Windows.Window]::new();$hostWindow.Opacity=0;$hostWindow.ShowActivated=$false
  $hostWindow.WindowStyle=[Windows.WindowStyle]::None;$hostWindow.Width=800;$hostWindow.Height=700;$hostWindow.Left=100;$hostWindow.Top=100
  $hostWindow.Show();$nativeHost=([Windows.Interop.WindowInteropHelper]::new($hostWindow)).Handle
  $follower=[GptWidgetHostFollower]::new($script:widgetHandle)
  try{
    $frame=[GptWidgetNative]::Frame($nativeHost);$geometry=Get-WidgetGravityGeometry
    $follower.Configure($nativeHost,$frame.Left,$frame.Top,$frame.Right,$frame.Bottom,$geometry.Width,$geometry.Height,40,0,100,'free',$true)
    $before=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$before)|Out-Null
    $follower.MovePose(60,0,120,'free')
    $after=New-Object GptWidgetNative+Rect;[GptWidgetNative]::GetWindowRect($script:widgetHandle,[ref]$after)|Out-Null
    if($after.Left-$before.Left-ne 20 -or $after.Top-$before.Top-ne -20){throw 'Native pose update must move without full reconfiguration.'}
    $checks++
  }finally{$follower.Dispose();$hostWindow.Close()}
  $script:mirrorCharacter=$true;$script:gravityStrength=2.2;$script:elasticStrength=1.5;Save-Settings
  if(!$script:savedSettings.mirrorCharacter -or $script:savedSettings.gravityStrength-ne 2.2 -or $script:savedSettings.elasticStrength-ne 1.5){throw 'Mirror and physical tuning must persist independently.'}
  Write-Output "PASS: $checks WPF floor/scale/mirror cases, live mode reset and settings persistence."
} finally {
  $script:gravityTimer.Stop();$script:gravitySampler.Stop();$script:window.Close()
}
