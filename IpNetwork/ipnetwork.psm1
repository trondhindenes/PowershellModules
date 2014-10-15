<#
.Synopsis
   Converts a CIDR-notated string into an array of ip addresses
.DESCRIPTION

.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Get-IpNetworkAddresses -subnet "192.168.1.0/24"
#>
Function Get-IpNetworkAddresses
{
    Param ([String]$Subnet)
    $IPNetwork = [LukeSkywalker.IPNetwork.IPNetwork]::Parse($subnet)
    [LukeSkywalker.IPNetwork.IPAddressCollection]$addresscollection = [LukeSkywalker.IPNetwork.IPNetwork]::ListIPAddress($IPNetwork)
    $addresscollection
}