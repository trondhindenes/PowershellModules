Param (
    [String]$environmentName = "Default",
    [String]$RootFolder = "C:\Scripts\SMA-CI",
    [string]$Operation = "ExportToSMA",
    [string]$ArtifactType = "variable"
)

$VerbosePreference = "Continue"
$ErrorActionPreference = "Stop"

$invocation = (Get-Variable MyInvocation).Value
$directorypath = Split-Path $invocation.MyCommand.Path
$settingspath = $directorypath + '\environments.json'

Write-verbose "Rootfolder is $rootfolder"
Write-verbose "Settings path is $settingspath"


$environments = @()
$environments += (get-content $settingspath -raw) | ConvertFrom-Json 
$ThisEnvironment = $environments | where {$_.EnvironmentName -eq $environmentName}
Write-verbose $ThisEnvironment.webserviceurl

$runbookRootFolder = Join-Path $rootfolder "runbooks"
$variablesRootFolder = Join-Path $rootfolder "variables"
$SchedulesRootFolder = Join-Path $rootfolder "schedules"
$CredentialsRootFolder = Join-Path $rootfolder "credentials"

$Folders = $runbookRootFolder,$variablesRootFolder,$SchedulesRootFolder,$CredentialsRootFolder
foreach ($folder in $folders)
{
    if (!(test-path $folder))
    {
        new-item -Path $folder -itemtype Directory | out-null
    }

}

if (!($PSDefaultParameterValues.Contains("*sma*:webserviceendpoint")))
{
    $PSDefaultParameterValues.Add("*sma*:WebServiceEndpoint",$ThisEnvironment.webserviceurl)
}
Else
{
    $PSDefaultParameterValues."*sma*:WebServiceEndpoint" = $ThisEnvironment.webserviceurl
}


if (($Operation -eq "ImportFromSMA") -and ($ArtifactType -eq "runbook"))
{
    write-verbose "performing Import from SMA to file system"
    $runbooks = Get-SmaRunbook
    #$runbooks.count
    foreach ($runbook in $runbooks)
    {
        #get the definition
        $runbookdef = Get-SmaRunbookDefinition -Id $runbook.RunbookID -Type Published
        $runbookfilename = join-path $runbookRootFolder ($runbook.RunbookName + ".ps1")
        $runbookfilecontent = $runbookdef.Content
        Write-Verbose "writing $runbookfilename"
        Set-Content -Path $runbookfilename -Value $runbookfilecontent -force
    
    }
}

if (($Operation -eq "ExportToSMA") -and ($ArtifactType -eq "runbook"))
{
    write-verbose "performing Export to SMA"

    $runbooksonfile = Get-ChildItem $runbookRootFolder | where {$_.Extension -eq ".ps1"}
    $runbooks = Get-SmaRunbook
    foreach ($runbook in $runbooksonfile)
    {
        
        $runbookname = $runbook.BaseName
        write-verbose "found runbook $runbookname"
        #See if we have a match in SMA
        $smarunbook = $runbooks | where {$_.RunbookName -eq $runbookname}
        if ($smarunbook)
        {
            #we have a match, check content
            $smarunbookdef = Get-SmaRunbookDefinition -Id $smarunbook.RunbookID -Type Published
            if ((get-content $runbook.FullName -Raw) -eq ($smarunbookdef.Content))
            {
                Write-Verbose "source and target are identical for $runbookname - skipping"
            }
            else
            {
                Write-verbose "Updating existing runbook $runbookname"
                Edit-SmaRunbook -Id $smarunbook.RunbookID -Path $runbook.Fullname -Overwrite
                Write-verbose "Publishing updated runbook $runbookname"
                Publish-SmaRunbook -Id $smarunbook.RunbookID
            }
        }
        Else
        {
            Write-Verbose "Creating new runbook $runbookname"
            $smarunbook = Import-SmaRunbook -Path $runbook.FullName
            Publish-SmaRunbook -Id $smarunbook.RunbookID

        }
    
    }

}

if (($Operation -eq "ImportFromSMA") -and ($ArtifactType -eq "variable"))
{
    write-verbose "performing Import from SMA to file system"
    $variables = Get-SmaVariable
    #$runbooks.count
    foreach ($variable in $variables)
    {
        $variablename = $variable.Name
        $variableFileName = "$variablename.json"
        $variable | Select VariableId,Name,Value,Description | ConvertTo-Json | Set-Content -path (Join-Path $variablesRootFolder $variableFileName)
    
    }
}

if (($Operation -eq "ExportToSma") -and ($ArtifactType -eq "variable"))
{
   write-verbose "performing Export to SMA"

    $variablesonfile = Get-ChildItem $variablesRootFolder | where {$_.Extension -eq ".json"}
    $variables = get-smavariable
    foreach ($variable in $variablesonfile)
    {
        $variableObj = get-content $variable.fullname -raw| ConvertFrom-Json
        $variablename = $variable.BaseName
        write-verbose "found variable $variablename"
        #See if we have a match in SMA
        $smavariable = $variables | where {$_.Name -eq $variablename}
        if ($smavariable.value)
        {
            #we have a match, check content
            if ($smavariable.Value -eq $variableobj.Value)
            {
                Write-verbose "identical - skipping"
            }
            Else
            {
                Write-verbose "Updating variable $variablename with new value $($variableObj.value)"
                set-smavariable -name $variablename -value $variableobj.Value
            }

        }
        Else
        {
            Write-Verbose "Creating new variable $variablename"
            new-smavariable -name $variablename -value $variableobj.value

        }
    
    }
}