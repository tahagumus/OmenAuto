# OmenTray.ps1 - OmenAuto icin sistem tepsisi simgesi (saatin yaninda).
# Sadece OKUMA yapar: OmenAuto.log dosyasinda "Profil:" gecen SON satira bakar.
#   Mavi    = Quiet
#   Kirmizi = Performance (ustune gelince oyunun adi da yazar)
#   Gri     = OmenAuto calismiyor veya durum bilinmiyor
# Simgenin icinde ekran kartinin sicakligi yazar (nvidia-smi ile, 10 saniyede bir okunur).
# Sag tik menusu: gunlugu ac, OmenAuto'yu yeniden baslat, simgeyi kapat.
# Kur.cmd bunu oturum acilisinda (yonetici OLMADAN, gizli pencereyle) baslatir.

$LogFile   = Join-Path $PSScriptRoot 'OmenAuto.log'
$RefreshMs = 3000
$TempRefreshSeconds = 10   # nvidia-smi her seferinde yeni bir program actigi icin seyrek okunur

# Ayni anda sadece bir simge olsun
$created = $false
$single  = New-Object System.Threading.Mutex($true, 'Local\OmenAutoTray', [ref]$created)
if (-not $created) { return }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Colors = @{
    Quiet       = @(40, 120, 230)
    Performance = @(225, 45, 45)
    Unknown     = @(140, 140, 140)
}
$Deg = [string][char]0xB0   # derece isareti (dosya ASCII kalsin diye kodla uretilir)

# Renkli yuvarlak simge; sicaklik biliniyorsa icine beyaz rakamla yazar.
# Ayni renk + sicaklik icin simge bir kez cizilir, sonra hazir olan kullanilir.
$IconCache = @{}
function Get-TrayIcon([string]$kind, $temp) {
    $key = "$kind|$temp"
    if ($IconCache.ContainsKey($key)) { return $IconCache[$key] }
    $c   = $Colors[$kind]
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $gfx.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($c[0], $c[1], $c[2]))
    if ($null -eq $temp) {
        $gfx.FillEllipse($brush, 3, 3, 26, 26)
    } else {
        $gfx.FillEllipse($brush, 0, 0, 32, 32)
        $txt  = [string]$temp
        $size = if ($txt.Length -gt 2) { 13 } else { 18 }
        $font = New-Object System.Drawing.Font('Segoe UI', $size, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $fmt  = New-Object System.Drawing.StringFormat
        $fmt.Alignment     = [System.Drawing.StringAlignment]::Center
        $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
        $gfx.DrawString($txt, $font, [System.Drawing.Brushes]::White, (New-Object System.Drawing.RectangleF(0, 1, 32, 32)), $fmt)
        $font.Dispose(); $fmt.Dispose()
    }
    $brush.Dispose(); $gfx.Dispose()
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $IconCache[$key] = $icon
    return $icon
}

# Ekran karti sicakligi (NVIDIA surucusuyle gelen nvidia-smi; yonetici yetkisi gerekmez).
function Get-GpuTemp {
    $smi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
    if (-not (Test-Path $smi)) { return $null }
    try {
        $t = & $smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($t -match '^\s*(\d+)') { return [int]$Matches[1] }
    } catch {}
    return $null
}

# Gunlukte "Profil:" gecen son satiri bulur. Performance ise ondan onceki "Oyun algilandi" satirindan oyun adini alir.
function Get-OmenState([string[]]$lines) {
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '^\d{4}-\d{2}-\d{2} (\d{2}:\d{2}):\d{2}\s+Profil: (\w+)') {
            $state = @{ Mode = $Matches[2]; Since = $Matches[1]; Game = $null }
            if ($state.Mode -eq 'Performance') {
                for ($j = $i - 1; $j -ge 0; $j--) {
                    if ($lines[$j] -match 'Oyun algilandi: (.+)$') { $state.Game = $Matches[1].Trim(); break }
                    if ($lines[$j] -match 'Profil:') { break }
                }
            }
            return $state
        }
    }
    return $null
}

