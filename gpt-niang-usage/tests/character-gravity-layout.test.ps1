param([string]$TestRoot=$PSScriptRoot)
# AI-generated compatibility regression; insufficiently validated.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase
$appDir=Split-Path $TestRoot -Parent
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseInput([IO.File]::ReadAllText((Join-Path $appDir 'widget.ps1'),[Text.Encoding]::UTF8),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
foreach($name in @('Get-WidgetLayoutScale','Set-WidgetIndependentLayout','Set-Facing')){
  $definition=$ast.Find({param($node)$node-is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name-eq $name},$true)
  if(!$definition){throw ('Missing production function: '+$name)}
  . ([ScriptBlock]::Create($definition.Extent.Text))
}
$gravityAst=[Management.Automation.Language.Parser]::ParseFile((Join-Path $appDir 'runtime/gravity.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
$definition=$gravityAst.Find({param($node)$node-is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name-eq 'Get-WidgetGravityPadding'},$true)
. ([ScriptBlock]::Create($definition.Extent.Text))
function Sync-WidgetCharacterColors {}
function Assert-Near([double]$Actual,[double]$Expected,[string]$Message,[double]$Tolerance=0.001){if([Math]::Abs($Actual-$Expected)-gt $Tolerance){throw ($Message+': expected '+$Expected+', got '+$Actual)}}
$script:window=[Windows.Markup.XamlReader]::Parse([IO.File]::ReadAllText((Join-Path $appDir 'widget.xaml'),[Text.Encoding]::UTF8))
$script:ui=@{}
foreach($name in @('Root','Girl','Bubble','Tail','TailNear','MenuButton','Refresh','FacingScale','TextFacingScale','CharacterMirror')){$script:ui[$name]=$script:window.FindName($name)}
$script:designHeight=$script:window.FindName('AnimationStage').Height
$script:widgetMusic=$null;$cases=0
try{
  foreach($shape in @(@{width=80;height=40},@{width=40;height=80},@{width=40;height=40})){
    $pixels=New-Object byte[] ($shape.width*$shape.height*4)
    $script:ui.Girl.Source=[Windows.Media.Imaging.BitmapSource]::Create($shape.width,$shape.height,96,96,[Windows.Media.PixelFormats]::Bgra32,$null,$pixels,($shape.width*4))
    foreach($character in @(0.6,1.0,2.5)){
      foreach($bubble in @(0.6,1.0,2.5)){
        $script:scale=$character;$script:bubbleScale=$bubble;Set-WidgetIndependentLayout
        foreach($mirrored in @($false,$true)){
          $script:mirrorCharacter=$mirrored
          foreach($side in @('left','right')){
            $script:side=$side;Set-Facing
            $girl=$script:ui.Girl
            $drawWidth=[Math]::Min($girl.Width/$shape.width,$girl.Height/$shape.height)*$shape.width
            Assert-Near $script:ui.CharacterMirror.CenterX (-$drawWidth/2) 'Mirror center tracks the Uniform source width at the independent character size'
            Assert-Near $script:ui.CharacterMirror.ScaleX $(if($mirrored){-1}else{1}) 'Host side preserves explicit mirror preference'
            $script:window.Content.Measure([Windows.Size]::new(378,378));$script:window.Content.Arrange([Windows.Rect]::new(0,0,378,378));$script:window.Content.UpdateLayout()
            $actualCenter=$girl.TranslatePoint([Windows.Point]::new($girl.ActualWidth/2,$girl.ActualHeight/2),$script:ui.Root)
            Assert-Near $actualCenter.X ([Windows.Controls.Canvas]::GetLeft($girl)+$girl.Width/2) ("Mirroring preserves center shape=$($shape.width)/$($shape.height) char=$character bubble=$bubble mirrored=$mirrored actualWidth=$($girl.ActualWidth) width=$($girl.Width) origin=$($girl.RenderTransformOrigin) matrix=$($girl.RenderTransform.Value)") 1.0
            $drawHeight=[Math]::Min($girl.Width/$shape.width,$girl.Height/$shape.height)*$shape.height
            $visibleFoot=[Windows.Controls.Canvas]::GetTop($script:ui.Root)+[Windows.Controls.Canvas]::GetTop($girl)+($girl.Height+$drawHeight)/2
            Assert-Near ($script:designHeight-(Get-WidgetGravityPadding)) $visibleFoot 'Gravity floor follows the Uniform image foot'
            $cases++
          }
        }
      }
    }
  }
  Write-Output ('PASS: '+$cases+' square/wide/tall character layouts preserve mirror preference, center and gravity feet')
}finally{$script:window.Close()}