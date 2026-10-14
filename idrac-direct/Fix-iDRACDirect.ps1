<#
.SYNOPSIS
    Diagnose (and optionally fix) Dell iDRAC Direct USB networking on a Windows laptop
    such as the HP EliteBook 8 G1i.

.DESCRIPTION
    When a laptop is plugged into the iDRAC Direct USB port, the server presents a USB
    network device. Windows should bind it to the in-box "Remote NDIS Compatible Device"
    driver (rndiscmp.inf / usb8023.sys) or download "iDRAC Virtual NIC USB Device" from
    Windows Update. The laptop then gets 169.254.0.4 and reaches iDRAC at 169.254.0.3.

    This script checks every step of that chain and reports the step that fails:
      1. Is the USB device enumerated at all (cable/port/BIOS problem if not)?
      2. Does it have a driver, or is it an "Unknown / RNDIS" device with an error code?
      3. Is the in-box RNDIS driver present on this Windows image?
      4. Do corporate policies block device installation or Windows Update drivers?
      5. Does the network adapter get 169.254.0.x, and can it reach 169.254.0.3?
      6. Could a VPN, firewall or proxy be taking over the traffic?

    With -Fix it also:
      - removes stale/failed iDRAC USB device entries and rescans
      - re-installs the in-box RNDIS driver package for matching devices
      - allows Windows to fetch device drivers from Windows Update (if not policy-locked)

    Run from an elevated PowerShell with the laptop CONNECTED to the iDRAC Direct port
    and the port in iDRAC Direct mode (green LED next to the wrench icon).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Fix-iDRACDirect.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Fix-iDRACDirect.ps1 -Fix
