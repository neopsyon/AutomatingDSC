Configuration ActiveDirectoryMaster {
    param(
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName xActiveDirectory
    Import-DscResource -ModuleName xDNSServer
    Import-DscResource -ModuleName NetworkingDsc
    Import-DSCResource -ModuleName ComputerManagementDsc
    Node $AllNodes.NodeName {
        $DomainNameStructure = "DC=custom,DC=company"
        Computer 'AD-Master-Computer' {
            Name = 'AD-MASTER'
        }
        xADOrganizationalUnit 'DisabledObjects' {
            Name = 'DisabledObjects'
            Path = "$DomainNameStructure"
            Ensure = 'Present'
            Credential = $Credential
        }
        xADOrganizationalUnit 'Computers' {
            Name = 'Computers'
            Path = "OU=DisabledObjects,$DomainNameStructure"
            Ensure = 'Present'
            ProtectedFromAccidentalDeletion = $true
            Credential = $Credential
            DependsOn = '[xADOrganizationalUnit]DisabledObjects'
        }
        xADOrganizationalUnit 'Users' {
            Name = 'Users'
            Path = "OU=DisabledObjects,$DomainNameStructure"
            Ensure = 'Present'
            ProtectedFromAccidentalDeletion = $true
            Credential = $Credential
            DependsOn = '[xADOrganizationalUnit]DisabledObjects'

        }
        xADOrganizationalUnit 'ServiceAdministration' {
            Name = 'ServiceAdministration'
            Path = "$DomainNameStructure"
            Ensure = 'Present'
            ProtectedFromAccidentalDeletion = $true
            Credential = $Credential
        }
        xADOrganizationalUnit 'ServiceAccounts' {
            Name = 'ServiceAccounts'
            Path = "OU=ServiceAdministration,$DomainNameStructure"
            Ensure = 'Present'
            ProtectedFromAccidentalDeletion = $true
            Credential = $Credential
            DependsOn = '[xADOrganizationalUnit]ServiceAdministration'
        }
        xADOrganizationalUnit 'Servers' {
            Name = 'Servers'
            Path = "OU=ServiceAdministration,$DomainNameStructure"
            Ensure = 'Present'
            ProtectedFromAccidentalDeletion = $true
            Credential = $Credential
            DependsOn = '[xADOrganizationalUnit]ServiceAdministration'
        }
        xADOrganizationalUnit 'AdministrativeUsers' {
            Name = 'AdministrativeUsers'
            Path = "OU=ServiceAdministration,$DomainNameStructure"
            Ensure = 'Present'
            ProtectedFromAccidentalDeletion = $true
            Credential = $Credential
            DependsOn = '[xADOrganizationalUnit]ServiceAdministration'
        }
        xADRecycleBin 'RecycleBin' {
            EnterpriseAdministratorCredential = $Credential
            ForestFQDN = 'nvm.global'
        }
        xDnsServerADZone 'DNS-NVM-GLOBAL' {
            Name = 'nvm.global'
            ReplicationScope = 'Forest'
            DynamicUpdate = 'Secure'
            Ensure = 'Present'
        }
        xDnsServerSetting 'AD-MASTER' {
            Name = 'AD-MASTER'
            AddressAnswerLimit = 28
            AllowUpdate = 1
            AutoConfigFileZones = 1
            DefaultAgingState = 1
            DisableAutoReverseZones = $false
            DisjointNets = $false
            EventLogLevel = 4
            Forwarders = '169.254.169.253','8.8.8.8','8.8.4.4'
            LocalNetPriority = $true
            MaxCacheTTL = 1800
            ScavengingInterval = 1
            DependsOn = '[xDnsServerADZone]DNS-CUSTOM-COMPANY'
        }
        xDnsServerZoneAging 'DNS-NVM-GLOBAL-Aging' {
            Name = 'custom.company'
            Enabled = $true
            RefreshInterval = 7
            NoRefreshInterval = 7
            DependsOn = '[xDnsServerADZone]DNS-CUSTOM-COMPANY'
        }
        DnsClientGlobalSetting 'DNSSettings' {
            IsSingleInstance = 'Yes'
            SuffixSearchList = 'custom.company'
            UseDevolution = $true
            DevolutionLevel = 0
        }
    }
}