Login-AzureRmAccount

$vmsBackupSuccessful = @()
$vmsWithBackupIssues = @()
$vmsWithoutBackupAllRSVs = @()
$vmsWithoutBackup = @()

$allSubscr = Get-AzureRmSubscription -WarningAction SilentlyContinue
foreach ($subscr in $allSubscr) {
    Select-AzureRmSubscription -SubscriptionID $subscr | Out-Null
    $vmList = Get-AzureRmVM -Status -WarningAction SilentlyContinue
    $allBkpVaults = Get-AzureRmRecoveryServicesVault
    foreach ($vm in $vmList) {
        $foundVM = $false
        foreach ($bkpVault in $allBkpVaults) {
            Set-AzureRmRecoveryServicesVaultContext -Vault $bkpVault
            $allContainers = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM
            foreach ($container in $allContainers) {
                if (($container).FriendlyName -eq ($vm).Name) {
                    $foundVm = $true
                    $bkpItem = Get-AzureRmRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM
                    if (($bkpItem).ProtectionState -eq "Protected") {
                        # Uncomment the below line if you want to see all VMs listed as "Protected" VMs
                        #Write-Host ($vm).Name" inside "($vm).ResourceGroupName" on "($subscr).SubscriptionName" is assigned to policy "($bkpItem).ProtectionPolicyName" and its protection state is Protected"

                        $vmsBackupSuccessful += $vm
                    }
                    else {
                        # Uncomment the below line if you want to see all VMs with a Backup Policy but that are with some issue right now
                        #Write-Host ($vm).Name" inside "($vm).ResourceGroupName" on "($subscr).SubscriptionName" is assigned to policy "($bkpItem).ProtectionPolicyName" and its protection state is "($bkpItem).ProtectionState

                        $vmsWithBackupIssues += $vm
                    }
                }
            }

        }
        if ($foundVM -eq $false) {
            # Uncomment the below line to see if a VM is not part of the RSV that the script is going through right now (what doesn't mean that the VM doesn't have a backup, since it can be inside another RSV)
            #Write-Host ($vm).Name" ON "($vm).ResourceGroupName" ON "($subscr).SubscriptionName" IS NOT LINKED TO A BACKUP POLICY. PLEASE FIX ASAP!"
            $vmsWithoutBackupAllRSVs += $vm
        }

    }
}

# The below code populates #vmsWithoutBackup just with VMs that are not inside another RSV (since on one subscription, you can have multiple RSVs) AAAAND, that are not on "Deallocated" Power State
foreach ($vm in $vmsWithoutBackupAllRSVs) {
    if (($vm.PowerState -ne "VM deallocated" -and $vm.PowerState -ne "Stopped") -and (($vmsBackupSuccessful -notcontains $vm) -or ($vmsWithBackupIssues -notcontains $vm)))  {
        $vmsWithoutBackup += $vm
        Write-Host ($vm).Name"  WITH CURRENT STATUS OF "($vm).PowerState" INSIDE "($vm).ResourceGroupName" IS NOT LINKED TO A BACKUP POLICY. PLEASE FIX ASAP!"
    }
}
