Function Sync-AeriesItemAssignment {
    <#
    .SYNOPSIS
        Assign users to items in Aeries
    .DESCRIPTION
        import a csv with the following headers:
        UserID - Should be student or staff Aeries User ID
        UserType - S for Student T for Staff
        SerialNumber - Serial Number of device to match, if incomplete put * into csv as a wildcard match   
    .EXAMPLE
        Sync-AeriesItemAssignment
    .PARAMETER
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
            [Parameter( Mandatory,
                Position=1)]
                [string]$csv
        )
    
        Begin {
            Write-Verbose -Message "Starting $($MyInvocation.InvocationName) with $($PsCmdlet.ParameterSetName) parameterset..."
            Write-Verbose -Message "Parameters are $($PSBoundParameters | Select-Object -Property *)"
    
            #include $DistrictAssetConfig
            . $env:LOCALAPPDATA\powershell\SPSAeriesAssetSync\$config\DistrictAssetConfig.ps1
            Set-SPSAeriesConfiguration -Name $DistrictAssetConfig.SPSAeriesConfig
            $SchoolConfigs = $DistrictAssetConfig.SchoolConfigs

            if (!(Test-Path $csv)) {
                return
            }
        }
        Process {
            $csvData = Import-Csv $csv
            Write-Verbose "csvData Count: $($csvData.Count)"

            $itemsHT = @{}
            $aeriesItems = Get-SPSAeriesDistrictAssetItem | Where-Object {(!([string]::IsNullOrEmpty($_.SerialNumber)))}
            Write-Verbose "aeriesItems: $($aeriesItems.Count)"

            foreach ($item in $aeriesItems) {
                #write-verbose $item.SerialNumber
                $itemsHT[$item.SerialNumber] = $item
                }

            Write-Verbose "Total item count: $($itemsHT.Count)"
            $itemKeys = $itemsHT.keys

            foreach ($user in $csvData) {
                Write-Verbose "Finding Matching serial number for $($user.SerialNumber)"
                foreach ($key in $itemKeys) {
                    #Write-Verbose "Comparing $($user.SerialNumber) against $key"
                    if ($key -like $user.SerialNumber) {
                        Write-Verbose "Match! $($user.SerialNumber) in $key"
                        Write-Verbose "Assigning $key to $($user.UserID)"

                        $AssignmentSplat = @{
                            AssetTitleNumber    = $itemsHT[$key].AssetTitleNumber
                            AssetItemNumber     = $itemsHT[$key].AssetItemNumber
                            UserID              = $user.userID
                            UserType            = $user.userType
                        }

                        Write-Verbose $AssignmentSplat

                        New-SPSAeriesDistrictAssetAssociation @AssignmentSplat
                    }
                }

                
            }
        }
        End {
            Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
        }
    }