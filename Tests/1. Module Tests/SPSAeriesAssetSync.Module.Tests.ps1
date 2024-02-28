Describe "SPSAeriesAssetSync Module Tests" {

    BeforeAll {
        $here = $PSScriptRoot
        $script:module = "SPSAeriesAssetSync"
        $script:moduleDirectory = (get-item $here).parent.parent.FullName + "\$module"
    }
    
    Context 'Module Setup' {
        
        It "has the root module $script:module.psm1"{
            "$script:moduleDirectory\$script:module.psm1" | Should -Exist
        }

        It "has the masifest file of $script:module.psd1" {
            "$script:moduleDirectory\$script:module.psd1" | Should -Exist
        }

        It "$script:module folder has functions" {
            (Get-ChildItem -Path "$script:moduleDirectory\Public" -Recurse -Include *.ps1).Count | Should -BeGreaterThan 0
        }
    }
}