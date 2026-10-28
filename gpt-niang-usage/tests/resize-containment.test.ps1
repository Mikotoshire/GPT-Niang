# AI-generated regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. (Join-Path $PSScriptRoot '../runtime/host-follow.ps1')
Add-Type @'
using System;using System.Runtime.InteropServices;
public static class ResizeProbe {
 public struct Rect {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int ht,uint f);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out Rect r);
}
'@
$hostWindow=$null;$pet=$null;$follower=$null;$count=0
try {
 $hostWindow=[Windows.Window]::new();$pet=[Windows.Window]::new()
 foreach($w in @($hostWindow,$pet)){$w.WindowStyle='None';$w.ShowActivated=$false;$w.ShowInTaskbar=$false;$w.Left=-20000;$w.Top=-20000;$w.Width=900;$w.Height=700;$w.Show()}
 $hostId=([Windows.Interop.WindowInteropHelper]::new($hostWindow)).Handle
 $petId=([Windows.Interop.WindowInteropHelper]::new($pet)).Handle
 $follower=[GptWidgetHostFollower]::new($petId)
 # Exercise the production layout-to-pixel cache with fictional square/wide/tall sources.
 $source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../widget.ps1'),[Text.Encoding]::UTF8)
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
 $fn=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq 'Update-WidgetHostCharacterBounds'},$true)
 if(!$fn){throw 'Missing production bounds cache'}
 . ([scriptblock]::Create($fn.Extent.Text))
 $script:hostFollower=$follower;$script:designWidth=$script:designHeight=378
 $root=[Windows.Controls.Canvas]::new();[Windows.Controls.Canvas]::SetLeft($root,14);[Windows.Controls.Canvas]::SetTop($root,14)
 $image=[Windows.Controls.Image]::new();$image.Stretch='Uniform'
 $script:ui=@{Root=$root;Girl=$image}
 foreach($dimensions in @(@(100,100),@(200,100),@(100,200))) {
  $image.Source=[Windows.Media.Imaging.BitmapSource]::Create($dimensions[0],$dimensions[1],96,96,[Windows.Media.PixelFormats]::Bgra32,$null,(New-Object byte[] ($dimensions[0]*$dimensions[1]*4)),($dimensions[0]*4))
  foreach($character in @(0.6,1,2.5)) {
   $image.Width=$image.Height=208*$character/2.5
   [Windows.Controls.Canvas]::SetLeft($image,(350-$image.Width));[Windows.Controls.Canvas]::SetTop($image,(350-$image.Height))
   $script:hostCharacterBoundsReady=$false
   foreach($pixels in @(378,567,945)) {
    Update-WidgetHostCharacterBounds $pixels $pixels
    $fit=[Math]::Min($image.Width/$dimensions[0],$image.Height/$dimensions[1]);$unit=$pixels/378
    $expectedLeft=(364-$image.Width/2-$dimensions[0]*$fit/2)*$unit
    $expectedBottom=(364-$image.Height/2+$dimensions[1]*$fit/2)*$unit
    $flags=[Reflection.BindingFlags]'Instance,NonPublic'
    $actualLeft=$follower.GetType().GetField('characterLeft',$flags).GetValue($follower)
    $actualBottom=$follower.GetType().GetField('characterBottom',$flags).GetValue($follower)
    if([Math]::Abs($actualLeft-$expectedLeft)-gt .001 -or [Math]::Abs($actualBottom-$expectedBottom)-gt .001){throw 'Production resting bounds mismatch'}
   }
  }
 }
 # Music changes Canvas placement without resizing the HWND; its lifecycle must refresh the cache.
 . ([scriptblock]::Create([IO.File]::ReadAllText((Join-Path $PSScriptRoot '../runtime/music.ps1'),[Text.Encoding]::UTF8)))
 $script:followHost=$true
 [Windows.Controls.Canvas]::SetLeft($image,50)
 Sync-WidgetMusicContainment
 $musicLeft=$follower.GetType().GetField('characterLeft',$flags).GetValue($follower)
 $script:widgetMusic=New-Object PSObject
 $script:widgetMusic|Add-Member ScriptMethod Stop {param($keep)[Windows.Controls.Canvas]::SetLeft($script:ui.Girl,100)}
 Stop-WidgetMusic
 $restoredLeft=$follower.GetType().GetField('characterLeft',$flags).GetValue($follower)
 if([Math]::Abs(($restoredLeft-$musicLeft)-50*945/378)-gt .001){throw 'Music stop retained old layout bounds'}
 foreach($anchor in @('free','left','right')) {
  foreach($shape in @(@(156,156,364,364),@(260,100,364,364))) {
   if($follower.GetType().GetMethod('SetCharacterBounds')){$follower.SetCharacterBounds($shape[0],$shape[1],$shape[2],$shape[3])}
   foreach($size in @(@(900,700),@(420,330),@(260,280),@(130,140),@(900,700))) {
    $null=[ResizeProbe]::SetWindowPos($hostId,[IntPtr]::Zero,-20000,-20000,$size[0],$size[1],0x14)
    $null=[ResizeProbe]::SetWindowPos($petId,[IntPtr]::Zero,-20000,-20000,378,378,0x14)
    $r=[ResizeProbe+Rect]::new();$null=[ResizeProbe]::GetWindowRect($hostId,[ref]$r)
    $follower.Configure($hostId,$r.Left,$r.Top,$r.Right,$r.Bottom,378,378,500,500,500,$anchor,$true)
    # Resize again without a layout/configure pass: this is the native event path.
    $null=[ResizeProbe]::SetWindowPos($hostId,[IntPtr]::Zero,-20000,-20000,($size[0]+17),($size[1]+11),0x14)
    $null=$follower.Synchronize()
    $null=[ResizeProbe]::GetWindowRect($hostId,[ref]$r)
    foreach($shift in @(-600,0,600)) {
     $follower.SetTemporaryOffset($shift,$shift)
     $p=[ResizeProbe+Rect]::new();$null=[ResizeProbe]::GetWindowRect($petId,[ref]$p)
     $minX=$r.Left-$shape[0];$maxX=$r.Right-$shape[2];$minY=$r.Top-$shape[1];$maxY=$r.Bottom-$shape[3]
     if($maxX -ge $minX){if($p.Left -lt $minX -or $p.Left -gt $maxX){throw 'Horizontal escape'}}
     elseif([Math]::Abs($p.Left-($minX+$maxX)/2)-gt 1){throw 'Oversized character not centered horizontally'}
     if($maxY -ge $minY){if($p.Top -lt $minY -or $p.Top -gt $maxY){throw 'Vertical escape'}}
     elseif([Math]::Abs($p.Top-($minY+$maxY)/2)-gt 1){throw 'Oversized character not centered vertically'}
     $count++
    }
   }
  }
 }
} finally {if($follower){$follower.Dispose()};if($pet){$pet.Close()};if($hostWindow){$hostWindow.Close()}}
"PASS: $count native resize/anchor/music-offset containment cases. No user window moved."
