# OmenTray.ps1 - OmenAuto icin sistem tepsisi simgesi (saatin yaninda).
# Sadece OKUMA yapar: OmenAuto.log dosyasinda "Profil:" gecen SON satira bakar.
#   Mavi    = Quiet
#   Kirmizi = Performance (ustune gelince oyunun adi da yazar)
#   Gri     = OmenAuto calismiyor veya durum bilinmiyor
# Sag tik menusu: gunlugu ac, OmenAuto'yu yeniden baslat, simgeyi kapat.
# Kur.cmd bunu oturum acilisinda (yonetici OLMADAN, gizli pencereyle) baslatir.

$LogFile   = Join-Path $PSScriptRoot 'OmenAuto.log'
$RefreshMs = 3000

# Ayni anda sadece bir simge olsun
$created = $false
$single  = New-Object System.Threading.Mutex($true, 'Local\OmenAutoTray', [ref]$created)
if (-not $created) { return }

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function New-DotIcon([int]$r, [int]$g, [int]$b) {
    $bmp = New-Object System.Drawing.Bitmap 32, 32
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $gfx.Clear([System.Drawing.Color]::Transparent)
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($r, $g, $b))
    $gfx.FillEllipse($brush, 3, 3, 26, 26)
    $brush.Dispose(); $gfx.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$Icons = @{
    Quiet       = New-DotIcon 40 120 230
    Performance = New-DotIcon 225 45 45
    Unknown     = New-DotIcon 140 140 140
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
$tray.Icon = $Icons.Unknown
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

function Update-Tray {
    try {
        $item = Get-Item -LiteralPath $LogFile -ErrorAction Stop
        if ($item.LastWriteTime -ne $script:lastWrite) {
            $script:state     = Get-OmenState (Read-LogLines)
            $script:lastWrite = $item.LastWriteTime
        }
    } catch {}

    $running = Test-OmenRunning
    if (-not $running) {
        $tray.Icon = $Icons.Unknown
        $text = 'OmenAuto: CALISMIYOR'
    } elseif (-not $script:state) {
        $tray.Icon = $Icons.Unknown
        $text = 'OmenAuto: durum bilinmiyor'
    } else {
        $s = $script:state
        $tray.Icon = if ($s.Mode -eq 'Performance') { $Icons.Performance } else { $Icons.Quiet }
        $text = "OmenAuto: $($s.Mode)"
        if ($s.Game) { $text += "`n$($s.Game)" }
        $text += "`n$($s.Since)'dan beri"
    }
    $statusItem.Text = $text -replace "`n", ' - '
    if ($text.Length -gt 63) { $text = $text.Substring(0, 63) }   # Windows tepsi yazisi en fazla 63 karakter
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
