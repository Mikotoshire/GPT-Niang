param([switch]$WidgetOnly,[switch]$SettingsMenuOnly,[string]$PreviewDirectory,[switch]$AllowLimitedCompositor)
$ErrorActionPreference='Stop'
if($SettingsMenuOnly){
  $source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'settings-menu.test.ps1'),[Text.Encoding]::UTF8)
  & ([ScriptBlock]::Create($source)) -TestRoot $PSScriptRoot
  return
}
if($WidgetOnly){
  $source=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'widget.test.ps1'),[Text.Encoding]::UTF8)
  & ([ScriptBlock]::Create($source)) -TestRoot $PSScriptRoot -PreviewDirectory $PreviewDirectory
  return
}
$powerShell=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'frame-diagnostics.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Frame diagnostics regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'ground-friction.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Ground friction regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'energy-duration.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Energy duration regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'rebound-steps.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Rebound steps regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'compression-curve.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Compression curve regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'energy-controls.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Energy controls regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'collision-energy.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Collision energy regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'elastic-impact.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Elastic impact regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'tap-compression.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Tap compression regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'animation-speed.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Animation speed regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'landing-easing.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Landing easing regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'landing-cycle.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Landing cycle regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'impact-squish.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Impact squish regression failed.'}
& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'quota-cache.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Quota cache regression failed.'}
& $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'plugin-registration.test.ps1')
if($LASTEXITCODE-ne 0){throw 'Plugin registration regression failed.'}
foreach($name in @('character-gravity-layout.test.ps1','gravity-motion-owners.test.ps1','transient-gravity.test.ps1','passive-router.test.ps1','native-movement.test.ps1','drag-motion.test.ps1','subpixel-motion.test.ps1','async-presence.test.ps1','physics-defaults.test.ps1','horizontal-impact.test.ps1','floor-contact.test.ps1','floor-support-recovery.test.ps1','managed-frames.test.ps1','motion-tuning.test.ps1','gravity.test.ps1','gravity-wpf.test.ps1','fork-policy.test.ps1','installation.test.ps1','update.test.ps1','lifecycle.test.ps1','entrypoint.test.ps1','quote-layout.test.ps1','size.test.ps1','display.test.ps1','desktop-mode.test.ps1','drag-sizing.test.ps1','settings-menu.test.ps1','host-ready.test.ps1','host-identity.test.ps1','peer-layer.test.ps1','host-occlusion.test.ps1','occlusion-move-cost.test.ps1','occlusion-reminder.test.ps1','music-audio.test.ps1','music-rhythm.test.ps1','music-beat-clock.test.ps1','music-envelope.test.ps1','music-color.test.ps1','music-interaction.test.ps1','music-throw-release.test.ps1','music-layer.test.ps1','music-background-lifecycle.test.ps1','music-drag-delivery.test.ps1','music-follow.test.ps1','music-motion.test.ps1','music-travel-speed.test.ps1','music-speed-settings.test.ps1','music-frame-clock.test.ps1','music-position-dispatch.test.ps1','music-tempo-recheck.test.ps1','music-startup-response.test.ps1','music-player-capture.test.ps1','music-native-position.test.ps1','music-quiet-startup.test.ps1','music-first-motion.test.ps1','music-visual.test.ps1','quota-selection.test.ps1','characters.test.ps1','character-startup.test.ps1','character-rendering.test.ps1','sound-player.test.ps1','audio-import.test.ps1','menu-icon.test.ps1','auto-quotes.test.ps1','completion-notifications.test.ps1','completion-current-position.test.ps1','completion-layer-restore.test.ps1','completion-pipe.test.ps1','independent-size.test.ps1','drag-facing.test.ps1','drag-horizontal.test.ps1','drag-vertical.test.ps1','fixed-relative-position.test.ps1','menu-dismiss.test.ps1','placement-settings.test.ps1')){
  if($name-eq 'settings-menu.test.ps1'){& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File $PSCommandPath -SettingsMenuOnly}
  elseif($name-eq 'managed-frames.test.ps1'){
    $frameArgs=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',(Join-Path $PSScriptRoot $name))
    if($AllowLimitedCompositor){$frameArgs+='-AllowLimitedCompositor'}
    & $powerShell @frameArgs
  }
  else {& $powerShell -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $name)}
  if($LASTEXITCODE-ne 0){throw "$name failed ($LASTEXITCODE)"}
}
$widgetTestArgs=@('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',$PSCommandPath,'-WidgetOnly')
if($PreviewDirectory){$widgetTestArgs+=@('-PreviewDirectory',$PreviewDirectory)}
& $powerShell @widgetTestArgs
if($LASTEXITCODE-ne 0){throw "Widget tests failed ($LASTEXITCODE)"}
