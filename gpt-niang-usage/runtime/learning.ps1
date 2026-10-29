function Get-WidgetLearningState {
  if($script:learningUiError){return @{enabled=$script:learningLastEnabled;state=$script:learningUiError}}
  try {
    $state=Get-Content -LiteralPath (Join-Path $script:dataDir 'learning\state.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $age=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$state.at
    if($age-ge 0 -and $age-lt 5000){
      if($script:learningPending -and $state.ack-ne $script:learningPending.id){
        return @{enabled=$script:learningPending.enabled;state=$(if($script:learningPending.enabled){'正在开启'}else{'正在停止'})}
      }
      $script:learningPending=$null
      return $state
    }
  } catch {}
  return @{enabled=$false;state='已关闭（后台未就绪）'}
}
function Set-WidgetLearningEnabled([bool]$Enabled) {
  $script:learningLastEnabled=[bool](Get-WidgetLearningState).enabled
  $script:learningUiError=$null
  try {
    $key=$null
    if($Enabled){
      $snapshot=Get-Content -LiteralPath (Join-Path $script:dataDir 'status.json') -Raw -Encoding UTF8 | ConvertFrom-Json
      if(!$snapshot.ok -or !$snapshot.queryOk -or !$snapshot.accountKey){throw 'Snapshot unavailable'}
      $primary=$snapshot.windows | Where-Object {$_.minutes-eq 300} | Select-Object -First 1
      if(!$primary){throw 'Window unavailable'}
      $sha=[Security.Cryptography.SHA256]::Create()
      try{$key=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($snapshot.accountKey+':'+$primary.resetsAt)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
    }
    $dir=Join-Path $script:dataDir 'learning';$null=New-Item -ItemType Directory -Path $dir -Force
    $tmp=Join-Path $dir ('request-'+[guid]::NewGuid().ToString()+'.tmp')
    $request=@{id=[guid]::NewGuid().ToString();enabled=$Enabled;key=$key}
    [IO.File]::WriteAllText($tmp,($request|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $tmp -Destination (Join-Path $dir 'request.json') -Force
    $script:learningPending=$request
  } catch { $script:learningUiError='操作失败，请重试；未确认停止前仍可能运行' }
  Update-WidgetSettingsMenu
}

function Update-WidgetLearningMenu {
  if(!$script:settingsMenuUi -or !$script:settingsMenuUi.Learning){return}
  $state=Get-WidgetLearningState
  $script:settingsMenuUi.Learning.IsChecked=[bool]$state.enabled
  $script:settingsMenuUi.LearningStatus.Header=[string]$state.state
}
