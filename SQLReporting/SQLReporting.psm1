Function Get-SSRSInstances
    {
        Param (
            [string]$InstanceName
        
        )
        $ReportingWMIInstances = @()
        $ReportingWMIInstances += Get-WmiObject -Namespace "Root\Microsoft\SqlServer\ReportServer" -Class "__Namespace" -ErrorAction 0

        if ($ReportingWMIInstances.count -lt 1)
            {
                Write-Error "Couldn't find any SQL Server Reporting Instances on this computer"
            }

        $ReportingInstances = @()

        Foreach ($ReportingWMIInstance in $ReportingWMIInstances)
            {
                #Find the SRS Version and admin instance
                $WMIInstanceName = $ReportingWMIInstance.Name
                #WMIInstanceName will be in the format "RS_InstanceName", split away the rs part
                $InstanceDisplayName = $WMIInstanceName.Replace("RS_","")


                $InstanceNameSpace = "Root\Microsoft\SqlServer\ReportServer\$WMIInstanceName"
                $VersionInstance = Get-WmiObject -Namespace $InstanceNameSpace -Class "__Namespace" -ErrorAction 0
                $VersionInstanceName = $VersionInstance.Name
                $AdminNameSpace = "Root\Microsoft\SqlServer\ReportServer\$WMIInstanceName\$VersionInstanceName\Admin"
                $ConfigSetting = Get-WmiObject -Namespace $AdminNameSpace -Class "MSReportServer_ConfigurationSetting" | where {$_.InstanceName -eq $InstanceDisplayName}
                $ConfigSetting | add-member -MemberType NoteProperty -Name "InstanceAdminNameSpace" -Value $AdminNameSpace
                [xml]$ReportServerInstanceConfig = Get-content $ConfigSetting.PathName
                $ConfigSetting | add-member -MemberType NoteProperty -Name "ConfigFileSettings" -Value $ReportServerInstanceConfig
                $ReportingInstances += $ConfigSetting
                
            }

            if ($InstanceName)
               {
                    $ReportingInstances = $ReportingInstances | where {$_.InstanceName -like $InstanceName}
               }

        $ReportingInstances

    }


    #  http://randypaulo.wordpress.com/2012/02/21/how-to-install-deploy-ssrs-rdl-using-powershell/
function Publish-SSRSReport
            (
	            [Parameter(Position=0,Mandatory=$true)]
	            [Alias("url")]
	            [string]$webServiceUrl,

	            [ValidateScript({Test-Path $_})]
	            [Parameter(Position=1,Mandatory=$true)]
	            [Alias("rdl")]
	            [string]$rdlFile,

	            [Parameter(Position=2)]
	            [Alias("folder")]
	            [string]$reportFolder="",

	            [Parameter(Position=3)]
	            [Alias("name")]
	            [string]$reportName="",

	            [bool]$force=$false, 
                [System.Management.Automation.PsCredential]$Credentials
            )
        {
            #$ErrorActionPreference="Stop"

            if ($webServiceUrl -notcontains "asmx")
                {
                    
                     $webServiceUrl = "$webServiceUrl/ReportService2010.asmx?WSDL"
                     #$webserviceurl = $webServiceUrl.Replace("//","/")
                     

                }

	        #Create Proxy
	        Write-Verbose "[Install-SSRSRDL()] Creating Proxy, connecting to : $webServiceUrl"
	        $ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -UseDefaultCredential -ErrorAction 0
            
            #Test that we're connected
            $members = $ssrsProxy | get-member -ErrorAction 0
            if (!($members))
                {
                    if ($credentials)
                        {
                            $ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -Credential $credentials
                        }
                    Else
                        {
                            $ssrsProxy = New-WebServiceProxy -Uri $webServiceUrl -Credential (Get-Credential)
                        }
                    

                }
            $members = $ssrsProxy | get-member -ErrorAction 0
            if (!($members))
                {
                    Write-Error "Could not connect to the Reporting Service"
                    Break
                }
	        $reportPath = "/"

	        if($force)
	        {
		        #Check if folder is existing, create if not found
		        try
		        {
			        $ssrsProxy.CreateFolder($reportFolder, $reportPath, $null)
			        Write-Verbose "[Install-SSRSRDL()] Created new folder: $reportFolder"
		        }
		        catch [System.Web.Services.Protocols.SoapException]
		        {
			        if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]")
			        {
				        Write-Verbose "[Install-SSRSRDL()] Folder: $reportFolder already exists."
			        }
			        else
			        {
				        $msg = "[Install-SSRSRDL()] Error creating folder: $reportFolder. Msg: '{0}'" -f $_.Exception.Detail.InnerText
				        Write-Error $msg
			        }
		        }

	        }

	        #Set reportname if blank, default will be the filename without extension
	        if(!($reportName)){ $reportName = [System.IO.Path]::GetFileNameWithoutExtension($rdlFile);}
	        Write-Verbose "[Install-SSRSRDL()] Report name set to: $reportName"

	       
		        #Get Report content in bytes
		        Write-Verbose "[Install-SSRSRDL()] Getting file content (byte) of : $rdlFile"
		        $byteArray = gc $rdlFile -encoding byte
		        $msg = "[Install-SSRSRDL()] Total length: {0}" -f $byteArray.Length
		        Write-Verbose $msg

		        $reportFolder = $reportPath + $reportFolder
		        Write-Verbose "[Install-SSRSRDL()] Uploading to: $reportFolder"

		        #Call Proxy to upload report
		        #$warnings = $ssrsProxy.CreateReport($reportName,$reportFolder,$force,$byteArray,$null)
                [Ref]$UploadWarnings = $null
                $ssrsProxy.CreateCatalogItem("Report",$reportName,$reportFolder,$force,$byteArray,$null,$UploadWarnings) | out-null

                $allitems = $ssrsProxy.ListChildren("/",$true)
                #Select the newest report with correct name
                $ThisReport = $allitems | where {($_.Name -eq $ReportName) -and ($_.TypeName -eq "Report")} | Sort-Object ModifiedDate -Descending | Select -first 1
                $dataSources = $ssrsProxy.GetItemDataSources($thisreport.path)
                
                foreach ($datasource in $datasources)
                    {
                
                         $proxyNamespace = $datasource.GetType().Namespace
                         $myDataSource = New-Object ("$proxyNamespace.DataSource")
                         $myDataSource.Name = $datasource.Name
                         $myDataSource.Item = New-Object ("$proxyNamespace.DataSourceReference")
                         $myDataSource.Item.Reference = ($allitems | where {($_.TypeName -eq "DataSource") -and ($_.Name -eq $Datasource.Name)}).Path

                         $datasource.item = $myDataSource.Item

                         $ssrsProxy.SetItemDataSources($thisreport.path, $myDataSource)

                         Write-Verbose "Report's DataSource Reference ($($myDataSource.Name)): $($myDataSource.Item.Reference)";
                    }




	       
	        

        }

