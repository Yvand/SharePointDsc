[CmdletBinding()]
param
(
    [Parameter()]
    [string]
    $SharePointCmdletModule = (Join-Path -Path $PSScriptRoot `
            -ChildPath "..\Stubs\SharePoint\15.0.4805.1000\Microsoft.SharePoint.PowerShell.psm1" `
            -Resolve)
)

$script:DSCModuleName = 'SharePointDsc'
$script:DSCResourceName = 'SPProjectServerAdditionalSettings'
$script:DSCResourceFullName = 'MSFT_' + $script:DSCResourceName

function Invoke-TestSetup
{
    try
    {
        Import-Module -Name DscResource.Test -Force

        Import-Module -Name (Join-Path -Path $PSScriptRoot `
                -ChildPath "..\UnitTestHelper.psm1" `
                -Resolve)

        $Global:SPDscHelper = New-SPDscUnitTestHelper -SharePointStubModule $SharePointCmdletModule `
            -DscResource $script:DSCResourceName
    }
    catch [System.IO.FileNotFoundException]
    {
        throw 'DscResource.Test module dependency not found. Please run ".\build.ps1 -Tasks build" first.'
    }

    $script:testEnvironment = Initialize-TestEnvironment `
        -DSCModuleName $script:DSCModuleName `
        -DSCResourceName $script:DSCResourceFullName `
        -ResourceType 'Mof' `
        -TestType 'Unit'
}

function Invoke-TestCleanup
{
    Restore-TestEnvironment -TestEnvironment $script:testEnvironment
}

Invoke-TestSetup

try
{
    Describe -Name $Global:SPDscHelper.DescribeHeader -Fixture {
        InModuleScope -ModuleName $Global:SPDscHelper.ModuleName -ScriptBlock {
            Invoke-Command -ScriptBlock $Global:SPDscHelper.InitializeScript -NoNewScope

            switch ($Global:SPDscHelper.CurrentStubBuildNumber.Major)
            {
                15
                {
                    Context -Name "All methods throw exceptions as Project Server support in SharePointDsc is only for 2016" -Fixture {
                        It "Should throw on the get method" {
                            { Get-TargetResource @testParams } | Should Throw
                        }

                        It "Should throw on the test method" {
                            { Test-TargetResource @testParams } | Should Throw
                        }

                        It "Should throw on the set method" {
                            { Set-TargetResource @testParams } | Should Throw
                        }
                    }
                }
                16
                {
                    $script:projectPath = "$PSScriptRoot\..\..\.." | Convert-Path
                    $script:projectName = (Get-ChildItem -Path "$script:projectPath\*\*.psd1" | Where-Object -FilterScript {
                            ($_.Directory.Name -match 'source|src' -or $_.Directory.Name -eq $_.BaseName) -and
                            $(try
                                { Test-ModuleManifest -Path $_.FullName -ErrorAction Stop
                                }
                                catch
                                { $false
                                })
                        }).BaseName

                    $script:parentModule = Get-Module -Name $script:projectName -ListAvailable | Select-Object -First 1
                    $script:subModulesFolder = Join-Path -Path $script:parentModule.ModuleBase -ChildPath 'Modules'

                    $modulePath = Join-Path -Path $script:subModulesFolder -ChildPath "SharePointDsc.ProjectServerConnector\SharePointDsc.ProjectServerConnector.psm1" -Resolve
                    Import-Module -Name $modulePath

                    [System.Reflection.Assembly]::LoadWithPartialName("System.ServiceModel") | Out-Null
                    $fullDllPath = Join-Path -Path $script:subModulesFolder -ChildPath "SharePointDsc.ProjectServerConnector\ProjectServerServices.dll" -Resolve
                    $bytes = [System.IO.File]::ReadAllBytes($fullDllPath)
                    [System.Reflection.Assembly]::Load($bytes) | Out-Null

                    Mock -CommandName "Import-Module" -MockWith { }

                    try
                    {
                        [SPDscTests.DummyWebService] | Out-Null
                    }
                    catch
                    {
                        Add-Type -TypeDefinition @"
                        namespace SPDscTests
                        {
                            public class DummyWebService : System.IDisposable
                            {
                                public void Dispose()
                                {

                                }
                            }
                        }
"@
                    }

                    Mock -CommandName Get-SPSite -MockWith {
                        return @{
                            WebApplication = @{
                                Url = "http://server"
                            }
                        }
                    }

                    Mock -CommandName Get-SPAuthenticationProvider -MockWith {
                        return @{
                            DisableKerberos = $true
                        }
                    }

                    Mock -CommandName "Get-SPProjectPermissionMode" -MockWith {
                        return "ProjectServer"
                    }

                    Mock -CommandName "New-SPDscProjectServerWebService" -ParameterFilter {
                        $EndpointName -eq "Admin"
                    } -MockWith {
                        $service = [SPDscTests.DummyWebService]::new()
                        $service = $service | Add-Member -MemberType ScriptMethod `
                            -Name GetProjectProfessionalMinimumBuildNumbers `
                            -Value {
                            return @{
                                Versions = @{
                                    Major    = 2
                                    Minor    = 0
                                    Build    = 0
                                    Revision = 0
                                    Rows     = @(
                                        @{
                                            Major    = 2
                                            Minor    = 0
                                            Build    = 0
                                            Revision = 0
                                        }
                                    )
                                }
                            }
                        } -PassThru -Force `
                        | Add-Member -MemberType ScriptMethod `
                            -Name GetServerCurrency `
                            -Value {
                            return "AUD"
                        } -PassThru -Force `
                        | Add-Member -MemberType ScriptMethod `
                            -Name GetSingleCurrencyEnforced `
                            -Value {
                            return $true
                        } -PassThru -Force `
                        | Add-Member -MemberType ScriptMethod `
                            -Name SetProjectProfessionalMinimumBuildNumbers `
                            -Value {
                            $global:SPDscSetProjectProfessionalMinimumBuildNumbersCalled = $true
                        } -PassThru -Force `
                        | Add-Member -MemberType ScriptMethod `
                            -Name SetServerCurrency `
                            -Value {
                            $global:SPDscSetServerCurrencyCalled = $true
                        } -PassThru -Force `
                        | Add-Member -MemberType ScriptMethod `
                            -Name SetSingleCurrencyEnforced `
                            -Value {
                            $global:SPDscSetSingleCurrencyEnforcedCalled = $true
                        } -PassThru -Force
                        return $service
                    }

                    Context -Name "Has incorrect settings applied" -Fixture {
                        $testParams = @{
                            Url                               = "http://server/pwa"
                            ProjectProfessionalMinBuildNumber = "1.0.0.0"
                            ServerCurrency                    = "USD"
                            EnforceServerCurrency             = $false
                        }

                        It "Should return current settings from the get method" {
                            Get-TargetResource @testParams | Should Not BeNullOrEmpty
                        }

                        It "Should return false from the test method" {
                            Test-TargetResource @testParams | Should Be $false
                        }

                        It "Should update all settings from the set method" {
                            $global:SPDscSetProjectProfessionalMinimumBuildNumbersCalled = $false
                            $global:SPDscSetServerCurrencyCalled = $false
                            $global:SPDscSetSingleCurrencyEnforcedCalled = $false
                            Set-TargetResource @testParams
                            $global:SPDscSetProjectProfessionalMinimumBuildNumbersCalled | Should Be $true
                            $global:SPDscSetServerCurrencyCalled | Should Be $true
                            $global:SPDscSetSingleCurrencyEnforcedCalled | Should Be $true
                        }
                    }

                    Context -Name "Has correct settings applied" -Fixture {
                        $testParams = @{
                            Url                               = "http://server/pwa"
                            ProjectProfessionalMinBuildNumber = "2.0.0.0"
                            ServerCurrency                    = "AUD"
                            EnforceServerCurrency             = $true
                        }

                        It "Should return current settings from the get method" {
                            Get-TargetResource @testParams | Should Not BeNullOrEmpty
                        }

                        It "Should return true from the test method" {
                            Test-TargetResource @testParams | Should Be $true
                        }
                    }

                }
                Default
                {
                    throw [Exception] "A supported version of SharePoint was not used in testing"
                }
            }
        }
    }
}
finally
{
    Invoke-TestCleanup
}
