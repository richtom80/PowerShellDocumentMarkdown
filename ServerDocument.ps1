$hostname = hostname
$systemInfo = Get-WmiObject -Class Win32_OperatingSystem
$cpuInfo = Get-WmiObject -Class Win32_Processor
$memoryInfo = Get-WmiObject -Class Win32_PhysicalMemory | Where-Object {$_.DeviceLocator -eq "M0001" }
$NicInfo = Get-NetIPAddress -AddressFamily IPv4
$softwareInfo = Get-WmiObject -Class Win32_Product
$roles = Get-WindowsFeature | Where-Object {$_.InstallState -eq 'Installed'}
$DiskInfo = get-wmiobject -class win32_logicaldisk
$Shares = Get-SMBShare

$SysOut = "# $(hostname) Configuration

#server

# System Information

- Operating System: $($systemInfo.Caption)
- Service Pack: $($systemInfo.ServicePackMajorVersion)
- Processor: $($cpuInfo.Name)
- Memory: $([Math]::round($memoryInfo.Capacity/1GB))GB

## Disk Information

| Disk | Name | Size | Free |
| - | - | - | - |`n"
$($DiskInfo | ForEach-Object{
    $SysOut += "| $($_.DeviceID) | $($_.VolumeName) | $([Math]::round($_.Size/1GB))GB | $([Math]::round($_.FreeSpace/1GB))GB |`n"
})
$SysOut += "
## Network Information

| Alias | IP | GW | DNS1 | DNS2 | MAC |
| - | - | - | - | - | - |`n"
$($NicInfo | ForEach-Object{
    $DNSServers = Get-DnsClientServerAddress -InterfaceAlias "$($_.InterfaceAlias)"
    $Gateway = Get-NetIPConfiguration -InterfaceAlias  "$($_.InterfaceAlias)"
    $MacAddr = Get-NetAdapter -InterfaceIndex $($_.InterfaceIndex)
    $SysOut += "| $($_.InterfaceAlias) | $($_.IPAddress) | $($Gateway.IPv4DefaultGateway.NextHop) | $($DNSServers[0].ServerAddresses[0]) |  $($DNSServers[0].ServerAddresses[1]) | $($MACAddr.MacAddress) |`n"
})
$SysOut += "
## Shares Information

| Name | Path | Description |
| - | - | - |`n"
$($Shares | ForEach-Object {
    $SysOut += "| $($_.Name) | $($_.Path) | $($_.Description) |`n"
})
$SysOut +="
# Software Information

## Installed Roles

| Name | Display Name |
| - | - |`n"
$($roles | ForEach-Object {
	$SysOut += "| $($_.Name) | $($_.DisplayName) |`n"
})

$SysOut += "
## Installed Software

| Vendor | Software | Version |
| - | - | - |`n"
$($softwareInfo | Select-Object -Property Vendor, Name, Version | ForEach-Object {
    $SysOut += "| $($_.Vendor) | $($_.Name) | $($_.Version) |`n"
})

$SysOut