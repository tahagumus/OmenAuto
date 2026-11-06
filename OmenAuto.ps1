# OmenAuto.ps1 - HP Victus otomatik performans / fan kontrolu
# OMEN Gaming Hub'i acmaz; BIOS'a dogrudan WMI ile komut gonderir (HpBios.ps1).
#
#  - Oyun yokken : Quiet modu, tam hiz fan kapali, GPU gucu orijinal ayarinda.
#  - Oyun acikken: Performance modu, GPU gucu maksimum.
#                  Istege bagli: islemci hizlandirma (varsayilan KAPALI, CpuBoost-Ac.cmd ile acilir).
#                  Ekran karti sicakligi $FanOnTemp'i gecerse fanlar tam hiza cikar,
#                  $FanOffTemp'in altina inince normale (otomatik) doner.
#
# Yonetici yetkisiyle calismasi gerekir (Kur.cmd Gorev Zamanlayici ile ayarlar).

param(
    [ValidateSet('Watch', 'Quiet', 'Performance')]
    [string]$Mode = 'Watch'
)

# ---------------- AYARLAR ----------------

# Oyun olarak sayilacak program adlari (.exe olmadan). Yeni oyun eklemek icin buraya yaz.
$GameProcessNames = @(
    'VALORANT-Win64-Shipping',
    'League of Legends',
    'Among Us',
    'cs2',
    'FortniteClient-Win64-Shipping',
    'GTA5',
    'RocketLeague'
)

# Bu klasorlerden calisan her program oyun sayilir (Steam, Epic, EA oyunlari).
$GameFolderPatterns = @(
    '*\steamapps\common\*',
    '*\Epic Games\*',
    '*\EA Games\*'
)

# Bu klasorlerdeki programlar oyun SAYILMAZ (launcher / yardimci araclar).
$IgnoreFolderPatterns = @(
    '*\steamapps\common\Steamworks Shared\*',
    '*\steamapps\common\Steam Controller Configs\*',
    '*\Epic Games\Launcher\*'
)

# Oyunda fan kontrolu (ekran karti sicakligina gore, derece C)
$FanOnTemp  = 80   # bu sicaklik ve ustunde fanlar tam hiz
$FanOffTemp = 72   # bu sicaklik ve altinda fanlar tekrar otomatik

# Oyunda ekran kartina maksimum guc verilsin mi (Custom TGP + AI Boost)
$GpuMaxInGame = $true

# Istege bagli: oyunda islemci ayarlari (Windows guc plani, sadece prize takiliyken gecerli degerler):
# hiz artirma Agresif, en dusuk durum %100, core parking kapali. Oyun kapaninca eski degerlere doner.
# Ac/kapa: CpuBoost-Ac.cmd / CpuBoost-Kapat.cmd
# (CpuBoost.txt dosyasinda 1 = acik, 0 = kapali; dosya yoksa KAPALI sayilir)
$CpuBoostFile = Join-Path $PSScriptRoot 'CpuBoost.txt'
$CpuNormalFile = Join-Path $PSScriptRoot 'CpuNormal.txt'
$CpuGameValues = [ordered]@{ 'PERFBOOSTMODE' = 2; 'PROCTHROTTLEMIN' = 100; 'CPMINCORES' = 100 }

$CheckIntervalSeconds = 5
$ReapplySeconds       = 60     # mod her dakika yeniden uygulanir (OMEN/HP servisi ezerse diye)

# Bu laptopta dogrulanan mod degerleri
$ModeValue = @{ 'Quiet' = 3; 'Performance' = 1 }

$LogFile = Join-Path $PSScriptRoot 'OmenAuto.log'

# -----------------------------------------

. (Join-Path $PSScriptRoot 'HpBios.ps1')

function Write-Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    try {
        if ((Test-Path $LogFile) -and ((Get-Item $LogFile).Length -gt 1MB)) { Remove-Item $LogFile -Force }
        Add-Content -Path $LogFile -Value $line
    } catch {}
}

# Oyun disindaki GPU guc ayari (bu laptopta olculen varsayilan: Custom TGP kapali, AI Boost acik)
$script:GpuOriginal = [byte[]](0, 1, 1, 0)

# ---- Islemci (Windows guc plani) ayarlari ----
function Get-CpuAcValue([string]$alias) {
    $txt = powercfg /qh SCHEME_CURRENT SUB_PROCESSOR $alias 2>$null | Out-String
    $hex = [regex]::Matches($txt, '0x[0-9a-fA-F]{8}') | ForEach-Object { $_.Value }
    if ($hex.Count -lt 2) { return $null }
    return [Convert]::ToInt32($hex[$hex.Count - 2], 16)   # sondan ikinci = AC, son = DC
}

function Get-CpuBoostEnabled {
    try { if (Test-Path $CpuBoostFile) { return ((Get-Content $CpuBoostFile -Raw).Trim() -eq '1') } } catch {}
    return $false
}

# Normal (oyun disi) islemci degerlerini bir kez kaydet; sonra hep bu dosyadan geri yukle
function Initialize-CpuNormal {
    if (Test-Path $CpuNormalFile) { return }
    $lines = foreach ($k in $CpuGameValues.Keys) { "$k=$(Get-CpuAcValue $k)" }
    Set-Content -Path $CpuNormalFile -Value $lines
}

