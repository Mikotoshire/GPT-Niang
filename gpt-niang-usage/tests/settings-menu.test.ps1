param([string]$TestRoot=$PSScriptRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$appDir=Split-Path $TestRoot -Parent
$library=Join-Path $appDir 'runtime/vendor/aether/Aether.Physics2D.dll'
Add-Type -Path $library
Add-Type -Path (Join-Path $appDir 'runtime/gravity-model.cs') -ReferencedAssemblies $library
$script:gravity=[GptGravityModel]::new()
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime\learning.ps1'),[Text.Encoding]::UTF8)))
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime\ui-settings.ps1'),[Text.Encoding]::UTF8)))
. (Join-Path $appDir 'runtime\quotes.ps1')
. (Join-Path $appDir 'runtime\audio.ps1')
Initialize-WidgetAutoQuoteSettings $null
. (Join-Path $appDir 'runtime\completion-notifications.ps1')
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime/music.ps1'),[Text.Encoding]::UTF8)))
Initialize-WidgetMusicSettings $null
Initialize-CompletionNotificationState $null
function Assert-Equal($actual,$expected,[string]$message){if($actual-ne $expected){throw "$message : expected '$expected', got '$actual'"}}
$script:settingsSaveCount=0
function Save-Settings {$script:settingsSaveCount++}
function Set-WidgetFollowHost([bool]$Follow){$script:followHost=$Follow}
$productionMenuBounds=${function:Set-WidgetMenuBounds}
function Set-WidgetMenuBounds {}
function Position-WidgetMenuToHost {}
function Set-Appearance {}
function Set-Facing {}
function Set-WidgetPhysicsTuning {$script:gravity.SetCompressionCurve($script:compressionCurve);Save-Settings}
function Restart-SceneTtl {}
$widgetSource=[IO.File]::ReadAllText((Join-Path $appDir 'widget.ps1'),[Text.Encoding]::UTF8)
$tokens=$null;$errors=$null
$widgetAst=[Management.Automation.Language.Parser]::ParseInput($widgetSource,[ref]$tokens,[ref]$errors)
foreach($name in @('Set-AnimatedValue','Set-BubbleState')){
  $definition=$widgetAst.Find({param($n)$n-is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name-eq $name},$true)
  . ([ScriptBlock]::Create($definition.Extent.Text))
}
$poseWindow=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{}
foreach($name in @('Bubble','Tail','TailNear','SceneText')){$script:ui[$name]=$poseWindow.FindName($name)}
function Set-WidgetAudioVolume {}
function Set-WidgetGravityMode([bool]$Enabled){$script:gravityEnabled=$Enabled;Save-Settings}
function Stop-WidgetAudio {}
. (Join-Path $appDir 'runtime\supervisor-task.ps1')
. (Join-Path $appDir 'runtime\update-common.ps1')
. ([ScriptBlock]::Create([IO.File]::ReadAllText((Join-Path $appDir 'runtime\update-ui.ps1'),[Text.Encoding]::UTF8)))
$script:dataDir=Join-Path ([IO.Path]::GetTempPath()) ('gpt-niang-menu-'+[Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $script:dataDir
$script:config=@{version='1.3.2'}
Initialize-WidgetUpdater
$script:window=New-Object Windows.Window
$script:collapsed=$true;$script:bubbleMode='quota';$script:followHost=$true;$script:desktopTopmost=$true
$script:scale=1.0;$script:bubbleScale=1.0;$script:soundOn=$true;$script:soundVolume=0.9;$script:bubbleTapAdvance=$false;$script:hideMenu=$false
$script:mirrorCharacter=$false;$script:gravityStrength=1.6;$script:elasticStrength=1.0;$script:squishStrength=1.0;$script:animationSpeed=1.0;$script:tapCompression=1.0;$script:energyConversion=42.5;$script:reboundStrength=50;$script:compressionCurve=1.6;$script:groundFriction=1.0
$script:colorMode='mixed';$script:colorChance=0.5;$script:colorTextChance=3;$script:colorPaused=$false
try{
  $script:galleryOpenCount=0
  function Open-WidgetCharacterGallery {$script:galleryOpenCount++}
  Initialize-WidgetSettingsMenu
  # AI-generated UI regression coverage; insufficiently validated.
  Assert-Equal ($script:context.Items.Contains($script:settingsMenuUi.MusicEnabled)) $true 'Music toggle stays top level'
  Assert-Equal ($script:context.Items.Contains($script:settingsMenuUi.MusicSettings)) $true 'Music settings are adjacent to the direct toggle'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.Minimum 0 'Music travel can be stopped'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.Maximum 200 'Music travel reaches double speed'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.TickFrequency 10 'Music travel has ten-percent steps'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.SmallChange 10 'Keyboard uses ten-percent steps'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.LargeChange 10 'Page keys use ten-percent steps'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.IsSnapToTickEnabled $true 'Music slider snaps to steps'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.IsEnabled $true 'Music travel can be configured while disabled'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.Value 100 'Music travel starts at accepted default'
  $beforeMusicSave=$script:settingsSaveCount
  $script:settingsMenuUi.MusicTravelSpeed.Value=154
  Assert-Equal $script:musicTravelSpeedPercent 150 'Intermediate music value normalizes to nearest step'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.Value 150 'Music slider reflects normalized value'
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeedText.Text '150%' 'Music travel displays an integer percentage'
  Assert-Equal $script:settingsSaveCount ($beforeMusicSave+1) 'One slider change saves exactly once'
  for($musicLevel=0;$musicLevel-le 200;$musicLevel+=10){
    $beforeMusicSave=$script:settingsSaveCount
    $script:settingsMenuUi.MusicTravelSpeed.Value=$musicLevel
    Assert-Equal $script:musicTravelSpeedPercent $musicLevel 'All twenty-one music levels are reachable'
    Assert-Equal $script:settingsMenuUi.MusicTravelSpeedText.Text ($musicLevel.ToString()+'%') 'Each music level displays an integer'
    Assert-Equal $script:settingsSaveCount ($beforeMusicSave+1) 'Each music level change saves once'
  }
  Assert-Equal ($null-eq $script:widgetMusic) $true 'Music slider does not implicitly enable capture'
  $beforeMusicSave=$script:settingsSaveCount
  Set-WidgetMusicTravelSpeedPercent 0
  Update-WidgetSettingsMenu
  Update-WidgetSettingsMenu
  Assert-Equal $script:settingsMenuUi.MusicTravelSpeed.Value 0 'Menu sync preserves zero'
  Assert-Equal $script:settingsSaveCount $beforeMusicSave 'Menu sync never saves music slider changes'
  $script:settingsMenuUi.MusicEnabled.IsChecked=$false
  $script:settingsMenuUi.MusicEnabled.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:musicTravelSpeedPercent 0 'Disabling music retains speed preference'
  Assert-Equal ($script:context.Items.Contains($script:settingsMenuUi.AINotice)) $true 'AI notice appears in the main settings menu'
  Assert-Equal $script:settingsMenuUi.AINotice.IsEnabled $false 'AI notice cannot trigger an action'
  Assert-Equal ($script:settingsMenuUi.AINotice.ToolTip.Contains('均由 AI 生成')) $true 'AI scope and validation warning is available in the tooltip'
  Assert-Equal ($script:context.Items.Contains($script:settingsMenuUi.Gravity)) $true 'Gravity mode is a top-level setting'
  Assert-Equal ($script:context.Items.Contains($script:settingsMenuUi.Appearance)) $true 'Appearance remains at the same menu level'
  $script:settingsMenuUi.Gravity.IsChecked=$true
  $script:settingsMenuUi.Gravity.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:gravityEnabled $true 'Gravity toggle enables the controller'
  $script:settingsMenuUi.Gravity.IsChecked=$false
  $script:settingsMenuUi.Gravity.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:gravityEnabled $false 'Gravity toggle disables the controller'
  $script:settingsMenuUi.Mirror.IsChecked=$true
  $script:settingsMenuUi.Mirror.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:mirrorCharacter $true 'Manual mirror is independently enabled'
  $script:settingsMenuUi.GravityStrength.Value=2.2
  $script:settingsMenuUi.ElasticStrength.Value=1.5
  Assert-Equal $script:gravityStrength 2.2 'Gravity slider updates local preference'
  Assert-Equal $script:settingsMenuUi.GroundFriction.Minimum 0 'Friction can be disabled'
  Assert-Equal $script:settingsMenuUi.GroundFriction.Maximum 3 'Friction upper bound'
  $script:settingsMenuUi.GroundFriction.Value=2.3
  Assert-Equal $script:groundFriction 2.3 'Friction slider updates the preference'
  Assert-Equal $script:settingsMenuUi.GroundFrictionText.Text '2.3×' 'Friction slider updates its label'
  Assert-Equal $script:elasticStrength 1.5 'Elasticity slider updates local preference'
  Assert-Equal $script:settingsMenuUi.SquishStrength.Minimum 0 'Squish slider allows zero'
  Assert-Equal $script:settingsMenuUi.SquishStrength.Maximum 3 'Squish slider has a safe upper bound'
  $script:settingsMenuUi.SquishStrength.Value=2.25
  Assert-Equal $script:squishStrength 2.25 'Squish slider updates the independent setting'
  Assert-Equal $script:settingsMenuUi.SquishStrengthText.Text '2.25×' 'Squish value label updates'
  Assert-Equal $script:elasticStrength 1.5 'Squish slider does not alter bounce energy'
  Assert-Equal $script:settingsMenuUi.AnimationSpeed.Minimum 0.25 'Animation speed lower bound'
  Assert-Equal $script:settingsMenuUi.AnimationSpeed.Maximum 3 'Animation speed upper bound'
  $script:settingsMenuUi.AnimationSpeed.Value=0.75
  Assert-Equal $script:animationSpeed 0.75 'Animation slider updates preference'
  Assert-Equal $script:settingsMenuUi.AnimationSpeedText.Text '0.75×' 'Animation label updates'
  Assert-Equal $script:elasticStrength 1.5 'Animation slider leaves energy unchanged'
  Assert-Equal $script:settingsMenuUi.TapCompression.Minimum 0 'Tap compression allows zero'
  Assert-Equal $script:settingsMenuUi.TapCompression.Maximum 3 'Tap compression upper bound'
  $script:settingsMenuUi.TapCompression.Value=2.25
  Assert-Equal $script:tapCompression 2.25 'Tap compression slider updates preference'
  Assert-Equal $script:settingsMenuUi.TapCompressionText.Text '2.25×' 'Tap compression label updates'
  Assert-Equal $script:elasticStrength 1.5 'Tap compression leaves energy unchanged'
  Assert-Equal $script:squishStrength 2.25 'Tap compression leaves landing squish unchanged'
  Assert-Equal $script:settingsMenuUi.EnergyConversion.Minimum 0 'Conversion slider allows zero'
  Assert-Equal $script:settingsMenuUi.ElasticStrength.Parent.Children[0].Children[0].Text '起跳能量' 'Old shared slider has an explicit launch-only label'
  Assert-Equal $script:settingsMenuUi.EnergyConversion.IsSnapToTickEnabled $true 'Rebound thumb snaps to integer levels'
  Assert-Equal $script:settingsMenuUi.EnergyConversion.Maximum 100 'Rebound scale reaches 100 percent'
  Assert-Equal (($script:settingsMenuUi.EnergyConversion.Maximum-$script:settingsMenuUi.EnergyConversion.Minimum)/$script:settingsMenuUi.EnergyConversion.TickFrequency) 20 'Twenty equal intervals including a zero endpoint'
  Assert-Equal $script:settingsMenuUi.EnergyConversion.TickFrequency 5 'Five-percent step'
  Assert-Equal $script:settingsMenuUi.EnergyConversion.SmallChange 5 'Keyboard also uses five-percent steps'
  Assert-Equal $script:settingsMenuUi.EnergyConversion.Parent.Children[0].Children[0].Text '反弹程度' 'Renamed visible caption'
  $script:settingsMenuUi.EnergyConversion.Value=63
  Assert-Equal $script:settingsMenuUi.EnergyConversion.Value 65 'Intermediate pointer values are snapped too'
  for($i=0;$i-le 20;$i++){
    $step=$i*5;$script:settingsMenuUi.EnergyConversion.Value=$step
    Assert-Equal $script:reboundStrength $step 'Every five-percent level is reachable'
    Assert-Equal $script:settingsMenuUi.EnergyConversionText.Text ($step.ToString()+'%') 'Each level has an integer label'
  }
  $script:settingsMenuUi.EnergyConversion.Value=65
  Assert-Equal $script:reboundStrength 65 'Rebound updates integer preference'
  Assert-Equal $script:energyConversion 55.25 'Rebound maps to retained energy'
  Assert-Equal $script:settingsMenuUi.EnergyConversionText.Text '65%' 'Conversion displays a percentage'
  Assert-Equal $script:elasticStrength 1.5 'Conversion leaves manual launch energy unchanged'
  Assert-Equal $script:settingsMenuUi.CompressionCurve.Minimum 1.5 'Curve minimum preserves deceleration'
  Assert-Equal $script:settingsMenuUi.CompressionCurve.Maximum 3 'Curve upper bound'
  Assert-Equal $script:settingsMenuUi.CompressionCurveLine.Points.Count 25 'Curve preview samples the actual model'
  $beforeCurve=$script:settingsMenuUi.CompressionCurveLine.Points[6].Y
  $script:settingsMenuUi.CompressionCurve.Value=3
  Assert-Equal $script:compressionCurve 3 'Curve slider updates preference'
  Assert-Equal $script:settingsMenuUi.CompressionCurveText.Text '3.00' 'Curve label updates'
  Assert-Equal ($script:settingsMenuUi.CompressionCurveLine.Points[6].Y-lt $beforeCurve) $true 'Preview updates with stronger initial compression'
  Assert-Equal $script:energyConversion 55.25 'Curve leaves stored energy setting unchanged'
  $script:settingsMenuUi.NaturalElasticity.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:compressionCurve 1.5 'Natural preset selects a near-sinusoidal compression'
  Assert-Equal $script:reboundStrength 75 'Natural preset uses the nearest five-percent reference rebound'
  Assert-Equal $script:energyConversion 63.75 'Preset keeps legacy retained-energy preference consistent'
  Assert-Equal $script:squishStrength 1 'Natural preset restores moderate visible deformation'
  Assert-Equal $script:animationSpeed 1 'Natural preset restores readable base timing'
  Assert-Equal $script:settingsMenuUi.CompressionCurve.Value 1.5 'Preset refreshes curve slider'
  Assert-Equal $script:settingsMenuUi.EnergyConversionText.Text '75%' 'Preset refreshes rebound label'
  Assert-Equal $script:elasticStrength 1.5 'Preset preserves manual launch energy'
  Assert-Equal $script:gravityStrength 2.2 'Preset preserves user gravity'
  Assert-Equal $script:groundFriction 2.3 'Natural elasticity preset preserves independent ground friction'
  Assert-Equal $script:tapCompression 2.25 'Preset preserves manual press shape'
  Assert-Equal $script:settingsMenuUi.AudioBuiltin.IsCheckable $true 'Builtin audio is a radio choice'
  Assert-Equal $script:settingsMenuUi.AudioCustom.IsCheckable $true 'Custom audio is a radio choice'
  $audioHandler=${function:Invoke-WidgetAudioAction};$script:audioCommands=@()
  function Invoke-WidgetAudioAction([string]$Action,[string]$Slot){$script:audioCommands+=@{action=$Action;slot=$Slot}}
  try{
    foreach($slot in @('press','release')){
      $items=@($script:settingsMenuUi['AudioSlot_'+$slot].Items)
      foreach($action in @(@{title='选择WAV';name='import'},@{title='设为无声';name='clear'},@{title='试听';name='preview'})){
        $item=@($items|Where-Object{$_.Header-is [string] -and $_.Header.StartsWith($action.title)})[0]
        $item.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
        $record=$script:audioCommands[-1]
        Assert-Equal $record.slot $slot 'Audio menu retains the correct independent phase'
        Assert-Equal $record.action $action.name 'Audio menu dispatches the intended operation'
      }
    }
  }finally{${function:Invoke-WidgetAudioAction}=$audioHandler}
  $script:audioDialogOpen=$true
  Assert-Equal (Test-WidgetUpdateEditor) $true 'Audio dialogs defer reminder and update activity'
  $script:audioDialogOpen=$false
  $script:settingsMenuUi.Character.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:galleryOpenCount 1 'Main menu opens character selection'
  $script:characterGallery=[pscustomobject]@{IsVisible=$true}
  Assert-Equal (Test-WidgetUpdateEditor) $true 'Open character gallery defers updater installation'
  $script:characterGallery=$null
  Assert-Equal (Test-WidgetUpdateEditor) $false 'Closed gallery returns to updater idle'
  Assert-Equal $script:settingsMenuUi.MusicEnabled.IsChecked $false 'Music capture starts only after an explicit enable'
  Assert-Equal $script:settingsMenuUi.MusicEnabled.Items.Count 0 'Music is one direct toggle without a second mode'
  Assert-Equal ($null-eq $script:settingsMenuUi.MusicColor) $true 'Music color has no separate toggle'
  Assert-Equal $script:settingsMenuUi.Learning.IsCheckable $true 'Learning is a direct checkable action'
  Assert-Equal $script:settingsMenuUi.Learning.IsChecked $false 'Learning defaults OFF without a worker'
  Assert-Equal $script:settingsMenuUi.LearningStatus.IsEnabled $false 'Learning status is passive'
  $expected=@('查看额度','刷新额度','换一句台词','更换形象','外观设置','重力与弹性','声音与点击','编辑我的语录','音乐律动','音乐设置','自动语录','回答结束提醒','显示与位置','余量学习（本轮额度）','已关闭（后台未就绪）','更新','退出 GPT 娘')
  $actual=@($script:context.Items|Where-Object{$_.Header-is [string] -or $_-eq $script:settingsMenuUi.Learning}|ForEach-Object{if($_-eq $script:settingsMenuUi.Learning){$_.Header.Children[0].Text}else{$_.Header}})
  Assert-Equal ($actual-join '|') ($expected-join '|') 'Menu entries and removed title block'
  Assert-Equal $script:settingsMenuUi.Completion.IsChecked $false 'Reply reminders default off'
  Assert-Equal $script:settingsMenuUi.Completion.StaysOpenOnClick $true 'Reply reminder toggle retains menu interaction'
  Assert-Equal $script:settingsMenuUi.AutoQuoteEnabled.IsChecked $false 'Automatic quotes default off'
  Assert-Equal (@($script:settingsMenuUi.AutoQuoteIntervals|Where-Object{$_.IsChecked}).Count) 1 'One interval is selected'
  Assert-Equal (@($script:settingsMenuUi.AutoQuoteIntervals|Where-Object{$_.IsChecked})[0].Tag) 300 'Default interval is five minutes'
  foreach($choice in $script:settingsMenuUi.AutoQuoteIntervals){
    $choice.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
    Assert-Equal $script:autoQuoteIntervalSeconds ([int]$choice.Tag) 'Interval row applies its own value'
    Assert-Equal $script:autoQuoteEnabled $false 'Choosing an interval does not enable quotes'
    Assert-Equal (@($script:settingsMenuUi.AutoQuoteIntervals|Where-Object{$_.IsChecked}).Count) 1 'Interval rows remain mutually exclusive'
  }
  $script:settingsMenuUi.AutoQuoteEnabled.IsChecked=$true
  $script:settingsMenuUi.AutoQuoteEnabled.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:autoQuoteEnabled $true 'Menu enables automatic quotes'
  $script:settingsMenuUi.AutoQuoteEnabled.IsChecked=$false
  $script:settingsMenuUi.AutoQuoteEnabled.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:autoQuoteEnabled $false 'Menu disables automatic quotes'
  Assert-Equal $script:autoQuoteIntervalSeconds 900 'Disabling remembers the selected interval'
  Assert-Equal $script:settingsMenuUi.AutoQuoteEnabled.StaysOpenOnClick $true 'Toggle retains the menu'
  Assert-Equal $script:settingsMenuUi.UpdateVersion.Header '当前版本：1.3.2' 'Update menu shows actual version'
  Assert-Equal $script:settingsMenuUi.AutoUpdate.IsChecked $true 'Automatic updates are on initially'
  $script:settingsMenuUi.AutoUpdate.IsChecked=$false
  $script:settingsMenuUi.AutoUpdate.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal (Read-WidgetUpdateJson (Join-Path $script:dataDir 'update-preferences.json')).automatic $false 'Menu toggle persists separately'
  Assert-Equal $script:settingsMenuUi.Topmost.Visibility Collapsed 'Window mode hides topmost'
  Assert-Equal $script:settingsMenuUi.TopmostDivider.Visibility Collapsed 'Window mode hides its divider'
  foreach($name in @('Follow','Desktop','Topmost','Hide','Sound','Tap')){
    Assert-Equal $script:settingsMenuUi[$name].StaysOpenOnClick $true 'All settings retain menu interaction'
    Assert-Equal $script:settingsMenuUi[$name].Style $script:settingsMenuResources['SettingsItem'] 'Rows share the same style'
  }
  $script:settingsMenuUi.Desktop.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:followHost $false 'Desktop row selects desktop mode'
  Assert-Equal $script:settingsMenuUi.Follow.IsChecked $false 'Modes are mutually exclusive'
  Assert-Equal $script:settingsMenuUi.Desktop.IsChecked $true 'Selected desktop indicator'
  Assert-Equal $script:settingsMenuUi.Topmost.Visibility Visible 'Desktop mode exposes topmost'
  Assert-Equal $script:settingsMenuUi.Topmost.IsChecked $true 'Remembered desktop preference'
  $script:settingsMenuUi.Follow.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:followHost $true 'Window row selects window mode'
  Assert-Equal $script:settingsMenuUi.Desktop.IsChecked $false 'Desktop indicator clears'
  Assert-Equal $script:settingsMenuUi.Topmost.Visibility Collapsed 'Topmost disappears immediately'
  Assert-Equal $script:desktopTopmost $true 'Switching modes retains desktop preference'
  $script:settingsMenuUi.SizeButtons[2].RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
  Assert-Equal $script:scale 1.4 'Preset updates actual size'
  Assert-Equal $script:sizeSlider.Value 1.4 'Preset and slider stay synchronized'
  $script:bubbleSizeSlider.Value=1.2
  Assert-Equal $script:bubbleScale 1.2 'Bubble slider changes bubble size'
  Assert-Equal $script:scale 1.4 'Bubble slider preserves character size'
  $script:sizeSlider.Value=0.6
  Assert-Equal $script:scale 0.6 'Character slider changes character size'
  Assert-Equal $script:bubbleScale 1.2 'Character slider preserves bubble size'
  Update-WidgetSettingsMenu
  Assert-Equal $script:settingsMenuUi.SizeText.Text '60%' 'Character label follows character size'
  Assert-Equal $script:settingsMenuUi.BubbleSizeText.Text '120%' 'Bubble label follows bubble size'
  $script:settingsMenuUi.Appearance.ApplyTemplate()|Out-Null
  $appearancePopup=$script:settingsMenuUi.Appearance.Template.FindName('PART_Popup',$script:settingsMenuUi.Appearance)
  if(!$appearancePopup.Child){throw 'The actual appearance popup template must exist for preview testing'}
  foreach($slider in @($script:sizeSlider,$script:bubbleSizeSlider)){
    $started=[Windows.Controls.Primitives.DragStartedEventArgs]::new(0,0)
    $started.RoutedEvent=[Windows.Controls.Primitives.Thumb]::DragStartedEvent
    $script:collapsed=$true;Set-BubbleState
    $slider.RaiseEvent($started)
    $expectedBubble=if($slider-eq $script:bubbleSizeSlider){[Windows.Visibility]::Visible}else{[Windows.Visibility]::Hidden}
    foreach($name in @('Bubble','Tail','TailNear')){Assert-Equal $script:ui[$name].Visibility $expectedBubble 'Bubble-size drag temporarily shows the actual bubble and tails'}
    Assert-Equal $script:collapsed $true 'Preview must not change the persisted collapsed preference'
    Assert-Equal $script:context.Opacity 0.08 'Dragging fades the main settings menu'
    Assert-Equal $appearancePopup.Child.Opacity 0.08 'Dragging also fades the separate submenu popup'
    Assert-Equal $script:context.IsHitTestVisible $true 'Transparent settings retain mouse interaction'
    $completed=[Windows.Controls.Primitives.DragCompletedEventArgs]::new(0,0,$false)
    $completed.RoutedEvent=[Windows.Controls.Primitives.Thumb]::DragCompletedEvent
    $slider.RaiseEvent($completed)
    Assert-Equal $script:ui.Bubble.Visibility Hidden 'Release restores the originally closed bubble'
    Assert-Equal $script:context.Opacity 1 'Releasing restores the main menu'
    Assert-Equal $appearancePopup.Child.Opacity 1 'Releasing restores the submenu'
    $slider.RaiseEvent($started)
    $lost=[Windows.Input.MouseEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0)
    $lost.RoutedEvent=[Windows.UIElement]::LostMouseCaptureEvent
    $slider.RaiseEvent($lost)
    Assert-Equal $script:ui.Bubble.Visibility Hidden 'Lost capture restores the originally closed bubble'
    Assert-Equal $script:context.Opacity 1 'Lost capture also restores settings'
  }
  $pressed=[Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,[Windows.Input.MouseButton]::Left)
  $pressed.RoutedEvent=[Windows.UIElement]::PreviewMouseLeftButtonDownEvent
  $script:sizeSlider.RaiseEvent($pressed)
  Assert-Equal $script:context.Opacity 0.08 'Clicking the track previews size too'
  $released=[Windows.Input.MouseButtonEventArgs]::new([Windows.Input.Mouse]::PrimaryDevice,0,[Windows.Input.MouseButton]::Left)
  $released.RoutedEvent=[Windows.UIElement]::PreviewMouseLeftButtonUpEvent
  $script:sizeSlider.RaiseEvent($released)
  Assert-Equal $script:context.Opacity 1 'Track release restores settings'
  $script:sizeSlider.RaiseEvent($pressed)
  $script:context.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.ContextMenu]::ClosedEvent))
  Assert-Equal $script:context.Opacity 1 'Closing the menu cannot leave it transparent'
  Assert-Equal $appearancePopup.Child.Opacity 1 'Closing restores the independent popup too'
  $script:collapsed=$false;Set-BubbleState
  $script:bubbleSizeSlider.RaiseEvent($started)
  $script:bubbleSizeSlider.RaiseEvent($completed)
  Assert-Equal $script:ui.Bubble.Visibility Visible 'An originally open bubble remains open after preview'
  Assert-Equal $script:collapsed $false 'Open preference stays open'
  $script:collapsed=$true;Set-BubbleState
  $script:bubbleSizeSlider.RaiseEvent($pressed)
  Assert-Equal $script:ui.Bubble.Visibility Visible 'Clicking the bubble track previews a closed bubble'
  $script:context.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.ContextMenu]::ClosedEvent))
  Assert-Equal $script:ui.Bubble.Visibility Hidden 'Closing the menu restores a temporary bubble'
  $script:bubbleSizeSlider.RaiseEvent($started)
  $handle=([Windows.Interop.WindowInteropHelper]::new($script:window)).EnsureHandle()
  $inputSource=[Windows.Interop.HwndSource]::FromHwnd($handle)
  $escape=[Windows.Input.KeyEventArgs]::new([Windows.Input.Keyboard]::PrimaryDevice,$inputSource,0,[Windows.Input.Key]::Escape)
  $escape.RoutedEvent=[Windows.UIElement]::PreviewKeyDownEvent
  $script:bubbleSizeSlider.RaiseEvent($escape)
  Assert-Equal $script:context.Opacity 1 'Escape restores size-preview opacity'
  Assert-Equal $script:ui.Bubble.Visibility Hidden 'Escape restores the originally collapsed bubble'
  $script:bubbleSizeSlider.RaiseEvent($started)
  $script:bubbleSizeSlider.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.FrameworkElement]::UnloadedEvent))
  Assert-Equal $script:context.Opacity 1 'Unloading the slider restores size-preview opacity'
  Assert-Equal $script:settingsSizePreview $false 'Unloading does not leave an active preview'
  $script:settingsMenuUi.Sound.IsChecked=$false
  $script:settingsMenuUi.Sound.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:settingsMenuUi.Volume.IsEnabled $false 'Muted sound disables volume control'
  $script:followHost=$false;$script:menuTestFrameWidth=1000
  function Get-WidgetPlacementFrame {return [pscustomobject]@{Left=0;Top=0;Right=$script:menuTestFrameWidth;Bottom=1000}}
  function Get-WidgetPlacementDpi {return 1.0}
  & $productionMenuBounds
  $oldWidth=$script:context.Resources['SettingsSubmenuWidth'];$oldHeight=$script:context.Resources['SettingsSubmenuMaxHeight']
  & $productionMenuBounds
  Assert-Equal ([object]::ReferenceEquals($oldWidth,$script:context.Resources['SettingsSubmenuWidth'])) $true 'Unchanged menu bounds must not invalidate dynamic width resources'
  Assert-Equal ([object]::ReferenceEquals($oldHeight,$script:context.Resources['SettingsSubmenuMaxHeight'])) $true 'Unchanged menu bounds must not invalidate dynamic height resources'
  $script:menuTestFrameWidth=240
  & $productionMenuBounds
  Assert-Equal $script:context.Resources['SettingsSubmenuWidth'] 224 'Host resizing still updates menu bounds'
  $script:settingsMenuUi.Mirror.IsChecked=$false
  $script:settingsMenuUi.Mirror.RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.MenuItem]::ClickEvent))
  Assert-Equal $script:mirrorCharacter $false 'Manual mirror can be disabled without affecting the new features'
  foreach($key in @('GroundFriction','TapCompression','SquishStrength','EnergyConversion')){$script:settingsMenuUi[$key].Value=0}
  Update-WidgetSettingsMenu
  Assert-Equal $script:groundFriction 0 'Settings refresh retains explicit zero friction'
  Assert-Equal $script:tapCompression 0 'Settings refresh retains explicit zero tap compression'
  Assert-Equal $script:squishStrength 0 'Settings refresh retains explicit zero landing deformation'
  Assert-Equal $script:reboundStrength 0 'Settings refresh retains explicit zero rebound'
  Assert-Equal $script:energyConversion 0 'Zero rebound retains zero stored energy'
  Assert-Equal $script:completionNotificationsEnabled $false 'Refreshing physics settings preserves disabled completion notifications'
  Assert-Equal $script:autoQuoteEnabled $false 'Refreshing physics settings preserves disabled auto quotes'
  Assert-Equal $script:settingsMenuUi.MusicEnabled.IsChecked $false 'Refreshing physics settings does not start music capture'
  $script:releaseUpdatesDisabled=$true
  Update-WidgetSettingsMenu
  Assert-Equal $script:settingsMenuUi.AutoUpdate.IsEnabled $false 'Personal fork policy disables the automatic update control'
  Set-WidgetAutomaticUpdate $true
  Assert-Equal $script:autoUpdate $false 'Personal fork policy rejects enabling automatic upstream updates'
  Write-Output 'PASS: menu modes, physics, personal update policy, character/bubble sizing, audio and opt-in controls'
}finally{
  $poseWindow.Close()
  $script:window.Close()
  Assert-WidgetUpdateChildPath $script:dataDir ([IO.Path]::GetTempPath())
  Remove-Item -LiteralPath $script:dataDir -Recurse -Force
}
