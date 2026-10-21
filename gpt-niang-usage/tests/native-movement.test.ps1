param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
Add-Type -ReferencedAssemblies @('PresentationFramework','PresentationCore','WindowsBase','System.Xaml') -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
public static class NativeMovementFixture {
 [StructLayout(LayoutKind.Sequential)] struct Rect {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int height,uint flags);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h,out Rect r);
 [DllImport("user32.dll")] static extern IntPtr GetCapture();
 [DllImport("user32.dll")] static extern IntPtr SetCapture(IntPtr h);
 [DllImport("user32.dll")] static extern bool ReleaseCapture();
 public static string Run(uint flags) {
  var window=new Window{Width=160,Height=160,Left=40,Top=40,ShowActivated=false,ShowInTaskbar=false,WindowStyle=WindowStyle.None,AllowsTransparency=true,Background=Brushes.Transparent,Opacity=0};
  int changing=0,changed=0;HwndSource source=null;
  HwndSourceHook hook=delegate(IntPtr h,int msg,IntPtr w,IntPtr l,ref bool handled){if(msg==0x46)changing++;if(msg==0x47)changed++;return IntPtr.Zero;};
  try {
   window.Show();var handle=new WindowInteropHelper(window).Handle;source=HwndSource.FromHwnd(handle);source.AddHook(hook);
   Rect initial;if(!GetWindowRect(handle,out initial))throw new Exception("Missing native rectangle");
   window.UpdateLayout();System.Windows.Threading.Dispatcher.CurrentDispatcher.Invoke(System.Windows.Threading.DispatcherPriority.ContextIdle,(Action)(()=>{}));
   SetCapture(handle);if(GetCapture()!=handle)throw new Exception("Native capture unavailable");
   for(int i=0;i<100;i++){
    int x=initial.Left+20+i%17,y=initial.Top+20+i%13;
    if(!SetWindowPos(handle,IntPtr.Zero,x,y,0,0,flags))throw new Exception("Move failed");
    Rect actual;GetWindowRect(handle,out actual);
    if(actual.Left!=x||actual.Top!=y||actual.Right-x!=initial.Right-initial.Left||actual.Bottom-y!=initial.Bottom-initial.Top)throw new Exception("Move changed position/size incorrectly");
    if(GetCapture()!=handle)throw new Exception("Moving lost capture");
   }
   Rect finalRect;GetWindowRect(handle,out finalRect);var origin=window.PointToScreen(new Point(0,0));
   if(Math.Abs(origin.X-finalRect.Left)>1||Math.Abs(origin.Y-finalRect.Top)>1)throw new Exception("WPF input coordinates lost native movement");
   if(changing!=0||changed<100)throw new Exception("Expected change-complete notifications without pre-change negotiation: "+changing+"/"+changed);
   ReleaseCapture();if(GetCapture()==handle)throw new Exception("Release retained native capture");
   return "PASS: 100 native moves retain size/capture and change-complete notifications; redundant pre-change notifications=0";
  } finally {ReleaseCapture();if(source!=null)source.RemoveHook(hook);window.Close();}
 }
}
'@
# Read the actual movement flags from production rather than testing a fixture-only flag.
$flags=@()
foreach($name in @('runtime/gravity-render.cs','runtime/host-follow.ps1','widget.ps1')){
 $source=[IO.File]::ReadAllText((Join-Path $AppDir $name))
 foreach($match in [regex]::Matches($source,',0,0,(0x[0-9a-fA-F]+)\)')){
  $value=[Convert]::ToUInt32($match.Groups[1].Value.Substring(2),16)
  if(($value-band 2)-eq 0){$flags+=,$value}
 }
}
if($flags.Count-ne 4){throw 'Expected four move-only production paths'}
foreach($value in ($flags|Select-Object -Unique)){[NativeMovementFixture]::Run($value)}
