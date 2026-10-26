param([string]$TestRoot=$PSScriptRoot)
# AI-generated regression coverage; insufficiently validated, no GUI/audio startup.
$ErrorActionPreference='Stop'
$appDir=Split-Path $TestRoot -Parent
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
function Assert-Equal($actual,$expected,[string]$message){if($actual-ne $expected){throw "$message : expected '$expected', got '$actual'"}}
Assert-Equal $script:musicTravelSpeedPercent 100 'Fresh music settings default to 100 percent'
$script:saves=0
function Save-Settings {$script:saves++}
foreach($settings in @($null,@{},@{musicTravelSpeedPercent=$null},@{musicTravelSpeedPercent=$false},@{musicTravelSpeedPercent=$true},@{musicTravelSpeedPercent='bad'},@{musicTravelSpeedPercent=[double]::NaN},@{musicTravelSpeedPercent=[double]::PositiveInfinity},@{musicTravelSpeedPercent=[double]::NegativeInfinity},@{musicTravelSpeedPercent=-1},@{musicTravelSpeedPercent=201})){
  Initialize-WidgetMusicSettings $settings
  Assert-Equal $script:musicTravelSpeedPercent 100 'Missing or invalid saved values use default'
}
foreach($entry in @(@{value=0;expected=0},@{value=200;expected=200},@{value=54;expected=50},@{value=55;expected=60},@{value=145;expected=150},@{value='120';expected=120})){
  Initialize-WidgetMusicSettings ([pscustomobject]@{musicTravelSpeedPercent=$entry.value})
  Assert-Equal $script:musicTravelSpeedPercent $entry.expected 'Saved value restores nearest ten-percent setting'
}
Set-WidgetMusicTravelSpeedPercent 0
Assert-Equal $script:musicTravelSpeedPercent 0 'Zero is a legitimate preference'
Assert-Equal ($null-eq $script:widgetMusic) $true 'Changing settings while disabled does not start music'
Assert-Equal (Get-WidgetMusicStatus).musicTravelSpeedPercent 0 'Disabled status reports preference'
# Only visual shell is fake: normalization/application use the real music module.
$script:widgetMusic=[pscustomobject]@{Enabled=$true;Motion=[pscustomobject]@{TravelSpeedMultiplier=1.0};Error=$null;Audio=$null;Paused=$false;LampHandle=[IntPtr]::Zero}
Set-WidgetMusicTravelSpeedPercent 154
Assert-Equal $script:musicTravelSpeedPercent 150 'Live setting rounds to nearest ten'
Assert-Equal $script:widgetMusic.Motion.TravelSpeedMultiplier 1.5 'Live setting reaches existing motion immediately'
Assert-Equal (Get-WidgetMusicStatus).musicTravelSpeedPercent 150 'Enabled status reports preference'
$script:widgetMusic.Motion=$null
$script:widgetMusic | Add-Member ScriptMethod Configure {param($a,$b,$c,$d,$e,$f,$g,$h,$i,$j,$k)$this.Motion=[pscustomobject]@{TravelSpeedMultiplier=1.0}}
Update-WidgetMusicPlacement @{Left=0;Bottom=100} 1 0 0 $true
Assert-Equal $script:widgetMusic.Motion.TravelSpeedMultiplier 1.5 'Newly configured motion receives remembered setting'
$script:widgetMusic | Add-Member ScriptMethod Stop {param($keep)}
Stop-WidgetMusic
Assert-Equal $script:musicTravelSpeedPercent 150 'Stopping leaves remembered preference intact'
Set-WidgetMusicTravelSpeedPercent $false
Assert-Equal $script:musicTravelSpeedPercent 100 'Boolean input never becomes zero'
Assert-Equal $script:saves 0 'Helpers and synchronization never save implicitly'
Initialize-WidgetMusicSettings @{musicTravelSpeedPercent=''}
Assert-Equal $script:musicTravelSpeedPercent 100 'Empty saved string is invalid rather than numeric zero'
# Exercise the real serialization function, not a test-only settings shape.
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $appDir 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Widget source must parse'}
$save=$ast.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq 'Save-Settings'},$true)
. ([scriptblock]::Create($save.Extent.Text))
function Write-WidgetJson($file,$data){$script:roundtrip=$data|ConvertTo-Json -Depth 5|ConvertFrom-Json}
foreach($value in @(0,100,200)){
  Set-WidgetMusicTravelSpeedPercent $value
  Save-Settings
  Assert-Equal $script:roundtrip.musicTravelSpeedPercent $value 'Production Save serializes music preference'
  Set-WidgetMusicTravelSpeedPercent 50
  Initialize-WidgetMusicSettings $script:roundtrip
  Assert-Equal $script:musicTravelSpeedPercent $value 'Serialized preference restores including zero'
}
Write-Output 'music-speed-settings: PASS'
