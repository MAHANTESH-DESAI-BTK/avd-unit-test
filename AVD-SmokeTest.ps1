########################################################################################################################
###                                                                                                                  ###
###    Script Name: AVD-SmokeTest.ps1                                                                                ###
###                                                                                                                  ###
###    Script Function:                                                                                              ###
###    This script performs automated smoke tests for an Azure Virtual Desktop (AVD) deployment.                     ###
###    It validates the presence and configuration of key AVD components including:                                  ###
###      - Host Pool deployments                                                                                     ###
###      - Session Host deployments                                                                                  ###
###      - Diagnostic Settings for both Host Pools and Session Hosts                                                 ###
###      - Scaling Plan configurations                                                                               ###
###                                                                                                                  ###
###    Script Usage:                                                                                                 ###
###    This script requires the following parameters to authenticate to Azure and run the tests:                     ###
###      -TenantId: The Azure Active Directory tenant ID.                                                            ###
###      -ClientId: The client ID of the Azure AD app registration (service principal).                              ###
###      -ClientSecret: The client secret of the Azure AD app registration.                                          ###
###      -SubscriptionId: The Azure subscription ID where AVD resources are deployed.                                ###
###                                                                                                                  ###
###    Script Example:                                                                                               ###
###    .\AVD-SmokeTest.ps1 -TenantId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"                                          ###
###                        -ClientId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"                                          ###
###                        -ClientSecret $env:ClientSecret                                                           ###
###                        -SubscriptionId $env:SubscriptionId                                                       ###
###                                                                                                                  ###
###    Script Version: 1.0.0                                                                                         ###
###    Version Details: Initial version. Includes smoke tests for Host Pools, Session Hosts,                         ###
###                     Diagnostic Settings, and Scaling Plans.                                                      ###
###                                                                                                                  ###
########################################################################################################################

# Script Parameters
param (
    [string]$TenantId,
    [string]$ClientId,
    [string]$ClientSecret,
    [string]$SubscriptionId
)

function Write-Log
{
    param (
        [string]$Message,
        [string]$FunctionName = $null
    )

    try
    {
        # Get current date and time
        $dateTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        # Log message with date and time to console and file
        $logMessage = "$dateTime - $FunctionName - $Message"
        Write-Host $logMessage
        
    }
    catch
    {
        Write-Host "Having issues creating or adding information to the logfile at $LogFilePath"
    }
}


function Connect-ToAzure {
    param (
        [string]$TenantId,
        [string]$ClientId,
        [string]$ClientSecret,
        [string]$SubscriptionId
    )

    try {
        $SecureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
        $Cred = New-Object System.Management.Automation.PSCredential ($ClientId, $SecureClientSecret)
        Connect-AzAccount -ServicePrincipal -Credential $Cred -TenantId $TenantId | Out-Null
        Select-AzSubscription -Tenant $TenantId -SubscriptionId $SubscriptionId | Out-Null
        Write-Log -Message "Connected to Azure and selected subscription $SubscriptionId" -FunctionName "Connect-ToAzure"
    }
    catch {
        Write-Log -Message "Failed to authenticate to Azure: $_" -FunctionName "Connect-ToAzure"
    }
}

# Check Host Pool Exist
function Test-AVDHostPool {
    try {
        $hostPools = Get-AzWvdHostPool
        if ($hostPools) {
            Write-Log -Message "Host Pools found: $($hostPools.Count)" -FunctionName "Test-AVDHostPool"
        } else {
            Write-Log -Message "No Host Pools found." -FunctionName "Test-AVDHostPool"
        }
    } catch {
        Write-Log -Message "Error checking Host Pools: $_" -FunctionName "Test-AVDHostPool"
    }
}

