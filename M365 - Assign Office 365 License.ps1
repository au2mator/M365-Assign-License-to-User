#########
# au2mator PS Services
# Type: New Service
#
# Title: M365 - Assign Office 365 License
#
# v 1.0 Initial Release
# 
#
# Init Release: 10.06.2021
# Last Update: 10.06.2021
# Code Template V 1.3
#
# URL: https://au2mator.com/assign-office-365-license-microsoft-365-self-service-with-au2mator/?utm_source=github&utm_medium=social&utm_campaign=M365_AssignLicense&utm_content=PS1
# Github: https://github.com/au2mator/M365-Assign-License-to-User
#################

#region InputParamaters
##Question in au2mator
param (
    [parameter(Mandatory = $true)] 
    [String]$c_User,

    [parameter(Mandatory = $true)] 
    [String]$c_License,

    [parameter(Mandatory = $true)] 
    [String]$InitiatedBy, 

    [parameter(Mandatory = $true)] 
    [String]$RequestId, 
 
    [parameter(Mandatory = $true)] 
    [String]$Service, 
 
    [parameter(Mandatory = $true)] 
    [String]$TargetUserId
)
#endregion  InputParamaters

#region Variables
Set-ExecutionPolicy -ExecutionPolicy Bypass
$DoImportPSSession = $false


## Environment
[string]$PSRemotingServer = "demo01"
[string]$LogPath = "C:\_SCOworkingDir\TFS\PS-Services\M365 - Assign Office 365 License"
[string]$LogfileName = "Assign Office 365 License"

[string]$CredentialStorePath = "C:\_SCOworkingDir\TFS\PS-Services\CredentialStore" #see for details: https://click.au2mator.com/PSCreds/?utm_source=github&utm_medium=social&utm_campaign=M365_RemoveOwnerFromTeams&utm_content=PS1



$Modules = @("ActiveDirectory") #$Modules = @("ActiveDirectory", "SharePointPnPPowerShellOnline")


## au2mator Settings
[string]$PortalURL = "http://demo01.au2mator.local"
[string]$au2matorDBServer = "demo01"
[string]$au2matorDBName = "au2mator40Demo2"

## Control Mail
$SendMailToInitiatedByUser = $true #Send a Mail after Service is completed
$SendMailToTargetUser = $true #Send Mail to Target User after Service is completed

## SMTP Settings
$SMTPServer = "smtp.office365.com"
$SMPTAuthentication = $true #When True, User and Password needed
$EnableSSLforSMTP = $true
$SMTPSender = "SelfService@au2mator.com"
$SMTPPort = "587"

# Stored Credentials
# See: https://click.au2mator.com/PSCreds/?utm_source=github&utm_medium=social&utm_campaign=M365_RemoveOwnerFromTeams&utm_content=PS1
$SMTPCredential_method = "Stored" #Stored, Manual
$SMTPcredential_File = "SMTPCreds.xml"
$SMTPUser = ""
$SMTPPassword = ""

if ($SMTPCredential_method -eq "Stored") {
    $SMTPcredential = Import-CliXml -Path (Get-ChildItem -Path $CredentialStorePath -Filter $SMTPcredential_File).FullName
}

if ($SMTPCredential_method -eq "Manual") {
    $f_secpasswd = ConvertTo-SecureString $SMTPPassword -AsPlainText -Force
    $SMTPcredential = New-Object System.Management.Automation.PSCredential ($SMTPUser, $f_secpasswd)
}

#endregion Variables


#region CustomVariables

$GraphAPICred_File = "TeamsCreds.xml"
$GraphAPICred = Import-CliXml -Path (Get-ChildItem -Path $CredentialStorePath -Filter $GraphAPICred_File).FullName
$clientId = $GraphAPICred.clientId
$clientSecret = $GraphAPICred.clientSecret
$tenantName = $GraphAPICred.tenantName

#endregion CustomVariables




