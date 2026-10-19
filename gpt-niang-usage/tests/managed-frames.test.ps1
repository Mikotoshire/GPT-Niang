param([string]$AppDir=(Split-Path $PSScriptRoot -Parent),[switch]$Visible,[switch]$AllowLimitedCompositor)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
# AI-generated test maintenance; see AI-NOTICE.md. Measure input separately so a
# hosted runner's compositor limit is never described as a successful 60-Hz test.
Add-Type -ReferencedAssemblies @([Windows.Media.CompositionTarget].Assembly.Location,[Windows.DependencyObject].Assembly.Location) -TypeDefinition @'
using System;
using System.Windows.Media;
public sealed class FrameInputProbe : IDisposable {
  public long Count; public TimeSpan First,Last=TimeSpan.MinValue;
  readonly System.Collections.Generic.Dictionary<long,bool> seen=new System.Collections.Generic.Dictionary<long,bool>();
  readonly Func<bool> active;
  public double Fps {get {return Count>1?(Count-1)/(Last-First).TotalSeconds:0;}}
  public FrameInputProbe():this(null){}
  public FrameInputProbe(Func<bool> active){this.active=active;CompositionTarget.Rendering+=Observe;}
  void Observe(object sender,EventArgs args){
    if(active!=null && !active())return;
    var frame=args as RenderingEventArgs;if(frame==null || seen.ContainsKey(frame.RenderingTime.Ticks))return;
    var time=frame.RenderingTime;seen.Add(time.Ticks,true);
    if(Count++==0)First=Last=time;
    else {if(time<First)First=time;if(time>Last)Last=time;}
  }
  public void Dispose(){CompositionTarget.Rendering-=Observe;}
}
'@
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
foreach($name in @('Root','Girl','GravityScale','CharacterMirror','PressScale','FacingScale')){$script:ui[$name]=$script:window.FindName($name)}
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
$script:window.Opacity=if($Visible){1}else{0};$script:window.ShowActivated=$false;$script:window.Show()
$script:widgetHandle=([Windows.Interop.WindowInteropHelper]::new($script:window)).Handle
$probe=$null
try{
  $null=Set-WidgetPixelSize 1
  $probeCheck=[FrameInputProbe]::new()
  $probeFlags=[Reflection.BindingFlags]'Instance,NonPublic'
  $observe=$probeCheck.GetType().GetMethod('Observe',$probeFlags)
  foreach($milliseconds in @(0,25,16.666667,25,33.333333,33.333333)){
    $event=[Activator]::CreateInstance([Windows.Media.RenderingEventArgs],$probeFlags,$null,@([TimeSpan]::FromMilliseconds(1000+$milliseconds)),$null)
    $null=$observe.Invoke($probeCheck,@($null,$event))
  }
  $probeCheck.Dispose()
  if($probeCheck.Count-ne 4){throw 'Compositor probe counted reentrant/out-of-order duplicate presentation timestamps'}
  Write-Output 'PASS: input probe counts each presentation timestamp once despite reentrant ordering'
  $script:gravityEnabled=$true;$script:gravityInertia=$true
  $script:gravity.SetTuning(0.5,0.25);$script:gravity.SetHorizontalPosition(300);$script:gravity.FlingFrom(600,100,0)
  # Unique presentation frames can arrive in a burst after a native window call.
  # Freezing the arrival clock makes this regression deterministic, without sleeps.
  $null=Set-WidgetGravityScene
  $script:gravityTimer.Start()
  $flags=[Reflection.BindingFlags]'Instance,NonPublic'
  $arrivalClock=$script:gravityTimer.GetType().GetField('clock',$flags).GetValue($script:gravityTimer)
  $arrivalClock.Stop()
  $renderMethod=$script:gravityTimer.GetType().GetMethod('RenderFrame',$flags)
  foreach($index in 0..5){
    $event=[Activator]::CreateInstance([Windows.Media.RenderingEventArgs],$flags,$null,@([TimeSpan]::FromSeconds(1+$index/60.0)),$null)
    $null=$renderMethod.Invoke($script:gravityTimer,@($null,$event))
  }
  $script:gravityTimer.Stop()
  if($script:gravityTimer.FrameCount-ne 6){throw 'Burst-delivered 60-Hz presentation frames were dropped by the arrival-clock limiter'}
  Write-Output 'PASS: six distinct 60-Hz presentation frames survive a burst with a frozen arrival clock'
  $script:gravityTimer.Start();$arrivalClock.Stop()
  # Seven frames in 100 ms (60 Hz), alternating long/short intervals. This is
  # ordinary compositor jitter, not a reason to discard the short-interval frames.
  foreach($milliseconds in @(0,25,33.333333,58.333333,66.666667,91.666667,100)){
    $event=[Activator]::CreateInstance([Windows.Media.RenderingEventArgs],$flags,$null,@([TimeSpan]::FromMilliseconds(1000+$milliseconds)),$null)
    $null=$renderMethod.Invoke($script:gravityTimer,@($null,$event))
  }
  $script:gravityTimer.Stop()
  if($script:gravityTimer.FrameCount-ne 7){throw 'Jittered 60-Hz presentation frames were discarded'}
  Write-Output 'PASS: all seven 60-Hz frames survive alternating 25-ms and 8.33-ms delivery intervals'
  $script:gravityTimer.Start();$arrivalClock.Stop()
  foreach($index in 0..239){
    $event=[Activator]::CreateInstance([Windows.Media.RenderingEventArgs],$flags,$null,@([TimeSpan]::FromSeconds(1+$index/240.0)),$null)
    $null=$renderMethod.Invoke($script:gravityTimer,@($null,$event))
  }
  $script:gravityTimer.Stop()
  if($script:gravityTimer.FrameCount-lt 88 -or $script:gravityTimer.FrameCount-gt 92){throw 'The limiter lost its sustained 90-Hz budget'}
  Write-Output 'PASS: 240-Hz synthetic input remains capped by the sustained 90-Hz budget'
  $activity=[Delegate]::CreateDelegate([Func[bool]],$script:gravityTimer,'get_CanObserveFrame')
  $gatedProbe=[FrameInputProbe]::new($activity)
  $gatedObserve=$gatedProbe.GetType().GetMethod('Observe',$probeFlags)
  $null=$gatedObserve.Invoke($gatedProbe,@($null,$event))
  if($gatedProbe.Count-ne 0){throw 'Inactive frames entered the probe sample'}
  $script:gravityTimer.Start();$arrivalClock.Stop()
  $null=$gatedObserve.Invoke($gatedProbe,@($null,$event))
  $script:gravityTimer.Stop()
  if($gatedProbe.Count-ne 1){throw 'Active frames were not measured by the probe'}
  $gatedProbe.Dispose()
  $script:gravity.SetHorizontalPosition(300);$script:gravity.FlingFrom(600,100,0)
  $script:notifications=0;$script:gravityTimer.Add_Tick({$script:notifications++})
  # A background-priority deadline can starve behind Rendering on a software GPU.
  $pump=[Windows.Threading.DispatcherFrame]::new();$finish=[Windows.Threading.DispatcherTimer]::new([Windows.Threading.DispatcherPriority]::Send)
  $finish.Tag=$pump;$finish.Interval=[TimeSpan]::FromSeconds(2)
  $finish.Add_Tick({param($sender,$event)$sender.Stop();$sender.Tag.Continue=$false})
  # C# delegate only: no PowerShell callback on each rendering event. Attach
  # before Start, but observe only the loop's enabled, non-reentrant interval.
  $isActive=[Delegate]::CreateDelegate([Func[bool]],$script:gravityTimer,'get_CanObserveFrame')
  $probe=[FrameInputProbe]::new($isActive)
  Start-WidgetGravityTimer
  $finish.Start();[Windows.Threading.Dispatcher]::PushFrame($pump)
  $loop=$script:gravityTimer;$loop.Stop()
  $probe.Dispose()
  # Print on failure too; otherwise the first failing assertion hides the useful measurements.
  Write-Output ('MEASURE: inputHz='+[Math]::Round($probe.Fps,2)+' renderHz='+[Math]::Round($loop.Fps,2)+' frames='+$loop.FrameCount+' meanStepMs='+[Math]::Round($loop.MeanStepMs,3)+' meanCpuMs='+[Math]::Round($loop.MeanCpuMs,3)+' physicsMs='+[Math]::Round($loop.MeanPhysicsMs,3)+' poseMs='+[Math]::Round($loop.MeanPoseMs,3)+' placementMs='+[Math]::Round($loop.MeanPlacementMs,3)+' maxStepMs='+[Math]::Round($loop.MaxStepMs,3))
  if($loop.LastError){throw $loop.LastError}
  # The requirement is 60 Hz when supplied; the 90-Hz cap is headroom, not a
  # guarantee to process every compositor callback above the required rate.
  $inputHz=$probe.Fps;$expectedHz=[Math]::Min(60,$inputHz)
  if($probe.Count-lt 10 -or $loop.Fps-lt $expectedHz*0.95 -or $loop.Fps-gt 95){throw ('Render processing lost input cadence: input='+$inputHz+' processed='+$loop.Fps)}
  $hardwareQualified=$loop.FrameCount-ge 100 -and $loop.Fps-ge 58
  if(!$hardwareQualified){
    if(!$AllowLimitedCompositor -or $inputHz-ge 58){throw ('60-Hz render cadence missed: input='+$inputHz+' processed='+$loop.Fps)}
    Write-Output ('::notice::60-Hz hardware acceptance UNQUALIFIED: hosted compositor input='+[Math]::Round($inputHz,2)+' Hz. Input tracking is tested; a local strict run is still required before release.')
  }
  # Keep the 5-ms CPU budget. SetWindowPos can wait for composition without using
  # CPU; actual wall-time cadence is checked separately above, never inferred here.
  if(!$loop.CpuTimingAvailable){throw 'Render CPU timing is unavailable'}
  if($loop.MeanCpuMs-ge 5){throw ('Managed step exceeds the 5-ms CPU budget: '+$loop.MeanCpuMs)}
  if($script:notifications-gt 10){throw 'PowerShell must not be called every animation frame'}
  if($loop.PositionUpdates-lt [Math]::Min(60,[Math]::Floor($loop.FrameCount*0.5))){throw 'Frame callbacks must include actual changing native positions'}
  Sync-WidgetGravityPosition
  if([Math]::Abs($script:desktopLeft-$loop.Scene.X)-gt 0.1){throw 'Low-frequency placement must retain the managed horizontal pose'}
  Write-Output ('PASS: managed frames='+$loop.FrameCount+' inputHz='+[Math]::Round($inputHz,1)+' renderHz='+[Math]::Round($loop.Fps,1)+' hardwareQualified='+$hardwareQualified+' positionUpdates='+$loop.PositionUpdates+' meanStepMs='+[Math]::Round($loop.MeanStepMs,3)+' maxStepMs='+[Math]::Round($loop.MaxStepMs,3)+' scriptNotifications='+$script:notifications)
}finally{if($probe){$probe.Dispose()};$script:gravityTimer.Stop();$script:gravitySampler.Stop();$script:window.Close()}