# OmenAuto calisiyor mu? OmenAuto.ps1 'Global\OmenAutoWatcher' kilidini tutar.
# Kilit yonetici surecine ait oldugu icin acmaya calisinca "erisim engellendi" hatasi gelir;
# bu da kilidin VAR oldugu, yani OmenAuto'nun calistigi anlamina gelir.
function Test-OmenRunning {
    try {
        $m = $null
        if ([System.Threading.Mutex]::TryOpenExisting('Global\OmenAutoWatcher', [ref]$m)) { $m.Dispose(); return $true }
        return $false
    } catch { return $true }
}

function Read-LogLines {
    $fs = [System.IO.File]::Open($LogFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    try {
        $sr = New-Object System.IO.StreamReader($fs)
        return ($sr.ReadToEnd() -split "`r?`n")
    } finally { $fs.Dispose() }
}

$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = Get-TrayIcon 'Unknown' $null
$tray.Text = 'OmenAuto: bekleniyor...'
$tray.Visible = $true

$menu       = New-Object System.Windows.Forms.ContextMenuStrip
$statusItem = $menu.Items.Add('OmenAuto')
$statusItem.Enabled = $false
[void]$menu.Items.Add('-')
$logItem     = $menu.Items.Add('Gunlugu ac')
$restartItem = $menu.Items.Add('OmenAuto''yu yeniden baslat')
[void]$menu.Items.Add('-')
$exitItem    = $menu.Items.Add('Simgeyi kapat')
$tray.ContextMenuStrip = $menu

$openLog = { if (Test-Path $LogFile) { Start-Process notepad.exe -ArgumentList "`"$LogFile`"" } }
$logItem.Add_Click($openLog)
$tray.Add_DoubleClick($openLog)
$restartItem.Add_Click({ Start-Process -FilePath (Join-Path $PSScriptRoot 'Yeniden-Baslat.cmd') })
$exitItem.Add_Click({ [System.Windows.Forms.Application]::Exit() })

$script:lastWrite = [datetime]::MinValue
$script:state     = $null
$script:gpuTemp   = $null
$script:nextTemp  = [datetime]::MinValue

function Update-Tray {
    try {
        $item = Get-Item -LiteralPath $LogFile -ErrorAction Stop
        if ($item.LastWriteTime -ne $script:lastWrite) {
            $script:state     = Get-OmenState (Read-LogLines)
            $script:lastWrite = $item.LastWriteTime
        }
    } catch {}

    if ((Get-Date) -ge $script:nextTemp) {
        $script:gpuTemp  = Get-GpuTemp
        $script:nextTemp = (Get-Date).AddSeconds($TempRefreshSeconds)
    }
    $temp = $script:gpuTemp

    $lines = @()
    if (-not (Test-OmenRunning)) {
        $kind  = 'Unknown'
        $lines += 'OmenAuto: CALISMIYOR'
    } elseif (-not $script:state) {
        $kind  = 'Unknown'
        $lines += 'OmenAuto: durum bilinmiyor'
    } else {
        $s = $script:state
        $kind  = if ($s.Mode -eq 'Performance') { 'Performance' } else { 'Quiet' }
        $lines += "OmenAuto: $($s.Mode)"
    }
    if ($null -ne $temp) { $lines += "GPU: $temp$($Deg)C" }
    if ($script:state -and $kind -ne 'Unknown') {
        if ($script:state.Game) { $lines += $script:state.Game }
        $lines += "$($script:state.Since)'dan beri"
    }

    $tray.Icon = Get-TrayIcon $kind $temp
    $statusItem.Text = $lines -join ' - '
    # Windows tepsi yazisi en fazla 63 karakter: sigmazsa sondaki satirlar atilir
    $text = $lines -join "`n"
    while ($text.Length -gt 63 -and $lines.Count -gt 1) {
        $lines = $lines[0..($lines.Count - 2)]
        $text  = $lines -join "`n"
    }
    if ($text.Length -gt 63) { $text = $text.Substring(0, 63) }
    $tray.Text = $text
}

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $RefreshMs
$timer.Add_Tick({ Update-Tray })
$timer.Start()
Update-Tray

try {
    [System.Windows.Forms.Application]::Run()
} finally {
    $timer.Stop()
    $tray.Visible = $false
    $tray.Dispose()
    $single.ReleaseMutex()
}
