<#
Setup rapido del lado Windows (host), equivalente a bootstrap.sh pero para lo
que no vive dentro de WSL: apps nativas via winget + config de Windows
Terminal. NO instala WSL ni la distro (eso ya lo cubre bootstrap.sh una vez
estas dentro de Ubuntu/WSL).

Requiere symlinks: activa "Modo desarrollador" (Settings > Privacidad y
seguridad > Para desarrolladores) o corre este script como Administrador.

Uso: clona este repo con Git for Windows y corre el script desde ahi.
    git clone <repo-url> dotfiles
    cd dotfiles
    .\scripts\bootstrap-windows.ps1
#>

$ErrorActionPreference = 'Stop'

$RootDir = Split-Path -Parent $PSScriptRoot
$WingetList = Join-Path $RootDir 'packages\winget.txt'
$TerminalSettingsSrc = Join-Path $RootDir 'windows\settings.json'
$TerminalSettingsDst = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"

function Write-Log($msg) { Write-Host "[setup] $msg" }

function Install-WingetApps {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log "winget no encontrado; instala 'App Installer' desde la Microsoft Store y reintenta."
        return
    }
    if (-not (Test-Path $WingetList)) {
        Write-Log "packages\winget.txt no encontrado; se omite instalacion de apps."
        return
    }

    Get-Content $WingetList | ForEach-Object {
        $id = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($id) -or $id.StartsWith('#')) { return }

        Write-Log "Instalando $id (winget se salta esto si ya esta instalado)..."
        winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) {
            Write-Log "AVISO: '$id' fallo o ya estaba instalado. Si es la primera vez, confirma el ID con: winget search `"<nombre>`""
        }
    }
}

function Link-TerminalSettings {
    if (-not (Test-Path $TerminalSettingsSrc)) {
        Write-Log "windows\settings.json no encontrado; se omite."
        return
    }
    $dstDir = Split-Path -Parent $TerminalSettingsDst
    if (-not (Test-Path $dstDir)) {
        Write-Log "Windows Terminal no parece instalado (falta $dstDir); se omite el symlink."
        return
    }

    $existing = Get-Item $TerminalSettingsDst -ErrorAction SilentlyContinue
    if ($existing -and $existing.LinkType -eq 'SymbolicLink') {
        Write-Log "settings.json ya es un symlink; se omite."
        return
    }
    if ($existing) {
        $backup = "$TerminalSettingsDst.backup.$(Get-Date -Format yyyyMMdd_HHmmss)"
        Write-Log "Backup settings.json -> $backup"
        Move-Item $TerminalSettingsDst $backup
    }

    try {
        New-Item -ItemType SymbolicLink -Path $TerminalSettingsDst -Target $TerminalSettingsSrc -Force | Out-Null
        Write-Log "Enlazado windows\settings.json -> $TerminalSettingsDst"
    } catch {
        Write-Log "No se pudo crear el symlink (activa Modo desarrollador o corre como Admin): $_"
    }
}

Write-Log "Apps sin paquete en winget (instalar manual): GlobalProtect (portal VPN de tu organizacion), NVIDIA App (nvidia.com/en-us/software/nvidia-app)."

Install-WingetApps
Link-TerminalSettings

Write-Log "Listo. Abre una ventana nueva de Windows Terminal para ver los cambios."
Write-Log "Pendiente manual: fijar 'defaultProfile' en windows\settings.json con el GUID de tu perfil Ubuntu."