#>
[CmdletBinding()]
param(
    [switch]$Fix,
    [string]$IdracIp = '169.254.0.3',
    [string]$LogPath = (Join-Path ([Environment]::GetFolderPath('Desktop')) ("iDRACDirect-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date)))
)

$ErrorActionPreference = 'Continue'
$findings = New-Object System.Collections.Generic.List[string]

function Write-Section($t) { $m = "`n=== $t ==="; Write-Host $m -ForegroundColor Cyan; Add-Content $LogPath $m }
function Write-Info($t)    { Write-Host "  $t"; Add-Content $LogPath "  $t" }
function Write-Ok($t)      { Write-Host "  [OK]   $t" -ForegroundColor Green;  Add-Content $LogPath "  [OK]   $t" }
function Write-Bad($t)     { Write-Host "  [FAIL] $t" -ForegroundColor Red;    Add-Content $LogPath "  [FAIL] $t"; $findings.Add($t) }
function Write-Warn2($t)   { Write-Host "  [WARN] $t" -ForegroundColor Yellow; Add-Content $LogPath "  [WARN] $t"; $findings.Add($t) }
function Get-RegValue($path, $name) {
    try { (Get-ItemProperty -Path $path -Name $name -ErrorAction Stop).$name } catch { $null }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host "Please run this script from an elevated (Run as administrator) PowerShell." -ForegroundColor Red; exit 1 }

"iDRAC Direct diagnostics - $(Get-Date)" | Set-Content $LogPath

# ---------------------------------------------------------------- 0. System
Write-Section "System"
$cs   = Get-CimInstance Win32_ComputerSystem
$bios = Get-CimInstance Win32_BIOS
$os   = Get-CimInstance Win32_OperatingSystem
$ubr  = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'UBR'
$disp = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' 'DisplayVersion'
Write-Info "Model : $($cs.Manufacturer) $($cs.Model)"
Write-Info "BIOS  : $($bios.SMBIOSBIOSVersion) ($($bios.ReleaseDate))"
Write-Info "OS    : $($os.Caption) $disp build $($os.BuildNumber).$ubr"

# ---------------------------------------------------------------- 1. USB enumeration
Write-Section "1. Is the iDRAC USB device visible to Windows?"
# Dell's USB vendor ID is 413C. Also match generic RNDIS/CDC names in case the
# device enumerates with a generic descriptor.
$pattern = 'VID_413C|RNDIS|Remote NDIS|iDRAC|Ethernet Gadget|CDC Ethernet|NCM'
$candidates = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue | Where-Object {
    ($_.InstanceId -match $pattern) -or ($_.FriendlyName -match $pattern) -or
    ($_.Class -in @('Net','USB','Unknown', $null, '') -and $_.InstanceId -match '^USB\\VID_413C')
}
# Problem devices with no driver often have an empty Class - include any present USB device in error state too.
$problemUsb = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
    Where-Object { $_.InstanceId -like 'USB\*' -and $_.Status -ne 'OK' }
$candidates = @($candidates) + @($problemUsb) | Sort-Object InstanceId -Unique

if (-not $candidates) {
    Write-Bad "No Dell (VID_413C) / RNDIS USB device is present. Windows does not see the iDRAC port at all."
    Write-Info "-> This is a physical-layer problem (cable, laptop port, BIOS USB-C policy, or the server port is not in iDRAC Direct mode)."
    Write-Info "-> Use a USB-C (server) to USB-A (laptop) cable in one of the EliteBook's USB-A ports (Dell's recommendation for 17G)."
} else {
    foreach ($d in $candidates) {
        $hw  = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds'   -ErrorAction SilentlyContinue).Data
        $cid = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_CompatibleIds' -ErrorAction SilentlyContinue).Data
        $inf = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction SilentlyContinue).Data
        $pc  = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_ProblemCode'   -ErrorAction SilentlyContinue).Data
        Write-Info "Device      : $($d.FriendlyName)  [Class=$($d.Class) Status=$($d.Status) Problem=$pc]"
        Write-Info "InstanceId  : $($d.InstanceId)"
        Write-Info "HardwareIds : $($hw -join ', ')"
        Write-Info "CompatIds   : $($cid -join ', ')"
        Write-Info "Driver INF  : $inf"
        if ($d.Status -eq 'OK' -and $d.Class -eq 'Net') {
            Write-Ok "Network driver is bound ($inf)."
        } elseif ($pc -eq 28) {
            Write-Bad "Code 28: no driver installed for '$($d.FriendlyName)'. Bind 'Remote NDIS Compatible Device' manually (see guide, step B)."
        } elseif ($pc -eq 43) {
            Write-Bad "Code 43: USB device descriptor failure. Typically cable / USB-C role negotiation - switch to a USB-A port + USB-C-to-A cable."
        } elseif ($pc -eq 10) {
            Write-Bad "Code 10: device cannot start. Remove the device, unplug/replug, or bind the Microsoft RNDIS driver manually."
        } elseif ($pc -in 31,32,39) {
            Write-Bad "Code $pc on '$($d.FriendlyName)': driver failed to load or is disabled."
        } elseif ($d.Status -ne 'OK') {
            Write-Warn2 "Device '$($d.FriendlyName)' status $($d.Status) (problem code $pc)."
        }
    }
}

# ---------------------------------------------------------------- 2. In-box driver present?
Write-Section "2. Is the Microsoft RNDIS driver present on this image?"
$rndisInf = Join-Path $env:windir 'INF\rndiscmp.inf'
$rndisSys = Join-Path $env:windir 'System32\drivers\usb8023.sys'
$ncmSys   = Join-Path $env:windir 'System32\drivers\UsbNcm.sys'
if (Test-Path $rndisInf) { Write-Ok "rndiscmp.inf present" } else { Write-Bad "rndiscmp.inf (Remote NDIS Compatible Device) is MISSING from $env:windir\INF - the image was stripped." }
if (Test-Path $rndisSys) { Write-Ok "usb8023.sys present" }  else { Write-Bad "usb8023.sys (RNDIS miniport) is MISSING." }
if (Test-Path $ncmSys)   { Write-Ok "UsbNcm.sys present (CDC-NCM class driver)" } else { Write-Info "UsbNcm.sys not present (only needed if the device is CDC-NCM)." }

# ---------------------------------------------------------------- 3. Policies
Write-Section "3. Policies that block driver installation / download"
$rKey = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions'
if (Test-Path $rKey) {
    $r = Get-ItemProperty $rKey
    foreach ($n in 'DenyAll','DenyRemovableDevices','DenyUnspecified','DenyDeviceClasses','DenyDeviceIDs','AllowDeviceClasses','AllowDeviceIDs','AllowAdminInstall') {
        if ($null -ne $r.$n) { Write-Info "$n = $($r.$n)" }
    }
    if ($r.DenyAll -eq 1 -or $r.DenyUnspecified -eq 1 -or $r.DenyRemovableDevices -eq 1 -or $r.DenyDeviceClasses -eq 1 -or $r.DenyDeviceIDs -eq 1) {
        Write-Bad "Device Installation Restrictions policy is active (GPO/Intune). It can silently block the new network adapter. Ask IT to allow class {4d36e972-e325-11ce-bfc1-08002be10318} (Net) or USB\VID_413C*."
        Get-ChildItem $rKey -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Info "  $($_.PSChildName):"; (Get-ItemProperty $_.PSPath).PSObject.Properties | Where-Object Name -notlike 'PS*' | ForEach-Object { Write-Info "    $($_.Value)" }
        }
    }
} else { Write-Ok "No Device Installation Restrictions policy." }

