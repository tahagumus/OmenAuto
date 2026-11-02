# Durum.ps1 - Sadece OKUMA yapar. Sensorlerin bu laptopta calisip calismadigini kontrol eder.
# Sonuclari Durum.txt dosyasina yazar.
param([int]$Count = 10, [int]$Interval = 3)

. (Join-Path $PSScriptRoot 'HpBios.ps1')
$out = Join-Path $PSScriptRoot 'Durum.txt'

function Out-Line([string]$s) { Add-Content -Path $out -Value $s; Write-Host $s }

Set-Content -Path $out -Value ("===== Durum testi {0} =====" -f (Get-Date))

try { Out-Line ("Thermal Policy Version: {0}" -f (Get-HpThermalPolicy)) } catch { Out-Line "Thermal Policy HATA: $($_.Exception.Message)" }
try { $g = Get-HpGpuPower; Out-Line ("GPU Power [CustomTgp,Ppab,DState,Peak]: {0}" -f ($g -join ',')) } catch { Out-Line "GPU Power HATA: $($_.Exception.Message)" }
try {
    $acpi = Get-AcpiTemps
    if ($acpi) { foreach ($z in $acpi) { Out-Line ("ACPI bolge: {0} = {1} C" -f $z.Name, $z.C) } } else { Out-Line "ACPI bolge: yok" }
} catch { Out-Line "ACPI HATA: $($_.Exception.Message)" }

for ($i = 1; $i -le $Count; $i++) {
    $parts = @((Get-Date -Format 'HH:mm:ss'))
    try { $parts += "BIOS sicaklik=$(Get-HpBiosTemp)" } catch { $parts += "BIOS sicaklik=HATA" }
    try { $parts += "GPU(nvidia)=$(Get-NvidiaTemp)" } catch { $parts += "GPU=HATA" }
    try { $f = Get-HpFanLevel; $parts += "Fan CPU=$($f[0]) GPU=$($f[1])" } catch { $parts += "Fan=HATA" }
    try { $parts += "TamHiz=$(Get-HpMaxFan)" } catch { $parts += "TamHiz=HATA" }
    try { $a = Get-AcpiTemps; if ($a) { $parts += "ACPI=" + (($a | ForEach-Object { $_.C }) -join '/') } } catch {}
    Out-Line ($parts -join '  ')
    if ($i -lt $Count) { Start-Sleep -Seconds $Interval }
}
Out-Line "Bitti."
