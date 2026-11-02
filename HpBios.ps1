# HpBios.ps1 - HP OMEN / Victus BIOS'una WMI uzerinden komut gonderen yardimci fonksiyonlar.
# Komut kodlari OmenMon (GPL3, omenmon.github.io) kaynak kodundan alinmistir.
# Surucu (WinRing0) kullanmaz; Vanguard ile sorun cikarmaz. Yonetici yetkisi gerekir.

$script:HpSign = [byte[]](0x53, 0x45, 0x43, 0x55)   # "SECU"
$script:HpCmdDefault = [uint32]0x20008

function Invoke-HpBios {
    param(
        [uint32]$Command = $script:HpCmdDefault,
        [uint32]$Type,
        [byte[]]$Data = $null,
        [ValidateSet(0, 4, 128, 1024, 4096)] [int]$OutSize = 0
    )
    $cls = Get-CimClass -Namespace 'root\wmi' -ClassName 'hpqBDataIn'
    $props = @{
        Sign        = $script:HpSign
        Command     = $Command
        CommandType = $Type
        Size        = [uint32]0
    }
    if ($Data) {
        $props['hpqBData'] = $Data
        $props['Size'] = [uint32]$Data.Length
    }
    $in  = New-CimInstance -CimClass $cls -ClientOnly -Property $props
    $obj = Get-CimInstance -Namespace 'root\wmi' -ClassName 'hpqBIntM'
    $res = Invoke-CimMethod -InputObject $obj -MethodName ("hpqBIOSInt" + $OutSize) -Arguments @{ InData = [ciminstance]$in }
    $out = $res.OutData
    [pscustomobject]@{
        ReturnCode = [int]$out.rwReturnCode
        Data       = if ($OutSize -gt 0) { [byte[]]$out.Data } else { $null }
    }
}

# --- Okuma ---
function Get-HpBiosTemp      { $r = Invoke-HpBios -Type 0x23 -Data ([byte[]](1,0,0,0)) -OutSize 4;   if ($r.ReturnCode -eq 0) { [int]$r.Data[0] } else { $null } }
function Get-HpFanLevel      { $r = Invoke-HpBios -Type 0x2D -Data ([byte[]](0,0,0,0)) -OutSize 128; if ($r.ReturnCode -eq 0) { ,@([int]$r.Data[0], [int]$r.Data[1]) } else { $null } }
function Get-HpMaxFan        { $r = Invoke-HpBios -Type 0x26 -Data ([byte[]](0,0,0,0)) -OutSize 4;   if ($r.ReturnCode -eq 0) { [bool]($r.Data[0] -band 1) } else { $null } }
function Get-HpGpuPower      { $r = Invoke-HpBios -Type 0x21 -Data ([byte[]](0,0,0,0)) -OutSize 4;   if ($r.ReturnCode -eq 0) { [byte[]]$r.Data[0..3] } else { $null } }
function Get-HpThermalPolicy { $r = Invoke-HpBios -Type 0x28 -OutSize 128; if ($r.ReturnCode -eq 0) { [int]$r.Data[3] } else { $null } }

# --- Yazma ---
# FanMode: 0 = Default, 1 = Performance, 3 = Quiet (bu laptopta dogrulandi)
function Set-HpFanMode([byte]$Mode) { (Invoke-HpBios -Type 0x1A -Data ([byte[]](0xFF, $Mode, 0, 0))).ReturnCode }
function Set-HpMaxFan([bool]$On)    { (Invoke-HpBios -Type 0x27 -Data ([byte[]]($(if ($On) {1} else {0}), 0, 0, 0))).ReturnCode }
# GpuPower: [CustomTgp, Ppab, DState, PeakTemp]  Maksimum = 1,1,1,0
function Set-HpGpuPower([byte[]]$Data) { (Invoke-HpBios -Type 0x22 -Data $Data).ReturnCode }

# --- Windows / NVIDIA tarafindan sicaklik ---
function Get-NvidiaTemp {
    $smi = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
    if (-not (Test-Path $smi)) { return $null }
    try {
        $t = & $smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($t -match '^\s*\d+') { return [int]$t.Trim() }
    } catch {}
    return $null
}

function Get-AcpiTemps {
    $list = @()
    try {
        foreach ($z in Get-CimInstance -Namespace 'root\wmi' -ClassName 'MSAcpi_ThermalZoneTemperature' -ErrorAction Stop) {
            $list += [pscustomobject]@{ Name = $z.InstanceName; C = [math]::Round($z.CurrentTemperature / 10 - 273.15, 1) }
        }
    } catch {}
    return $list
}
