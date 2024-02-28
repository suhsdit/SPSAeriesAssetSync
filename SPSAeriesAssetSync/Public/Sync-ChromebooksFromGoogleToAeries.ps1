Function Sync-ChromebooksFromGoogleToAeries {
<#
.SYNOPSIS
    Sync Chromebook data from Google to Aeries
.DESCRIPTION
    The Sync-NewChromebooksFromGoogleToAeries function pulls devices from configured OUs in Google and adds them under the appropriate school in Google Admin Console.

    It will create new Titles in Aeries for new models detected in Google, and create new asset items in Aeries for new unique serial numbers found in the Google Admin Console.
.EXAMPLE
    Sync-NewChromebooksFromGoogleToAeries
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
        Write-Verbose -Message "Starting $($MyInvocation.InvocationName) with $($PsCmdlet.ParameterSetName) parameterset..."
        Write-Verbose -Message "Parameters are $($PSBoundParameters | Select-Object -Property *)"

        #include $DistrictAssetConfig
        Write-Verbose "Using Config: $config"
        . $env:LOCALAPPDATA\powershell\SPSAeriesAssetSync\$config\DistrictAssetConfig.ps1
        Set-PSGSuiteConfig $DistrictAssetConfig.PSGSuiteConfig
        Set-PSAeriesConfiguration -Name $DistrictAssetConfig.PSAeriesConfig
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
        $AeriesTitles = Get-AeriesDistrictAssetTitle

        ForEach ($model in $Models) {
            if ($AeriesTitles.Title -notcontains $model) {
                Write-Verbose "Model missing from Aeries District Assets, creating title in Aeries: $($model)"
                New-AeriesDistrictAssetTitle -Title $model
            } else {
                Write-Verbose "Model exists in Aeries District Assets Titles: $($model)"
            }
        }

        # Get Updated list of District Asset Titles
        $AeriesTitles = Get-AeriesDistrictAssetTitle | Where-Object {$Models -contains $_.Title}
        $TitleHT = @{}
        $ItemsHT = @{}
        $AeriesTitles | ForEach-Object {$TitleHT[$_.Title] = $_}
        
        Write-Verbose "Iterating through items under titles: "
        Write-Verbose $TitleHT

        # Hashtable for all Chromebook items in Aeries
        foreach ($title in $TitleHT.GetEnumerator()) {
            Get-AeriesDistrictAssetItem -AssetTitleNumber $title.Value.AssetTitleNumber | ForEach-Object {
                $ItemsHT[$_.Barcode] = $_
            }
        }
        #Write-Verbose "Including items: "
        #$ItemsHT

        foreach ($cb in $cbHT.GetEnumerator()) {

            #Assign the assetID as room and look for ##-## match
            $room = $cb.Value.annotatedAssetID | Select-String -Pattern '\d*-\d*'
            if ($room) {
                $room = $room.Matches.Groups[0].Value
            } else {
                $room = ' '
            }
            
            if ($ItemsHT.ContainsKey($cb.Value.SerialNumber)) {
                $item = $ItemsHT[$cb.Value.SerialNumber]
                Write-Verbose "Chromebook already exists as an item in Aeries with SerialNumber: $($cb.Value.SerialNumber)"
                # Check if Google OU matches School Code in Aeries
                if ($item.School -notlike $cb.Value.AeriesSiteCode -or
                    $item.Room   -notlike $room) {
                    Write-Verbose "Updating Aeries School code/room from $($ItemsHT[$cb.Value.SerialNumber].School)/$($ItemsHT[$cb.Value.SerialNumber].Room) to $($cb.Value.AeriesSiteCode)/$room"
                    
                    $UpdateItemSplat = @{
                        AssetTitleNumber    = $item.AssetTitleNumber
                        AssetItemNumber     = $item.AssetItemNumber
                        NewSchool           = $cb.Value.AeriesSiteCode
                        NewRoom             = $room
                    }
                    Update-AeriesDistrictAssetItem @UpdateItemSplat
                }

            } else {
                Write-Verbose "Not detected. Creating Item for SerialNumber: $($cb.Value.SerialNumber)"
                
                $NewItemSplat = @{
                    AssetTitleNumber    = $titleHT[$cb.Value.Model].AssetTitleNumber 
                    Barcode             = $cb.Value.SerialNumber 
                    SerialNumber        = $cb.Value.SerialNumber 
                    MACAddress          = $cb.Value.MacAddress
                    Price               = $titleHT[$cb.Value.Model].Price
                    School              = $cb.Value.AeriesSiteCode
                    Room                = $room
                    Comment             = $cb.Value.Notes
                }
                Write-verbose $NewItemSplat
                New-AeriesDistrictAssetItem @NewItemSplat

                # Blank out the annotatedUser fields in Google Admin Console
                Update-GSChromeOSDevice -ResourceID $cb.Value.DeviceId -AnnotatedUser ''
            }
        }
    }
    End {
        Write-Verbose -Message "Ending $($MyInvocation.InvocationName)..."
    }

}