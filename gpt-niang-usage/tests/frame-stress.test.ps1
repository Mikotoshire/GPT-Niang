param([string]$AppDir=(Split-Path $PSScriptRoot -Parent),[ValidateRange(3,30)][int]$SecondsPerPhase=6,[string]$ReportFile,[switch]$Hidden,[switch]$RequireSmooth60)
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
if($script:gravityTimer.TargetFps-ne 120){throw 'Animation scheduling must allow 120 FPS'}
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
$reports=@();$driver=$null;$finish=$null;$script:frameProbe=$null
try{
  foreach($phase in @('bounce','drag','menu','quota')){
    $script:stressPhase=$phase;$script:stressStep=0;$script:context.IsOpen=$false
    $script:gravityTimer.Stop();$script:gravitySampler.Stop();$script:gravity.Reset();$script:drag=$null
    $script:gravityEnabled=$true;$script:gravityInertia=$true
    $script:gravity.SetTuning(.5,1);$script:gravity.SetGroundFriction(1)
    $script:gravity.SetHorizontalPosition(100);$script:gravity.FlingFrom(300,180,0)
    if($phase-eq 'drag'){$script:drag=@{x=0;y=0;left=$area.Left+50;top=$area.Top+50;moved=$true};$script:gravity.BeginDrag()}
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
    $result=[pscustomobject]@{phase=$phase;seconds=$SecondsPerPhase;smooth60Candidate=$smooth;presentation=$p.Presentation;delivery=$p.Delivery;workMaxMs=$p.MaxWorkMs;stalls=$p.Stalls;work=$p.WorkEvents;physicsMeanMs=$script:gravityTimer.MeanPhysicsMs;placementMeanMs=$script:gravityTimer.MeanPlacementMs}
    $reports+=,$result
    Write-Output ($phase+': intervals='+$p.Delivery.Count+' p95='+$p.Delivery.P95Ms+'ms p99='+$p.Delivery.P99Ms+'ms worst='+[Math]::Round($p.Delivery.MaxMs,2)+'ms over25='+$p.Delivery.Over25Ms+' over50='+$p.Delivery.Over50Ms+' workMax='+[Math]::Round($p.MaxWorkMs,2)+'ms')
    if($p.Delivery.Count-lt 10){throw 'Insufficient frame observations; cannot claim performance acceptance'}
  }
  if($ReportFile){[IO.File]::WriteAllText([IO.Path]::GetFullPath($ReportFile),($reports|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))}
  if($RequireSmooth60 -and @($reports|Where-Object{!$_.smooth60Candidate}).Count){throw 'Smooth-60 stress acceptance failed; inspect every phase report instead of relying on average FPS'}
}finally{
  if($driver){$driver.Stop()};if($finish){$finish.Stop()};if($script:frameProbe){$script:frameProbe.Dispose()}
  $script:gravityTimer.Stop();$script:gravitySampler.Stop();$script:context.IsOpen=$false;$script:window.Close()
  $temporary=[IO.Path]::GetFullPath($script:dataDir)
  if(!$temporary.StartsWith([IO.Path]::GetFullPath([IO.Path]::GetTempPath()),[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe temporary cleanup path'}
  Remove-Item -LiteralPath $temporary -Recurse -Force
}
