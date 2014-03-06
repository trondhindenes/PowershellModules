Function Get-TransmissionSessionID	
	{
		Param
			(
				[parameter(Mandatory=$true)] 
				[String]$TransmissionUrl,
                [System.Management.Automation.PsCredential]$credential

				
			)

        if ($credential)
            {
                $Password = ($Credential.Password) | ConvertTo-PlainText
                $Username = $credential.UserName

                
            }
			
		$xHTTP = new-object -com msxml2.xmlhttp
			$xHTTP.open("GET",$TransmissionUrl,$false, $UserName, $Password)
			$xHTTP.send()
			$html = $xHTTP.ResponseText; # returns the html doc like downloadstring
			#$xHTTP.status # returns the status code
			$pattern =  '(?i)<code[^>]*>(.*)</code>'
			$result = [Regex]::Matches($html, $pattern)
			$TransmissionSessionID = $result.Value.Split(":")[1].Trim().Replace("</code>","")
		 #End of old-school method which seems to be working best
		$TransmissionSessionID
		
	}
	
	

function ConvertTo-Base64($string) {
   $bytes  = [System.Text.Encoding]::UTF8.GetBytes($string);
   $encoded = [System.Convert]::ToBase64String($bytes); 

   return $encoded;
}

Function ConvertTo-PlainText
    {
        Param(
            [parameter(ValueFromPipeLine= $true, Mandatory=$true, Position=0)] 
            [System.security.securestring]$secure
        )
        $marshal = [Runtime.InteropServices.Marshal]
        $marshal::PtrToStringAuto( $marshal::SecureStringToBSTR($secure) )
        
    }

Function Save-TransmissionCredential
    {
        <#
    .Synopsis
       Saves your transmission credentials (username/Password) so you won't have to enter them every time
    .DESCRIPTION
       Instead of using the "Credential" parameter on every Transmission command, you can save your credentials
       to an encrypted file, and have PowerShell use them whenever they're needed. We are storing them in 
       %Temp% (or C:\users\username\Appdata\Local\Temp to be precise) in two files, called TransmissionPassword.cred and
       TransmissionUser.Cred. The Password file is encrypted and unusable for other users or on other computers.

       After you've run Save-TransmissionCredential you can use the "UseSaveCredential" in every other command to 
       load your saved credentials. 

       If you put this in your PowerSHell profile, you won't have to bother with it at all:
       $PSDefaultParameterValues.Add("*Transmission*:UseSavedCredential",$true)

       If you want to overwrite the saved credentials, just run Save-TranmissionCredential again, it will overwrite the previous
       files with new ones
    .EXAMPLE
       Save-TransmissionCredential

    .EXAMPLE
       $cred = Get-Credential
       Save-TransmissionCredential -credential $cred
    .EXAMPLE
       $cred = Get-Credential
       $cred | save-transmissionCredential
    .INPUTS
       System.Management.Automation.PsCredential
    .OUTPUTS
       None
    #>

        Param(
             
            [parameter(ValueFromPipeLine= $true, Mandatory=$true, Position=0)] 
            [System.Management.Automation.PsCredential]$Credential

        )

        $TransmissionPasswordFile = $env:TEMP
        $transmissionPasswordFile += "\TransmissionPassword.cred"
        $TransmissionUserFile = $env:TEMP
        $TransmissionUserFile  += "\TransmissionUser.cred"
         
        $credential.Password | ConvertFrom-SecureString |Set-Content $TransmissionPasswordFile -force
		$credential.Username | Set-Content $TransmissionUserFile -force


    }
 


