#PowerShell implementation based on c# example found here:
#https://gist.github.com/j3tm0t0/2024833

Function Create-AwsRoute53Record
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
        [String]$RecordType,

        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        $value,

        [int]$TTL,
        
        # If wait is specified, the function will wait until AWS confirms that the change is in sync, 
        #meaning it has been written to the zone
        $wait = $false,

        # If wait is specified, waitinterval specifies the interval in miliseconds between each polling
        [int]$waitinterval = 1000


        )

    Begin 
    {
        $route53client = New-Object Amazon.Route53.AmazonRoute53Client -ArgumentList $creds,$region
    }

    Process
    {
        $records = @()
        foreach ($valueentry in $value)
            {
                $Record = new-object Amazon.Route53.Model.ResourceRecord
                $record.Value = $valueentry
                $records += $Record
                $record = $null

            }

        #add the trailing dot
        if (!($Name.EndsWith(".")) -and $Name)
            {$Name += "."}

        $ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
        $ResourceRecordSet.Type = $RecordType
        $ResourceRecordSet.ResourceRecords = $Records
        $ResourceRecordSet.Name = $Name
        $ResourceRecordSet.TTL = $ttl

        $changebatch = New-Object Amazon.Route53.Model.ChangeBatch
        $change = New-Object Amazon.Route53.Model.Change
        $change.Action = "Create"
        $change.ResourceRecordSet = $ResourceRecordSet
        $changebatch.Changes = $change

        $ChangeResourceRecordSetsRequest = new-object Amazon.Route53.Model.ChangeResourceRecordSetsRequest
        $ChangeResourceRecordSetsRequest.HostedZoneId = $Zone.Id
        $ChangeResourceRecordSetsRequest.ChangeBatch = $changebatch

        Try
        {
            $result = $route53client.ChangeResourceRecordSets($ChangeResourceRecordSetsRequest)
        }
        Catch [system.Exception]
        {
            Write-error $error[0]
        }
        
        if ($result)
        {
            $result = $result.ChangeInfo
            if ($wait)
            {
            #Keep polling the changeinfo until it is no longer pending
            Do 
                {
                    #get change status
                    if ($SecondPoll)
                        {Start-Sleep -Milliseconds $waitinterval}
                    $changeGet = new-object Amazon.Route53.Model.GetChangeRequest
                    $changeGet.Id = $result.Id
                    $status = $route53client.GetChange($changeGet)
                    $SecondPoll = $true
                    Write-verbose "Waiting for changes to sync. Current status is $($status.ChangeInfo.Status.Value)"
                }
            Until ($status.ChangeInfo.Status.Value -eq "INSYNC")

        
            }
        
            $Status

        }

        
    }
}


