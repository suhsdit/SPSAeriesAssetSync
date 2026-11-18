Function Sync-CBDataFromAeriesToGoogle {
<#
.SYNOPSIS
    Import Chromebook data from Aeries to Google
.DESCRIPTION
    Updates Associated User and comment field from Aeries Items back into Google.
.PARAMETER config
    Name of the DistrictAssetConfig to load from
    $env:LOCALAPPDATA\powershell\SPSAeriesAssetSync.
.PARAMETER DetailedLogging
    Emit one verbose line per item examined, not just per item changed. Off by
    default, because a district-wide run with this on produces thousands of lines.
    Has no effect without -Verbose.
.EXAMPLE
    Sync-CBDataFromAeriesToGoogle
.EXAMPLE
    Sync-CBDataFromAeriesToGoogle -config District1 -Verbose -DetailedLogging

    Reports every device examined, not just the ones that changed. Use when
    tracking down a single asset.
.INPUTS
.OUTPUTS
.NOTES
.LINK
#>
    [CmdletBinding()] #Enable all the default paramters, including -Verbose
    Param(
        [Parameter( Mandatory,
                    Position=0)]
            [string]$config,
        # Per-item examination lines are suppressed unless this is passed. They are
        # one line per device and bury the change events in a district-wide run.
        [Parameter()]
            [switch]$DetailedLogging
    )

    Begin {
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName) with $($PsCmdlet.ParameterSetName) parameterset..."
        Write-Verbose -Message "Parameters are $($PSBoundParameters | Select-Object -Property *)"

        #include $DistrictAssetConfig
        . $env:LOCALAPPDATA\powershell\SPSAeriesAssetSync\$config\DistrictAssetConfig.ps1
        Set-PSGSuiteConfig $DistrictAssetConfig.PSGSuiteConfig
        Set-SPSAeriesConfiguration -Name $DistrictAssetConfig.SPSAeriesConfig
        $SchoolConfigs = $DistrictAssetConfig.SchoolConfigs
    }
    Process {
        # We'll pull Active chromebooks from each 1:1 unassigned directory
        # and put into a hastable with the serial number as the key
        $cbHT = @{}
        foreach ($schoolConfig in $SchoolConfigs) {
            foreach ($GoogleOU in $schoolconfig.GoogleOUs) {
                [string]$OUPath = $GoogleOU
                Write-Verbose "Retrieving active Chromebooks from $($OUPath)"
                Get-GSChromeOSDevice -Filter status:ACTIVE -OrgUnitPath $OUPath -Projection FULL |
                ForEach-Object {
                    $cbHT[$_.serialnumber] = $_
                    $cbHT[$_.serialnumber] | Add-Member -NotePropertyName 'AeriesSiteCode' -NotePropertyValue $schoolConfig.AeriesSiteCode
                    $cbHT[$_.serialnumber] | Add-Member -NotePropertyName 'Site' -NotePropertyValue $schoolConfig.Site

                }
                Write-Verbose "Chromebooks Pulled from $($OUPath): $($cbHT.Count)"
            }
        }
        Write-Verbose "Total Chromebook count: $($cbHT.Count)"

        # Get unique models so we know what items to compare against in Aeries
        $Models = $cbHT.GetEnumerator() | ForEach-Object {$_.Value.Model} | Sort-Object | Get-Unique
        Write-Verbose "Found unique models: $($Models)"

        # Get Updated list of District Asset Titles
        $AeriesTitles = Get-SPSAeriesDistrictAssetTitle | Where-Object {$Models -contains $_.Title}
        $TitlesHT = @{}
        $ItemsHT = @{}
        $AeriesTitles | ForEach-Object {$TitlesHT[$_.Title] = $_}


        # Hashtable for all Chromebook items in Aeries
        foreach ($title in $TitlesHT.GetEnumerator()) {
            Get-SPSAeriesDistrictAssetItem -AssetTitleNumber $title.Value.AssetTitleNumber | ForEach-Object {
                $ItemsHT[$_.Barcode] = $_
            }
        }
        if ($DetailedLogging) {
            Write-Verbose "Including items to check assigned users: "
            Write-Verbose ($ItemsHT.Values | Format-Table | Out-String)
        }

        # Go through and match Aeries items to Google items to compare Comments->Notes and Assigned users
        foreach ($item in $ItemsHT.GetEnumerator()) {
            $item = $item.Value
            if ($cbHT.ContainsKey($item.SerialNumber)) {
                $cb = $cbHT[$item.SerialNumber]
                $itemAssoc = Get-SPSAeriesDistrictAssetAssociation -AssetTitleNumber $item.AssetTitleNumber -AssetItemNumber $item.AssetItemNumber |
                    Select-Object -Last 1
                if ($itemAssoc -And [string]::IsNullOrEmpty($itemAssoc.DateReturned)) {
                    # If Date returned is empty, the item is currently checked out to a user

                    # We want to check this first because Get-SPSAeriesDistrictAssetAssociation will return an assigned user whether
                    # the device is checked out or not and we don't want to populate Google with the last user to have the
                    # chromebook if they don't currently have it.

                    #Get assigned student/staff email address
                    $userEmail = $null
                    if ($itemAssoc.UserType -like "S") {
                        $userEmail = "$($itemAssoc.UserID)@suhsd.net"
                    } elseif ($itemAssoc.UserType -like "T") {
                        $userEmail = (Get-SPSAeriesStaffEmail -ID $itemAssoc.UserID).EmailAddress
                    }

                    if ($DetailedLogging) {
                        Write-Verbose "Checking annotated user for CB $($cb.SerialNumber)"
                    }
                    # Let's make sure the right user is annotated in Google
                    if ($userEmail -like $cb.annotatedUser) {
                        if ($DetailedLogging) {
                            Write-Verbose "Aeries User $($userEmail) matches $($cb.annotatedUser) is already annotated for CB $($cb.SerialNumber)"
                        }
                        # Users match, do nothing
                    } else {
                        # Users don't match, update var for annotatedUser in Google
                        Write-Verbose "Updating CB $($cb.SerialNumber) with user: $($userEmail)"
                        Update-GSChromeOSDevice -ResourceID $cb.DeviceId -AnnotatedUser $userEmail
                    }
                } else {
                    # Date returned has a value, so it shouldn't be checked out to a user.
                    if ([string]::IsNullOrEmpty($cb.annotatedUser)) {
                        # If no annoted user, then all is good, nothing to update
                    } else {
                        # If it does have a value, it should be made blank, as the device is not checked out.
                        Write-Verbose "Updating CB $($cb.SerialNumber) with no user"
                        Update-GSChromeOSDevice -ResourceID $cb.DeviceId -AnnotatedUser ''
                    }
                }
                if ($item.Comment -like $cb.Notes) {
                    # If comment in Aeries matches Notes in Google, do nothing
                } else {
                    # Fields don't match, update Notes field in Google
                    Write-Verbose "Updating CB $($cb.SerialNumber) with Note: $($item.Comment)"
                    Update-GSChromeOSDevice -ResourceID $cb.DeviceId -Notes $item.Comment
                }
            }
        }
    }
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }
}