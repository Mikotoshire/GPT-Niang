$ErrorActionPreference='Stop'
$script:appDir=Split-Path $PSScriptRoot -Parent
foreach($module in @('music.ps1','completion-notifications.ps1')){
  . ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $script:appDir ('runtime/'+$module)),[Text.Encoding]::UTF8)))
}
Initialize-WidgetMusicTypes
$script:events=[Collections.Generic.List[string]]::new()
function Assert($Condition,[string]$Message){if(!$Condition){throw $Message}}
function Suspend-WidgetGravityForTransientMotion([string]$Owner){$script:events.Add('suspend:'+$Owner);if($script:failSuspend){throw 'test suspend failure'}}
function Resume-WidgetGravityFromNativePosition([string]$Owner){$script:events.Add('resume:'+$Owner)}
function Update-WidgetMusicVisibility([bool]$Visible,[bool]$Blocked=$false){}

# Stop reconciles a constructor failure even when assignment never completed,
# and resumes only after an existing object's disposal was attempted.
$script:musicGravitySuspended=$true
Stop-WidgetMusic
Assert (($script:events -join ',')-eq 'resume:music') 'Constructor-failure cleanup leaked the music owner'
Stop-WidgetMusic
Assert ($script:events.Count-eq 1) 'Repeated stop resumed music twice'
$script:widgetMusic=[pscustomobject]@{Error=$null}
$script:widgetMusic|Add-Member ScriptMethod Stop {param($keep)$script:events.Add('dispose:music');throw 'test stop failure'}
$script:musicGravitySuspended=$true
try{Stop-WidgetMusic;throw 'Expected stop failure'}catch{Assert ($_.Exception.Message-match 'test stop failure') 'Unexpected stop exception'}
Assert (($script:events -join ',')-eq 'resume:music,dispose:music,resume:music') 'Disposal failure did not release its owner in order'

$script:window=[Windows.Window]::new();$script:window.Width=378;$script:window.Height=378;$script:window.Opacity=0;$script:window.ShowInTaskbar=$false;$script:window.ShowActivated=$false
$root=[Windows.Controls.Canvas]::new();$script:window.Content=$root
$girl=[Windows.Controls.Image]::new();$girl.Width=208;$girl.Height=208;$root.Children.Add($girl)|Out-Null
[Windows.Controls.Canvas]::SetLeft($girl,142);[Windows.Controls.Canvas]::SetTop($girl,142)
$girl.Source=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $script:appDir 'assets/gpt-dragon-niang-bust.png'))
$mirror=[Windows.Media.ScaleTransform]::new(-1,1,-104,0);$gravity=[Windows.Media.ScaleTransform]::new(1,1)
$old=[Windows.Media.TransformGroup]::new();$old.Children.Add($mirror);$old.Children.Add($gravity)
$girl.RenderTransform=$old;$girl.RenderTransformOrigin=[Windows.Point]::new(1,1)
$music=$null
try{
  $script:widgetHandle=([Windows.Interop.WindowInteropHelper]::new($script:window)).EnsureHandle()
  $script:window.Show();$script:window.UpdateLayout()
  $music=[GptMusicVisual]::new($script:window,$girl,$null,[Action[int,int]]{param($x,$y)},[Windows.Media.Color[]]@([Windows.Media.Colors]::Pink),$false)
  $composed=$girl.RenderTransform
  Assert ($composed-is [Windows.Media.TransformGroup]) 'Music replaced the transform chain with a scale'
  Assert ([object]::ReferenceEquals($composed.Children[1],$old)) 'Music cloned away live mirror/gravity objects'
  $before=$composed.Transform([Windows.Point]::new(20,30))
  $mirror.ScaleX=1
  $after=$composed.Transform([Windows.Point]::new(20,30))
  Assert ([Math]::Abs($before.X-$after.X)-gt 1) 'Live mirror changes did not affect music pose'
  # With music compression neutral, wrapping the old origin must preserve
  # its effective coordinates rather than translating a mirrored character.
  $mirror.ScaleX=-1
  $point=[Windows.Point]::new(20,30)
  $expected=$old.Transform([Windows.Point]::new($point.X-208,$point.Y-208));$expected.Offset(208,208)
  $actual=$composed.Transform($point)
  Assert (([Math]::Abs($actual.X-$expected.X)+[Math]::Abs($actual.Y-$expected.Y))-lt .001) 'Music changed the original transform origin'
  $music.Stop($false);$music=$null
  Assert ([object]::ReferenceEquals($girl.RenderTransform,$old)) 'Stop did not restore the live transform chain'
  Assert ($girl.RenderTransformOrigin-eq [Windows.Point]::new(1,1)) 'Stop did not restore the transform origin'

  $script:events.Clear();$script:failSuspend=$false
  Assert (Start-TemporaryCompletion) 'Temporary completion did not start'
  Assert (($script:events -join ',')-eq 'suspend:completion') 'Completion did not acquire its movement owner'
  Stop-TemporaryCompletion;Stop-TemporaryCompletion
  Assert (($script:events -join ',')-eq 'suspend:completion,resume:completion') 'Completion cleanup did not release exactly once'
  $script:events.Clear();$script:failSuspend=$true
  Assert (!(Start-TemporaryCompletion)) 'Expected temporary completion startup failure'
  Assert (!$script:completionTemporary) 'Failed completion startup retained temporary state'
  Assert (($script:events -join ',')-eq 'suspend:completion,resume:completion') 'Failed completion startup leaked its movement owner'
}finally{
  $script:failSuspend=$false
  if($music){$music.Stop($false)}
  Stop-TemporaryCompletion
  $script:window.Close()
}
Write-Output 'PASS: transient motion owners and live music transform composition'
