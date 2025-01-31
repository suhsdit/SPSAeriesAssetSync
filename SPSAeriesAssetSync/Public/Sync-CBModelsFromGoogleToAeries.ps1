Function Sync-CBModelsFromGoogleToAeries {
<#
.SYNOPSIS
    Import Chromebook Models from Google to Titles in Aeries
.DESCRIPTION
    The Sync-CBModelsFromGoogleToAeries function pulls adds new unique models to Aeries as Titles in Aeries District Assets
.EXAMPLE
    Sync-CBModelsFromGoogleToAeries
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
            [string]$config
    )

    Begin {
        Write-Verbose "$($MyInvocation.line)"
        Write-Verbose "Starting $($MyInvocation.InvocationName) with $($PsCmdlet.ParameterSetName) parameterset..."
        Write-Verbose "Parameters are $($PSBoundParameters | Select-Object -Property *)"

        #include $DistrictAssetConfig
        Write-Verbose "Using Config: $config"
        . $env:LOCALAPPDATA\powershell\SPSAeriesAssetSync\$config\DistrictAssetConfig.ps1
        Set-PSGSuiteConfig $DistrictAssetConfig.PSGSuiteConfig
        Set-SPSAeriesConfiguration -Name $DistrictAssetConfig.SPSAeriesConfig
        $SchoolConfigs = $DistrictAssetConfig.SchoolConfigs
        Write-Verbose ($SchoolConfigs | Format-Table | Out-String)
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
                    # This if statement is to catch long model names such as the below example from Acer
                    # Model: Acer Chromebook Spin 511 (R753T) & Acer Chromebook spin 511 (R753TN) & Acer Chromebook Spin 511(R752T-R)
                    # Truncated: Acer Chromebook Spin 511 (R753T R753TN R752T-R)
                    if ($_.Model.length -gt 60) {
                        $model = $_.Model
                        Write-Verbose "Model name is over 60 characters: $model"
                        $modelNumbers = Get-TextWithin $model -WithinChar "("
                        $pos = $model.IndexOf("(")
                        $modelBeginning = $model.Substring(0, $pos)
                        $model = $modelBeginning + "($($modelNumbers))"
                        $cbHT[$_.serialnumber].Model = $model
                        Write-Verbose "Model name truncated to: $model"
                    }

                }
                Write-Verbose "Chromebooks Pulled from $($OUPath): $($cbHT.Count)"
            }
        }
        Write-Verbose "Total Chromebook count: $($cbHT.Count)"

        $Models = $cbHT.GetEnumerator() | ForEach-Object {$_.Value.Model} | Sort-Object | Get-Unique
        Write-Verbose "Found unique models: $($Models)"
        $AeriesTitles = Get-SPSAeriesDistrictAssetTitle

        ForEach ($model in $Models) {
            if ($AeriesTitles.Title -notcontains $model) {
                Write-Verbose "Model missing from Aeries District Assets, creating title in Aeries: $($model)"
                New-SPSAeriesDistrictAssetTitle -Title $model
            } else {
                Write-Verbose "Model exists in Aeries District Assets Titles: $($model)"
            }
        }
    }
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }

}