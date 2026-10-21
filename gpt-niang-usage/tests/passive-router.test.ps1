param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
. (Join-Path $AppDir 'runtime/gravity.ps1')
Add-Type -ReferencedAssemblies @([Windows.Interop.HwndSource].Assembly.Location) -TypeDefinition @"
using System;using System.Windows.Interop;
public static class RouterInvokeFixture {
 public static HwndSourceHook Echo {get{return delegate(IntPtr h,int m,IntPtr w,IntPtr l,ref bool handled){handled=true;return new IntPtr(12345);};}}
 public static object[] Call(HwndSourceHook hook,int message,bool handled){
  IntPtr result=hook(new IntPtr(17),message,new IntPtr(23),new IntPtr(29),ref handled);
  return new object[]{result,handled};
 }
}
"@
$source=[IO.File]::ReadAllText((Join-Path $AppDir 'widget.ps1'))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Widget source parse failed'}
$node=$ast.Find({param($n)$n-is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text-eq '$script:messageHook'},$true)
$required=@([regex]::Matches($node.Extent.Text,'\$msg-eq\s+(0x[0-9a-fA-F]+)')|ForEach-Object{[Convert]::ToInt32($_.Groups[1].Value.Substring(2),16)}|Select-Object -Unique)
$script:routerCalls=0;$script:routerMessage=0
$callback=[Windows.Interop.HwndSourceHook]{param($h,$msg,$w,$l,[ref]$handled)
 if($h.ToInt64()-ne 17 -or $w.ToInt64()-ne 23 -or $l.ToInt64()-ne 29){throw 'Router changed message arguments'}
 $script:routerCalls++;$script:routerMessage=$msg;$handled.Value=$true
 return [IntPtr]12345
}
$router=[GptWidgetMessageRouter]::new($callback)
foreach($msg in 0..4095){
 $handled=$false;$expected=$null
 if($msg-in $required){$expected=[RouterInvokeFixture]::Call($callback,$msg,$false)}
 $before=$script:routerCalls
 $invoked=[RouterInvokeFixture]::Call($router.Hook,$msg,$handled);$result=$invoked[0];$handled=$invoked[1]
 if($msg-in $required){
  if($script:routerCalls-ne $before+1 -or $script:routerMessage-ne $msg -or $handled-ne $expected[1] -or $result-ne $expected[0]){throw "Required message was changed or lost: $msg calls=$script:routerCalls before=$before seen=$script:routerMessage handled=$handled result=$result"}
 }elseif($script:routerCalls-ne $before -or $handled -or $result-ne [IntPtr]::Zero){throw "Unrelated message entered the script or was consumed: $msg"}
}
if($script:routerCalls-ne 2*$required.Count){throw 'Unexpected script-call count'}
if($router.Messages-ne 4096 -or $router.ScriptMessages-ne $required.Count){throw 'Routing counters mismatch'}
$handled=$true
$invoked=[RouterInvokeFixture]::Call($router.Hook,0x200,$handled);$handled=$invoked[1]
if(!$handled){throw 'Existing handled value was overwritten'}
$nativeRouter=[GptWidgetMessageRouter]::new([RouterInvokeFixture]::Echo)
$nativeResult=[RouterInvokeFixture]::Call($nativeRouter.Hook,0x21,$false)
if(!$nativeResult[1] -or $nativeResult[0].ToInt64()-ne 12345){throw "Native ref/result propagation failed"}
'PASS: 4096 messages checked against production hook requirements; arguments/results/handled preserved, unrelated mouse messages stay with WPF'
