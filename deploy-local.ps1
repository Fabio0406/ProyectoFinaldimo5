# CD local: carga la imagen descargada desde los artifacts de GitHub Actions
# (artifact "docker-image") y la despliega con Docker Compose.
#
# Uso:  .\deploy-local.ps1 -Archive .\springboot-devsecops-lab.tar.gz
param(
    [Parameter(Mandatory = $true)]
    [string]$Archive
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Archive)) {
    throw "No se encontro el archivo de imagen: $Archive"
}

Write-Host "Cargando imagen desde $Archive ..."
$loadOutput = docker load -i $Archive
if ($LASTEXITCODE -ne 0) { throw "docker load fallo" }
$loadOutput | Write-Host

$loaded = $loadOutput | Select-String -Pattern 'Loaded image: springboot-devsecops-lab:(\S+)' | Select-Object -First 1
if (-not $loaded) {
    throw "El archivo no contiene una imagen springboot-devsecops-lab"
}
$env:IMAGE_TAG = $loaded.Matches[0].Groups[1].Value

Write-Host "Desplegando springboot-devsecops-lab:$($env:IMAGE_TAG) ..."
docker compose up -d --force-recreate
if ($LASTEXITCODE -ne 0) { throw "docker compose up fallo" }

Write-Host "Esperando a que la aplicacion responda ..."
foreach ($i in 1..30) {
    try {
        $health = Invoke-RestMethod -Uri 'http://localhost:8080/actuator/health' -TimeoutSec 3
        Write-Host "Aplicacion desplegada. Estado: $($health.status)  Imagen: springboot-devsecops-lab:$($env:IMAGE_TAG)"
        Write-Host "URL: http://localhost:8080/api/products/search?name=Laptop"
        exit 0
    } catch {
        Start-Sleep -Seconds 2
    }
}
throw "La aplicacion no respondio en http://localhost:8080/actuator/health"
