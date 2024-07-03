# Administrative scripts etc

## Get list of Zonal restrictions on Subscriptions

Demand overflow on Amsterdam and Dublin regions forced Microsoft to implement hard Zonal restrictions on Subscriptions.
This humble script will print a nice table of desired regions...

``` ps1
$subscriptions = Get-AzSubscription -TenantId  "ttt" | ? {$_.name -like "S*"} | sort-object Name

$sku = "Standard_D2s_v5" # Most accurate sample
$locations = @( "westeurope", "northeurope", "italynorth" )

$results = @()

foreach ($subscription in $subscriptions) {
    set-azcontext -SubscriptionId $subscription.Id
    
    $subscriptionResult = [PSCustomObject]@{
        "Subscription Name" = $subscription.Name
    }
    
    foreach ($location in $locations) {
        $zone = Get-AzComputeResourceSku -Location $location | Where-Object { $_.ResourceType -eq 'virtualMachines' -and $_.Name -eq $sku }
        $subscriptionResult | Add-Member -MemberType NoteProperty -Name $location -Value ($zone.Restrictions.RestrictionInfo.Zones -join ",")
    }

    $results += $subscriptionResult
    echo $subscriptionResult | ft # print to see progress
}

$results | Format-Table -AutoSize
```

![alt text](image-1.png)

Listed Zones cannot be used. Empty means Zonal no restrictions


## Get VM Quota statistics

``` ps1
$subscriptions = Get-AzSubscription -TenantId  "ttt" | ? {$_.name -like "S*"} | sort-object Name

$locations = @( "westeurope", "northeurope", "italynorth" )
$quotaResults = @()

foreach ($subscription in $subscriptions) {
    set-azcontext -SubscriptionId $subscription.Id
    
    foreach ($location in $locations) {
        $quotas = get-azvmusage -location westeurope | ? {$_.limit -gt 0 -and $_.CurrentValue -gt 0}

        foreach ($quota in $quotas) {
            $quotaperc = [math]::Round($quota.CurrentValue / $quota.Limit *100, 0)

            $subscriptionResult = [PSCustomObject]@{
                "Subscription" = $subscription.Name
                "Location" = $location
                "QuotaName" = $quota.Name.LocalizedValue
                "QuotaUsed" = $quotaperc
                "QuotaLimit" = $quota.Limit
            }

            $quotaResults += $subscriptionResult
            echo $subscriptionResult | ft # print to see progress
        }
    }
}

$quotaResults | ? {$_.QuotaName -eq "Total Regional vCPUs" -and $_.QuotaUsed -gt 20} | Format-Table -AutoSize
```