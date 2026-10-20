function Open-QuoteEditor {
  if($script:quoteEditor -and $script:quoteEditor.IsVisible){$script:quoteEditor.Activate()|Out-Null;return}
  $editor=[Windows.Markup.XamlReader]::Parse(@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
 Title="GPT 娘 · 我的语录" Width="540" Height="480" MinWidth="440" MinHeight="340" ShowInTaskbar="False"
 FontFamily="Microsoft YaHei UI" FontSize="14" Background="#FAF8FD" WindowStartupLocation="CenterScreen">
 <Grid Margin="22">
  <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
  <TextBlock Margin="0,0,0,14" TextWrapping="Wrap" Foreground="#745A98" Text="一行一句语录。想让某句更常出现，可写：3 | 这句语录。"/>
  <TextBox x:Name="Lines" Grid.Row="1" AcceptsReturn="True" AcceptsTab="True" VerticalScrollBarVisibility="Auto" TextWrapping="Wrap" FontSize="16" Padding="12" Background="White" BorderBrush="#DDD4EA"/>
  <TextBlock x:Name="Feedback" Grid.Row="2" Margin="0,12,0,10" Foreground="#745A98" TextWrapping="Wrap"/>
  <Grid Grid.Row="3">
   <Button x:Name="Defaults" Content="恢复内置语录" Padding="12,6" HorizontalAlignment="Left"/>
   <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
    <Button x:Name="Save" Content="保存" Padding="20,6" Margin="0,0,10,0"/>
    <Button x:Name="Done" Content="关闭" Padding="20,6"/>
   </StackPanel>
  </Grid>
 </Grid>
</Window>
'@)
  $script:quoteEditor=$editor
  $editor.Owner=$script:window
  $lines=$editor.FindName('Lines');$feedback=$editor.FindName('Feedback')
  $current=Get-WidgetQuoteSettings $script:dataDir
  $lines.Text=($current.quotes|ForEach-Object{if($_.weight-eq 1){$_.text}else{([string]$_.weight)+' | '+$_.text}})-join [Environment]::NewLine
  $feedback.Text=if($current.error){$current.error}else{'每条最多 200 字。语录在你的电脑上保存。'}
  $editor.FindName('Save').Add_Click({
    try{
      $rows=@(foreach($line in ($script:quoteEditor.FindName('Lines').Text -split '\r?\n')){
        $text=$line.Trim();if(!$text){continue}
        if($text-match '^\s*(\d+(?:\.\d+)?)\s*\|\s*(.+)$'){@{text=$Matches[2].Trim();weight=[double]::Parse($Matches[1],[Globalization.CultureInfo]::InvariantCulture)}}
        else{@{text=$text;weight=1}}
      })
      $saved=Save-WidgetQuotes $script:dataDir $rows
      $script:quoteEditor.FindName('Feedback').Text="已保存 $($saved.quotes.Count) 句。下一次点击气泡时就会使用。"
    }catch{$script:quoteEditor.FindName('Feedback').Text=$_.Exception.Message}
  })
  $editor.FindName('Defaults').Add_Click({
    try{
      $restored=Reset-WidgetQuotes $script:dataDir
      $script:quoteEditor.FindName('Lines').Text=($restored.quotes|ForEach-Object{$_.text})-join [Environment]::NewLine
      $script:quoteEditor.FindName('Feedback').Text='已恢复内置语录，你的旧列表已备份。'
    }catch{$script:quoteEditor.FindName('Feedback').Text=$_.Exception.Message}
  })
  $editor.FindName('Done').Add_Click({$script:quoteEditor.Close()})
  $editor.Add_KeyDown({param($sender,$event)if($event.Key-eq [Windows.Input.Key]::Escape){$sender.Close();$event.Handled=$true}})
  $editor.Show()
}

function Initialize-WidgetSettingsMenu {
  $script:settingsMenuResources=[Windows.Markup.XamlReader]::Parse(@'
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
 <Style x:Key="SettingsItem" TargetType="MenuItem">
  <Setter Property="Foreground" Value="#443552"/><Setter Property="FontSize" Value="14.5"/>
  <Setter Property="Padding" Value="10,7"/><Setter Property="Margin" Value="0,1"/><Setter Property="Cursor" Value="Hand"/>
  <Setter Property="MinHeight" Value="36"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="MenuItem">
   <Grid><Border x:Name="ItemBody" Background="Transparent" CornerRadius="8" Padding="{TemplateBinding Padding}">
    <Grid><Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="22"/></Grid.ColumnDefinitions>
     <ContentPresenter ContentSource="Header" RecognizesAccessKey="True" VerticalAlignment="Center"/>
     <TextBlock x:Name="CheckMark" Grid.Column="1" Text="✓" Foreground="#8461B0" FontSize="17" FontWeight="Bold" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Right"/>
     <TextBlock x:Name="SubmenuArrow" Grid.Column="1" Text="›" Foreground="#9C80B6" FontSize="22" Visibility="Collapsed" VerticalAlignment="Center" HorizontalAlignment="Right"/>
    </Grid>
   </Border>
   <Popup x:Name="PART_Popup" Placement="{Binding Tag, RelativeSource={RelativeSource TemplatedParent}, FallbackValue=Right, TargetNullValue=Right}" PlacementTarget="{Binding ElementName=ItemBody}" IsOpen="{Binding IsSubmenuOpen, RelativeSource={RelativeSource TemplatedParent}}" AllowsTransparency="True" Focusable="False" PopupAnimation="Fade">
    <Border x:Name="SubmenuBody" Background="#FFFCFF" BorderBrush="#DFD1EC" BorderThickness="1" CornerRadius="12" Padding="9,8" MinWidth="{DynamicResource SettingsSubmenuWidth}" MaxWidth="{DynamicResource SettingsSubmenuWidth}" MaxHeight="{DynamicResource SettingsSubmenuMaxHeight}">
     <ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" CanContentScroll="False"><ItemsPresenter KeyboardNavigation.DirectionalNavigation="Cycle" KeyboardNavigation.TabNavigation="Cycle"/></ScrollViewer>
    </Border>
   </Popup></Grid>
   <ControlTemplate.Triggers>
    <Trigger Property="IsHighlighted" Value="True"><Setter TargetName="ItemBody" Property="Background" Value="#F0E8F8"/></Trigger>
    <Trigger Property="IsChecked" Value="True"><Setter TargetName="CheckMark" Property="Visibility" Value="Visible"/></Trigger>
    <Trigger Property="Uid" Value="radio"><Setter TargetName="CheckMark" Property="Text" Value="●"/><Setter TargetName="CheckMark" Property="FontSize" Value="14"/></Trigger>
    <Trigger Property="HasItems" Value="True"><Setter TargetName="SubmenuArrow" Property="Visibility" Value="Visible"/></Trigger>
    <Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.5"/></Trigger>
   </ControlTemplate.Triggers>
  </ControlTemplate></Setter.Value></Setter>
 </Style>
 <Style x:Key="SettingsPreset" TargetType="Button">
  <Setter Property="FontSize" Value="13"/><Setter Property="Foreground" Value="#75588E"/><Setter Property="Background" Value="#F2ECF8"/>
  <Setter Property="Padding" Value="8,6"/><Setter Property="BorderThickness" Value="0"/><Setter Property="Cursor" Value="Hand"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Button">
   <Border x:Name="PresetBody" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}"><ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/></Border>
   <ControlTemplate.Triggers>
    <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="PresetBody" Property="Background" Value="#E7DCF2"/></Trigger>
    <Trigger Property="IsPressed" Value="True"><Setter TargetName="PresetBody" Property="Background" Value="#DACAED"/></Trigger>
   </ControlTemplate.Triggers>
  </ControlTemplate></Setter.Value></Setter>
 </Style>
 <Style x:Key="SettingsSlider" TargetType="Slider">
  <Setter Property="Height" Value="26"/><Setter Property="IsMoveToPointEnabled" Value="True"/>
  <Setter Property="Template"><Setter.Value><ControlTemplate TargetType="Slider"><Grid Background="Transparent">
   <Track x:Name="PART_Track" VerticalAlignment="Center">
    <Track.DecreaseRepeatButton><RepeatButton Command="Slider.DecreaseLarge" Focusable="False"><RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Height="4" Background="#AC8BCB" CornerRadius="2"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.DecreaseRepeatButton>
    <Track.Thumb><Thumb Width="16" Height="16"><Thumb.Template><ControlTemplate TargetType="Thumb"><Border Background="White" BorderBrush="#9F7CC2" BorderThickness="2.5" CornerRadius="8"/></ControlTemplate></Thumb.Template></Thumb></Track.Thumb>
    <Track.IncreaseRepeatButton><RepeatButton Command="Slider.IncreaseLarge" Focusable="False"><RepeatButton.Template><ControlTemplate TargetType="RepeatButton"><Border Height="4" Background="#E8DFF0" CornerRadius="2"/></ControlTemplate></RepeatButton.Template></RepeatButton></Track.IncreaseRepeatButton>
   </Track>
  </Grid></ControlTemplate></Setter.Value></Setter>
  <Style.Triggers><Trigger Property="IsEnabled" Value="False"><Setter Property="Opacity" Value="0.4"/></Trigger></Style.Triggers>
 </Style>
</ResourceDictionary>
'@)
  $script:settingsMenuSync=$false;$script:settingsMenuUi=@{};$script:settingsSubmenus=@()
  $script:context=New-Object Windows.Controls.ContextMenu
  $script:context.FontFamily=[Windows.Media.FontFamily]::new('Microsoft YaHei UI');$script:context.FontSize=14.5;$script:context.Width=328
  $script:context.MaxHeight=[Math]::Max(360,[Math]::Min(730,[Windows.SystemParameters]::WorkArea.Height-28))
  $script:context.Resources.MergedDictionaries.Add($script:settingsMenuResources)
  $script:context.Resources['SettingsSubmenuWidth']=[double]300
  $script:context.Resources['SettingsSubmenuMaxHeight']=[double]600
  $script:settingsMenuTarget=$script:context
  $script:context.Template=[Windows.Markup.XamlReader]::Parse(@'
<ControlTemplate xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ContextMenu"><Border Background="#FFFCFF" BorderBrush="#DFD1EC" BorderThickness="1" CornerRadius="12" Padding="9,8"><ScrollViewer VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled" CanContentScroll="False"><ItemsPresenter/></ScrollViewer></Border></ControlTemplate>
'@)
  $script:settingsMenuUi.AINotice=Add-SettingsAction 'AI 生成修改 · 未经充分验证' {} -Description '测试和 AI 自查仅覆盖有限场景，仅供试用' -ReturnItem
  $script:settingsMenuUi.AINotice.IsEnabled=$false
  $script:settingsMenuUi.AINotice.ToolTip='本维护分支相对上游的修改及新增或改写文档均由 AI 生成，未经充分验证或独立人工审查；不能保证正确性、稳定性或安全性。'
  [Windows.Controls.ToolTipService]::SetShowOnDisabled($script:settingsMenuUi.AINotice,$true)
  Add-SettingsDivider
  $script:settingsMenuUi.Bubble=Add-SettingsAction '查看额度' {if(!$script:collapsed -and $script:bubbleMode-eq 'quota'){Hide-Quota}else{Show-Quota}} -ReturnItem
  $script:settingsMenuUi.Quote=Add-SettingsAction '换一句台词' {if($script:collapsed){Show-Quota};Switch-Scene 'quote'} -ReturnItem
  Add-SettingsAction '刷新额度' {Request-Refresh}
  Add-SettingsAction '编辑我的语录' {Open-QuoteEditor}
  Add-SettingsDivider
  $script:settingsMenuUi.Display=Add-SettingsSubmenu '显示与位置' {
  $script:settingsMenuUi.Follow=Add-SettingsAction '仅在 Codex 窗口内' {Set-WidgetFollowHost $true;Update-WidgetSettingsMenu;Set-WidgetMenuBounds;Position-WidgetMenuToHost} -Checkable -ReturnItem
  $script:settingsMenuUi.Follow.Uid='radio'
  $script:settingsMenuUi.Desktop=Add-SettingsAction '整个桌面自由拖动' {Set-WidgetFollowHost $false;Update-WidgetSettingsMenu;Set-WidgetMenuBounds;Position-WidgetMenuToHost} -Checkable -ReturnItem
  $script:settingsMenuUi.Desktop.Uid='radio'
  $script:settingsMenuUi.TopmostDivider=Add-SettingsDivider -ReturnItem
  $script:settingsMenuUi.Topmost=Add-SettingsAction '始终置顶' {param($sender,$event)if($script:followHost){Update-WidgetSettingsMenu;return};$script:desktopTopmost=[bool]$sender.IsChecked;Save-Settings;Tick-Widget} -Checkable -ReturnItem
  Add-SettingsDivider
  Add-SettingsAction '恢复右下角位置' {if($script:followHost){$script:offsetRight=0;$script:offsetLeft=0;$script:offsetBottom=0;$script:anchor='right'}else{$script:desktopLeft=$null;$script:desktopTop=$null};if($script:gravityEnabled){$script:gravity.Reset();$script:gravityTimer.Stop();Set-WidgetGravityPose};$script:side='right';$script:lastPosition=$null;Set-Facing;Hide-Quota;Save-Settings;Tick-Widget} -StayOpen
  } -ReturnItem
  $script:settingsMenuUi.Appearance=Add-SettingsSubmenu '外观设置' {
  $presets=New-Object Windows.Controls.Primitives.UniformGrid;$presets.Columns=3;$presets.Margin=[Windows.Thickness]::new(0,1,0,2);$script:settingsMenuUi.SizeButtons=@()
  foreach($choice in @(@{label='小 · 80%';scale=0.8},@{label='标准 · 100%';scale=1.0},@{label='大 · 140%';scale=1.4})){
    $button=New-Object Windows.Controls.Button;$button.Content=$choice.label;$button.Tag=$choice.scale;$button.Margin=[Windows.Thickness]::new(0,0,5,0);$button.Style=$script:settingsMenuResources['SettingsPreset']
    $button.Add_Click({param($sender,$event)$script:sizeSlider.Value=[double]$sender.Tag;$event.Handled=$true})
    $presets.Children.Add($button)|Out-Null;$script:settingsMenuUi.SizeButtons+=,$button
  }
  Add-SettingsPanel $presets
  $size=New-SettingsSlider '挂件大小' 0.6 2.5 0.1
  $script:sizeSlider=$size.Slider;$script:settingsMenuUi.SizeText=$size.Value;$size.Slider.Value=$script:scale
  $size.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:scale=[Math]::Round($sender.Value,1);$script:settingsMenuUi.SizeText.Text=([Math]::Round($script:scale*100)).ToString()+'%';Update-WidgetSizePresets;Set-Appearance;Save-Settings})
  Add-SettingsPanel $size.Panel
  $script:settingsMenuUi.Mirror=Add-SettingsAction '角色镜像翻转' {param($sender,$event)$script:mirrorCharacter=[bool]$sender.IsChecked;Set-Facing;Save-Settings} -Checkable -ReturnItem
  $script:settingsMenuUi.Hide=Add-SettingsAction '隐藏设置按钮' {param($sender,$event)$script:hideMenu=$sender.IsChecked;Set-MenuVisible $false;Save-Settings} -Description '仍可右键点角色打开设置' -Checkable -ReturnItem
  } -ReturnItem
  $script:settingsMenuUi.Gravity=Add-SettingsAction '重力模式' {param($sender,$event)Set-WidgetGravityMode ([bool]$sender.IsChecked)} -Description '单击轻跳，长按蓄力，拖动甩出带惯性' -Checkable -ReturnItem
  $script:settingsMenuUi.Physics=Add-SettingsSubmenu '重力与弹性' {
    $script:settingsMenuUi.NaturalElasticity=Add-SettingsAction '应用自然弹性' {
      $script:compressionCurve=1.5;$script:reboundStrength=75;$script:energyConversion=63.75
      $script:squishStrength=1.0;$script:animationSpeed=1.0
      Set-WidgetPhysicsTuning;Update-WidgetSettingsMenu
    } -Description '曲线 1.5、反弹 75%、Q弹 1×、动画 1×；以实球运动为参考的视觉预设' -ReturnItem
    $g=New-SettingsSlider '重力强度' 0.5 4 0.1
    $script:settingsMenuUi.GravityStrength=$g.Slider;$script:settingsMenuUi.GravityStrengthText=$g.Value
    $g.Slider.Value=$script:gravityStrength
    $g.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:gravityStrength=[Math]::Round($sender.Value,1);$script:settingsMenuUi.GravityStrengthText.Text=$script:gravityStrength.ToString('0.0')+'×';Set-WidgetPhysicsTuning})
    Add-SettingsPanel $g.Panel
    $f=New-SettingsSlider '底部摩擦力' 0 3 0.1
    $f.Panel.ToolTip='只降低贴底时的水平速度；向下撞击越快，触底期间摩擦越强（最多 3 倍），随后恢复普通滑动摩擦。0 关闭滑动摩擦，1 为标准；撞击时的横向损耗仍保留'
    $script:settingsMenuUi.GroundFriction=$f.Slider;$script:settingsMenuUi.GroundFrictionText=$f.Value
    $f.Slider.Value=$script:groundFriction
    $f.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:groundFriction=[Math]::Round($sender.Value,1);$script:settingsMenuUi.GroundFrictionText.Text=$script:groundFriction.ToString('0.0')+'×';Set-WidgetPhysicsTuning})
    Add-SettingsPanel $f.Panel
    $e=New-SettingsSlider '起跳能量' 0.25 3 0.05
    $script:settingsMenuUi.ElasticStrength=$e.Slider;$script:settingsMenuUi.ElasticStrengthText=$e.Value
    $e.Panel.ToolTip='只调整手动轻点或长按的起跳能量和停跳阈值；碰撞储能由反弹程度单独控制'
    $e.Slider.Value=$script:elasticStrength
    $e.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:elasticStrength=[Math]::Round($sender.Value,2);$script:settingsMenuUi.ElasticStrengthText.Text=$script:elasticStrength.ToString('0.00')+'×';Set-WidgetPhysicsTuning})
    Add-SettingsPanel $e.Panel
    $t=New-SettingsSlider '单点压缩程度' 0 3 0.05
    $t.Panel.ToolTip='默认 1×，越大按压初段越扁；0 关闭基础压缩。长按追加形变、蓄力时间和弹跳高度保持独立'
    $script:settingsMenuUi.TapCompression=$t.Slider;$script:settingsMenuUi.TapCompressionText=$t.Value
    $t.Slider.Value=$script:tapCompression
    $t.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:tapCompression=[Math]::Round($sender.Value,2);$script:settingsMenuUi.TapCompressionText.Text=$script:tapCompression.ToString('0.00')+'×';Set-WidgetPhysicsTuning})
    Add-SettingsPanel $t.Panel
    $c=New-SettingsSlider '反弹程度' 0 100 5
    $c.Panel.ToolTip='每档 5%；越高压缩越深、反弹越高，触底动画更长。0 关闭反弹，100 为最大反弹且仍有能量损耗；不影响手动起跳'
    $script:settingsMenuUi.EnergyConversion=$c.Slider;$script:settingsMenuUi.EnergyConversionText=$c.Value
    $c.Slider.IsSnapToTickEnabled=$true
    $c.Slider.Value=$script:reboundStrength
    $c.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:reboundStrength=[int]([Math]::Round($sender.Value/5,0,[MidpointRounding]::AwayFromZero)*5);if($sender.Value-ne $script:reboundStrength){$sender.Value=$script:reboundStrength;return};$script:energyConversion=0.85*$script:reboundStrength;$script:settingsMenuUi.EnergyConversionText.Text=$script:reboundStrength.ToString('0')+'%';Set-WidgetPhysicsTuning})
    Add-SettingsPanel $c.Panel
    $q=New-SettingsSlider 'Q弹程度' 0 3 0.05
    $q.Panel.ToolTip='触底形变随撞地速度和反弹程度增大；此滑条额外调节强度，0 关闭形变，1 为标准。先压缩恢复，再弹起'
    $script:settingsMenuUi.SquishStrength=$q.Slider;$script:settingsMenuUi.SquishStrengthText=$q.Value
    $q.Slider.Value=$script:squishStrength
    $q.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:squishStrength=[Math]::Round($sender.Value,2);$script:settingsMenuUi.SquishStrengthText.Text=$script:squishStrength.ToString('0.00')+'×';Set-WidgetPhysicsTuning})
    Add-SettingsPanel $q.Panel
    $a=New-SettingsSlider '动画速度' 0.25 3 0.05
    $a.Panel.ToolTip='默认 1×，越大越快。调整触底压缩、恢复和起跳拉伸；不改变按压蓄力时间、重力和弹跳能量'
    $script:settingsMenuUi.AnimationSpeed=$a.Slider;$script:settingsMenuUi.AnimationSpeedText=$a.Value
    $a.Slider.Value=$script:animationSpeed
    $a.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:animationSpeed=[Math]::Round($sender.Value,2);$script:settingsMenuUi.AnimationSpeedText.Text=$script:animationSpeed.ToString('0.00')+'×';Set-WidgetPhysicsTuning})
    Add-SettingsPanel $a.Panel
    $script:settingsMenuUi.CompressionCurveMenu=Add-SettingsSubmenu '压缩曲线' {
      $r=New-SettingsSlider '压缩减速强度' 1.5 3 0.05
      $r.Panel.ToolTip='1.5 更接近弹性球的正弦压缩；越大，垂直压缩初速越快、越早接近最扁并缓慢收住；末端速度为零。只调整压缩段，下次触底生效；基础时长随储能变化，再由动画速度统一调节'
      $script:settingsMenuUi.CompressionCurve=$r.Slider;$script:settingsMenuUi.CompressionCurveText=$r.Value
      $r.Slider.Value=$script:compressionCurve
      $canvas=New-Object Windows.Controls.Canvas;$canvas.Width=200;$canvas.Height=76
      $axis=New-Object Windows.Shapes.Polyline;$axis.Stroke=[Windows.Media.BrushConverter]::new().ConvertFromString('#DFD1EC');$axis.StrokeThickness=1
      foreach($point in @([Windows.Point]::new(8,8),[Windows.Point]::new(8,68),[Windows.Point]::new(192,68))){$axis.Points.Add($point)}
      $canvas.Children.Add($axis)|Out-Null
      $line=New-Object Windows.Shapes.Polyline;$line.Stroke=[Windows.Media.BrushConverter]::new().ConvertFromString('#9C80B6');$line.StrokeThickness=2
      $canvas.Children.Add($line)|Out-Null;$script:settingsMenuUi.CompressionCurveLine=$line
      $r.Panel.Children.Add($canvas)|Out-Null
      $r.Panel.Children.Add((New-SettingsText '横轴：时间　纵轴：压缩进度' 10 '#927AAB'))|Out-Null
      $r.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:compressionCurve=[Math]::Round($sender.Value,2);$script:settingsMenuUi.CompressionCurveText.Text=$script:compressionCurve.ToString('0.00');Set-WidgetPhysicsTuning;Update-WidgetCompressionCurvePreview})
      Add-SettingsPanel $r.Panel
    } -ReturnItem
  } -ReturnItem
  $script:settingsMenuUi.Colors=Add-SettingsSubmenu '配色效果' {
  $script:settingsMenuUi.ColorMixed=Add-SettingsAction '台词与颜色独立随机' {Set-WidgetColorMode 'mixed';Save-Settings;Update-WidgetSettingsMenu} -Description '先抽台词，再抽变色；每句都能触发' -Checkable -ReturnItem
  $script:settingsMenuUi.ColorOriginal=Add-SettingsAction '保持原色' {Set-WidgetColorMode 'original';Save-Settings;Update-WidgetSettingsMenu} -Checkable -ReturnItem
  $script:settingsMenuUi.ColorPause=Add-SettingsAction '暂停颜色流动' {param($sender,$event)$script:colorPaused=$sender.IsChecked;Update-WidgetColorScene;Save-Settings} -Checkable -ReturnItem
  Add-SettingsDivider
  $chance=New-SettingsSlider '全挂件变色概率' 0 30 0.5
  $script:settingsMenuUi.ColorChance=$chance.Slider;$script:settingsMenuUi.ColorChanceText=$chance.Value;$chance.Slider.Value=$script:colorChance
  $chance.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:colorChance=[Math]::Round($sender.Value,1);$script:settingsMenuUi.ColorChanceText.Text=$script:colorChance.ToString()+'%';Save-Settings})
  Add-SettingsPanel $chance.Panel
  $textChance=New-SettingsSlider '仅台词变色概率' 0 30 0.5
  $script:settingsMenuUi.ColorTextChance=$textChance.Slider;$script:settingsMenuUi.ColorTextChanceText=$textChance.Value;$textChance.Slider.Value=$script:colorTextChance
  $textChance.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:colorTextChance=[Math]::Round($sender.Value,1);$script:settingsMenuUi.ColorTextChanceText.Text=$script:colorTextChance.ToString()+'%';Save-Settings})
  Add-SettingsPanel $textChance.Panel
  Add-SettingsSection '其他效果' -Divider
  $script:settingsMenuUi.ColorLinked=Add-SettingsAction '每句都随内容变色' {Set-WidgetColorMode 'linked';Save-Settings;Update-WidgetSettingsMenu} -Checkable -ReturnItem
  $script:settingsMenuUi.ColorRainbow=Add-SettingsAction '一直流动彩虹' {Set-WidgetColorMode 'rainbow';Save-Settings;Update-WidgetSettingsMenu} -Checkable -ReturnItem
  $script:settingsMenuUi.ColorRare=Add-SettingsAction '只偶尔全变色' {Set-WidgetColorMode 'rare';Save-Settings;Update-WidgetSettingsMenu} -Checkable -ReturnItem
  $script:settingsMenuUi.ColorSurprise=Add-SettingsAction '偶尔变色＋指定台词' {Set-WidgetColorMode 'surprise';Save-Settings;Update-WidgetSettingsMenu} -Checkable -ReturnItem
  $script:settingsMenuUi.ColorSpecial=Add-SettingsAction '只在指定台词出现时变色' {Set-WidgetColorMode 'special';Save-Settings;Update-WidgetSettingsMenu} -Checkable -ReturnItem
  $script:settingsMenuUi.ColorTriggerList=Add-SettingsAction '编辑指定台词名单' {Open-ColorTriggerEditor} -Description '独立随机模式不使用此名单' -ReturnItem
  } -ReturnItem
  # Retain controls only for internal maintenance; the normal menu has no entry.
  $script:context.Items.Remove($script:settingsMenuUi.Colors)
  $script:settingsSubmenus=@($script:settingsSubmenus|Where-Object{$_-ne $script:settingsMenuUi.Colors})
  $script:settingsMenuUi.Audio=Add-SettingsSubmenu '声音与点击' {
  $script:settingsMenuUi.Sound=Add-SettingsAction '点击音效' {param($sender,$event)$script:soundOn=$sender.IsChecked;if(!$script:soundOn){Stop-WidgetAudio};$script:settingsMenuUi.Volume.IsEnabled=$script:soundOn;Save-Settings} -Checkable -StayOpen -ReturnItem
  $volume=New-SettingsSlider '音量' 0 1 0.1
  $script:settingsMenuUi.Volume=$volume.Slider;$script:settingsMenuUi.VolumeText=$volume.Value;$volume.Slider.Value=$script:soundVolume
  $volume.Slider.Add_ValueChanged({param($sender,$event)if($script:settingsMenuSync){return};$script:soundVolume=[Math]::Round($sender.Value,2);$script:settingsMenuUi.VolumeText.Text=([Math]::Round($sender.Value*100)).ToString()+'%';Set-WidgetAudioVolume;Save-Settings})
  Add-SettingsPanel $volume.Panel
  Add-SettingsDivider
  $script:settingsMenuUi.Tap=Add-SettingsAction '点角色也切换内容' {param($sender,$event)$script:bubbleTapAdvance=$sender.IsChecked;Save-Settings} -Description '开启后，连续点角色就能看下一句' -Checkable -ReturnItem
  } -ReturnItem
  Add-SettingsDivider
  $script:settingsMenuUi.Updates=Add-SettingsSubmenu '更新' {
    $script:settingsMenuUi.UpdateVersion=Add-SettingsAction '当前版本' {} -ReturnItem;$script:settingsMenuUi.UpdateVersion.IsEnabled=$false
    $updateLabel=if($script:releaseUpdatesDisabled){'个人版更新说明'}else{'检查并更新'}
    Add-SettingsAction $updateLabel {Start-WidgetUpdate 'manual'}
    $script:settingsMenuUi.AutoUpdate=Add-SettingsAction '自动更新' {param($sender,$event)Set-WidgetAutomaticUpdate ([bool]$sender.IsChecked)} -Checkable -ReturnItem
    $status=New-SettingsText '' 12 '#927AAB';$status.TextWrapping=[Windows.TextWrapping]::Wrap
    $script:settingsMenuUi.UpdateStatus=Add-SettingsPanel $status -Passive -ReturnItem
  } -ReturnItem
  Add-SettingsDivider
  $exit=Add-SettingsAction '退出 GPT 娘' {Exit-WidgetForSession} -ReturnItem;$exit.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString('#A1788D')
  $script:context.Add_Opened({Update-WidgetSettingsMenu;Set-WidgetMenuBounds;Position-WidgetMenuToHost});Update-WidgetSettingsMenu;$script:window.ContextMenu=$script:context
}

