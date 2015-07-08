#
# Copyright="© Microsoft Corporation. All rights reserved."
#

configuration ConfigureTCServer
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

    Import-DscResource -ModuleName xComputerManagement, xActiveDirectory, xDisk, cDisk, xNetworking

    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

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
        cDiskNoRestart TCDataDisk
        {
            DiskNumber = 2
            DriveLetter = "F"
        }
        xFirewall TeamServer443FirewallRule
        {
            Direction = "Inbound"
            Name = "TeamServer-443-TCP-In"
            DisplayName = "Team Server (443 TCP-In)"
            Description = "Inbound rule for Team Server to allow TCP traffic."
            DisplayGroup = "Team Server"
            State = "Enabled"
            Access = "Allow"
            Protocol = "TCP"
            LocalPort = "443"
            Ensure = "Present"
        }
		xFirewall TeamServer80FirewallRule
        {
            Direction = "Inbound"
            Name = "TeamServer-80-TCP-In"
            DisplayName = "Team Server (80 TCP-In)"
            Description = "Inbound rule for Team Server to allow TCP traffic."
            DisplayGroup = "Team Server"
            State = "Enabled"
            Access = "Allow"
            Protocol = "TCP"
            LocalPort = "443"
            Ensure = "Present"
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
# ConfigureTCServer -DomainName 'contoso.com' -OutputPath c:\DSC
# Start-DscConfiguration -Path C:\DSC -Verbose -Wait -Force