Function Get-TransmissionTorrent
	{
	<#
	.Synopsis
	Get transmission's torrents
	.Description
	This function returns an array of all torrents added to the Transmission server, active or not.
	
	The functino takes only one parameter (transmissionURL), which is the address of your transmission server, normally this would
	be in the shape of "http://myserver:9091/transmission/rpc"
	
	All *-transmission CmdLets take this parameters, so it might be a good idea to add it to your PsDefaultParameters property, which can be done like this:
	$PsdefaultParameterValues.Add("*Transmission:TransmissionUrl"="http://transmissionserver:9091/transmission/rpc"
	
	The CmdLet returns an array of all torrents. The CmdLet does not take any search parameters, but filtering can be done with piping and the "Where-Object" CmdLet.

    If your Transmission server is password-enabled, this is taken care of. You can either use the "credential" parameter each time you use a tranmission function,
    or you can use the Save-TransmissionCredential to permanently save the credentials on your system. If you combine this with setting "UseSavedCredential" to $true
    in your PSDefaultParamters property you will have a secure and seamless experience.

    For example, enter the foloowing in your PowerShell Profile:
    $PSDefaultParameterValues.Add("*Transmission*:UseSavedCredential",$true)

	  
	.Example
	Get-TransmissionTorrent -TransmissionUrl "http://myserver:9091/transmission/rpc"
	Get-TransmissionTorrent -TransmissionUrl "http://myserver:9091/transmission/rpc" | where {$_.percentDone -eq 100}
	Get-TransmissionTorrent -credential (get-credential)
    

    Save-TransmissionCredential
    Get-transmissionTorrent -useSavedCredential $true
    #>
	
		Param
			(
				[parameter(ValueFromPipeLine= $false, Mandatory=$false, Position=0)] 
				[String]$Name,
				[parameter(ValueFromPipeLine= $true, Mandatory=$true)] 
				[String]$TransmissionUrl,
                [System.Management.Automation.PsCredential]$credential,
                [switch]$UseSavedCredential = $false,
                [switch]$HideCompleted = $false

			
			)
			
		Write-Verbose "Connecting to transmission URL $TransmissionURL"
		
		#Transmission requires a session ID, we wrap it in its own function


        if ($UseSavedCredential)
            {
                $TransmissionPasswordFile = $env:TEMP
                $transmissionPasswordFile += "\TransmissionPassword.cred"
                $TransmissionUserFile = $env:TEMP
                $TransmissionUserFile  += "\TransmissionUser.cred"

                if ((Test-Path $TransmissionPasswordFile) -and (Test-Path $TransmissionUserFile))
			        {
				        #Load from file
				        $password = Get-Content $TransmissionPasswordFile | ConvertTo-SecureString
				        $user = Get-Content $TransmissionUserFile
				        $credential = New-Object System.Management.Automation.PsCredential $user,$password
                        Write-Verbose "Loaded saved credential user name $User"
				      
			        }
                

            }
        
      

		$TransmissionSessionID = Get-TransmissionSessionID -TransmissionUrl $TransmissionUrl -credential $Credential		
		$Headers = @{"X-Transmission-Session-Id"=$TransmissionSessionID}
        if ($headers) {Write-verbose "Got session header"}
		
		#The request format is documented at https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt
		$Request = "" | Select arguments, method, tag
		$Request.method = "torrent-get"
		$Request.arguments = @{"fields"= @("id","name","percentDone","eta","isFinished","peersConnected","queuePosition","status","priorities","rateDownload")}
		$RequestJson = $Request | ConvertTo-Json

		
		############# Rest method of doing things ################
		$Response = Invoke-RestMethod -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson -Credential $credential
		
				
				if ($Response.Result -eq "success")
					{
						$Torrents = $Response.Arguments.Torrents
						foreach ($torrent in $Torrents)
							{
                                #Add object info
                                $torrent.PSObject.TypeNames.Insert(0,’TransmissionTorrent’)							

								#make stuff a little nicer
                                
								$torrent.percentDone = ($torrent.PercentDone*100)
								if ($torrent.status -eq 6){$torrent.status = "Seeding"}
								if ($torrent.status -eq 4){$torrent.status = "Downloading"}
								if ($torrent.status -eq 3){$torrent.status = "Queued"}
								if ($torrent.status -eq 0){$torrent.status = "Paused"}
								
								#Show eta in datetime format 
								if ($torrent.eta -gt 0) {$torrent.eta = (Get-Date).AddSeconds($torrent.eta)}
								
								#Use some combo logic to present the same status as the WEB UI does.
								if (($torrent.isFinished -eq $true) -and ($torrent.status -eq "paused")) {$torrent.status = "Completed"}
								if (($torrent.peersconnected -eq 0 ) -and ($torrent.status -eq "Downloading")) {$torrent.status = "Idle"}
                                
                                #Change speed to display in KBits/sec
                                $Torrent.rateDownload = ($torrent.RateDownload)/1KB

								
							}
						if ($Name)
							{
								$Torrents = $Torrents | where {$_.Name -like $name}
							}
						if ($HideCompleted)
                            {
                                $Torrents = $torrents | where {$_.Status -ne "Completed"}
                            }
						$Torrents
					}
				Else
					{
						Write-Warning "Could not retrieve torrents"
					}
		############## End Rest method of doing things #######################
		
#		$Response = Invoke-WebRequest -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson	
#		
#		if ($Response.StatusDescription -eq "OK")
#			{
#			
#				#Convert raw response to object
#				$Response = $Response.Content
#				$Response = $Response | convertFrom-Json
#				
#				if ($Response.Result -eq "success")
#					{
#						$Torrents = $Response.Arguments.Torrents
#						foreach ($torrent in $Torrents)
#							{
#								$torrent.percentDone = ($torrent.PercentDone*100)
#							}
#						$Torrents
#					}
#				Else
#					{
#						Write-Warning "Could not retrieve torrents"
#					}
#			
#			}
#		
#		
#		
#		Else
#			{
#				Write-Warning "Could not retrieve torrents"
#			}
	
	}
	
Function Add-TransmissionTorrent
	{
	
		<#
		.Synopsis
		Adds a torrent to transmissions list of active torrents
		.Description
		Adds a torrent to transmissions list of active torrents, from a link or .torrent file
		
		The functino takes two parameters:
		transmissionURL; which is the address of your transmission server, normally this would
		be in the shape of "http://myserver:9091/transmission/rpc"
		
		All *-transmission CmdLets take this parameters, so it might be a good idea to add it to your PsDefaultParameters property, which can be done like this:
		$PsdefaultParameterValues.Add("*Transmission:TransmissionUrl"="http://transmissionserver:9091/transmission/rpc"
		
		TorrentURL; the link to the torrent or magnet to be added. This needs to be reachable by the Transmission server
		
		The CmdLet returns an object containing status success or the error the transmission server sends
		  
		.Example
		PS C:\Scripts> Add-TransmissionTorrent -TransmissionUrl "http://myserver:9091/transmission/rpc" -torrentURL "htt://torrentlink.torrent"	

        if you have the "Get-Clipboard" function installed, you can simply do a 
        Get-Clipboard | Add-Transmissiontorrent
        	
		#>
		Param
			(
				[parameter(ValueFromPipeLine= $true, Mandatory=$true, position=0)] 
				[String]$TorrentUrl,
                [parameter(ValueFromPipeLine= $false, Mandatory=$true)] 
				[String]$TransmissionUrl,
                [System.Management.Automation.PsCredential]$credential,
				[bool]$UseSavedCredential = $false
				
			)
		
		

        if ($UseSavedCredential)
            {
                $TransmissionPasswordFile = $env:TEMP
                $transmissionPasswordFile += "\TransmissionPassword.cred"
                $TransmissionUserFile = $env:TEMP
                $TransmissionUserFile  += "\TransmissionUser.cred"

                if ((Test-Path $TransmissionPasswordFile) -and (Test-Path $TransmissionUserFile))
			        {
				        #Load from file
				        $password = Get-Content $TransmissionPasswordFile | ConvertTo-SecureString
				        $user = Get-Content $TransmissionUserFile
				        $credential = New-Object System.Management.Automation.PsCredential $user,$password
                        Write-Verbose "Loaded saved credential user name $User"
				      
			        }
                

            }

        #Transmission requires a session ID, we wrap it in its own function	
		$TransmissionSessionID = Get-TransmissionSessionID -TransmissionUrl $TransmissionUrl -credential $Credential	
		$Headers = @{"X-Transmission-Session-Id"=$TransmissionSessionID}
        if ($headers) {Write-verbose "Got session header"}
		
		#$TorrentUrl = ConvertTo-Base64 -string $TorrentUrl
		#The request format is documented at https://trac.transmissionbt.com/browser/trunk/extras/rpc-spec.txt
		$Request = "" | Select arguments, method, tag
		$Request.method = "torrent-add"
		$Request.arguments = @{"filename"=$TorrentUrl}
		$RequestJson = $Request | ConvertTo-Json
		
		$Response = Invoke-RestMethod -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson	-credential $Credential

		if ($Response.Result -eq "success")
			{
				$Response.arguments."torrent-added"
				
			}
		Else
			{
				Write-Warning "Could not add torrent"
			}
		
	}
	
Function Remove-TransmissionTorrent
	{
		Param
			(
				[parameter(ValueFromPipeLine= $false, Mandatory=$true)] 
				[String]$TransmissionUrl,
				[parameter(ValueFromPipelineByPropertyName = $true, Mandatory=$true, position=0)][Alias('id')]
				[Int32]$Torrentid,
				[bool]$RemoveLocalData = $false,
                [System.Management.Automation.PsCredential]$credential,
				[bool]$UseSavedCredential = $false
				
			)
			
		Begin
			{
				#Transmission requires a session ID, we wrap it in its own function	
				$TransmissionSessionID = Get-TransmissionSessionID -TransmissionUrl $TransmissionUrl		
				$Headers = @{"X-Transmission-Session-Id"=$TransmissionSessionID}
				#$RemoveLocalDataString = $RemoveLocalData.ToString()

                if ($UseSavedCredential)
                    {
                        $TransmissionPasswordFile = $env:TEMP
                        $transmissionPasswordFile += "\TransmissionPassword.cred"
                        $TransmissionUserFile = $env:TEMP
                        $TransmissionUserFile  += "\TransmissionUser.cred"

                        if ((Test-Path $TransmissionPasswordFile) -and (Test-Path $TransmissionUserFile))
			                {
				                #Load from file
				                $password = Get-Content $TransmissionPasswordFile | ConvertTo-SecureString
				                $user = Get-Content $TransmissionUserFile
				                $credential = New-Object System.Management.Automation.PsCredential $user,$password
				      
			                }
                

                    }
				
			}
			
		Process
			{
				$Request = "" | Select arguments, method, tag
				$Request.method = "torrent-remove"
				$Request.arguments = @{"ids"=$Torrentid;"delete-local-data"=$RemoveLocalData}
				$RequestJson = $Request | ConvertTo-Json
				
				$Response = Invoke-RestMethod -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson	-credential $Credential

				if ($Response.Result -eq "success")
					{
						$Response
						
					}
				Else
					{
						Write-Warning "Could not retrieve torrents"
					}
			
			}
		
	}

Function Suspend-TransmissionTorrent
	{
		Param
			(
				[parameter(ValueFromPipeLine= $false, Mandatory=$true)] 
				[String]$TransmissionUrl,
				[parameter(ValueFromPipelineByPropertyName = $true, Mandatory=$true, position=0)][Alias('id')]
				[Int32]$Torrentid,
                [System.Management.Automation.PsCredential]$credential,
				[bool]$UseSavedCredential = $false
				
			)
			
		Begin
			{
				#Transmission requires a session ID, we wrap it in its own function	
				$TransmissionSessionID = Get-TransmissionSessionID -TransmissionUrl $TransmissionUrl		
				$Headers = @{"X-Transmission-Session-Id"=$TransmissionSessionID}
				#$RemoveLocalDataString = $RemoveLocalData.ToString()

                if ($UseSavedCredential)
                    {
                        $TransmissionPasswordFile = $env:TEMP
                        $transmissionPasswordFile += "\TransmissionPassword.cred"
                        $TransmissionUserFile = $env:TEMP
                        $TransmissionUserFile  += "\TransmissionUser.cred"

                        if ((Test-Path $TransmissionPasswordFile) -and (Test-Path $TransmissionUserFile))
			                {
				                #Load from file
				                $password = Get-Content $TransmissionPasswordFile | ConvertTo-SecureString
				                $user = Get-Content $TransmissionUserFile
				                $credential = New-Object System.Management.Automation.PsCredential $user,$password
				      
			                }
                

                    }
				
			}
			
		Process
			{
				$Request = "" | Select arguments, method, tag
				$Request.method = "torrent-stop"
				$Request.arguments = @{"ids"=$Torrentid}
				$RequestJson = $Request | ConvertTo-Json
				
				$Response = Invoke-RestMethod -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson	-Credential $Credential

				if ($Response.Result -eq "success")
					{
						$Response
						
					}
				Else
					{
						Write-Warning "Could not retrieve torrents"
					}
			
			}
		
	}

Function Start-TransmissionTorrent
	{
		Param
			(
				[parameter(ValueFromPipeLine= $false, Mandatory=$true)] 
				[String]$TransmissionUrl,
				[parameter(ValueFromPipelineByPropertyName = $true, Mandatory=$true, position=0)][Alias('id')]
				[Int32]$Torrentid,
                [System.Management.Automation.PsCredential]$credential,
				[bool]$UseSavedCredential = $false
				
			)
			
		Begin
			{
				#Transmission requires a session ID, we wrap it in its own function	
				$TransmissionSessionID = Get-TransmissionSessionID -TransmissionUrl $TransmissionUrl		
				$Headers = @{"X-Transmission-Session-Id"=$TransmissionSessionID}
				#$RemoveLocalDataString = $RemoveLocalData.ToString()

                if ($UseSavedCredential)
                    {
                        $TransmissionPasswordFile = $env:TEMP
                        $transmissionPasswordFile += "\TransmissionPassword.cred"
                        $TransmissionUserFile = $env:TEMP
                        $TransmissionUserFile  += "\TransmissionUser.cred"

                        if ((Test-Path $TransmissionPasswordFile) -and (Test-Path $TransmissionUserFile))
			                {
				                #Load from file
				                $password = Get-Content $TransmissionPasswordFile | ConvertTo-SecureString
				                $user = Get-Content $TransmissionUserFile
				                $credential = New-Object System.Management.Automation.PsCredential $user,$password
				      
			                }
                

                    }
				
			}
			
		Process
			{
				$Request = "" | Select arguments, method, tag
				$Request.method = "torrent-start"
				$Request.arguments = @{"ids"=$Torrentid}
				$RequestJson = $Request | ConvertTo-Json
				
				$Response = Invoke-RestMethod -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson	-credential $Credential

				if ($Response.Result -eq "success")
					{
						$Response
						
					}
				Else
					{
						Write-Warning "Could not retrieve torrents"
					}
			
			}
		
	}
	
Function Set-TransmissionTorrent
	{
		Param
			(
				[parameter(ValueFromPipeLine= $false, Mandatory=$true)] 
				[String]$TransmissionUrl,
				[parameter(ValueFromPipelineByPropertyName = $true, Mandatory=$true,position=0)][Alias('id')]
				[Int32]$Torrentid,
				[ValidateSet("high","normal","low")] 
				[String]$Priority,
				[int]$QueuePosition,
                [System.Management.Automation.PsCredential]$credential,
				[bool]$UseSavedCredential = $false
				
			)
			
		Begin
			{
				#Transmission requires a session ID, we wrap it in its own function	
				$TransmissionSessionID = Get-TransmissionSessionID -TransmissionUrl $TransmissionUrl		
				$Headers = @{"X-Transmission-Session-Id"=$TransmissionSessionID}
				#$RemoveLocalDataString = $RemoveLocalData.ToString()

                if ($UseSavedCredential)
                    {
                        $TransmissionPasswordFile = $env:TEMP
                        $transmissionPasswordFile += "\TransmissionPassword.cred"
                        $TransmissionUserFile = $env:TEMP
                        $TransmissionUserFile  += "\TransmissionUser.cred"

                        if ((Test-Path $TransmissionPasswordFile) -and (Test-Path $TransmissionUserFile))
			                {
				                #Load from file
				                $password = Get-Content $TransmissionPasswordFile | ConvertTo-SecureString
				                $user = Get-Content $TransmissionUserFile
				                $credential = New-Object System.Management.Automation.PsCredential $user,$password
				      
			                }
                

                    }
				
			}
			
		Process
			{
				$Request = "" | Select arguments, method, tag
				$Request.method = "torrent-set"
				$Request.arguments = @{"ids"=$Torrentid}
				
				if ($Priority)
					{
						$TorrentPriority = "priority-$priority"
						$Request.arguments.add($TorrentPriority,"")
					}
				
				if ($QueuePosition)
					{
						$Request.arguments.add("queuePosition",$QueuePosition)
					}
				
				$RequestJson = $Request | ConvertTo-Json
				Write-Verbose "Sending JSON request:"
				Write-Verbose $RequestJson
				
				$Response = Invoke-RestMethod -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson	-Credential $Credential

				if ($Response.Result -eq "success")
					{
						$Response
						
					}
				Else
					{
						Write-Warning "Could not retrieve torrents"
					}
			
			}
		
	}
	
Function Set-TransmissionAltSpeedEnabled
	{
		Param
			(
				[parameter(ValueFromPipeLine= $false, Mandatory=$true)] 
				[String]$TransmissionUrl,
				[parameter(ValueFromPipeLine= $false, Mandatory=$true, position=0)] 
				[bool]$AltSpeedEnabled = $true,
                [System.Management.Automation.PsCredential]$credential,
				[bool]$UseSavedCredential = $false
				
			)
			
		Begin
			{
				#Transmission requires a session ID, we wrap it in its own function	
				$TransmissionSessionID = Get-TransmissionSessionID -TransmissionUrl $TransmissionUrl		
				$Headers = @{"X-Transmission-Session-Id"=$TransmissionSessionID}
				#$RemoveLocalDataString = $RemoveLocalData.ToString()

                if ($UseSavedCredential)
                    {
                        $TransmissionPasswordFile = $env:TEMP
                        $transmissionPasswordFile += "\TransmissionPassword.cred"
                        $TransmissionUserFile = $env:TEMP
                        $TransmissionUserFile  += "\TransmissionUser.cred"

                        if ((Test-Path $TransmissionPasswordFile) -and (Test-Path $TransmissionUserFile))
			                {
				                #Load from file
				                $password = Get-Content $TransmissionPasswordFile | ConvertTo-SecureString
				                $user = Get-Content $TransmissionUserFile
				                $credential = New-Object System.Management.Automation.PsCredential $user,$password
				      
			                }
                

                    }
				
			}
			
		Process
			{
				$Request = "" | Select arguments, method, tag
				$Request.method = "session-set"
				$Request.arguments = @{}
				$Request.arguments.add("alt-speed-enabled",($AltSpeedEnabled))
					
				
				$RequestJson = $Request | ConvertTo-Json
				Write-Verbose "Sending JSON request:"
				Write-Verbose $RequestJson
				
				$Response = Invoke-RestMethod -Headers $Headers -Method "POST" -uri $TransmissionUrl -body $RequestJson	-Credential $Credential

				if ($Response.Result -eq "success")
					{
						$Response
						
					}
				Else
					{
						Write-Warning "Could not process request"
					}
			
			}
		
	}

#Aliases
New-alias -name Resume-TransmissionTorrent -Value Start-TransmissionTorrent

#We won't export helper functions - keeping it tidy	
export-modulemember *-TransmissionTorrent, Set-TransmissionAltSpeedEnabled, Save-TransmissionCredential -Alias *