function New-SettingsText([string]$Text,[double]$Size,[string]$Color){$t=New-Object Windows.Controls.TextBlock;$t.Text=$Text;$t.FontSize=$Size;$t.Foreground=[Windows.Media.BrushConverter]::new().ConvertFromString($Color);return $t}
function Add-SettingsPanel($Panel,[switch]$Passive,[switch]$ReturnItem){
  $item=New-Object Windows.Controls.MenuItem;$item.Header=$Panel;$item.StaysOpenOnClick=$true;$item.Padding=[Windows.Thickness]::new(10,0,10,0);$item.Style=$script:settingsMenuResources['SettingsItem']
  $item.MinHeight=0
  if($Passive){$item.IsHitTestVisible=$false;$item.Focusable=$false};$script:settingsMenuTarget.Items.Add($item)|Out-Null;if($ReturnItem){return $item}
}
function Add-SettingsDivider([switch]$ReturnItem){$line=New-Object Windows.Controls.Border;$line.Height=1;$line.Margin=[Windows.Thickness]::new(10,7,10,7);$line.Background=[Windows.Media.BrushConverter]::new().ConvertFromString('#EEE6F4');Add-SettingsPanel $line -Passive -ReturnItem:$ReturnItem}
function Add-SettingsSection([string]$Label,[switch]$Divider){if($Divider){Add-SettingsDivider};$t=New-SettingsText $Label 11.5 '#A28DAF';$t.FontWeight=[Windows.FontWeights]::SemiBold;$t.Margin=[Windows.Thickness]::new(10,3,0,3);Add-SettingsPanel $t -Passive}
function Add-SettingsAction{
  param([string]$Label,[scriptblock]$Action,[string]$Description,[switch]$Checkable,[switch]$StayOpen,[switch]$ReturnItem)
  $item=New-Object Windows.Controls.MenuItem;$item.Style=$script:settingsMenuResources['SettingsItem'];$item.IsCheckable=[bool]$Checkable;$item.StaysOpenOnClick=([bool]$StayOpen -or [bool]$Checkable)
  if($Description){$p=New-Object Windows.Controls.StackPanel;$main=New-SettingsText $Label 14.5 '#443552';$detail=New-SettingsText $Description 11.5 '#A08EAD';$detail.Margin=[Windows.Thickness]::new(0,3,0,0);$p.Children.Add($main)|Out-Null;$p.Children.Add($detail)|Out-Null;$item.Header=$p}else{$item.Header=$Label}
  $item.Add_Click($Action);$script:settingsMenuTarget.Items.Add($item)|Out-Null;if($ReturnItem){return $item}
}
function Add-SettingsSubmenu {
  param([string]$Label,[scriptblock]$Content,[switch]$ReturnItem)
  $item=New-Object Windows.Controls.MenuItem;$item.Header=$Label;$item.Style=$script:settingsMenuResources['SettingsItem'];$item.Tag=[Windows.Controls.Primitives.PlacementMode]::Right
  $script:settingsMenuTarget.Items.Add($item)|Out-Null;$script:settingsSubmenus+=,$item
  $previous=$script:settingsMenuTarget;$script:settingsMenuTarget=$item
  try{& $Content}finally{$script:settingsMenuTarget=$previous}
  if($ReturnItem){return $item}
}
function New-SettingsSlider([string]$Label,[double]$Minimum,[double]$Maximum,[double]$Step){
  $panel=New-Object Windows.Controls.StackPanel;$panel.Margin=[Windows.Thickness]::new(0,6,0,2)
  $row=New-Object Windows.Controls.Grid;$row.ColumnDefinitions.Add((New-Object Windows.Controls.ColumnDefinition))|Out-Null;$right=New-Object Windows.Controls.ColumnDefinition;$right.Width=[Windows.GridLength]::Auto;$row.ColumnDefinitions.Add($right)|Out-Null
  $caption=New-SettingsText $Label 12 '#927AAB';$value=New-SettingsText '' 12 '#8764A9';$value.FontWeight=[Windows.FontWeights]::SemiBold;[Windows.Controls.Grid]::SetColumn($value,1);$row.Children.Add($caption)|Out-Null;$row.Children.Add($value)|Out-Null
  $slider=New-Object Windows.Controls.Slider;$slider.Minimum=$Minimum;$slider.Maximum=$Maximum;$slider.TickFrequency=$Step;$slider.SmallChange=$Step;$slider.LargeChange=$Step;$slider.IsSnapToTickEnabled=$true;$slider.Style=$script:settingsMenuResources['SettingsSlider'];$slider.Margin=[Windows.Thickness]::new(0,2,0,0)
  $panel.Children.Add($row)|Out-Null;$panel.Children.Add($slider)|Out-Null;return @{Panel=$panel;Slider=$slider;Value=$value}
}
function Update-WidgetSizePresets{
  foreach($button in $script:settingsMenuUi.SizeButtons){$color=if([Math]::Abs([double]$button.Tag-$script:scale)-lt 0.05){'#E2D2EE'}else{'#F2ECF8'};$button.Background=[Windows.Media.BrushConverter]::new().ConvertFromString($color)}
}
function Update-WidgetCompressionCurvePreview {
  $points=New-Object Windows.Media.PointCollection
  for($i=0;$i-le 24;$i++){$t=$i/24.0;$points.Add([Windows.Point]::new((8+184*$t),(68-60*$script:gravity.GetCompressionProgress($t))))}
  $script:settingsMenuUi.CompressionCurveLine.Points=$points
}
function Update-WidgetSettingsMenu{
  $script:settingsMenuSync=$true
  try{
    Update-WidgetUpdateMenu
    $script:settingsMenuUi.Bubble.Header=if(!$script:collapsed -and $script:bubbleMode-eq 'quota'){'收起额度气泡'}else{'查看额度'}
    $script:settingsMenuUi.Follow.IsChecked=$script:followHost;$script:settingsMenuUi.Desktop.IsChecked=!$script:followHost
    $script:settingsMenuUi.Topmost.IsChecked=$script:desktopTopmost;$script:settingsMenuUi.Topmost.IsEnabled=!$script:followHost
    $desktopVisibility=if($script:followHost){[Windows.Visibility]::Collapsed}else{[Windows.Visibility]::Visible}
    $script:settingsMenuUi.Topmost.Visibility=$desktopVisibility;$script:settingsMenuUi.TopmostDivider.Visibility=$desktopVisibility
    $script:settingsMenuUi.Tap.IsChecked=$script:bubbleTapAdvance;$script:settingsMenuUi.Sound.IsChecked=$script:soundOn;$script:settingsMenuUi.Hide.IsChecked=$script:hideMenu
    $script:settingsMenuUi.Gravity.IsChecked=$script:gravityEnabled
    $script:settingsMenuUi.Mirror.IsChecked=$script:mirrorCharacter
    $script:settingsMenuUi.GravityStrength.Value=$script:gravityStrength;$script:settingsMenuUi.GravityStrengthText.Text=$script:gravityStrength.ToString('0.0')+'×'
    $script:settingsMenuUi.ElasticStrength.Value=$script:elasticStrength;$script:settingsMenuUi.ElasticStrengthText.Text=$script:elasticStrength.ToString('0.00')+'×'
    $script:settingsMenuUi.GroundFriction.Value=$script:groundFriction;$script:settingsMenuUi.GroundFrictionText.Text=$script:groundFriction.ToString('0.0')+'×'
    $script:settingsMenuUi.CompressionCurve.Value=$script:compressionCurve;$script:settingsMenuUi.CompressionCurveText.Text=$script:compressionCurve.ToString('0.00');Update-WidgetCompressionCurvePreview
    $script:settingsMenuUi.EnergyConversion.Value=$script:reboundStrength;$script:settingsMenuUi.EnergyConversionText.Text=$script:reboundStrength.ToString('0')+'%'
    $script:settingsMenuUi.TapCompression.Value=$script:tapCompression;$script:settingsMenuUi.TapCompressionText.Text=$script:tapCompression.ToString('0.00')+'×'
    $script:settingsMenuUi.AnimationSpeed.Value=$script:animationSpeed;$script:settingsMenuUi.AnimationSpeedText.Text=$script:animationSpeed.ToString('0.00')+'×'
    $script:settingsMenuUi.SquishStrength.Value=$script:squishStrength;$script:settingsMenuUi.SquishStrengthText.Text=$script:squishStrength.ToString('0.00')+'×'
    $script:settingsMenuUi.ColorLinked.IsChecked=$script:colorMode-eq 'linked';$script:settingsMenuUi.ColorRainbow.IsChecked=$script:colorMode-eq 'rainbow';$script:settingsMenuUi.ColorOriginal.IsChecked=$script:colorMode-eq 'original'
    $script:settingsMenuUi.ColorSurprise.IsChecked=$script:colorMode-eq 'surprise';$script:settingsMenuUi.ColorRare.IsChecked=$script:colorMode-eq 'rare';$script:settingsMenuUi.ColorSpecial.IsChecked=$script:colorMode-eq 'special'
    $script:settingsMenuUi.ColorMixed.IsChecked=$script:colorMode-eq 'mixed'
    $script:settingsMenuUi.ColorChance.Value=$script:colorChance;$script:settingsMenuUi.ColorChanceText.Text=$script:colorChance.ToString()+'%';$script:settingsMenuUi.ColorChance.IsEnabled=$script:colorMode-in @('rare','surprise','mixed')
    $script:settingsMenuUi.ColorTextChance.Value=$script:colorTextChance;$script:settingsMenuUi.ColorTextChanceText.Text=$script:colorTextChance.ToString()+'%';$script:settingsMenuUi.ColorTextChance.IsEnabled=$script:colorMode-eq 'mixed'
    $script:settingsMenuUi.ColorTriggerList.IsEnabled=$script:colorMode-in @('special','surprise')
    $script:settingsMenuUi.ColorPause.IsChecked=$script:colorPaused;$script:settingsMenuUi.ColorPause.IsEnabled=$script:colorMode-ne 'original'
    $script:settingsMenuUi.Volume.Value=$script:soundVolume;$script:settingsMenuUi.Volume.IsEnabled=$script:soundOn;$script:settingsMenuUi.VolumeText.Text=([Math]::Round($script:soundVolume*100)).ToString()+'%'
    $script:sizeSlider.Value=$script:scale;$script:settingsMenuUi.SizeText.Text=([Math]::Round($script:scale*100)).ToString()+'%';Update-WidgetSizePresets
  }finally{$script:settingsMenuSync=$false}
}