#region Functions
function Write-au2matorLog {
    [CmdletBinding()]
    param
    (
        [ValidateSet('DEBUG', 'INFO', 'WARNING', 'ERROR')]
        [string]$Type,
        [string]$Text
    )

    # Set logging path
    if (!(Test-Path -Path $logPath)) {
        try {
            $null = New-Item -Path $logPath -ItemType Directory
            Write-Verbose ("Path: ""{0}"" was created." -f $logPath)
        }
        catch {
            Write-Verbose ("Path: ""{0}"" couldn't be created." -f $logPath)
        }
    }
    else {
        Write-Verbose ("Path: ""{0}"" already exists." -f $logPath)
    }
    [string]$logFile = '{0}\{1}_{2}.log' -f $logPath, $(Get-Date -Format 'yyyyMMdd'), $LogfileName
    $logEntry = '{0}: <{1}> <{2}> <{3}> {4}' -f $(Get-Date -Format dd.MM.yyyy-HH:mm:ss), $Type, $RequestId, $Service, $Text
    Add-Content -Path $logFile -Value $logEntry
}

function ConnectToDB {
    # define parameters
    param(
        [string]
        $servername,
        [string]
        $database
    )
    Write-au2matorLog -Type INFO -Text "Function ConnectToDB"
    # create connection and save it as global variable
    $global:Connection = New-Object System.Data.SQLClient.SQLConnection
    $Connection.ConnectionString = "server='$servername';database='$database';trusted_connection=false; integrated security='true'"
    $Connection.Open()
    Write-au2matorLog -Type INFO -Text 'Connection established'
}

function ExecuteSqlQuery {
    # define parameters
    param(

        [string]
        $sqlquery

    )
    Write-au2matorLog -Type INFO -Text "Function ExecuteSqlQuery"
    #Begin {
    If (!$Connection) {
        Write-au2matorLog -Type WARNING -Text"No connection to the database detected. Run command ConnectToDB first."
    }
    elseif ($Connection.State -eq 'Closed') {
        Write-au2matorLog -Type INFO -Text 'Connection to the database is closed. Re-opening connection...'
        try {
            # if connection was closed (by an error in the previous script) then try reopen it for this query
            $Connection.Open()
        }
        catch {
            Write-au2matorLog -Type INFO -Text "Error re-opening connection. Removing connection variable."
            Remove-Variable -Scope Global -Name Connection
            Write-au2matorLog -Type WARNING -Text "Unable to re-open connection to the database. Please reconnect using the ConnectToDB commandlet. Error is $($_.exception)."
        }
    }
    #}

    #Process {
    #$Command = New-Object System.Data.SQLClient.SQLCommand
    $command = $Connection.CreateCommand()
    $command.CommandText = $sqlquery

    Write-au2matorLog -Type INFO -Text "Running SQL query '$sqlquery'"
    try {
        $result = $command.ExecuteReader()
    }
    catch {
        $Connection.Close()
    }
    $Datatable = New-Object "System.Data.Datatable"
    $Datatable.Load($result)

    return $Datatable

    #}

    #End {
    Write-au2matorLog -Type INFO -Text "Finished running SQL query."
    #}
}

