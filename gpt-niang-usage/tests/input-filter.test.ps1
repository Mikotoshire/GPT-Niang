param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated native/WPF regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework
. (Join-Path $AppDir 'runtime/gravity.ps1')
function Assert($v,$m){if(!$v){throw $m}}
$script:forwarded=0
$fallback=[Windows.Interop.HwndSourceHook]{param($h,$m,$w,$l,[ref]$handled)$script:forwarded++;return [IntPtr]::Zero}
$window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $AppDir 'widget.xaml'),[Text.Encoding]::UTF8))
$girl=$window.FindName('Girl');$girl.Source=[Windows.Media.Imaging.BitmapImage]::new([Uri](Join-Path $AppDir 'assets/gpt-dragon-niang-bust.png'))
$window.ShowActivated=$false;$window.Show();$window.UpdateLayout()
$h=([Windows.Interop.WindowInteropHelper]::new($window)).Handle
$src=[Windows.Interop.HwndSource]::FromHwnd($h);$filter=$null
try{
 $filter=[GptWidgetInputFilter]::new($src,$fallback)
 $filter.Root=$window.FindName('Root');$filter.Character=$girl
 $filter.Model=[GptGravityModel]::new();$filter.GravityEnabled=$true
 $filter.Model.FlingFrom(240,600,-300)
 $handled=$false
 for($i=0;$i-lt 2000;$i++){$null=$filter.Handle($h,0x46,[IntPtr]::Zero,[IntPtr]::Zero,[ref]$handled)}
 Assert ($script:forwarded-eq 0) 'Unrelated native messages never enter PowerShell'
 foreach($msg in @(0x84,0x21,0x2e0,0x7e,0x1a)){$null=$filter.Handle($h,$msg,[IntPtr]::Zero,[IntPtr]::Zero,[ref]$handled)}
 Assert ($script:forwarded-eq 5) 'Hit testing, activation and layout messages retain their handler'
 $point=$girl.TranslatePoint([Windows.Point]::new(100,150),$window)
 $matrix=$src.CompositionTarget.TransformToDevice;$physical=$matrix.Transform($point)
 $packed=([long][int]$physical.Y-shl 16)-bor ([int]$physical.X-band 65535)
 $null=$filter.Handle($h,0x201,[IntPtr]::Zero,[IntPtr]$packed,[ref]$handled)
 Assert ($filter.Model.IsPressed -and $girl.IsMouseCaptured) 'A native button press captures an airborne character immediately'
 $height=$filter.Model.Height;$filter.Model.Advance(.05,900,20000)
 Assert ($filter.Model.Height-eq $height -and $filter.Model.HorizontalVelocity-eq 0 -and $filter.Model.Velocity-eq 0) 'Caught character cannot fly away before script input dispatch'
 Assert (!$handled) 'Native early catch preserves normal WPF mouse routing'
 $girl.ReleaseMouseCapture();$filter.Model.FlingFrom(240,600,-300);$filter.GravityEnabled=$false
 $null=$filter.Handle($h,0x201,[IntPtr]::Zero,[IntPtr]$packed,[ref]$handled)
 Assert (!$filter.Model.IsPressed -and !$girl.IsMouseCaptured) 'Ordinary mode does not acquire the gravity catch'
 Assert (!$filter.LastError) 'Input hook reports no hidden errors'
}finally{if($filter){$filter.Dispose()};$girl.ReleaseMouseCapture();$window.Close()}
'PASS: compiled native message filter and immediate airborne capture'
