# #region: Mock a config and load it for other functions to use
# Mock 'Set-SPSAccountSyncConfiguration' -ModuleName SPSAccountSync -MockWith {
#     Write-Verbose "Getting mocked SPSAccountSync config"
#     $script:SPSAccountSync = [PSCustomObject][Ordered]@{
#         ConfigName = 'Pester'
#         APIKey = ([System.IO.Path]::Combine($PSScriptRoot,"fake_api_key.xml"))
#         APIURL = 'https://prefix.domain.com/api/v3/'
#     }
# }
# Set-SPSAccountSyncConfiguration -Verbose
# #endregion