# Check Session Host VM Exists in Hostpool
function Test-AVDSessionHosts {
    try {
        $hostPools = Get-AzWvdHostPool
        foreach ($pool in $hostPools) {
            $sessionHosts = Get-AzWvdSessionHost -ResourceGroupName $pool.ResourceGroupName -HostPoolName $pool.Name
            Write-Log -Message "Session Hosts in $($pool.Name): $($sessionHosts.Count)" -FunctionName "Test-AVDSessionHosts"
        }
    } catch {
        Write-Log -Message "Error checking Session Hosts: $_" -FunctionName "Test-AVDSessionHosts"
    }
}
function Test-AVDDiagnostics {
    try {
        # Check Host Pool diagnostics
        $hostPools = Get-AzResource | Where-Object { $_.ResourceType -like "Microsoft.DesktopVirtualization/hostPools" }
        foreach ($res in $hostPools) {
            $diag = Get-AzDiagnosticSetting -ResourceId $res.ResourceId -ErrorAction SilentlyContinue
            if ($diag) {
                Write-Log -Message "Diagnostics configured for Host Pool: $($res.Name)" -FunctionName "Test-AVDDiagnostics"
            } else {
                Write-Log -Message "No diagnostics found for Host Pool: $($res.Name)" -FunctionName "Test-AVDDiagnostics"
            }
        }

        # Check Session Host diagnostics
        $sessionHosts = Get-AzResource | Where-Object { $_.ResourceType -like "Microsoft.DesktopVirtualization/hostPools/sessionHosts" }
        foreach ($res in $sessionHosts) {
            $diag = Get-AzDiagnosticSetting -ResourceId $res.ResourceId -ErrorAction SilentlyContinue
            if ($diag) {
                Write-Log -Message "Diagnostics configured for Session Host: $($res.Name)" -FunctionName "Test-AVDDiagnostics"
            } else {
                Write-Log -Message "No diagnostics found for Session Host: $($res.Name)" -FunctionName "Test-AVDDiagnostics"
            }
        }      

        # Check WorkSpace diagnostics
        $diagworkSpaces = Get-AzResource | Where-Object { $_.ResourceType -like "Microsoft.DesktopVirtualization/workspaces" }
        foreach ($res in $diagworkSpaces) {
            $diag = Get-AzDiagnosticSetting -ResourceId $res.ResourceId -ErrorAction SilentlyContinue
            if ($diag) {
                Write-Log -Message "Diagnostics configured for Workspace: $($res.Name)" -FunctionName "Test-AVDDiagnostics"
            } else {
                Write-Log -Message "No diagnostics found for Workspace: $($res.Name)" -FunctionName "Test-AVDDiagnostics"
            }
        }
    } catch {
        Write-Log -Message "Error checking diagnostics: $_" -FunctionName "Test-AVDDiagnostics"
    }
}

# Check Scaling Plans Exists
function Test-AVDScaling {
    try {
        $scalingPlans = Get-AzWvdScalingPlan
        if ($scalingPlans) {
            Write-Log -Message "Scaling Plans found: $($scalingPlans.Count)" -FunctionName "Test-AVDScaling"
        } else {
            Write-Log -Message "No Scaling Plans found." -FunctionName "Test-AVDScaling"
        }
    } catch {
        Write-Log -Message "Error checking Scaling Plans: $_" -FunctionName "Test-AVDScaling"
    }
}

# Check Workspaces Exists
function Test-AVDWorkspace {
    try {
        $workSpaces = Get-AzWvdWorkspace
        if ($workSpaces) {
            Write-Log -Message "Workspaces found: $($workSpaces.Name)" -FunctionName "Test-AVDWorkspace"
        } else {
            Write-Log -Message "No Workspaces  found." -FunctionName "Test-AVDWorkspace"
        }
    } catch {
        Write-Log -Message "Error checking Workspaces: $_" -FunctionName "Test-AVDWorkspace"
    }
}

# Check Images Exists
function Test-AVDImagePackage {
    try {
        $msixPackage = Get-AzWvdMsixPackage
        if ($msixPackage) {
            Write-Log -Message "Images found: $($msixPackage.Name)" -FunctionName "Test-AVDImagePackage"
        } else {
            Write-Log -Message "No Images  found." -FunctionName "Test-AVDImagePackage"
        }
    } catch {
        Write-Log -Message "Error checking Images: $_" -FunctionName "Test-AVDImagePackage"
    }
}

# Check Session Host exists in AVD
function Test-HostAvailability {
    # Get session hosts in the specified host pool
    $sessionHosts = Get-AzResource | Where-Object { $_.ResourceType -like "Microsoft.DesktopVirtualization/hostPools/sessionHosts" }

    # Check availability
    foreach ($host in $sessionHosts) {
    try {
        $status = $host.Status
        $hostName = $host.Name
        if ($status -eq "Available") {
            Write-Output "$hostName is available."
        } else {
            Write-Output "$hostName is not available. Status: $status"
        }    
     } catch {
        Write-Log -Message "Error checking Session Hosts : $_" -FunctionName "Test-HostAvailability"
    }
}

# Check Session Host exists in AVD
function Test-HostDrainMode {
    # Get session hosts in the specified host pool
    $sessionHosts = Get-AzResource | Where-Object { $_.ResourceType -like "Microsoft.DesktopVirtualization/hostPools/sessionHosts" }

    # Check drain mode status
    foreach ($Host in $SessionHosts) {
        try {
            $DrainModeStatus = $Host.AllowNewSession
            $HostName = $Host.Name.Split("/")[-1]
                
            if ($DrainModeStatus -eq $false) {
                Write-Host "Drain mode is ON for session host: $HostName"
            } else {
                    Write-Host "Drain mode is OFF for session host: $HostName"
            }
        } catch {
            Write-Log -Message "Error checking Session Hosts : $_" -FunctionName "Test-HostDrainMode"
        }
}

 
