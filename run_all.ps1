# Start all FiftyFood applications in separate PowerShell windows
# Usage: .\run_all.ps1

Write-Host "🚀 Starting FiftyFood Applications..." -ForegroundColor Green
Write-Host ""

$BackendPath = "C:\Users\ismai\FiftyFood\backend"
$AdminPath = "C:\Users\ismai\FiftyFood\frontend-web\admin"
$RestaurantPath = "C:\Users\ismai\FiftyFood\frontend-web\restaurant"

# Start Backend
Write-Host "📦 Starting Backend (Port 3000)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$BackendPath'; npm run dev" -WindowStyle Normal

# Start Admin
Write-Host "👨‍💼 Starting Admin Dashboard (Port 5174)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$AdminPath'; npm run dev" -WindowStyle Normal

# Start Restaurant
Write-Host "🍽️  Starting Restaurant Portal (Port 5175)..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList "-NoExit", "-Command", "cd '$RestaurantPath'; npm run dev" -WindowStyle Normal

Write-Host ""
Write-Host "✅ All applications started!" -ForegroundColor Green
Write-Host ""
Write-Host "Access URLs:" -ForegroundColor Yellow
Write-Host "  📦 Backend:     http://localhost:3000" -ForegroundColor White
Write-Host "  👨‍💼 Admin:       http://localhost:5174" -ForegroundColor White
Write-Host "  🍽️  Restaurant:  http://localhost:5175" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C in each window to stop the server" -ForegroundColor Gray
