$mobileAppRoot = Join-Path $PSScriptRoot "mobile_app"
$pubCacheRoot = Join-Path $mobileAppRoot ".pub-cache"

if (-not (Test-Path $pubCacheRoot)) {
	New-Item -ItemType Directory -Path $pubCacheRoot | Out-Null
}

Remove-Item Env:FLUTTER_NO_CACHE -ErrorAction SilentlyContinue
$env:PUB_CACHE = $pubCacheRoot

Set-Location $mobileAppRoot
flutter run
