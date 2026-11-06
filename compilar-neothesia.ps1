#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$RepoPath,
    [switch]$Run
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Ejecutar {
    param([string]$Programa, [string[]]$Argumentos)

    & $Programa @Argumentos
    if ($LASTEXITCODE -ne 0) {
        throw "$Programa fallo con codigo $LASTEXITCODE."
    }
}

try {
    if ($env:OS -ne 'Windows_NT') {
        throw 'Este script requiere Windows.'
    }

    foreach ($herramienta in @('rustup', 'cargo')) {
        if (-not (Get-Command $herramienta -ErrorAction SilentlyContinue)) {
            throw 'Instala Rust desde https://rustup.rs/ y vuelve a abrir PowerShell.'
        }
    }

    if ([string]::IsNullOrWhiteSpace($RepoPath)) {
        if (Test-Path "$PSScriptRoot\neothesia\Cargo.toml") {
            $RepoPath = $PSScriptRoot
        } else {
            $RepoPath = Join-Path $PSScriptRoot 'Neothesia'
        }
    }

    $RepoPath = [System.IO.Path]::GetFullPath($RepoPath)

    if (-not (Test-Path -LiteralPath $RepoPath)) {
        if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
            throw 'Instala Git desde https://git-scm.com/download/win'
        }
        Ejecutar 'git' @(
            'clone',
            'https://github.com/yatahunt/Neothesia.git',
            $RepoPath
        )
    }

    foreach ($archivo in @('Cargo.lock', 'neothesia\Cargo.toml', 'default.sf2')) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoPath $archivo))) {
            throw "Falta $archivo. Indica la raiz del repositorio con -RepoPath."
        }
    }

    $toolchain = 'stable-x86_64-pc-windows-msvc'
    Ejecutar 'rustup' @('toolchain', 'install', $toolchain, '--profile', 'minimal')

    Push-Location -LiteralPath $RepoPath
    try {
        Write-Host 'Compilando... La primera vez puede tardar varios minutos.'

        $destino = Join-Path $RepoPath 'target'
        Ejecutar 'cargo' @(
            "+$toolchain", 'build',
            '--release', '--locked',
            '-p', 'neothesia', '--bin', 'neothesia',
            '--target', 'x86_64-pc-windows-msvc',
            '--target-dir', $destino
        )

        $carpetaExe = Join-Path $destino 'x86_64-pc-windows-msvc\release'
        $exe = Join-Path $carpetaExe 'neothesia.exe'

        if (-not (Test-Path -LiteralPath $exe)) {
            throw "No se encontro el ejecutable: $exe"
        }

        Copy-Item -LiteralPath "$RepoPath\default.sf2" -Destination $carpetaExe -Force
        Write-Host "Compilacion completada: $exe" -ForegroundColor Green

        if ($Run) {
            Start-Process -FilePath $exe -WorkingDirectory $RepoPath
        }
    } finally {
        Pop-Location
    }
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