function Open-WidgetMenu {
  Set-WidgetMenuBounds
  Update-WidgetSettingsMenu
  $script:context.IsOpen=$true
  Position-WidgetMenuToHost
}

function Set-WidgetMenuBounds {
  $script:context.PlacementTarget=$script:ui.MenuButton
  $script:context.Placement=if($script:side-eq 'left'){[Windows.Controls.Primitives.PlacementMode]::Right}else{[Windows.Controls.Primitives.PlacementMode]::Left}
  $script:context.HorizontalOffset=if($script:side-eq 'left'){8}else{-8}
  $script:context.VerticalOffset=0
  foreach($submenu in $script:settingsSubmenus){$submenu.Tag=if($script:side-eq 'left'){[Windows.Controls.Primitives.PlacementMode]::Right}else{[Windows.Controls.Primitives.PlacementMode]::Left}}
  try{
    if(!$script:followHost -or ($script:hostHandle-ne [IntPtr]::Zero -and [GptWidgetNative]::IsWindow($script:hostHandle))){
      $frame=Get-WidgetPlacementFrame;$dpi=Get-WidgetPlacementDpi
      $script:context.Width=[Math]::Max(180,[Math]::Min(328,($frame.Right-$frame.Left)/$dpi-16))
      $script:context.MaxHeight=[Math]::Max(160,[Math]::Min(730,($frame.Bottom-$frame.Top)/$dpi-16))
      $submenuWidth=[double][Math]::Max(180,[Math]::Min(300,($frame.Right-$frame.Left)/$dpi-16))
      $submenuHeight=[double][Math]::Max(160,[Math]::Min(600,($frame.Bottom-$frame.Top)/$dpi-16))
      # Replacing even an equal resource invalidates dependent submenu layouts.
      if($script:context.Resources['SettingsSubmenuWidth']-ne $submenuWidth){$script:context.Resources['SettingsSubmenuWidth']=$submenuWidth}
      if($script:context.Resources['SettingsSubmenuMaxHeight']-ne $submenuHeight){$script:context.Resources['SettingsSubmenuMaxHeight']=$submenuHeight}
    }
  }catch{}
}

