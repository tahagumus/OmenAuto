# FpsOlc.ps1 - Oyun acikken FPS'i ve islemci / ekran karti durumunu olcer (FpsOlc.cmd yonetici olarak baslatir).
# FPS icin PresentMon kullanir (Intel, MIT lisansi). PresentMon oyuna dokunmaz: Windows'un kare
# gunlugunu (ETW) okur. PresentMon-*.exe dosyasini bu klasore koy (README'ye bak).
# Oyuna donmen icin 20 sn bekler, sonra 15 sn olcer. Sonuc: FpsOlc-<tarih>.txt
# Hicbir ayari degistirmez.

$WaitSeconds    = 20
$MeasureSeconds = 15

Start-Sleep -Seconds $WaitSeconds
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$out = Join-Path $PSScriptRoot "FpsOlc-$stamp.txt"
$csv = Join-Path $env:TEMP "OmenAuto-FpsOlc-$stamp.csv"
$r = New-Object System.Collections.Generic.List[string]

# Olculecek oyun: OmenAuto.log'daki son "Oyun algilandi" satiri
$game = $null
try {
    $hit = Select-String -Path (Join-Path $PSScriptRoot 'OmenAuto.log') -Pattern 'Oyun algilandi: (.+)$' | Select-Object -Last 1
    if ($hit) { $game = $hit.Matches[0].Groups[1].Value.Trim() }
} catch {}

$boost = 'kapali'
try { if ((Get-Content (Join-Path $PSScriptRoot 'CpuBoost.txt') -Raw).Trim() -eq '1') { $boost = 'acik' } } catch {}
$gpu = 'bilinmiyor'
try { $gpu = ((Select-String -Path (Join-Path $PSScriptRoot 'OmenAuto.ps1') -Pattern '^\$GpuMaxInGame = (\S+)' | Select-Object -First 1).Matches[0].Groups[1].Value) } catch {}

$r.Add("===== FPS olcumu $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') =====")
$r.Add("Oyun: $game    Islemci hizlandirma: $boost    GpuMaxInGame: $gpu")

$pm = Get-ChildItem $PSScriptRoot -Filter 'PresentMon*.exe' | Select-Object -First 1
$proc = $null
if (-not $pm) { $r.Add('PresentMon bulunamadi: FPS olculmedi (README > FPS olcumu)') }
elseif (-not $game) { $r.Add('Oyun bulunamadi: once oyunu ac, OmenAuto algilasin') }
else {
    $proc = Start-Process -FilePath $pm.FullName -WindowStyle Hidden -PassThru -ArgumentList @(
        '--process_name', "$game.exe", '--output_file', "`"$csv`"",
        '--timed', "$MeasureSeconds", '--terminate_after_timed', '--stop_existing_session', '--no_console_stats')
}

$r.Add('saat     | en hizli cekirdek MHz | en yogun cekirdek % | GPU kullanim % | GPU MHz | GPU W | GPU C')
$base = 0
try { $base = (Get-CimInstance Win32_Processor | Select-Object -First 1).MaxClockSpeed } catch {}
$smi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
for ($i = 0; $i -lt $MeasureSeconds; $i++) {
    $line = Get-Date -Format 'HH:mm:ss'
    try {
        $cores = Get-CimInstance Win32_PerfFormattedData_Counters_ProcessorInformation -ErrorAction Stop | Where-Object { $_.Name -notmatch '_Total' }
        $busy  = ($cores | Measure-Object -Property PercentProcessorUtility -Maximum).Maximum
        $maxP  = ($cores | Measure-Object -Property PercentProcessorPerformance -Maximum).Maximum
        $line += " | $([math]::Round($base * $maxP / 100)) | $busy"
    } catch { $line += ' | HATA | HATA' }
    if (Test-Path $smi) {
        try {
            $g = (& $smi --query-gpu=utilization.gpu,clocks.gr,power.draw,temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1) -split ',\s*'
            $line += " | $($g[0]) | $($g[1]) | $($g[2]) | $($g[3])"
        } catch { $line += ' | HATA' }
    }
    $r.Add($line)
    Start-Sleep -Seconds 1
}

if ($proc) {
    try { $proc | Wait-Process -Timeout ($MeasureSeconds + 10) -ErrorAction Stop } catch { try { $proc | Stop-Process -Force } catch {} }
    try {
        $inv  = [System.Globalization.CultureInfo]::InvariantCulture
        $rows = Import-Csv $csv
        $ft   = @($rows | ForEach-Object { $v = 0.0; if ([double]::TryParse($_.MsBetweenPresents, [System.Globalization.NumberStyles]::Float, $inv, [ref]$v)) { $v } } | Where-Object { $_ -gt 0 } | Sort-Object)
        $cpuB = @($rows | ForEach-Object { $v = 0.0; if ([double]::TryParse($_.MsCPUBusy, [System.Globalization.NumberStyles]::Float, $inv, [ref]$v)) { $v } })
        $gpuB = @($rows | ForEach-Object { $v = 0.0; if ([double]::TryParse($_.MsGPUBusy, [System.Globalization.NumberStyles]::Float, $inv, [ref]$v)) { $v } })
        $n = $ft.Count
        $avg = ($ft | Measure-Object -Average).Average
        $r.Add(('FPS: ortalama {0}  |  en kotu %1 {1}  |  en kotu %0.1 {2}  |  {3} kare' -f `
            [math]::Round(1000 / $avg), [math]::Round(1000 / $ft[[int][math]::Floor($n * 0.99)]),
            [math]::Round(1000 / $ft[[int][math]::Floor($n * 0.999)]), $n))
        if ($cpuB.Count -and $gpuB.Count) {
            $c = ($cpuB | Measure-Object -Average).Average; $gg = ($gpuB | Measure-Object -Average).Average
            $who = 'islemci'; if ($gg -gt $c) { $who = 'ekran karti' }
            $r.Add(('Kare basina: islemci {0:N2} ms, ekran karti {1:N2} ms  ->  FPS''i {2} belirliyor' -f $c, $gg, $who))
        }
    } catch { $r.Add("FPS hesaplanamadi: $($_.Exception.Message)") }
    Remove-Item $csv -ErrorAction SilentlyContinue
}

Set-Content -Path $out -Value $r
