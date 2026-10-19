param([string]$AppDir=(Split-Path $PSScriptRoot -Parent),[switch]$Visible)
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
try{
  $null=Set-WidgetPixelSize 1
  $script:gravityEnabled=$true;$script:gravityInertia=$true
  $script:gravity.SetTuning(0.5,0.25);$script:gravity.SetHorizontalPosition(300);$script:gravity.FlingFrom(600,100,0)
  $script:notifications=0;$script:gravityTimer.Add_Tick({$script:notifications++})
  $pump=[Windows.Threading.DispatcherFrame]::new();$finish=[Windows.Threading.DispatcherTimer]::new()
  $finish.Tag=$pump;$finish.Interval=[TimeSpan]::FromSeconds(2)
  $finish.Add_Tick({param($sender,$event)$sender.Stop();$sender.Tag.Continue=$false})
  Start-WidgetGravityTimer;$finish.Start();[Windows.Threading.Dispatcher]::PushFrame($pump)
  $loop=$script:gravityTimer;$loop.Stop()
  if($loop.LastError){throw $loop.LastError}
  if($loop.FrameCount-lt 100 -or $loop.Fps-lt 58 -or $loop.Fps-gt 95){throw ('60-Hz render cadence missed: '+$loop.Fps)}
  if($loop.MeanStepMs-ge 5){throw 'Managed step consumes too much of the 16.67-ms frame budget'}
  if($script:notifications-gt 10){throw 'PowerShell must not be called every animation frame'}
  if($loop.PositionUpdates-lt 60){throw 'Frame callbacks must include actual changing native positions'}
  Sync-WidgetGravityPosition
  if([Math]::Abs($script:desktopLeft-$loop.Scene.X)-gt 0.1){throw 'Low-frequency placement must retain the managed horizontal pose'}
  Write-Output ('PASS: managed frames='+$loop.FrameCount+' renderHz='+[Math]::Round($loop.Fps,1)+' positionUpdates='+$loop.PositionUpdates+' meanStepMs='+[Math]::Round($loop.MeanStepMs,3)+' maxStepMs='+[Math]::Round($loop.MaxStepMs,3)+' scriptNotifications='+$script:notifications)
}finally{$script:gravityTimer.Stop();$script:gravitySampler.Stop();$script:window.Close()}
