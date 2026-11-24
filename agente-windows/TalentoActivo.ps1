$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$SUPABASE_URL = "https://ezpmwfdyvoogqnvnaumq.supabase.co"
$SUPABASE_ANON_KEY = "sb_publishable_Zns8JZPfB7l_0rSmKvY6zw_vCkKhUnM"

Add-Type @"
using System;
using System.Runtime.InteropServices;

public class IdleTime {
    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO {
        public uint cbSize;
        public uint dwTime;
    }

    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    public static uint GetIdleSeconds() {
        LASTINPUTINFO lii = new LASTINPUTINFO();
        lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
        if (GetLastInputInfo(ref lii)) {
            uint idleTicks = ((uint)Environment.TickCount - lii.dwTime);
            return idleTicks / 1000;
        }
        return 0;
    }
}
"@

$carpetaDatos = Join-Path $env:APPDATA "TalentoActivo"
if (-not (Test-Path $carpetaDatos)) { New-Item -ItemType Directory -Path $carpetaDatos | Out-Null }
$rutaSesion = Join-Path $carpetaDatos "sesion.json"
$rutaPendientes = Join-Path $carpetaDatos "pendientes.json"

function Pedir-Token($grant, $cuerpoObj) {
    $headers = @{
        "apikey" = $SUPABASE_ANON_KEY
        "Content-Type" = "application/json"
    }
    $body = $cuerpoObj | ConvertTo-Json -Compress
    return Invoke-RestMethod -Uri "$SUPABASE_URL/auth/v1/token?grant_type=$grant" -Method Post -Headers $headers -Body $body
}

$sesion = $null
if (Test-Path $rutaSesion) {
    try {
        $guardada = Get-Content $rutaSesion -Raw | ConvertFrom-Json
        $resp = Pedir-Token "refresh_token" @{ refresh_token = $guardada.refreshToken }
        $sesion = @{
            accessToken  = $resp.access_token
            refreshToken = $resp.refresh_token
            email        = $guardada.email
            userId       = $resp.user.id
            expira       = (Get-Date).AddSeconds($resp.expires_in - 60)
        }
        $sesion | ConvertTo-Json | Set-Content $rutaSesion
    } catch {
        Remove-Item $rutaSesion -ErrorAction SilentlyContinue
    }
}

while (-not $sesion) {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "   TalentoActivo - Monitor de Windows   " -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    $email = Read-Host "Correo de TalentoActivo"
    $passSecure = Read-Host "Contrasena" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($passSecure)
    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    try {
        $resp = Pedir-Token "password" @{ email = $email; password = $password }
        $sesion = @{
            accessToken  = $resp.access_token
            refreshToken = $resp.refresh_token
            email        = $email
            userId       = $resp.user.id
            expira       = (Get-Date).AddSeconds($resp.expires_in - 60)
        }
        $sesion | ConvertTo-Json | Set-Content $rutaSesion
        Write-Host "`nInicio de sesion exitoso." -ForegroundColor Green
    } catch {
        Write-Host "`nCorreo o contrasena incorrectos. Intenta de nuevo." -ForegroundColor Red
        Start-Sleep -Seconds 2
    }
}

Write-Host "`nMonitoreo activo para $($sesion.email)." -ForegroundColor Green
Write-Host "Guarda bloques localmente si no hay internet y los envia al reconectar."
Write-Host "Ya puedes cerrar esta ventana y usar 'Iniciar-Segundo-Plano.vbs' si deseas que corra oculto.`n" -ForegroundColor Yellow

$pendientes = @()
if (Test-Path $rutaPendientes) {
    try {
        $cargados = Get-Content $rutaPendientes -Raw | ConvertFrom-Json
        if ($cargados) { $pendientes = @($cargados) }
    } catch { $pendientes = @() }
}

$activos = 0
$inactivos = 0
$inicioBloque = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

while ($true) {
    Start-Sleep -Seconds 60
    $idle = [IdleTime]::GetIdleSeconds()
    if ($idle -lt 60) {
        $activos++
        Write-Host "[$(Get-Date -Format 'HH:mm')] Activo ($activos min activos / $inactivos min inactivos)" -ForegroundColor Gray
    } else {
        $inactivos++
        Write-Host "[$(Get-Date -Format 'HH:mm')] Inactivo ($activos min activos / $inactivos min inactivos)" -ForegroundColor DarkGray
    }

    if (($activos + $inactivos) -ge 5) {
        $pendientes += @{
            perfil_id         = $sesion.userId
            inicio            = $inicioBloque
            minutos_activos   = $activos
            minutos_inactivos = $inactivos
            origen            = "agente"
        }
        $pendientes | ConvertTo-Json -Compress | Set-Content $rutaPendientes
        $activos = 0
        $inactivos = 0
        $inicioBloque = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

        try {
            if ((Get-Date) -ge [datetime]$sesion.expira) {
                $resp = Pedir-Token "refresh_token" @{ refresh_token = $sesion.refreshToken }
                $sesion.accessToken  = $resp.access_token
                $sesion.refreshToken = $resp.refresh_token
                $sesion.expira       = (Get-Date).AddSeconds($resp.expires_in - 60)
                $sesion | ConvertTo-Json | Set-Content $rutaSesion
            }

            $headers = @{
                "apikey"        = $SUPABASE_ANON_KEY
                "Authorization" = "Bearer $($sesion.accessToken)"
                "Content-Type"  = "application/json"
                "Prefer"        = "resolution=ignore-duplicates,return=minimal"
            }
            $cuerpoJson = ConvertTo-Json -InputObject @($pendientes) -Compress
            Invoke-RestMethod -Uri "$SUPABASE_URL/rest/v1/actividad_bloques?on_conflict=perfil_id,inicio" -Method Post -Headers $headers -Body $cuerpoJson | Out-Null

            Write-Host "-> $($pendientes.Count) bloque(s) enviado(s) a TalentoActivo." -ForegroundColor Cyan
            $pendientes = @()
            Remove-Item $rutaPendientes -ErrorAction SilentlyContinue
        } catch {
            Write-Host "-> Sin conexion o error temporal. $($pendientes.Count) bloque(s) guardado(s) en cola local." -ForegroundColor Yellow
        }
    }
}