$searchOrder = Get-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig'
$excludeWU   = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate'
$dontSearch  = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' 'DontSearchWindowsUpdate'
$policyOrder = Get-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching' 'SearchOrderConfig'
Write-Info "SearchOrderConfig=$searchOrder  Policy SearchOrderConfig=$policyOrder  ExcludeWUDriversInQualityUpdate=$excludeWU  DontSearchWindowsUpdate=$dontSearch"
if ($searchOrder -eq 0 -or $policyOrder -eq 0 -or $excludeWU -eq 1 -or $dontSearch -eq 1) {
    Write-Warn2 "Windows is NOT allowed to download device drivers from Windows Update. The 'iDRAC Virtual NIC USB Device' driver Dell expects Windows to fetch automatically cannot arrive this way."
} else { Write-Ok "Windows Update driver download allowed." }

# ---------------------------------------------------------------- 4. Network
Write-Section "4. Network adapter and reachability"
$nics = Get-NetAdapter -IncludeHidden -ErrorAction SilentlyContinue |
    Where-Object { $_.InterfaceDescription -match 'Remote NDIS|RNDIS|iDRAC|NCM|USB' -or $_.PnPDeviceID -match 'VID_413C' }
if (-not $nics) {
    Write-Bad "No iDRAC/RNDIS network adapter exists in Network Connections."
} else {
    foreach ($n in $nics) {
        Write-Info "Adapter: $($n.Name) | $($n.InterfaceDescription) | Status=$($n.Status) | Admin=$($n.AdminStatus)"
        if ($n.AdminStatus -ne 'Up') { Write-Bad "Adapter '$($n.Name)' is disabled." }
        $ips = Get-NetIPAddress -InterfaceIndex $n.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        foreach ($ip in $ips) { Write-Info "  IPv4: $($ip.IPAddress)/$($ip.PrefixLength) ($($ip.PrefixOrigin))" }
        if (-not ($ips.IPAddress -match '^169\.254\.')) { Write-Warn2 "Adapter has no 169.254.x.x address (expected 169.254.0.4 from iDRAC)." }
    }
}
$ping = Test-Connection -ComputerName $IdracIp -Count 2 -Quiet -ErrorAction SilentlyContinue
if ($ping) { Write-Ok "Ping $IdracIp OK" } else { Write-Bad "Cannot ping $IdracIp." }
$tcp = Test-NetConnection -ComputerName $IdracIp -Port 443 -WarningAction SilentlyContinue
if ($tcp.TcpTestSucceeded) { Write-Ok "TCP 443 to $IdracIp OK - open https://$IdracIp in a browser." } else { Write-Info "TCP 443 to $IdracIp not reachable." }
$route = Find-NetRoute -RemoteIPAddress $IdracIp -ErrorAction SilentlyContinue | Select-Object -First 1
if ($route) { Write-Info "Route to $IdracIp uses interface: $((Get-NetAdapter -InterfaceIndex $route.InterfaceIndex -ErrorAction SilentlyContinue).InterfaceDescription)" }

