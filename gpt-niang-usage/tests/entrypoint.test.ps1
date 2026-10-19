param([string]$PreviewDirectory)
$ErrorActionPreference='Stop'
$source=Split-Path $PSScriptRoot -Parent
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('gpt-niang-entrypoint-'+[Guid]::NewGuid().ToString('N'))
$testApp=Join-Path $testRoot 'app'
$testData=Join-Path $testRoot 'state'
# AI-generated test maintenance: follow the packaged dependency list, excluding
# the machine-generated MCP configuration. Never copy private installation state.
$requiredFiles=Get-Content -LiteralPath (Join-Path $source 'runtime\install-files.json') -Raw -Encoding UTF8|ConvertFrom-Json
$files=@($requiredFiles|Where-Object{$_-ne '.mcp.json'})
$directories=@($testRoot,$testApp,$testData,(Join-Path $testApp 'runtime'),(Join-Path $testApp 'assets'))
try{
  foreach($directory in $directories){$null=New-Item -ItemType Directory -Path $directory}
  foreach($file in $files){$target=Join-Path $testApp $file;$null=New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force;Copy-Item -LiteralPath (Join-Path $source $file) -Destination $target}
  $config=@{appDir=$testApp;dataDir=$testData;codexPath='unused-in-preview'}
  [IO.File]::WriteAllText((Join-Path $testApp 'installation.json'),($config|ConvertTo-Json),[Text.UTF8Encoding]::new($false))
  $snapshot=@{ok=$true;queryOk=$true;observedAt=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();windows=@(@{minutes=300;used=25;remaining=75;resetsAt=$null},@{minutes=10080;used=10;remaining=90;resetsAt=$null})}
  [IO.File]::WriteAllText((Join-Path $testData 'status.json'),($snapshot|ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
  $powerShell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
  & $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $testApp 'runtime\start-widget.ps1') -WidgetPath (Join-Path $testApp 'widget.ps1') -Preview
  if($LASTEXITCODE-ne 0){throw 'The full WPF entry point failed.'}
  $preview=Join-Path $testApp 'preview.png'
  if(!(Test-Path -LiteralPath $preview) -or [IO.File]::ReadAllBytes($preview).Length-lt 1000){throw 'The WPF preview is missing or empty.'}
  if($PreviewDirectory){
    $null=New-Item -ItemType Directory -Path $PreviewDirectory -Force
    Copy-Item -LiteralPath $preview -Destination (Join-Path $PreviewDirectory 'quota-aligned.png')
  }
  Write-Output 'PASS: full WPF widget and UTF-8 entry point on Windows PowerShell 5.1'
}finally{
  $resolved=[IO.Path]::GetFullPath($testRoot)
  $prefix=[IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\')+'\'
  if(!$resolved.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) -or [IO.Path]::GetFileName($resolved)-notlike 'gpt-niang-entrypoint-*'){throw 'Unsafe entrypoint test cleanup path.'}
  if(Test-Path -LiteralPath $resolved){Remove-Item -LiteralPath $resolved -Recurse -Force}
}
