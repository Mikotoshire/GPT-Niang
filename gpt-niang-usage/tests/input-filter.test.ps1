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
 $bitmap=$girl.Source
 $alpha=[Windows.Media.Imaging.FormatConvertedBitmap]::new($bitmap,[Windows.Media.PixelFormats]::Bgra32,$null,0)
 $script:alphaStride=$bitmap.PixelWidth*4;$script:alphaPixels=[byte[]]::new($script:alphaStride*$bitmap.PixelHeight)
 $alpha.CopyPixels($script:alphaPixels,$script:alphaStride,0)
 $script:ui=@{Root=$filter.Root;Girl=$girl}
 $filter.AlphaPixels=$script:alphaPixels;$filter.AlphaStride=$script:alphaStride
 $filter.PixelWidth=$bitmap.PixelWidth;$filter.PixelHeight=$bitmap.PixelHeight
 $source=[IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1'),[Text.Encoding]::UTF8)
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
 foreach($name in @('Test-GirlAlpha','Test-WidgetHit')){
   $node=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
   . ([scriptblock]::Create($node.Extent.Text))
 }
 $opaque=0;$transparent=0
 foreach($mirror in @(1,-1)){foreach($squash in @(.5,1.0,1.1)){
   $window.FindName('CharacterMirror').ScaleX=$mirror;$window.FindName('GravityScale').ScaleY=$squash;$window.UpdateLayout()
   for($x=0;$x-le 350;$x+=25){for($y=0;$y-le 350;$y+=25){
     $screen=$filter.Root.PointToScreen([Windows.Point]::new($x,$y));$sx=[int][Math]::Round($screen.X);$sy=[int][Math]::Round($screen.Y)
     $expected=Test-WidgetHit ($filter.Root.PointFromScreen([Windows.Point]::new($sx,$sy)))
     $packedHit=([long]($sy-band 65535)-shl 16)-bor ($sx-band 65535);$hitHandled=$false
     $answer=$filter.Handle($h,0x84,[IntPtr]::Zero,[IntPtr]$packedHit,[ref]$hitHandled)
     Assert (($answer.ToInt64()-ne -1)-eq $expected) 'Compiled hit testing agrees with transformed alpha hit testing'
     if($expected){$opaque++}else{$transparent++}
   }}
 }}
 Assert ($opaque-gt 0 -and $transparent-gt 0) 'Hit tests cover both click-through and interactive pixels'
 Assert ($script:forwarded-eq 5) 'Configured alpha hits never enter PowerShell'
 $window.FindName('CharacterMirror').ScaleX=1;$window.FindName('GravityScale').ScaleY=1;$window.UpdateLayout()
 $point=$girl.TranslatePoint([Windows.Point]::new(100,150),$window)
 $matrix=$src.CompositionTarget.TransformToDevice;$physical=$matrix.Transform($point)
 $packed=([long][int]$physical.Y-shl 16)-bor ([int]$physical.X-band 65535)
 $null=$filter.Handle($h,0x201,[IntPtr]::Zero,[IntPtr]$packed,[ref]$handled)
 Assert ($filter.Model.IsPressed) 'A native button press stops an airborne character before WPF input routing'
 $height=$filter.Model.Height;$filter.Model.Advance(.05,900,20000)
 Assert ($filter.Model.Height-eq $height -and $filter.Model.HorizontalVelocity-eq 0 -and $filter.Model.Velocity-eq 0) 'Caught character cannot fly away before script input dispatch'
 Assert (!$handled) 'Native early catch preserves normal WPF mouse routing'
 $filter.Model.FlingFrom(240,600,-300)
 $null=$filter.Handle($h,0x203,[IntPtr]::Zero,[IntPtr]$packed,[ref]$handled)
 Assert $filter.Model.IsPressed 'The second click of a native double-click also catches the character'
 $girl.ReleaseMouseCapture();$filter.Model.FlingFrom(240,600,-300);$filter.GravityEnabled=$false
 $null=$filter.Handle($h,0x201,[IntPtr]::Zero,[IntPtr]$packed,[ref]$handled)
 Assert (!$filter.Model.IsPressed -and !$girl.IsMouseCaptured) 'Ordinary mode does not acquire the gravity catch'
 Assert (!$filter.LastError) 'Input hook reports no hidden errors'

 # Exercise the production handler's failed-capture cleanup without OS input.
 $down=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq '$pressDown'},$true)
 $text=$down.Right.Extent.Text.Trim();$handler=[scriptblock]::Create($text.Substring(1,$text.Length-2))
 $sender=[pscustomobject]@{};$sender|Add-Member ScriptMethod CaptureMouse {return $false}
 $script:gravityEnabled=$true;$script:cancelled=$false
 function Release-WidgetGravityDrop {param([switch]$Cancel)$script:cancelled=[bool]$Cancel}
 & $handler $sender ([pscustomobject]@{Handled=$false})
 Assert $script:cancelled 'Failed OS capture cancels early hold rather than freezing the pet'

}finally{if($filter){$filter.Dispose()};$girl.ReleaseMouseCapture();$window.Close()}
'PASS: compiled native message filter and immediate airborne press'
