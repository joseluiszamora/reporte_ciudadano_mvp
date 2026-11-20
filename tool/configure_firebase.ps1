param([Parameter(Mandatory = $true)][string]$GoogleServicesPath)
$ErrorActionPreference = 'Stop'
$firebaseData = Get-Content -LiteralPath $GoogleServicesPath -Raw | ConvertFrom-Json
$androidClient = @($firebaseData.client | Where-Object { $_.client_info.android_client_info.package_name -eq 'bo.elalto.reporte_ciudadano_mvp' })
if ($androidClient.Count -ne 1) { throw 'Debe existir exactamente un cliente Android para bo.elalto.reporte_ciudadano_mvp.' }
$selectedClient = $androidClient[0]
$webClient = @($selectedClient.oauth_client | Where-Object { $_.client_type -eq 3 })
if ($webClient.Count -lt 1) { throw 'Falta un cliente OAuth web (client_type 3). Habilita Google en Firebase Auth y vuelve a descargar google-services.json.' }
$outputConfig = [ordered]@{
  FIREBASE_API_KEY = [string]$selectedClient.api_key[0].current_key
  FIREBASE_APP_ID = [string]$selectedClient.client_info.mobilesdk_app_id
  FIREBASE_PROJECT_ID = [string]$firebaseData.project_info.project_id
  FIREBASE_MESSAGING_SENDER_ID = [string]$firebaseData.project_info.project_number
  GOOGLE_WEB_CLIENT_ID = [string]$webClient[0].client_id
}
foreach ($entry in $outputConfig.GetEnumerator()) {
  if ([string]::IsNullOrWhiteSpace($entry.Value)) { throw "Falta el campo $($entry.Key) en la configuración." }
}
$outputPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config/firebase.android.json'
$outputConfig | ConvertTo-Json | Set-Content -LiteralPath $outputPath -Encoding utf8
Write-Output "Configuración generada en $outputPath. El archivo está excluido de Git."
