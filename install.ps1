<#
Instalador de una linea para el host Windows (no WSL):
    irm https://raw.githubusercontent.com/savaf/dotfiles/main/install.ps1 | iex

Asegura git (via winget), clona (HTTPS) o actualiza el repo y lanza
scripts\bootstrap-windows.ps1 con -ExecutionPolicy Bypass solo para ese proceso.
Variables de entorno opcionales: DOTFILES_DIR (def. ~\dotfiles), DOTFILES_REPO,
DOTFILES_BRANCH (def. main), DOTFILES_NO_BOOTSTRAP=1 (solo clonar).

Los symlinks de Windows Terminal requieren Modo desarrollador o PowerShell como
Administrador (ver docs/windows-host.md).
#>

function Install-Dotfiles {
    $ErrorActionPreference = 'Stop'

    $Dir    = if ($env:DOTFILES_DIR)    { $env:DOTFILES_DIR }    else { Join-Path $HOME 'dotfiles' }
    $Repo   = if ($env:DOTFILES_REPO)   { $env:DOTFILES_REPO }   else { 'https://github.com/savaf/dotfiles.git' }
    $Branch = if ($env:DOTFILES_BRANCH) { $env:DOTFILES_BRANCH } else { 'main' }

    function Write-Log($msg) { Write-Host "[install] $msg" }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            throw "Ni git ni winget estan instalados; instala 'App Installer' desde la Microsoft Store y reintenta."
        }
        Write-Log "Instalando Git for Windows con winget..."
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
        $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
                    [Environment]::GetEnvironmentVariable('Path', 'User')
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw "git sigue sin estar en el PATH; abre una terminal nueva y reintenta."
        }
    }

    if (Test-Path (Join-Path $Dir '.git')) {
        $origin = git -C $Dir remote get-url origin 2>$null
        if ($origin -ne $Repo -and $origin -notmatch 'savaf/dotfiles(\.git)?$') {
            throw "$Dir ya existe y no es este repo; usa DOTFILES_DIR=<otra ruta>."
        }
        if (git -C $Dir status --porcelain) {
            Write-Log "$Dir tiene cambios locales; se omite el pull."
        } else {
            Write-Log "Actualizando $Dir..."
            git -C $Dir pull --ff-only
            if ($LASTEXITCODE -ne 0) { Write-Log "No se pudo hacer fast-forward; sigo con lo que hay." }
        }
    } elseif (Test-Path $Dir) {
        throw "$Dir ya existe y no es un repo git; muevelo o usa DOTFILES_DIR=<otra ruta>."
    } else {
        Write-Log "Clonando $Repo ($Branch) en $Dir..."
        git clone --branch $Branch $Repo $Dir
        if ($LASTEXITCODE -ne 0) { throw "git clone fallo." }
    }

    if ($env:DOTFILES_NO_BOOTSTRAP -eq '1') {
        Write-Log "DOTFILES_NO_BOOTSTRAP=1: listo. Para instalar: $Dir\scripts\bootstrap-windows.cmd"
        return
    }

    $bootstrap = Join-Path $Dir 'scripts\bootstrap-windows.ps1'
    Write-Log "Lanzando $bootstrap..."
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File $bootstrap
}

Install-Dotfiles
