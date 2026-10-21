param([string]$AppDir=(Split-Path $PSScriptRoot -Parent),[ValidateRange(3,30)][int]$SecondsPerPhase=6,[string]$ReportFile,[switch]$Hidden,[switch]$RequireSmooth60,[switch]$DefaultProfile,[switch]$HostMode,[switch]$LegacyMessageHook)
# AI-generated diagnostic fixture; insufficiently validated. Uses fictional data only.
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
if($script:gravityTimer.TargetFps-lt 120){throw 'Animation scheduling must allow 120 FPS'}
$script:window.Opacity=if($Hidden){0}else{1};$script:window.ShowActivated=$false;$script:window.Show()
$script:widgetHandle=([Windows.Interop.WindowInteropHelper]::new($script:window)).Handle
$null=Set-WidgetPixelSize $script:testDpi

Add-Type -AssemblyName System.Windows.Forms
$area=[Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$script:stressFrame=[pscustomobject]@{Left=$area.Left+20;Top=$area.Top+20;Right=$area.Right-20;Bottom=$area.Bottom-20}
function Get-WidgetPlacementFrame {return $script:stressFrame}
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('gpt-frame-stress-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($script:dataDir)|Out-Null
$script:settingsFile=Join-Path $script:dataDir 'settings.json'
$xaml=[IO.File]::ReadAllText((Join-Path $AppDir 'widget.xaml'))
foreach($match in [regex]::Matches($xaml,'x:Name="([^"\s]+)"')){$name=$match.Groups[1].Value;$script:ui[$name]=$script:window.FindName($name)}
foreach($name in @('Get-WidgetStaticBrush','Reset-Label','Format-ResetTime','Format-ResetDisplay','Get-QuotaWindowLabel','Get-QuotaRows','Update-BubbleTooltip','Update-Quota')){
  $node=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
  if($node){. ([scriptblock]::Create($node.Extent.Text))}
}
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $AppDir 'runtime/ui-settings.ps1'))))
. ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $AppDir 'runtime/color-theme.ps1'))))
function Update-WidgetUpdateMenu {}
$script:config=@{version='diagnostic'};$script:releaseUpdatesDisabled=$true
$script:side='right';$script:anchor='free';$script:scale=1;$script:desktopTopmost=$false
$script:collapsed=$false;$script:bubbleMode='quota';$script:resetTimeMode='fixed';$script:sceneRevision=0
$script:soundOn=$false;$script:soundVolume=.5;$script:bubbleTapAdvance=$false;$script:hideMenu=$false
$script:groundFriction=1;$script:gravityStrength=1.6;$script:elasticStrength=1;$script:squishStrength=1;$script:tapCompression=1;$script:animationSpeed=1;$script:reboundStrength=75;$script:compressionCurve=1.5
$script:colorMode='original';$script:colorPaused=$false;$script:colorChance=0;$script:colorTextChance=0
$script:offsetLeft=50;$script:offsetRight=50;$script:statusStamp=0;$script:status=$null
if($HostMode){
  . (Join-Path $AppDir 'runtime/host-follow.ps1')
  Add-Type @'
using System;using System.Runtime.InteropServices;
public static class FrameStressHost {
 [DllImport("user32.dll",CharSet=CharSet.Unicode)]public static extern IntPtr CreateWindowEx(uint ex,string cls,string title,uint style,int x,int y,int w,int h,IntPtr parent,IntPtr menu,IntPtr instance,IntPtr param);
 [DllImport("user32.dll")]public static extern bool DestroyWindow(IntPtr h);
}
'@
  $script:hostHandle=[FrameStressHost]::CreateWindowEx(0x08000088,'STATIC','Frame stress host',2415919104,$area.Left+40,$area.Top+40,[Math]::Min(1000,$area.Width-80),[Math]::Min(850,$area.Height-80),[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero,[IntPtr]::Zero)
  if($script:hostHandle-eq [IntPtr]::Zero){throw 'Native fixture host creation failed'}
  $script:followHost=$true;$script:testDpi=[GptWidgetNative]::GetDpiForWindow($script:hostHandle)/96.0
  function Get-WidgetPlacementFrame {return [GptWidgetNative]::Frame($script:hostHandle)}
  $null=Set-WidgetPixelSize $script:testDpi
  $hostFrame=Get-WidgetPlacementFrame;$geometry=Get-WidgetGravityGeometry
  $script:hostFollower=[GptWidgetHostFollower]::new($script:widgetHandle)
  $script:hostFollower.Configure($script:hostHandle,$hostFrame.Left,$hostFrame.Top,$hostFrame.Right,$hostFrame.Bottom,$geometry.Width,$geometry.Height,50,50,0,'free',$true)
  [GptWidgetNative]::SetWindowPos($script:widgetHandle,[IntPtr](-1),0,0,0,0,0x13)|Out-Null
}
$now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$fake=@{ok=$true;queryOk=$true;observedAt=$now;windows=@(@{minutes=300;used=25;remaining=75;resetsAt=[Math]::Floor($now/1000)+3600},@{minutes=10080;used=10;remaining=90;resetsAt=[Math]::Floor($now/1000)+7200})}
[IO.File]::WriteAllText((Join-Path $script:dataDir 'status.json'),($fake|ConvertTo-Json -Depth 6))
Initialize-WidgetSettingsMenu
Initialize-WidgetColors
Update-Quota
$move=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq '$pressMove'},$true)
$moveText=$move.Right.Extent.Text.Trim();$moveText=$moveText.Substring(1,$moveText.Length-2)
$moveText=$moveText.Replace('[GptWidgetNative]::GetCursorPos([ref]$cursor)|Out-Null','$cursor.X=$script:stressCursorX;$cursor.Y=$script:stressCursorY')
$script:stressDrag=[scriptblock]::Create($moveText)
# Include the real production native hook; previous fixtures omitted this path.
foreach($name in @('Test-GirlAlpha','Test-WidgetHit')){
  $node=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
  . ([scriptblock]::Create($node.Extent.Text))
}
$bitmap=$script:ui.Girl.Source
$alpha=[Windows.Media.Imaging.FormatConvertedBitmap]::new($bitmap,[Windows.Media.PixelFormats]::Bgra32,$null,0)
$script:alphaStride=$bitmap.PixelWidth*4;$script:alphaPixels=[byte[]]::new($script:alphaStride*$bitmap.PixelHeight)
$alpha.CopyPixels($script:alphaPixels,$script:alphaStride,0)
$hookNode=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq '$script:messageHook'},$true)
. ([scriptblock]::Create($hookNode.Extent.Text))
$nativeSource=[Windows.Interop.HwndSource]::FromHwnd($script:widgetHandle)
$script:inputFilter=$null
if($LegacyMessageHook){$nativeSource.AddHook($script:messageHook)}else{
  $script:inputFilter=[GptWidgetInputFilter]::new($nativeSource,$script:messageHook)
  $script:inputFilter.Root=$script:ui.Root;$script:inputFilter.Character=$script:ui.Girl
  $script:inputFilter.AlphaPixels=$script:alphaPixels;$script:inputFilter.AlphaStride=$script:alphaStride
  $script:inputFilter.PixelWidth=$bitmap.PixelWidth;$script:inputFilter.PixelHeight=$bitmap.PixelHeight
  $script:inputFilter.Model=$script:gravity;$script:inputFilter.GravityEnabled=$true
}
# Exercise moving-image hit testing each frame without moving the user's mouse.
Add-Type -ReferencedAssemblies @([Windows.Media.CompositionTarget].Assembly.Location,[Windows.DependencyObject].Assembly.Location) -TypeDefinition @'
using System;using System.Runtime.InteropServices;using System.Windows;using System.Windows.Media;
public sealed class GptStressHover : IDisposable {
 [DllImport("user32.dll")]static extern IntPtr SendMessage(IntPtr h,int msg,IntPtr w,IntPtr l);
 readonly IntPtr hwnd;readonly UIElement girl;
 public GptStressHover(IntPtr hwnd,UIElement girl){this.hwnd=hwnd;this.girl=girl;CompositionTarget.Rendering+=Render;}
 void Render(object sender,EventArgs args){var p=girl.PointToScreen(new Point(100,150));long x=(int)Math.Round(p.X),y=(int)Math.Round(p.Y);SendMessage(hwnd,0x84,IntPtr.Zero,new IntPtr(((y&65535)<<16)|(x&65535)));}
 public void Dispose(){CompositionTarget.Rendering-=Render;}
}
'@
$hover=[GptStressHover]::new($script:widgetHandle,$script:ui.Girl)
$reports=@();$driver=$null;$finish=$null;$script:frameProbe=$null
try{
  foreach($phase in @('bounce','drag','menu','quota')){
    $script:stressPhase=$phase;$script:stressStep=0;$script:context.IsOpen=$false
    $script:gravityTimer.Stop();$script:gravitySampler.Stop();$script:gravity.Reset();$script:drag=$null
    $script:gravityEnabled=$true;$script:gravityInertia=$true
    if($DefaultProfile){$script:gravity.SetTuning([GptGravityModel]::DefaultGravityMultiplier,[GptGravityModel]::DefaultElasticity);$script:gravity.SetGroundFriction([GptGravityModel]::DefaultGroundFrictionMultiplier)}else{$script:gravity.SetTuning(.5,1);$script:gravity.SetGroundFriction(1)}
    $script:gravity.SetHorizontalPosition(100);$script:gravity.FlingFrom(300,180,0)
    if($phase-eq 'drag'){$script:drag=@{x=0;y=0;left=$area.Left+50;top=$area.Top+50;moved=$true};$script:gravity.BeginDrag();Begin-WidgetGravityDrag}
    else{Start-WidgetGravityTimer}
    if($phase-eq 'menu'){Open-WidgetMenu}
    $script:frameProbe=[GptFrameProbe]::new($SecondsPerPhase+2)
    $pump=[Windows.Threading.DispatcherFrame]::new()
    $finish=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Send)
    $finish.Tag=$pump;$finish.Interval=[TimeSpan]::FromSeconds($SecondsPerPhase)
    $finish.Add_Tick({param($sender,$event)$sender.Stop();$sender.Tag.Continue=$false})
    $driver=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Input)
    $driver.Interval=[TimeSpan]::FromMilliseconds($(if($phase-eq 'drag'){16}else{250}))
    $driver.Add_Tick({
      $script:stressStep++;$watch=[Diagnostics.Stopwatch]::StartNew()
      if($script:stressPhase-eq 'drag'){
        $script:stressCursorX=100+[int](80*[Math]::Sin($script:stressStep*.1));$script:stressCursorY=100+[int](40*[Math]::Cos($script:stressStep*.1))
        & $script:stressDrag $null ([pscustomobject]@{Handled=$false})
      }else{
        if(!$script:gravity.Active){$script:gravity.FlingFrom(300,180,0);Start-WidgetGravityTimer}
        if($script:stressPhase-eq 'quota' -and $script:stressStep%4-eq 0){Update-Quota}
      }
      $watch.Stop()
      # Production handlers record their own bounded work timings.
    })
    $finish.Start();$driver.Start();[Windows.Threading.Dispatcher]::PushFrame($pump)
    $driver.Stop();$finish.Stop();$script:frameProbe.Dispose();$script:gravityTimer.Stop()
    $p=$script:frameProbe
    $smooth=$p.Delivery.Count-ge 100 -and $p.Delivery.MeanMs-le 17.5 -and $p.Delivery.P95Ms-le 20 -and $p.Delivery.Over50Ms-eq 0
    $result=[pscustomobject]@{phase=$phase;seconds=$SecondsPerPhase;smooth60Candidate=$smooth;presentation=$p.Presentation;delivery=$p.Delivery;workMaxMs=$p.MaxWorkMs;stalls=$p.Stalls;work=$p.WorkEvents;renderFps=$script:gravityTimer.Fps;renderFrames=$script:gravityTimer.FrameCount;nativeMoves=$script:gravityTimer.PositionUpdates;legacyMessageHook=[bool]$LegacyMessageHook;nativeMessages=$script:inputFilter.Messages;scriptMessages=$script:inputFilter.Forwarded;hostMode=[bool]$HostMode;defaultProfile=[bool]$DefaultProfile;physicsMeanMs=$script:gravityTimer.MeanPhysicsMs;placementMeanMs=$script:gravityTimer.MeanPlacementMs}
    $reports+=,$result
    Write-Output ($phase+': intervals='+$p.Delivery.Count+' p95='+$p.Delivery.P95Ms+'ms p99='+$p.Delivery.P99Ms+'ms worst='+[Math]::Round($p.Delivery.MaxMs,2)+'ms renderHz='+[Math]::Round($script:gravityTimer.Fps,1)+' nativeMoves='+$script:gravityTimer.PositionUpdates+' over25='+$p.Delivery.Over25Ms+' over50='+$p.Delivery.Over50Ms+' workMax='+[Math]::Round($p.MaxWorkMs,2)+'ms')
    if($p.Delivery.Count-lt 10){throw 'Insufficient frame observations; cannot claim performance acceptance'}
  }
  if($ReportFile){[IO.File]::WriteAllText([IO.Path]::GetFullPath($ReportFile),($reports|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))}
  if($RequireSmooth60 -and @($reports|Where-Object{!$_.smooth60Candidate}).Count){throw 'Smooth-60 stress acceptance failed; inspect every phase report instead of relying on average FPS'}
}finally{
  if($driver){$driver.Stop()};if($finish){$finish.Stop()};if($script:frameProbe){$script:frameProbe.Dispose()}
  $hover.Dispose()
  if($script:inputFilter){$script:inputFilter.Dispose()}elseif(!$nativeSource.IsDisposed){$nativeSource.RemoveHook($script:messageHook)}
  $script:gravityTimer.Stop();$script:gravitySampler.Stop();$script:context.IsOpen=$false;$script:window.Close()
  if($HostMode){$script:hostFollower.Dispose();[FrameStressHost]::DestroyWindow($script:hostHandle)|Out-Null}
  $temporary=[IO.Path]::GetFullPath($script:dataDir)
  if(!$temporary.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe temporary cleanup path'}
  Remove-Item -LiteralPath $temporary -Recurse -Force
}
