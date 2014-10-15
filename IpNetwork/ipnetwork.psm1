#add-type -Path "$psscriptroot\LukeSkywalker.IPNetwork.dll"

Function Get-IpNetworkAddresses
{
    Param ([String]$Subnet)
    $IPNetwork = [LukeSkywalker.IPNetwork.IPNetwork]::Parse($subnet)
    [LukeSkywalker.IPNetwork.IPAddressCollection]$addresscollection = [LukeSkywalker.IPNetwork.IPNetwork]::ListIPAddress($IPNetwork)
    $addresscollection
}