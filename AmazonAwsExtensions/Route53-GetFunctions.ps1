#$creds = Get-AWSCredentials -StoredCredentials "trond@hindenes.com"

Function Get-AwsRoute53Zone 
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param (
        [Parameter(Position=0)]
        [string]$ZoneName,
        
        # The credentials object should be generated from running Get-AWSCredentials
        [Parameter(Mandatory=$true)]
        [Amazon.Runtime.BasicAWSCredentials]$credentials,

        [Amazon.RegionEndpoint]$region = [Amazon.RegionEndpoint]::USWest1,
        $AddCredstoReturnedObject = $true,
        $AddRegiontoReturnedObject = $true

    )

    #add the trailing dot
    if (!($ZoneName.EndsWith(".")) -and $ZoneName)
        {$ZoneName += "."}

    $route53client = New-Object Amazon.Route53.AmazonRoute53Client -ArgumentList $credentials,$region

    $hostedZones = $route53client.ListHostedZones()
    $zone = $hostedZones.HostedZones

    if ($ZoneName)
        {
            $zone = $zone | where {$_.Name -like $ZoneName}
            return $zone
        }
    if ($AddCredstoReturnedObject)
    {
        $zone | ForEach-Object {
            $zone | Add-Member -MemberType NoteProperty -Name "Credentials" -Value $credentials -Force
            }
    }

    if ($addregionToReturnedObject)
    {
        $zone | ForEach-Object {
            $zone | Add-Member -MemberType NoteProperty -Name "Region" -Value $region -Force
            }
    }

    $zone
   
}

Function Get-AwsRoute53Record
{
    [CmdletBinding(SupportsShouldProcess=$true)]
    Param (
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Amazon.Runtime.BasicAWSCredentials]$credentials,
        
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [Amazon.Route53.Model.HostedZone]$Zone,
        
        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [Amazon.RegionEndpoint]$region = [Amazon.RegionEndpoint]::USWest1,

        [ValidateSet("A", "SOA", "PTR", "MX", "CNAME","TXT","SRV","SPF","AAAA","NS")]
        $RecordType
    )

    Begin {}
    Process
    {
        $route53client = New-Object Amazon.Route53.AmazonRoute53Client -ArgumentList $credentials,$region
        $ZonesRequest = New-Object -TypeName Amazon.Route53.Model.ListResourceRecordSetsRequest
        Write-verbose "Retrieving records for zone $($zone.id) using region $region"
        $ZonesRequest.HostedzoneId = $zone.Id
        $Recordset = $route53client.ListResourceRecordSets($ZonesRequest)
        $records = $Recordset.ResourceRecordSets
        if ($RecordType)
            {
                $records  = $records | where {$_.Type -eq $RecordType}
            }
        
        $Records

    }
}