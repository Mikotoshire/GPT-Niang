param([string]$AppDir=(Split-Path $PSScriptRoot -Parent),[ValidateRange(100000,2000000)][int]$Count=1000000)
# AI-generated regression; insufficiently validated. Uses one hidden owned HWND.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
. (Join-Path $AppDir 'runtime/host-occlusion.ps1')
Add-Type @'
using System;using System.Diagnostics;using System.Runtime.InteropServices;
public static class OcclusionMoveCost {
 public static string Run(Action<IntPtr> handler,IntPtr widget,int count){
  IntPtr data=Marshal.AllocHGlobal(2*IntPtr.Size+24);
  try {
   for(int n=0;n<2*IntPtr.Size+24;n++)Marshal.WriteByte(data,n,0);
   Marshal.WriteIntPtr(data,widget);
   Marshal.WriteInt32(data,2*IntPtr.Size+16,0x415);
   for(int i=0;i<2000;i++)handler(data);
   var method=typeof(GC).GetMethod("GetAllocatedBytesForCurrentThread",Type.EmptyTypes);
   var allocated=method==null?null:(Func<long>)Delegate.CreateDelegate(typeof(Func<long>),method);
   var timer=new Stopwatch();
   if(allocated!=null){allocated();allocated();}
   GC.Collect();GC.WaitForPendingFinalizers();GC.Collect();
   int before=GC.CollectionCount(0);long bytes=allocated==null?-1:allocated();timer.Start();
   for(int i=0;i<count;i++)handler(data);
   timer.Stop();long delta=allocated==null?-1:allocated()-bytes;int collections=GC.CollectionCount(0)-before;
   return collections+"|"+timer.Elapsed.TotalMilliseconds.ToString(System.Globalization.CultureInfo.InvariantCulture)+"|"+delta;
  }finally{Marshal.FreeHGlobal(data);}
 }
}
'@
$window=New-Object Windows.Window
$recovery=$null
try{
 $handle=([Windows.Interop.WindowInteropHelper]::new($window)).EnsureHandle()
 $recovery=[GptWidgetOcclusionRecovery]::new($handle)
 # Keep the production recovery enabled, while a hidden own host prevents a
 # timer burst. Pure geometry notifications must not start coverage scans.
 $recovery.Configure($handle,$true)
 $checks=$recovery.Checks
 $callback=[Delegate]::CreateDelegate([Action[IntPtr]],$recovery,'OnPositionChanged')
 $result=([OcclusionMoveCost]::Run($callback,$handle,$Count)).Split('|')
 Write-Output ('MEASURE: geometry messages='+$Count+' gen0Collections='+$result[0]+' elapsedMs='+$result[1]+' threadAllocatedBytes='+$result[2])
 # Thread bytes isolate the callback from unrelated process GC. A tiny fixed
 # allowance covers measurement setup; any per-message boxing exceeds it.
 if([long]$result[2]-gt 512){throw 'Geometry-only notifications allocated per-message objects'}
 if([long]$result[2]-lt 0){Write-Output 'NOTE: thread allocation API unavailable; GC count is diagnostic only'}
 if($recovery.Checks-ne $checks -or $recovery.Pending){throw 'Geometry-only notification started a recovery scan'}
 Write-Output 'PASS: geometry notification checks completed; no recovery scans started'
}finally{if($recovery){$recovery.Dispose()};$window.Close()}