function Get-UserInput ($RequestID) {
    [hashtable]$return = @{ }

    Write-au2matorLog -Type INFO -Text "Function Get-UserInput"
    ConnectToDB -servername $au2matorDBServer -database $au2matorDBName

    $Result = ExecuteSqlQuery -sqlquery "SELECT        RPM.Text AS Question, RP.Value
    FROM            dbo.Requests AS R INNER JOIN
                             dbo.RunbookParameterMappings AS RPM ON R.ServiceId = RPM.ServiceId INNER JOIN
                             dbo.RequestParameters AS RP ON RPM.ParameterName = RP.[Key] AND R.ID = RP.RequestId
    where RP.RequestId = '$RequestID' and rpm.IsDeleted = '0' order by [Order]"

    $html = "<table><tr><td><b>Question</b></td><td><b>Answer</b></td></tr>"
    $html = "<table>"
    foreach ($row in $Result) {
        #$row
        $html += "<tr><td><b>" + $row.Question + ":</b></td><td>" + $row.Value + "</td></tr>"
    }
    $html += "</table>"

    $f_RequestInfo = ExecuteSqlQuery -sqlquery "select InitiatedBy, TargetUserId,[ApprovedBy], [ApprovedTime], Comment from Requests where Id =  '$RequestID'"

    $Connection.Close()
    Remove-Variable -Scope Global -Name Connection

    $f_SamInitiatedBy = $f_RequestInfo.InitiatedBy.Split("\")[1]
    $f_UserInitiatedBy = Get-ADUser -Identity $f_SamInitiatedBy -Properties Mail


    $f_SamTarget = $f_RequestInfo.TargetUserId.Split("\")[1]
    $f_UserTarget = Get-ADUser -Identity $f_SamTarget -Properties Mail

    $return.InitiatedBy = $f_RequestInfo.InitiatedBy.trim()
    $return.MailInitiatedBy = $f_UserInitiatedBy.mail.trim()
    $return.MailTarget = $f_UserTarget.mail.trim()
    $return.TargetUserId = $f_RequestInfo.TargetUserId.trim()
    $return.ApprovedBy = $f_RequestInfo.ApprovedBy.trim()
    $return.ApprovedTime = $f_RequestInfo.ApprovedTime
    $return.Comment = $f_RequestInfo.Comment
    $return.HTML = $HTML

    return $return
}

Function Get-MailContent ($RequestID, $RequestTitle, $EndDate, $TargetUserId, $InitiatedBy, $Status, $PortalURL, $RequestedBy, $AdditionalHTML, $InputHTML) {

    Write-au2matorLog -Type INFO -Text "Function Get-MailContent"
    $f_RequestID = $RequestID
    $f_InitiatedBy = $InitiatedBy

    $f_RequestTitle = $RequestTitle

    try {
        $f_EndDate = (get-Date -Date $EndDate -Format (Get-Culture).DateTimeFormat.ShortDatePattern) + " (" + (get-Date -Date $EndDate -Format (Get-Culture).DateTimeFormat.ShortTimePattern) + ")"
    }
    catch {
        $f_EndDate = $EndDate
    }

    $f_RequestStatus = $Status
    $f_RequestLink = "$PortalURL/requeststatus?id=$RequestID"
    $f_HTMLINFO = $AdditionalHTML
    $f_InputHTML = $InputHTML

    $f_SamInitiatedBy = $f_InitiatedBy.Split("\")[1]
    $f_UserInitiatedBy = Get-ADUser -Identity $f_SamInitiatedBy -Properties DisplayName
    $f_DisplaynameInitiatedBy = $f_UserInitiatedBy.DisplayName


    $HTML = @'
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 1.5pt; background: #F7F8F3; mso-yfti-tbllook: 1184;" border="0" width="100%" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes; mso-yfti-lastrow: yes;">
    <td style="padding: .75pt .75pt .75pt .75pt;" valign="top">&nbsp;</td>
    <td style="width: 450.0pt; padding: .75pt .75pt .75pt .75pt; box-sizing: border-box;" valign="top" width="600">
    <div style="box-sizing: border-box;">
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 0cm; background: white; border: solid #E9E9E9 1.0pt; mso-border-alt: solid #E9E9E9 .75pt; mso-yfti-tbllook: 1184; mso-padding-alt: 0cm 0cm 0cm 0cm;" border="1" width="100%" cellspacing="0" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes;">
    <td style="border: none; background: #6ddc36; padding: 15.0pt 0cm 15.0pt 15.0pt;" valign="top">
    <p class="MsoNormal" style="line-height: 19.2pt;"><img src="https://au2mator.com/wp-content/uploads/2018/02/HPLogoau2mator-1.png" alt="" width="198" height="43" /></p>
    </td>
    </tr>
    <tr style="mso-yfti-irow: 1; box-sizing: border-box;">
    <td style="border: none; padding: 15.0pt 15.0pt 15.0pt 15.0pt; box-sizing: border-box;" valign="top">
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 0cm; mso-yfti-tbllook: 1184; mso-padding-alt: 0cm 0cm 0cm 0cm; box-sizing: border-box;" border="0" width="100%" cellspacing="0" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes; mso-yfti-lastrow: yes; box-sizing: border-box;">
    <td style="padding: 0cm 0cm 15.0pt 0cm; box-sizing: border-box;" valign="top">
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 0cm; mso-yfti-tbllook: 1184; mso-padding-alt: 0cm 0cm 0cm 0cm; box-sizing: border-box;" border="0" width="100%" cellspacing="0" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes; mso-yfti-lastrow: yes; box-sizing: border-box;">
    <td style="width: 55.0%; padding: 0cm 0cm 0cm 0cm; box-sizing: border-box;" valign="top" width="55%">
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 0cm; mso-yfti-tbllook: 1184; mso-padding-alt: 0cm 0cm 0cm 0cm;" border="0" width="100%" cellspacing="0" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes;">
    <td style="width: 18.75pt; border-top: solid #E3E3E3 1.0pt; border-left: solid #E3E3E3 1.0pt; border-bottom: none; border-right: none; mso-border-top-alt: solid #E3E3E3 .75pt; mso-border-left-alt: solid #E3E3E3 .75pt; padding: 0cm 0cm 0cm 0cm; box-sizing: border-box;" width="25">
    <p class="MsoNormal" style="text-align: center; line-height: 19.2pt;" align="center">&nbsp;</p>
    </td>
    <td style="border-top: solid #E3E3E3 1.0pt; border-left: none; border-bottom: none; border-right: solid #E3E3E3 1.0pt; mso-border-top-alt: solid #E3E3E3 .75pt; mso-border-right-alt: solid #E3E3E3 .75pt; padding: 0cm 0cm 3.75pt 0cm; font-color: #0000;"><strong>End Date</strong>: ##EndDate</td>
    </tr>
    <tr style="mso-yfti-irow: 1;">
    <td style="border-top: solid #E3E3E3 1.0pt; border-left: solid #E3E3E3 1.0pt; border-bottom: none; border-right: none; mso-border-top-alt: solid #E3E3E3 .75pt; mso-border-left-alt: solid #E3E3E3 .75pt; padding: 0cm 0cm 0cm 0cm;">
    <p class="MsoNormal" style="text-align: center; line-height: 19.2pt;" align="center">&nbsp;</p>
    </td>
    <td style="border-top: solid #E3E3E3 1.0pt; border-left: none; border-bottom: none; border-right: solid #E3E3E3 1.0pt; mso-border-top-alt: solid #E3E3E3 .75pt; mso-border-right-alt: solid #E3E3E3 .75pt; padding: 0cm 0cm 3.75pt 0cm;"><strong>Status</strong>: ##Status</td>
    </tr>
    <tr style="mso-yfti-irow: 2; mso-yfti-lastrow: yes;">
    <td style="border: solid #E3E3E3 1.0pt; border-right: none; mso-border-top-alt: solid #E3E3E3 .75pt; mso-border-left-alt: solid #E3E3E3 .75pt; mso-border-bottom-alt: solid #E3E3E3 .75pt; padding: 0cm 0cm 3.75pt 0cm;">
    <p class="MsoNormal" style="text-align: center; line-height: 19.2pt;" align="center">&nbsp;</p>
    </td>
    <td style="border: solid #E3E3E3 1.0pt; border-left: none; mso-border-top-alt: solid #E3E3E3 .75pt; mso-border-bottom-alt: solid #E3E3E3 .75pt; mso-border-right-alt: solid #E3E3E3 .75pt; padding: 0cm 0cm 3.75pt 0cm;"><strong>Requested By</strong>: ##RequestedBy</td>
    </tr>
    </tbody>
    </table>
    </td>
    <td style="width: 5.0%; padding: 0cm 0cm 0cm 0cm; box-sizing: border-box;" width="5%">
    <p class="MsoNormal" style="line-height: 19.2pt;"><span style="font-size: 9.0pt; font-family: 'Helvetica',sans-serif; mso-fareast-font-family: 'Times New Roman';">&nbsp;</span></p>
    </td>
    <td style="width: 40.0%; padding: 0cm 0cm 0cm 0cm; box-sizing: border-box;" valign="top" width="40%">
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 0cm; background: #FAFAFA; mso-yfti-tbllook: 1184; mso-padding-alt: 0cm 0cm 0cm 0cm;" border="0" width="100%" cellspacing="0" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes; mso-yfti-lastrow: yes;">
    <td style="width: 100.0%; border: solid #E3E3E3 1.0pt; mso-border-alt: solid #E3E3E3 .75pt; padding: 7.5pt 0cm 1.5pt 3.75pt;" width="100%">
    <p style="text-align: center;" align="center"><span style="font-size: 10.5pt; color: #959595;">au2mator Request ID</span></p>
    <p style="text-align: center;" align="center"><u><span style="font-size: 12.0pt; color: black;"><a href="##RequestLink"><span style="color: black;">##REQUESTID</span></a></span></u></p>
    <p class="MsoNormal" style="text-align: center;" align="center"><span style="mso-fareast-font-family: 'Times New Roman';">&nbsp;</span></p>
    </td>
    </tr>
    </tbody>
    </table>
    </td>
    </tr>
    </tbody>
    </table>
    </td>
    </tr>
    </tbody>
    </table>
    </td>
    </tr>
    <tr style="mso-yfti-irow: 2; box-sizing: border-box;">
    <td style="border: none; padding: 0cm 15.0pt 15.0pt 15.0pt; box-sizing: border-box;" valign="top">
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 0cm; mso-yfti-tbllook: 1184; mso-padding-alt: 0cm 0cm 0cm 0cm; box-sizing: border-box;" border="0" width="100%" cellspacing="0" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes; box-sizing: border-box;">
    <td style="padding: 0cm 0cm 15.0pt 0cm; box-sizing: border-box;" valign="top">
    <p class="MsoNormal" style="line-height: 19.2pt;"><strong><span style="font-size: 10.5pt; font-family: 'Helvetica',sans-serif; mso-fareast-font-family: 'Times New Roman';">Dear ##UserDisplayname,</span></strong></p>
    </td>
    </tr>
    <tr style="mso-yfti-irow: 1; box-sizing: border-box;">
    <td style="padding: 0cm 0cm 15.0pt 0cm; box-sizing: border-box;" valign="top">
    <p class="MsoNormal" style="line-height: 19.2pt;"><span style="font-size: 10.5pt; font-family: 'Helvetica',sans-serif; mso-fareast-font-family: 'Times New Roman';">We finished the Request <strong>"##RequestTitle"</strong>!<br /> <br /> Here are the Result of the Request:<br /><b>##HTMLINFO&nbsp;</b><br /></span></p>
    <div>&nbsp;</div>
    <div>See the details of the Request</div>
    <div>##InputHTML</div>
    <div>&nbsp;</div>
    <div>&nbsp;</div>
    Kind regards,<br /> au2mator Self Service Team
    <p>&nbsp;</p>
    </td>
    </tr>
    <tr style="mso-yfti-irow: 2; mso-yfti-lastrow: yes; box-sizing: border-box;">
    <td style="padding: 0cm 0cm 15.0pt 0cm; box-sizing: border-box;" valign="top">
    <p class="MsoNormal" style="text-align: center; line-height: 19.2pt;" align="center"><span style="font-size: 10.5pt; font-family: 'Helvetica',sans-serif; mso-fareast-font-family: 'Times New Roman';"><a style="border-radius: 3px; -webkit-border-radius: 3px; -moz-border-radius: 3px; display: inline-block;" href="##RequestLink"><strong><span style="color: white; border: solid #50D691 6.0pt; padding: 0cm; background: #50D691; text-decoration: none; text-underline: none;">View your Request</span></strong></a></span></p>
    </td>
    </tr>
    </tbody>
    </table>
    </td>
    </tr>
    <tr style="mso-yfti-irow: 3; mso-yfti-lastrow: yes; box-sizing: border-box;">
    <td style="border: none; padding: 0cm 0cm 0cm 0cm; box-sizing: border-box;" valign="top">
    <table class="MsoNormalTable" style="width: 100.0%; mso-cellspacing: 0cm; background: #333333; mso-yfti-tbllook: 1184; mso-padding-alt: 0cm 0cm 0cm 0cm;" border="0" width="100%" cellspacing="0" cellpadding="0">
    <tbody>
    <tr style="mso-yfti-irow: 0; mso-yfti-firstrow: yes; mso-yfti-lastrow: yes; box-sizing: border-box;">
    <td style="width: 50.0%; border: none; border-right: solid lightgrey 1.0pt; mso-border-right-alt: solid lightgrey .75pt; padding: 22.5pt 15.0pt 22.5pt 15.0pt; box-sizing: border-box;" valign="top" width="50%">&nbsp;</td>
    <td style="width: 50.0%; padding: 22.5pt 15.0pt 22.5pt 15.0pt; box-sizing: border-box;" valign="top" width="50%">&nbsp;</td>
    </tr>
    </tbody>
    </table>
    </td>
    </tr>
    </tbody>
    </table>
    </div>
    </td>
    <td style="padding: .75pt .75pt .75pt .75pt; box-sizing: border-box;" valign="top">&nbsp;</td>
    </tr>
    </tbody>
    </table>
    <p class="MsoNormal"><span style="mso-fareast-font-family: 'Times New Roman';">&nbsp;</span></p>
'@

    $html = $html.replace('##REQUESTID', $f_RequestID).replace('##UserDisplayname', $f_DisplaynameInitiatedBy).replace('##RequestTitle', $f_RequestTitle).replace('##EndDate', $f_EndDate).replace('##Status', $f_RequestStatus).replace('##RequestedBy', $f_InitiatedBy).replace('##HTMLINFO', $f_HTMLINFO).replace('##InputHTML', $f_InputHTML).replace('##RequestLink', $f_RequestLink)

    return $html
}

Function Send-ServiceMail ($HTMLBody, $ServiceName, $Recipient, $RequestID, $RequestStatus) {
    Write-au2matorLog -Type INFO -Text "Function Send-ServiceMail"
    $f_Subject = "au2mator - $ServiceName Request [$RequestID] - $RequestStatus"
    Write-au2matorLog -Type INFO -Text "Subject:  $f_Subject "
    Write-au2matorLog -Type INFO -Text "Recipient: $Recipient"

    try {
        if ($SMPTAuthentication) {

            if ($EnableSSLforSMTP) {
                Write-au2matorLog -Type INFO -Text "Run SMTP with Authentication and SSL"
                Send-MailMessage -SmtpServer $SMTPServer -To $Recipient -From $SMTPSender -Subject $f_Subject -Body $HTMLBody -BodyAsHtml -Priority high -Credential $SMTPcredential -UseSsl -Port $SMTPPort
            }
            else {
                Write-au2matorLog -Type INFO -Text "Run SMTP with Authentication and no SSL"
                Send-MailMessage -SmtpServer $SMTPServer -To $Recipient -From $SMTPSender -Subject $f_Subject -Body $HTMLBody -BodyAsHtml -Priority high -Credential $SMTPcredential -Port $SMTPPort
            }
        }
        else {

            if ($EnableSSLforSMTP) {
                Write-au2matorLog -Type INFO -Text "Run SMTP without Authentication and SSL"
                Send-MailMessage -SmtpServer $SMTPServer -To $Recipient -From $SMTPSender -Subject $f_Subject -Body $HTMLBody -BodyAsHtml -Priority high -UseSsl -Port $SMTPPort
            }
            else {
                Write-au2matorLog -Type INFO -Text "Run SMTP without Authentication and no SSL"
                Send-MailMessage -SmtpServer $SMTPServer -To $Recipient -From $SMTPSender -Subject $f_Subject -Body $HTMLBody -BodyAsHtml -Priority high -Port $SMTPPort
            }
        }
    }
    catch {
        Write-au2matorLog -Type WARNING -Text "Error on sending Mail"
        Write-au2matorLog -Type WARNING -Text $Error
    }

}
#endregion Functions


#region CustomFunctions

# This is a sample list of comon used SKUIDs
# List is taken from here: https://docs.microsoft.com/en-us/azure/active-directory/enterprise-users/licensing-service-plan-reference
Function GET-SKUId {
   
    Param (
        [string]$Name,
        [string]$Searchcoloumn,
        [string]$resultcoloumn
    )
    $data = @(
        [pscustomobject]@{ProductName = 'POWER BI (FREE)'; SKUID = 'a403ebcc-fae0-4ca2-8c8c-7a907fd6c235' }
        [pscustomobject]@{ProductName = 'POWER BI PRO'; SKUID = 'f8a1db68-be16-40ed-86d5-cb42ce701560' }
        [pscustomobject]@{ProductName = 'EXCHANGE ONLINE (PLAN 1)'; SKUID = '4b9405b0-7788-4568-add1-99614e613b69' }
        [pscustomobject]@{ProductName = 'EXCHANGE ONLINE (PLAN 2)'; SKUID = '19ec0d23-8335-4cbd-94ac-6050e30712fa' }
        [pscustomobject]@{ProductName = 'ONEDRIVE FOR BUSINESS (PLAN 1)'; SKUID = 'e6778190-713e-4e4f-9119-8b8238de25df' }
        [pscustomobject]@{ProductName = 'ONEDRIVE FOR BUSINESS (PLAN 2)'; SKUID = 'ed01faf2-1d88-4947-ae91-45ca18703a96' }
        [pscustomobject]@{ProductName = 'PROJECT PLAN 1'; SKUID = 'beb6439c-caad-48d3-bf46-0c82871e12be' }
        [pscustomobject]@{ProductName = 'Microsoft StaffHub'; SKUID = '8c7d2df8-86f0-4902-b2ed-a0458298f3b3' }
    )
 
    $result = $data | Where-Object { $_.$Searchcoloumn -eq $Name } | select -Property $resultcoloumn
    return $result[0].$resultcoloumn
 
}

#endregion CustomFunctions

#region Script
Write-au2matorLog -Type INFO -Text "Start Script"


if ($DoImportPSSession) {

    Write-au2matorLog -Type INFO -Text "Import-Pssession"
    $PSSession = New-PSSession -ComputerName $PSRemotingServer
    Import-PSSession -Session $PSSession -DisableNameChecking -AllowClobber 
}

#Check for Modules if installed
Write-au2matorLog -Type INFO -Text "Try to install all PowerShell Modules"
foreach ($Module in $Modules) {
    if (Get-Module -ListAvailable -Name $Module) {
        Write-au2matorLog -Type INFO -Text "Module is already installed:  $Module"        
    }
    else {
        Write-au2matorLog -Type INFO -Text "Module is not installed, try simple method:  $Module"
        try {

            Install-Module $Module -Force -Confirm:$false
            Write-au2matorLog -Type INFO -Text "Module was installed the simple way:  $Module"

        }
        catch {
            Write-au2matorLog -Type INFO -Text "Module is not installed, try the advanced way:  $Module"
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Install-PackageProvider -Name NuGet  -MinimumVersion 2.8.5.201 -Force
                Install-Module $Module -Force -Confirm:$false
                Write-au2matorLog -Type INFO -Text "Module was installed the advanced way:  $Module"

            }
            catch {
                Write-au2matorLog -Type ERROR -Text "could not install module:  $Module"
                $au2matorReturn = "could not install module:  $Module, Error: $Error"
                $AdditionalHTML = "could not install module:  $Module, Error: $Error
                "
                $Status = "ERROR"
            }
        }
    }
    Write-au2matorLog -Type INFO -Text "Import Module:  $Module"
    Import-module $Module
}

#region CustomCode
Write-au2matorLog -Type INFO -Text "Start Custom Code"
$error.Clear()

try {
    Write-au2matorLog -Type INFO -Text "Try to connect to GRAPH API
        
    $tokenBody = @{  
        Grant_Type    = "client_credentials"  
        Scope         = "https://graph.microsoft.com/.default"  
        Client_Id     = $clientId  
        Client_Secret = $clientSecret  
    }   
  
    $tokenResponse = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$TenantName/oauth2/v2.0/token" -Method POST -Body $tokenBody  

    $headers = @{
        "Authorization" = "Bearer $($tokenResponse.access_token)"
        "Content-type"  = "application/json"
    }

    try {
        Write-au2matorLog -Type INFO -Text "Try to map the selected License to its SKU ID"
        
        $SKUID = GET-SKUId -Name "$c_License" -Searchcoloumn "ProductName" -resultcoloumn "SKUID"

        if ($SKUID.length -eq 36) {
            Write-au2matorLog -Type INFO -Text "SKUID found so continue: $SKUID"
        }
        else {

            Write-au2matorLog -Type WARNING -Text "No SKUID found for $c_License"
            throw
        }


        try {
            $UPN = (Get-ADUser -Identity $c_User).UserPrincipalName

            $URLtoassignLicense = "https://graph.microsoft.com/v1.0/users/$UPN/assignLicense" 
            $BodyJsontoassignLicense = @"
            {
                "addLicenses":[
                      {
                        "disabledPlans": [ ],
                        "skuId": " $SKUID"
                      }
                   ],
                   "removeLicenses": []
            }
"@
    
            $Result = Invoke-RestMethod -Headers $headers -Body $BodyJsontoassignLicense -Uri $URLtoassignLicense -Method POST
            $au2matorReturn = "The License $C_license($SKUID) was assigned to User $UPN"
            $AdditionalHTML = "The License $C_license($SKUID) was assigned to User $UPN
            <br>
            "
            $Status = "COMPLETED"
        }

        catch {
            Write-au2matorLog -Type ERROR -Text "Could not assign the License"
            Write-au2matorLog -Type ERROR -Text "Error: $Error"

            $au2matorReturn = "Could not assign the License, Error: $Error"
            $AdditionalHTML = "Could not assign the License
            <br>
            Error: $Error
            "
            $Status = "ERROR"
        }
    }
    catch {
        Write-au2matorLog -Type ERROR -Text "Could not get a SKUID for the selected License"
        Write-au2matorLog -Type ERROR -Text "Error: $Error"

        $au2matorReturn = "Could not get a SKUID for the selected License, Error: $Error"
        $AdditionalHTML = "Could not get a SKUID for the selected License
        <br>
        Error: $Error
            "
        $Status = "ERROR"
    }
}
catch {
    Write-au2matorLog -Type ERROR -Text "Error on connecting to GRAPH API, Error: $Error"
    Write-au2matorLog -Type ERROR -Text "Error on connecting to GRAPH API: $Error"

    $au2matorReturn = "Error on connecting to GRAPH API, Error: $Error"
    $AdditionalHTML = "Error on connecting to GRAPH API
        <br>
        Error: $Error
            "
    $Status = "ERROR"
}



#endregion CustomCode
#endregion Script

#region Return


Write-au2matorLog -Type INFO -Text "Service finished"

if ($SendMailToInitiatedByUser) {
    Write-au2matorLog -Type INFO -Text "Send Mail to Initiated By User"

    $UserInput = Get-UserInput -RequestID $RequestId
    $HTML = Get-MailContent -RequestID $RequestId -RequestTitle $Service -EndDate $UserInput.ApprovedTime -TargetUserId $UserInput.TargetUserId -InitiatedBy $UserInput.InitiatedBy -Status $Status -PortalURL $PortalURL  -AdditionalHTML $AdditionalHTML -InputHTML $UserInput.html
    Send-ServiceMail -HTMLBody $HTML -RequestID $RequestId -Recipient $($UserInput.MailInitiatedBy) -RequestStatus $Status -ServiceName $Service
}

if ($SendMailToTargetUser) {
    Write-au2matorLog -Type INFO -Text "Send Mail to Target User"

    $UserInput = Get-UserInput -RequestID $RequestId
    $HTML = Get-MailContent -RequestID $RequestId -RequestTitle $Service -EndDate $UserInput.ApprovedTime -TargetUserId $UserInput.TargetUserId -InitiatedBy $UserInput.InitiatedBy -Status $Status -PortalURL $PortalURL -AdditionalHTML $AdditionalHTML -InputHTML $UserInput.html
    Send-ServiceMail -HTMLBody $HTML -RequestID $RequestId -Recipient $($UserInput.MailTarget) -RequestStatus $Status -ServiceName $Service
}

return $au2matorReturn
#endregion Return

