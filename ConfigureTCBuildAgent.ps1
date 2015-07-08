#
# Copyright="© Microsoft Corporation. All rights reserved."
#

configuration ConfigureTCBuildAgent
{
	
    param
    (
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Int]$RetryCount=30,
        [Int]$RetryIntervalSec=60
    )

        Write-Verbose "AzureExtensionHandler loaded continuing with configuration"

        [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

        Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xDisk, cDisk, xNetworking

        Node localhost
        {
            Script ConfigureCPU
			{
				GetScript = {
					@{
						Result = ""
					}
				}
				TestScript = {
					$false
				}
				SetScript ={

				  # Set PowerPlan to "High Performance"
					$guid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "ElementName='High Performance'").InstanceID.ToString()
					$regex = [regex]"{(.*?)}$"
					$plan = $regex.Match($guid).groups[1].value
					powercfg -S $plan
				}
			}
            xWaitforDisk Disk2
            {
                DiskNumber = 2
                RetryIntervalSec =$RetryIntervalSec
                RetryCount = $RetryCount
            }
            cDiskNoRestart SPDataDisk
            {
                DiskNumber = 2
                DriveLetter = "F"
                DependsOn = "[xWaitforDisk]Disk2"
            }
            WindowsFeature NET-Framework-Core
            {
                Name = "NET-Framework-Core"
                Ensure = "Present"
            }
            xWaitForADDomain DscForestWait 
            { 
                DomainName = $DomainName 
                DomainUserCredential= $DomainCreds
                RetryCount = $RetryCount 
                RetryIntervalSec = $RetryIntervalSec 
                DependsOn = "[WindowsFeature]NET-Framework-Core"      
            }
            xComputer DomainJoin
            {
                Name = $env:COMPUTERNAME
                DomainName = $DomainName
                Credential = $DomainCreds
                DependsOn = "[xWaitForADDomain]DscForestWait" 
            }
        }
}

# Comment out when running locally for debugging purposes
# ConfigureTCBuildAgent -DomainName 'contoso.com' -OutputPath c:\DSC
# Start-DscConfiguration -Path C:\DSC -Verbose -Wait -Force
