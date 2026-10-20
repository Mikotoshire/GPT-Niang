param([string]$AppDir=(Split-Path $PSScriptRoot -Parent))
# AI-generated regression; insufficiently validated. See AI-NOTICE.md.
$ErrorActionPreference='Stop'
. (Join-Path $AppDir 'runtime/gravity.ps1')
function Assert($value,$message){if(!$value){throw $message}}
$a=[GptDragMotion]::new(100,100);$b=[GptDragMotion]::new(100,100)
foreach($m in @($a,$b)){$m.SetTarget(200,300)}
foreach($i in 1..12){$a.Advance(1.0/120,0,0,1000,1000)}
foreach($i in 1..6){$b.Advance(1.0/60,0,0,1000,1000)}
Assert ([Math]::Abs($a.X-$b.X)-lt .001 -and [Math]::Abs($a.Y-$b.Y)-lt .001) 'Drag smoothing depends on time rather than callback count'
Assert ([Math]::Abs($a.X-200)-lt .1 -and [Math]::Abs($a.Y-300)-lt .1) 'A stopped cursor settles rapidly without persistent lag'
$a.SetTarget(2000,-100);$a.Advance(.02,0,0,500,500)
Assert ($a.X-le 500 -and $a.Y-ge 0) 'Targets stay inside native placement bounds'
$a.Advance(0,0,0,50,50)
Assert ($a.X-le 50 -and $a.Y-le 50) 'A shrinking frame immediately clamps the current pose'
$a.SetTarget([double]::NaN,[double]::PositiveInfinity);$a.Advance(.1,0,0,50,50)
Assert (![double]::IsNaN($a.X) -and ![double]::IsNaN($a.Y)) 'Invalid targets cannot poison the visual pose'
'PASS: bounded time-based drag tracking, rapid settling, resize recovery and invalid-input isolation'
