[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidGlobalVars", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingComputerNameHardcoded", "")]
param()

$ErrorActionPreference = 'stop'
Set-StrictMode -Version latest

$RepoRoot = (Resolve-Path $PSScriptRoot\..\..).Path

Import-Module (Join-Path $RepoRoot "Modules\SharePointDsc\SharePointDsc.psd1")

Describe -Tags @("PostWebApp") "SPAlternateUrl - Integration Tests" {
    Context "Creates a new alternate URL" {
        It "Is able to create a service app" {
            $configName = "SPAlternateUrl-CreateNewUrl"
            Configuration $configName {
                Import-DscResource -ModuleName SharePointDsc
                node "localhost" {
                    SPAlternateUrl CreateAlternateUrl {
                        WebAppUrl            = "http://$($env:COMPUTERNAME)"
                        Url                  = "http://testurl.contoso.com"
                        Zone                 = "Internet"
                        Ensure               = "Present"
                        PsDscRunAsCredential = $Global:SPDscIntegrationCredPool.Setup
                    }
                }
            }
            . $configName -ConfigurationData $global:SPDscIntegrationConfigData -OutputPath "TestDrive:\$configName"
            Start-DscConfiguration -Wait -Force -Path "TestDrive:\$configName" -ComputerName "localhost"
            (Test-DscConfiguration -ComputerName "localhost" -ReferenceConfiguration "TestDrive:\$configName\localhost.mof").InDesiredState | Should be $true    
        }
    }

    Context "Updates existing alternate URLs" {
        It "Is able to update an existing alternate URL" {
            $configName = "SPAlternateUrl-UpdateUrl"
            Configuration $configName {
                Import-DscResource -ModuleName SharePointDsc
                node "localhost" {
                    SPAlternateUrl CreateAlternateUrl {
                        WebAppUrl            = "http://$($env:COMPUTERNAME)"
                        Url                  = "http://anotherurl.contoso.com"
                        Zone                 = "Internet"
                        Ensure               = "Present"
                        PsDscRunAsCredential = $Global:SPDscIntegrationCredPool.Setup
                    }
                }
            }
            . $configName -ConfigurationData $global:SPDscIntegrationConfigData -OutputPath "TestDrive:\$configName"
            Start-DscConfiguration -Wait -Force -Path "TestDrive:\$configName" -ComputerName "localhost"
            (Test-DscConfiguration -ComputerName "localhost" -ReferenceConfiguration "TestDrive:\$configName\localhost.mof").InDesiredState | Should be $true    
        }
    }

    Context "Delete existing alternate URLs" {
        It "Is able to delete an existing alternate URL" {
            $configName = "SPAlternateUrl-DeleteUrl"
            Configuration $configName {
                Import-DscResource -ModuleName SharePointDsc
                node "localhost" {
                    SPAlternateUrl CreateAlternateUrl {
                        WebAppUrl            = "http://$($env:COMPUTERNAME)"
                        Url                  = "http://anotherurl.contoso.com"
                        Zone                 = "Internet"
                        Ensure               = "Absent"
                        PsDscRunAsCredential = $Global:SPDscIntegrationCredPool.Setup
                    }
                }
            }
            . $configName -ConfigurationData $global:SPDscIntegrationConfigData -OutputPath "TestDrive:\$configName"
            Start-DscConfiguration -Wait -Force -Path "TestDrive:\$configName" -ComputerName "localhost"
            (Test-DscConfiguration -ComputerName "localhost" -ReferenceConfiguration "TestDrive:\$configName\localhost.mof").InDesiredState | Should be $true    
        }
    }

    AfterEach {
        Remove-DscConfigurationDocument -Stage Current, Pending, Previous -Force -Confirm:$false
    }
}
