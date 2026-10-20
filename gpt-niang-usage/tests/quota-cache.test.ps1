param([string]$TestRoot=$PSScriptRoot)
# AI-generated maintenance test; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$source=[IO.File]::ReadAllText((Join-Path (Split-Path $TestRoot -Parent) 'widget.ps1'),[Text.Encoding]::UTF8)
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Widget syntax errors'}
foreach($name in @('Request-Refresh','Update-Quota')){
  $definition=$ast.Find({param($n) $n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
  . ([scriptblock]::Create($definition.Extent.Text))
}
function Get-QuotaRows {return @()}
function Update-BubbleTooltip {}
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('quota-cache-'+[Guid]::NewGuid().ToString('N'))
[IO.Directory]::CreateDirectory($script:dataDir)|Out-Null
$script:ui=@{Status=[Windows.Controls.TextBlock]::new();Header=[Windows.Controls.TextBlock]::new();LiveDot=[Windows.Shapes.Ellipse]::new();WeekRow=[Windows.Controls.Border]::new();ShortRow=[Windows.Controls.Border]::new()}
$script:widgetColors=$null;$script:statusStamp=0
$file=Join-Path $script:dataDir 'status.json';$flag=Join-Path $script:dataDir 'refresh.flag'
function Write-Fixture($value){[IO.File]::WriteAllText($file,($value|ConvertTo-Json -Depth 5));$script:statusStamp=0;Update-Quota}
try{
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
  $fixture=@{ok=$true;queryOk=$true;accountKey='fictional';observedAt=$now;windows=@();refreshing=$false}
  Write-Fixture $fixture
  Request-Refresh -IfNeeded
  if(Test-Path $flag){throw 'Opening fresh data must not query again'}
  $fixture.refreshing=$true;$fixture.refreshStartedAt=$now;Write-Fixture $fixture
  Request-Refresh
  if(Test-Path $flag){throw 'Clicks must not duplicate an active query'}
  if($script:ui.Header.Text-notmatch ([char]0x21BB)){throw 'Visible fetching indicator missing'}
  if($script:ui.Status.Text-notmatch '正在获取新数据'){throw 'Fetching indicator missing'}
  $fixture.refreshing=$false;$fixture.queryOk=$false;$fixture.error='fictional failure';Write-Fixture $fixture
  if($script:ui.Header.Text-notmatch ([char]0x26A0)){throw 'Visible failure indicator missing'}
  if($script:ui.Status.Text-notmatch '⚠'){throw 'Failure warning missing'}
  Request-Refresh -IfNeeded
  if(!(Test-Path $flag)){throw 'Next click must permit a bounded retry after failure'}
  Remove-Item -LiteralPath $flag
  $fixture.queryOk=$true;$fixture.error=$null;$fixture.observedAt=$now-61000;Write-Fixture $fixture
  Request-Refresh -IfNeeded
  if(!(Test-Path $flag)){throw 'Old data must be eligible for refresh'}
  'PASS: fresh cache, active click suppression, fetching and failure indicators, next-click recovery, old cache refresh'
}finally{Remove-Item -LiteralPath $script:dataDir -Recurse -Force}