function Position-WidgetMenuToHost {
  # Move only our own popup; host geometry is read-only.
  if(!$script:context.IsOpen){return}
  try{
    if($script:followHost -and ($script:hostHandle-eq [IntPtr]::Zero -or ![GptWidgetNative]::IsWindow($script:hostHandle))){return}
    $script:context.UpdateLayout()
    $source=[Windows.Interop.HwndSource]::FromVisual($script:context)
    if(!$source -or $source.Handle-eq [IntPtr]::Zero){return}
    $frame=Get-WidgetPlacementFrame;$menu=[GptWidgetNative]::Frame($source.Handle)
    $dpi=Get-WidgetPlacementDpi
    $margin=[int][Math]::Round(8*$dpi);$width=$menu.Right-$menu.Left;$height=$menu.Bottom-$menu.Top
    $origin=$script:ui.MenuButton.PointToScreen([Windows.Point]::new(0,0))
    $edge=$script:ui.MenuButton.PointToScreen([Windows.Point]::new($script:ui.MenuButton.ActualWidth,0))
    $desiredX=if($script:side-eq 'left'){$edge.X+$margin}else{$origin.X-$width-$margin}
    $x=[int][Math]::Round([Math]::Max($frame.Left+$margin,[Math]::Min($frame.Right-$width-$margin,$desiredX)))
    $y=[int][Math]::Round([Math]::Max($frame.Top+$margin,[Math]::Min($frame.Bottom-$height-$margin,$origin.Y)))
    if($menu.Left-ne $x -or $menu.Top-ne $y){[GptWidgetNative]::SetWindowPos($source.Handle,[IntPtr]::Zero,$x,$y,0,0,0x15)|Out-Null}
  }catch{}
}