<#
    .Synopsis
       Uploads all SQL Server Reporting report files in a folder structure
    .DESCRIPTION
       Reports will be uploaded to the SSRS folder corresponding to the "Description"-field in the report definition. 
       This folder will be created on the server if it doesn't already exist.

       Any existing reports with the same name will be overwritten.

       Specify the "credentials" parameter if the script is run from an account without permissions on the report server. If this parameter is omitted, the script will
       attempt to use the current user's default credentials. If this fails, the script will prompt for credentials for each report uploaded (which is a hassle).

       The script will not upload datasources or datasets, but any references to datasources in uploaded reports will be relinked to datasources on the server, if these exist.
    .EXAMPLE
       Publish-SSRSReportsDirectory -directory "C:\MyReportFiles" -WebServiceURL "http://myreportserver/reports"
    .EXAMPLE
       $cred = Get-Credential
       Publish-SSRSReportsDirectory -directory "C:\MyReportFiles" -WebServiceURL "http://myreportserver/reports" -credentials $cred
    .EXAMPLE
       Publish-SSRSReportsDirectory -directory "C:\MyReportFiles" -WebServiceURL "http://myreportserver/reports" -credentials (get-credential) -verbose
    .INPUTS
    .OUTPUTS
       
#>
Function Publish-SSRSReportsDirectory
            (
        [Parameter(Position=0,Mandatory=$true)]
        [Alias("folder")]
        [string]$Directory,
        [Parameter(Position=1,Mandatory=$true)]
        [Alias("url")]
        [string]$webServiceUrl,
        [Parameter(Position=2,Mandatory=$false)]
        [System.Management.Automation.PsCredential]$Credentials = $null
        )
    {
        $Reports = Get-childitem $Directory -Recurse -Include *.rdl

        #Get Description field from each report xml
        Foreach ($report in $reports)
            {
                [xml]$ReportXMl = get-content $Report
                $Description = $reportxml.Report.Description
                if (!($Description))
                    {
                        $Description = ""
                    }
                $report | add-member -MemberType NoteProperty -Name "TargetFolder" -Value $Description -force
                $ReportFullname = $report.FullName
                $TargetFolder = $report.TargetFolder

                Write-Verbose "Publish-SSRSReport -webServiceUrl $webServiceUrl -rdlFile $ReportFullname -reportFolder $TargetFolder -force -Credentials $Credentials"
                Publish-SSRSReport -webServiceUrl $webServiceUrl -rdlFile $ReportFullname -reportFolder $TargetFolder -force $true -Credentials $Credentials
                

            }

    }

