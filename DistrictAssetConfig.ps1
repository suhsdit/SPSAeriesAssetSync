#Config file for Aeries District Asset Sync in ShastaPSToolkit

$DistrictAssetConfig = [PSCustomObject]@{
    PSGSuiteConfig =    'ConfigName' # Used to Set PSGSuite Config
    SPSAeriesConfig =    'ConfigName'# Used to Set SPSAeries Config
    SchoolConfigs =     [PSCustomObject]@{
        Site =              'SiteName'
        AeriesSiteCode =    '11'
        GoogleOUs =         @('/Student/High School 1/Devices/1:1')
    }, [PSCustomObject]@{
        Site =              'SiteName2'
        AeriesSiteCode =    '2'
        GoogleOUs =         @('/Student/High School 2/Devices/1:1')
    } # Add as many sites as needed with mappings to CB OUs for that site
}
