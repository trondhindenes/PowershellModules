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

Function Get-IPNetworkFromIpAddress
{
    Param (
        [Parameter(Mandatory=$true,ParameterSetName='CIDR')]
        [string]$IpAddressWithCidr,
        
        [Parameter(Mandatory=$true,ParameterSetName='IPandsubnet')]
        [string]$IpAddress,
        [Parameter(Mandatory=$true,ParameterSetName='IPandsubnet')]
        [string]$Subnetmask
    )

    if ($IpAddress)
    {
        $cidr = Get-SubnetCidr -Subnet $Subnetmask
        $IpAddressWithCidr = "$ipaddress/$cidr"
    }

    if ($IpAddressWithCidr.Split("/").count -ne 2)
    {
        Write-error "Couldn't parse address. Specify as '192.168.1.5/24'"
        break
    }
    [LukeSkywalker.IPNetwork.IPNetwork]::Parse($IpAddressWithCidr)
}

Function Get-SubnetCidr
{
    Param ([String]$Subnet)
    if ($subnet.split(".").count -ne 4)
    {
        Write-error "Couldn't parse address. Specify as '255.255.255.0'"
        break
    }
    [LukeSkywalker.IPNetwork.IPNetwork]::ToCidr($subnet)
}