# ---------------------------------------------------------------- 5. VPN / firewall / proxy
Write-Section "5. VPN, proxy, security software"
$vpn = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -match 'VPN|AnyConnect|GlobalProtect|PANGP|Fortinet|Zscaler|Pulse|Ivanti|Wintun|WireGuard|TAP-|NordLynx|Juniper|Netskope' }
if ($vpn) { $vpn | ForEach-Object { Write-Warn2 "Active VPN adapter: $($_.InterfaceDescription). Always-on/force-tunnel VPNs block local 169.254.x.x traffic - disconnect it while using iDRAC Direct." } }
else { Write-Ok "No active VPN adapter detected." }
$wh = (netsh winhttp show proxy) -join ' '
Write-Info "WinHTTP proxy: $($wh -replace '\s+',' ')"
$ieProxy = Get-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'ProxyEnable'
if ($ieProxy -eq 1) { Write-Warn2 "A browser proxy is enabled. Add 169.254.* to the proxy bypass list or the browser will send https://$IdracIp to the proxy." }
$av = Get-CimInstance -Namespace root/SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction SilentlyContinue
if ($av) { Write-Info "Security products: $(($av.displayName) -join ', ')" }

# ---------------------------------------------------------------- Fix
if ($Fix) {
    Write-Section "FIX"
    if ($searchOrder -eq 0 -and $null -eq $policyOrder -and $excludeWU -ne 1 -and $dontSearch -ne 1) {
        Set-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' -Name SearchOrderConfig -Value 1 -Type DWord
        Write-Info "Enabled automatic driver download from Windows Update (SearchOrderConfig=1)."
    }

    $targets = $candidates | Where-Object { $_.InstanceId -match 'VID_413C' -or $_.FriendlyName -match 'RNDIS|Remote NDIS|iDRAC' }
    foreach ($d in $targets) {
        if ($d.Status -ne 'OK') {
            Write-Info "Removing failed device entry $($d.InstanceId)"
            pnputil /remove-device "$($d.InstanceId)" | Out-Null
        }
    }
    if (Test-Path $rndisInf) {
        Write-Info "Re-staging in-box RNDIS driver package (rndiscmp.inf)"
        pnputil /add-driver $rndisInf /install | ForEach-Object { Write-Info "  $_" }
    }
    Write-Info "Rescanning hardware..."
    pnputil /scan-devices | Out-Null
    Start-Sleep -Seconds 8

    $after = Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -match 'VID_413C' -or $_.FriendlyName -match 'RNDIS|Remote NDIS|iDRAC' }
    $after | ForEach-Object { Write-Info "After: $($_.FriendlyName) [$($_.Class)] Status=$($_.Status)" }
    if ($after | Where-Object { $_.Class -eq 'Net' -and $_.Status -eq 'OK' }) {
        Write-Ok "iDRAC network adapter is now working. Browse to https://$IdracIp"
    } else {
        Write-Warn2 "Automatic binding did not succeed. Bind the driver manually: Device Manager > the device > Update driver > Browse my computer > Let me pick > Network adapters > Microsoft > Remote NDIS Compatible Device."
        Write-Info "Opening Device Manager..."
        Start-Process devmgmt.msc
    }
}

# ---------------------------------------------------------------- Summary
Write-Section "SUMMARY"
if ($findings.Count -eq 0) { Write-Ok "No problems detected." }
else { $i = 1; foreach ($f in $findings) { Write-Info ("{0}. {1}" -f $i++, $f) } }
Write-Host "`nLog saved to $LogPath" -ForegroundColor Cyan
