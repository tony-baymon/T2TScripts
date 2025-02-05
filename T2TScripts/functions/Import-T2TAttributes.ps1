﻿Function Import-T2TAttributes {
    <#
    .SYNOPSIS
    The script will create on the target AD On-Prem the MEU objects getting all
    attribute values from the CSV generated by Export-T2TAttributes command.
    
    .DESCRIPTION
    The script will create on the target AD On-Prem the MEU objects getting all
    attribute values from the CSV generated by Export-T2TAttributes command.

    .PARAMETER UPNSuffix
    Mandatory parameter used to inform which is the UPN domain for the MEU object e.g: contoso.com

    .PARAMETER Password
    Optional parameter if you want to choose a password for all new MEU objects

    .PARAMETER ResetPassword
    Optional parameter if you want to require users to reset password in the first sign-in

    .PARAMETER OU
    Optional parameter if you want to create MEU objects in a specific OU. Valid values are
    name, Canonical name, Distinguished name (DN) or GUID. If not defined, the user object will
    be created on Users container.

    .PARAMETER FilePath
    Optional parameter used to inform which path will be used import the CSV. If no
    path is chosen, the script will search for UserListToImport.csv file on desktop path.

    .PARAMETER LocalMachineIsNotExchange
    Optional parameter used to inform that you are running the script from a
    non-Exchange Server machine. This parameter will require the -ExchangeHostname.

    .PARAMETER ExchangeHostname
    Mandatory parameter if the switch -LocalMachineIsNotExchange was used.
    Used to inform the Exchange Server FQDN that the script will connect.

    .EXAMPLE
    PS C:\> Import-T2TAttributes -UPNSuffix "fabrikam.com" -ResetPassword -FilePath "C:\temp\UserListToImport.csv"
    The function will import all users from the file "C:\temp\UserListToImport.csv", create the new MailUsers
    with the new UPNSuffix of "fabrikam.com", and enable the check mark to "Reset the password on next logon".

    .EXAMPLE
    PS C:\> Import-T2TAttributes -UPNSuffix "fabrikam.com" -ResetPassword -FilePath "C:\temp\UserListToImport.csv" -LocalMachineIsNotExchange -ExchangeHostname "ExServer2"
    The function will connect to the onprem Exchange Server "ExServer2" and import all users
    from the file "C:\temp\UserListToImport.csv", create the new MailUsers with the new UPNSuffix
    of "fabrikam.com", and enable the check mark to "Reset the password on next logon".

    .NOTES
    Title: Import-T2TAttributes.ps1
    Version: 1.2
    Date: 2021.01.03
    Author: Denis Vilaca Signorelli (denis.signorelli@microsoft.com)
    Contributors: Agustin Gallegos (agustin.gallegos@microsoft.com)


    REQUIREMENTS:
    
    1 - To make things easier, run this script from Exchange On-Premises machine powershell,
        the script will automatically import the Exchange On-Prem module. If you don't want
        to run the script from an Exchange machine, use the switch -LocalMachineIsNotExchange
        and enter the Exchange Server hostname.

    2 - The script encourage you to stop the Azure AD Sync cycle before the execution. The
        script can disable the sync for you as long as you provide the Azure AD Connect
        hostname. Otherwiser, you can disable by your self manually and then re-run the script.

    ##############################################################################################
    #This sample script is not supported under any Microsoft standard support program or service.
    #This sample script is provided AS IS without warranty of any kind.
    #Microsoft further disclaims all implied warranties including, without limitation, any implied
    #warranties of merchantability or of fitness for a particular purpose. The entire risk arising
    #out of the use or performance of the sample script and documentation remains with you. In no
    #event shall Microsoft, its authors, or anyone else involved in the creation, production, or
    #delivery of the scripts be liable for any damages whatsoever (including, without limitation,
    #damages for loss of business profits, business interruption, loss of business information,
    #or other pecuniary loss) arising out of the use of or inability to use the sample script or
    #documentation, even if Microsoft has been advised of the possibility of such damages.
    ##############################################################################################

    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlaintextForPassword", "")]
    [CmdletBinding(DefaultParameterSetName="Default")]
    Param(
        [Parameter(Mandatory=$true,
        HelpMessage="Enter UPN suffix of your domain E.g. contoso.com")]
        [string]$UPNSuffix,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Enter the password for the new MEU objects. If no password is chosen,
        the script will define '?r4mdon-_p@ss0rd!' as password")]
        [string]$Password,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Require password change on first user access")]
        [switch]$ResetPassword,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Enter the organization unit that MEU objects will be created.
        The input is accepted as Name, Canonical name, Distinguished name (DN) or GUID")]
        [string]$OU,
        
        [Parameter(Mandatory=$false,
        HelpMessage="Enter a custom import path for the csv. if no value is defined
        the script will search on Desktop path for the UserListToImport.csv")]
        [string]$FilePath,

        [Parameter(ParameterSetName="RemoteExchange",Mandatory=$false)]
        [switch]$LocalMachineIsNotExchange,
        
        [Parameter(ParameterSetName="RemoteExchange",Mandatory=$true,
        HelpMessage="Enter the remote exchange hostname")]
        [string]$ExchangeHostname
    )

    Set-PSFConfig -FullName PSFramework.Logging.FileSystem.ModernLog -Value $True
    Write-PSFMessage  -Level Output -Message "Starting script. All logs are being saved in: $((Get-PSFConfig PSFramework.Logging.FileSystem.LogPath).Value)"

    # Requirements check
    $AADCStopped =  Get-Requirements -Requirements AADConnect
    if ( $AADCStopped -eq 0 ) { Break }

    if ( $Password ) {
        
        $pwstr = $Password

    } else {

        $pwstr = "?r4mdon-_p@ss0rd!"

    }

    if ( $FilePath ) {
        
        $ImportUserList = Import-CSV "$FilePath"

    } else {

        $ImportUserList = Import-CSV "$home\desktop\UserListToImport.csv"

    }

    if ( $ResetPassword.IsPresent ) {

        [bool]$resetpwrd = $True

    } else {

        [bool]$resetpwrd = $False

    }


    $UPNSuffix = "@$UPNSuffix"
    $pw = new-object "System.Security.SecureString";
    #$CustomAttribute = "CustomAttribute$CustomAttributeNumber"

    # Connecto to Exchange and AD
    if ( $LocalMachineIsNotExchange ) {

        $ServicesToConnect = Assert-ServiceConnection -Services AD, ExchangeRemote
        # Connect to services if ServicesToConnect is not empty
        if ( $ServicesToConnect.Count ) { Connect-OnlineServices -Services $ServicesToConnect -ExchangeHostname $ExchangeHostname }
    
    } else {

        $ServicesToConnect = Assert-ServiceConnection -Services ExchangeLocal
        # Connect to services if ServicesToConnect is not empty
        if ( $ServicesToConnect.Count ) { Connect-OnlineServices -Services $ServicesToConnect }
    }

    for ($i=0; $i -lt $pwstr.Length; $i++) {$pw.AppendChar($pwstr[$i])}

    [int]$counter = 0
    $UsersCount = ($ImportUserList | Measure-Object).count
    foreach ($user in $ImportUserList)
    {
        $counter++
        Write-Progress -Activity "Creating MEU objects and importing attributes from CSV" -Status "Working on $($user.DisplayName)" -PercentComplete ($counter * 100 / $UsersCount )
        
        $tmpUser = $null
            
        $UPN = $user.Alias+$UPNSuffix
        
        # If OU was passed through param, honor it.
        # Otherwise create the MEU without OU specification
        if ( $OU )
        {
            $tmpUser = New-MailUser -UserPrincipalName $upn -ExternalEmailAddress $user.ExternalEmailAddress -FirstName $user.FirstName -LastName $user.LastName -SamAccountName $user.SamAccountName -Alias $user.alias -PrimarySmtpAddress $UPN -Name $User.Name -DisplayName $user.DisplayName -Password $pw -ResetPasswordOnNextLogon $resetpwrd -OrganizationalUnit $OU

        } else {

            $tmpUser = New-MailUser -UserPrincipalName $upn -ExternalEmailAddress $user.ExternalEmailAddress -FirstName $user.FirstName -LastName $user.LastName -SamAccountName $user.SamAccountName -Alias $user.alias -PrimarySmtpAddress $UPN -Name $User.Name -DisplayName $user.DisplayName -Password $pw -ResetPasswordOnNextLogon $resetpwrd

        }

        # Convert legacyDN to X500, replace back to ","
        $x500 = "x500:" + $user.legacyExchangeDN
        $proxy = $user.EmailAddresses.Replace(";",",")
        $ProxyArray = @()
        $ProxyArray = $Proxy -split ","
        $ProxyArray = $ProxyArray + $x500
        
        # Matching the variable's name to the parameter's name
        $CustomAttributeParam = @{ $User.CustomAttribute = $user.CustomAttributeValue }
        
        # Set ExchangeGuid, old LegacyDN as X500 and CustomAttribute
        $tmpUser | Set-MailUser -ExchangeGuid $user.ExchangeGuid @CustomAttributeParam -EmailAddresses @{ Add=$ProxyArray }

        # Set ELC value
        if ( $LocalMachineIsNotExchange.IsPresent -and $null -eq $LocalAD )
        {
            
            Set-RemoteADUser -Identity $user.SamAccountName -Replace @{ msExchELCMailboxFlags = $user.ELCValue }
                
        } else {

            Set-ADUser -Identity $user.SamAccountName -Replace @{ msExchELCMailboxFlags=$user.ELCValue }
		        
        }
                        
        # Set ArchiveGuid if user has source cloud archive. We don't really care if the
        # archive will be moved, it's up to the batch to decide, we just sync the attribute
        if ( $null -ne $user.ArchiveGuid -and $user.ArchiveGuid -ne '' )
        {
            
            $tmpUser | Set-MailUser -ArchiveGuid $user.ArchiveGuid
        
        }

        # If the user has Junk hash, convert the HEX string to byte array and set it
        if ( $null -ne $user.SafeSender -and $user.SafeSender -ne '' )
        {
        
            $BytelistSafeSender = New-Object -TypeName System.Collections.Generic.List[System.Byte]
            $HexStringSafeSender = $user.SafeSender
                for ($i = 0; $i -lt $HexStringSafeSender.Length; $i += 2)
                {
                    $HexByteSafeSender = [System.Convert]::ToByte($HexStringsafeSender.Substring($i, 2), 16)
                    $BytelistSafeSender.Add($HexByteSafeSender)
                }
            
            $BytelistSafeSenderArray = $BytelistSafeSender.ToArray()
            
                if ( $LocalMachineIsNotExchange.IsPresent -and $null -eq $LocalAD )
                {
                    
                    Set-RemoteADUser -Identity $user.SamAccountName -Replace @{ msExchSafeSendersHash = $BytelistSafeSenderArray }

                } else {

                    Set-ADUser -Identity $user.SamAccountName -Replace @{ msExchSafeSendersHash = $BytelistSafeSenderArray }

                }
            
        }

        if ( $null -ne $user.SafeRecipient -and $user.SafeRecipient -ne '' )
        {
        
            $BytelistSafeRecipient = New-Object -TypeName System.Collections.Generic.List[System.Byte]
            $HexStringSafeRecipient = $user.SafeRecipient
                for ($i = 0; $i -lt $HexStringSafeRecipient.Length; $i += 2)
                {
                    $HexByteSafeRecipient = [System.Convert]::ToByte($HexStringSafeRecipient.Substring($i, 2), 16)
                    $BytelistSafeRecipient.Add($HexByteSafeRecipient)
                }
            
            $BytelistSafeRecipientArray = $BytelistSafeRecipient.ToArray()
            
                if ( $LocalMachineIsNotExchange.IsPresent -and $null -eq $LocalAD )
                {
                    
                    Set-RemoteADUser -Identity $user.SamAccountName -Replace @{ msExchSafeRecipientsHash = $BytelistSafeRecipientArray }

                } else {

                    Set-ADUser -Identity $user.SamAccountName -Replace @{ msExchSafeRecipientsHash = $BytelistSafeRecipientArray }

                }
        
        }

        if ( $null -ne $user.BlockedSender -and $user.BlockedSender -ne '' )
        {
        
            $BytelistBlockedSender = New-Object -TypeName System.Collections.Generic.List[System.Byte]
            $HexStringBlockedSender = $user.BlockedSender
                for ($i = 0; $i -lt $HexStringBlockedSender.Length; $i += 2)
                {
                    $HexByteBlockedSender = [System.Convert]::ToByte($HexStringBlockedSender.Substring($i, 2), 16)
                    $BytelistBlockedSender.Add($HexByteBlockedSender)
                }
            
            $BytelistBlockedSenderArray = $BytelistBlockedSender.ToArray()
            
                if ( $LocalMachineIsNotExchange.IsPresent -and $null -eq $LocalAD )
                {
                    
                    Set-RemoteADUser -Identity $user.SamAccountName -Replace @{ msExchBlockedSendersHash = $BytelistBlockedSenderArray }

                } else {

                    Set-ADUser -Identity $user.SamAccountName -Replace @{ msExchBlockedSendersHash = $BytelistBlockedSenderArray }

                }
        
            }
        Write-PSFMessage -Level InternalComment -Message "$($user.alias) MailUser successfully created."
    }

    Write-PSFMessage -Level Output -Message "The import is completed. Please confirm that all users are correctly created before enable the Azure AD Sync Cycle."
    Write-PSFMessage -Level Output -Message "You can re-enable Azure AD Connect using the following cmdlet: 'Set-ADSyncScheduler -SyncCycleEnabled 1'"
    Remove-Variable * -ErrorAction SilentlyContinue
    Get-PSSession | Remove-PSSession

}