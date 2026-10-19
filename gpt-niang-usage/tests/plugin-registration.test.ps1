# AI-generated maintenance test; limited coverage, see AI-NOTICE.md.
$ErrorActionPreference='Stop'
. (Join-Path (Split-Path $PSScriptRoot -Parent) 'runtime\install-preflight.ps1')
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('gpt-niang-verification-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $testRoot
$checks=0
function Write-WidgetSupervisorJson([string]$File,$Value){[IO.File]::WriteAllText($File,($Value|ConvertTo-Json),[Text.Encoding]::UTF8)}
function Assert($condition,[string]$label){if(!$condition){throw ('Assertion failed: '+$label)};$script:checks++;Write-Output ('PASS '+$label)}
try{
  $exe=Join-Path $testRoot 'fixture.exe'
  Add-Type -OutputAssembly $exe -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.Threading;
class Fixture {
  static int Main(string[] args) {
    string mode=Environment.GetEnvironmentVariable("GPT_NIANG_VERIFY_FIXTURE");
    bool scoped=String.Join(" ",args)=="plugin list --marketplace gpt-niang-local --json";
    if(!scoped || mode=="timeout"){Thread.Sleep(60000);return 9;}
    if(mode=="stderr"){Console.Error.Write(new string('x',200000));}
    if(mode=="exit"){Console.Error.Write("private diagnostic must not escape");return 7;}
    if(mode=="invalid"){Console.Write("not json");return 0;}
    string version=mode=="version"?"0.0.0":"1.4.2";
    string enabled=mode=="disabled"?"false":"true";
    string item="{\"pluginId\":\"gpt-niang-usage@gpt-niang-local\",\"version\":\""+version+"\",\"installed\":true,\"enabled\":"+enabled+"}";
    Console.Write("{\"installed\":["+item+(mode=="duplicate"?","+item:"")+"]}");return 0;
  }
}
'@
  $env:GPT_NIANG_VERIFY_FIXTURE='ok'
  $summary=Join-Path $testRoot 'summary.json'
  Assert-WidgetPluginRegistration $exe '1.4.2' -TimeoutMilliseconds 2000 -DiagnosticFile $summary
  Assert $true 'only the local marketplace is queried (unscoped fixture hangs)'
  Assert ((Get-Content -LiteralPath $summary -Raw|ConvertFrom-Json).status-eq 'verified') 'successful summary is recorded'
  $env:GPT_NIANG_VERIFY_FIXTURE='stderr'
  Assert-WidgetPluginRegistration $exe '1.4.2' -TimeoutMilliseconds 2000
  Assert $true 'large stderr does not block verification'
  foreach($case in @(@('timeout','timeout'),@('exit','command-failed'),@('invalid','invalid-json'),@('version','registration-mismatch'),@('disabled','registration-mismatch'),@('duplicate','registration-mismatch'))){
    $env:GPT_NIANG_VERIFY_FIXTURE=$case[0];$watch=[Diagnostics.Stopwatch]::StartNew()
    try{Assert-WidgetPluginRegistration $exe '1.4.2' -TimeoutMilliseconds 500 -DiagnosticFile $summary;throw 'Expected rejection'}
    catch{Assert ($_.Exception.Message.Contains($case[1])) ('reject '+$case[0]);Assert (!$_.Exception.Message.Contains('private diagnostic')) 'raw CLI diagnostics remain private'}
    Assert ($watch.Elapsed.TotalSeconds-lt 5) 'failure is bounded'
    $record=Get-Content -LiteralPath $summary -Raw|ConvertFrom-Json
    Assert ($record.status-eq $case[1]) 'summary records exact failure stage'
    Assert ((@($record.PSObject.Properties.Name|Sort-Object)-join ',')-eq 'at,elapsedMs,exitCode,schema,scope,stage,status,version') 'summary uses privacy allowlist'
  }
  Assert (@(Get-Process fixture -ErrorAction SilentlyContinue|Where-Object{$_.Path-eq $exe}).Count-eq 0) 'no verification process leaked'
  Write-Output ("PASS $checks registration assertions")
}finally{
  Remove-Item Env:\GPT_NIANG_VERIFY_FIXTURE -ErrorAction SilentlyContinue
  $resolved=[IO.Path]::GetFullPath($testRoot)
  if(!(Split-Path $resolved -Leaf).StartsWith('gpt-niang-verification-') -or !(Split-Path $resolved -Parent).Equals([IO.Path]::GetTempPath().TrimEnd('\'),[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe fixture cleanup path.'}
  Remove-Item -LiteralPath $resolved -Recurse -Force
}