function Set-CpuProfile([bool]$game) {
    try {
        Initialize-CpuNormal
        if ($game) {
            foreach ($k in $CpuGameValues.Keys) { powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR $k $CpuGameValues[$k] | Out-Null }
        } else {
            foreach ($line in Get-Content $CpuNormalFile) {
                $k, $v = $line -split '=', 2
                if ($v -match '^\d+$') { powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR $k ([int]$v) | Out-Null }
            }
        }
        powercfg /setactive SCHEME_CURRENT | Out-Null
        return $(if ($game) { 'oyun' } else { 'normal' })
    } catch {
        Write-Log "HATA (islemci ayari): $($_.Exception.Message)"
        return 'hata'
    }
}

function Set-Profile([ValidateSet('Quiet', 'Performance')] [string]$target, [switch]$NoLog) {
    try {
        $rc1 = Set-HpFanMode $ModeValue[$target]
        if ($target -eq 'Performance' -and $GpuMaxInGame) {
            $rc2 = Set-HpGpuPower ([byte[]](1, 1, 1, 0))
        } else {
            $rc2 = Set-HpGpuPower $script:GpuOriginal
        }
        if ($target -eq 'Quiet') { Set-HpMaxFan $false | Out-Null; $script:MaxFanOn = $false }
        elseif ($script:MaxFanOn) { Set-HpMaxFan $true | Out-Null }
        $cpu = 'dokunulmadi'
        if (-not $NoLog) {
            # Islemci ayari sadece profil degisince uygulanir (her dakika degil).
            # Hizlandirma kapaliysa ve hic acilmamissa (CpuNormal.txt yok) guc planina hic dokunulmaz.
            if (Get-CpuBoostEnabled) {
                $cpu = Set-CpuProfile ($target -eq 'Performance')
            } elseif (Test-Path $CpuNormalFile) {
                $cpu = Set-CpuProfile $false
            } else {
                $cpu = 'kapali'
            }
            Write-Log "Profil: $target (mod kodu $rc1, gpu kodu $rc2, islemci $cpu)"
        }
        return $true
    } catch {
        Write-Log "HATA: $($_.Exception.Message)"
        return $false
    }
}

function Update-Fan {
    $t = $null
    try { $t = Get-NvidiaTemp } catch {}
    if ($null -eq $t) { return }
    if (-not $script:MaxFanOn -and $t -ge $FanOnTemp) {
        try { Set-HpMaxFan $true | Out-Null; $script:MaxFanOn = $true; Write-Log "GPU $t C -> fanlar tam hiz" } catch {}
    }
    elseif ($script:MaxFanOn -and $t -le $FanOffTemp) {
        try { Set-HpMaxFan $false | Out-Null; $script:MaxFanOn = $false; Write-Log "GPU $t C -> fanlar otomatik" } catch {}
    }
}

function Get-RunningGame {
    foreach ($p in Get-Process -ErrorAction SilentlyContinue) {
        if ($GameProcessNames -contains $p.ProcessName) { return $p.ProcessName }
        $path = $null
        try { $path = $p.Path } catch {}
        if (-not $path) { continue }
        $ignored = $false
        foreach ($ig in $IgnoreFolderPatterns) { if ($path -like $ig) { $ignored = $true; break } }
        if ($ignored) { continue }
        foreach ($pat in $GameFolderPatterns) { if ($path -like $pat) { return $p.ProcessName } }
    }
    return $null
}

# ---------------- CALISMA ----------------

if ($Mode -ne 'Watch') {
    Set-Profile $Mode | Out-Null
    return
}

# Ayni anda sadece bir kopya calissin
$created = $false
$mutex = New-Object System.Threading.Mutex($true, 'Global\OmenAutoWatcher', [ref]$created)
if (-not $created) { return }

Write-Log "Baslatildi."

$script:MaxFanOn = $false
try { $script:MaxFanOn = [bool](Get-HpMaxFan) } catch {}

$current   = $null
$reapplyAt = (Get-Date).AddSeconds($ReapplySeconds)
$lastTick  = Get-Date

while ($true) {
    $game   = Get-RunningGame
    $wanted = if ($game) { 'Performance' } else { 'Quiet' }

    # Dongu arasinda 30 sn'den fazla gecmisse bilgisayar uykudan/hazirda beklemeden uyanmistir:
    # BIOS modu sifirlamis olabilir, hemen yeniden uygula.
    $now = Get-Date
    if (($now - $lastTick).TotalSeconds -gt 30 -and $current) {
        Write-Log "Uykudan uyanma algilandi."
        $current = $null
    }
    $lastTick = $now

    if ($wanted -ne $current) {
        if ($game) { Write-Log "Oyun algilandi: $game" } else { Write-Log "Oyun yok." }
        if (Set-Profile $wanted) { $current = $wanted }
        $reapplyAt = (Get-Date).AddSeconds($ReapplySeconds)
    }
    elseif ((Get-Date) -ge $reapplyAt) {
        Set-Profile $current -NoLog | Out-Null
        $reapplyAt = (Get-Date).AddSeconds($ReapplySeconds)
    }

    if ($current -eq 'Performance') { Update-Fan }

    Start-Sleep -Seconds $CheckIntervalSeconds
}
