param([string]$TestRoot=$PSScriptRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$appDir=Split-Path $TestRoot -Parent
. (Join-Path $appDir 'runtime\host-ready.ps1')
function Assert-Equal($actual,$expected,[string]$message){if($actual-ne $expected){throw "$message : expected '$expected', got '$actual'"}}
$state=New-WidgetReadinessState
$script:probeReady=$false;$script:probes=0
$probe={param($h)$script:probes++;return $script:probeReady}
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]1) 0 $probe) $false 'Loading screen stays hidden'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]1) 500 $probe) $false 'Probe is throttled'
Assert-Equal $script:probes 1 'No rapid accessibility polling'
$script:probeReady=$true
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]1) 1000 $probe) $false 'First interface sample stays hidden'
$script:probeReady=$false
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]1) 2000 $probe) $false 'Loading recurrence clears the candidate'
$script:probeReady=$true
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]1) 3000 $probe) $false 'New candidate needs confirmation'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]1) 4000 $probe) $true 'Loaded interface becomes visible'
$script:probeReady=$false
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]1) 5000 $probe) $true 'Later content refreshes do not hide the widget'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]2) 5000 $probe) $false 'New window waits for its own interface'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]::Zero) 6000 $probe) $false 'Missing host is not ready'
# Deterministic fallback timing; no accessibility-provider timing is involved.
$state=New-WidgetReadinessState
$script:fallbackProbes=0
$neverReady={param($h)$script:fallbackProbes++;return $false}
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]10) 0 $neverReady $true $true) $false 'Visible host starts its wait'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]10) 1999 $neverReady $true $true) $false 'Fallback does not show before two seconds'
$beforeFallbackProbes=$script:fallbackProbes
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]10) 2000 $neverReady $true $true) $true 'Visible host shows at two seconds without accessibility'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]10) 2100 $neverReady $false $false) $true 'Readiness remains latched after first display'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]10) 2200 $neverReady $true $true) $true 'Already-ready host restores immediately'
Assert-Equal $script:fallbackProbes $beforeFallbackProbes 'Fallback and latched readiness do not start new accessibility probes'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]11) 2200 $neverReady $true $true) $false 'Host replacement resets latched readiness'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]11) 4000 $neverReady $false $true) $false 'Hidden or minimized host interrupts waiting'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]11) 5000 $neverReady $true $true) $false 'Restored host starts a fresh wait'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]11) 6999 $neverReady $true $true) $false 'Restored host still needs full two seconds'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]11) 7000 $neverReady $true $true) $true 'Restored host reaches its new deadline'
$state=New-WidgetReadinessState
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]12) 0 $neverReady $true $true) $false 'New visible candidate starts'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]12) 1500 $neverReady $true $false) $false 'Invalid frame interrupts waiting'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]12) 2000 $neverReady $true $true) $false 'Valid frame restarts waiting'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]12) 3999 $neverReady $true $true) $false 'Invalid-frame interval does not count'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]::Zero) 4000 $neverReady $true $true) $false 'No host never qualifies for fallback'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]12) 5000 $neverReady $true $true) $false 'Missing host clears prior deadline'
$state=New-WidgetReadinessState
$alwaysReady={param($h)return $true}
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]13) 0 $alwaysReady $true $true) $false 'Accessibility keeps stable-sample requirement'
Assert-Equal (Test-WidgetHostReady $state ([IntPtr]13) 1000 $alwaysReady $true $true) $true 'Accessibility can show before fallback deadline'
# Exercise real accessibility controls in our own isolated WPF window.
$window=New-Object Windows.Window;$window.ShowActivated=$false;$window.ShowInTaskbar=$false;$window.Width=300;$window.Height=200
$panel=New-Object Windows.Controls.StackPanel;$window.Content=$panel
$loading=New-Object Windows.Controls.ProgressBar;$loading.IsIndeterminate=$true;$loading.Height=20;$panel.Children.Add($loading)|Out-Null
try{
  $window.Show();$window.UpdateLayout()
  $handle=([Windows.Interop.WindowInteropHelper]::new($window)).Handle
  function Get-ProbedInterface([bool]$Expected){
    $deadline=[DateTime]::UtcNow.AddSeconds(3)
    do{
      $result=[GptWidgetHostReadiness]::Poll($handle)
      $frame=New-Object Windows.Threading.DispatcherFrame
      $timer=New-Object Windows.Threading.DispatcherTimer;$timer.Interval=[TimeSpan]::FromMilliseconds(30)
      $timer.Add_Tick({param($sender,$event)$sender.Stop();$frame.Continue=$false})
      $timer.Start();[Windows.Threading.Dispatcher]::PushFrame($frame)
      if($result-eq $Expected){return $result}
    }while([DateTime]::UtcNow-lt $deadline)
    return $result
  }
  Assert-Equal (Get-ProbedInterface $false) $false 'Progress-only window is not loaded'
  $input=New-Object Windows.Controls.TextBox;$input.Height=40;$panel.Children.Add($input)|Out-Null;$window.UpdateLayout()
  Assert-Equal (Get-ProbedInterface $true) $true 'Visible input confirms usable UI'
  $panel.Children.Remove($input)
  $button=New-Object Windows.Controls.Button;$button.Content='New thread';$button.IsEnabled=$false;$panel.Children.Add($button)|Out-Null;$window.UpdateLayout()
  Assert-Equal (Get-ProbedInterface $false) $false 'Disabled navigation is not usable'
  $button.IsEnabled=$true;$window.UpdateLayout()
  Assert-Equal (Get-ProbedInterface $true) $true 'Enabled navigation confirms usable UI'
  Write-Output 'PASS: startup waits for usable UI, resets for new hosts, and latches after loading'
}finally{$window.Close()}
