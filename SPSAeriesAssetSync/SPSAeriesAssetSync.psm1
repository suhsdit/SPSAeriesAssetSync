#Get public and private function definition files.
$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\ -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\ -Filter *.ps1 -Recurse -ErrorAction SilentlyContinue)

#Dot source the files
Foreach($import in @($Public + $Private))
{
    Try
    {
        . $import.fullname
    }
    Catch
    {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Here I might...
# Read in or create an initial config file and variable


# Export Public functions ($Public.BaseName) for WIP modules

# Examples from Aeries Config info, set script variables
New-Variable -Name SPSAeriesAssetSyncConfigName -Scope Script -Force
New-Variable -Name SPSAeriesAssetSyncConfigRoot -Scope Script -Force
$SPSAeriesAssetSyncConfigRoot = "$Env:USERPROFILE\AppData\Local\powershell\SPSAeriesAssetSync"
New-Variable -Name SPSAeriesAssetSyncConfigDir -Scope Script -Force
New-Variable -Name Config -Scope Script -Force
#New-Variable -Name APIKey -Scope Script -Force
#New-Variable -Name SQLCreds -Scope Script -Force

Export-ModuleMember -Function $Public.Basename