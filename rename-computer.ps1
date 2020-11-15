##################################################################################
# rename-computer.ps1
#
# This script is designed to be pushed out to a batch of computers and rename
# them to <prefix><asset> based on their serial number.  The script gets the
# information from the $csv variable, which needs to be defined in a csv format.
# The design decision to include the csv information in the script instead of a
# separate csv file was made in order to easily deploy the script through
# Intune's built in powershell functionality which only allows for a single ps1
# file to be uploaded.
#
# The $csv variable needs to have the headers $csv="Tag,Serial,Prefix and the
# data should follow, one computer per line in that order.  At the end of the
# data, it should be closed with a following double quote.  It is important to 
# make sure your csv data does not contain any single or double quotes.
# Example:
#    $csv="Tag,Serial,Prefix
#    12345,System Serial Number,Test-
#    40001,4CD03809Z4,MDE-
#    40002,4CD0380B1R,MDE-
#    40003,4CD03805LM,MDE-
#    "
#
# The script is controled by several administrator defined variables. 
#     $testRun - provides a way to test the script without rebooting or renaming
#                the computer.
#     $forceReboot - forces the system to restart after the name change.
#     $rebootTimeoutInSec - if rebooting, how many seconds do you want to give
#                the end user to save docs, etc. before rebooting.
#     $notifyUser - notify the user using the Windows 10 toast notifications
# Please read the comments above each variable for a more detailed description
# of each variable.
#
# This script is provided as-is and Josh Huwe nor the Mississippi Department of
# Education make any warranty as to its effectiveness, nor that that it won't
# destroy your computers and burn them down to the ground.  Use at your own risk!
# It is highly recommended that this script is initially deployed to small test
# batches of computers to ensure the behavior is expected.
#
# If you run into issues, hit me up in email and I will make a best effort among
# my other commitments to help you figure out what is going wrong.
#
# For further reading of using Intune to push out PowerShell scripts
# https://docs.microsoft.com/en-us/mem/intune/apps/intune-management-extension
#
# More information on the Show-Notification function 
# https://den.dev/blog/powershell-windows-notification/
#
# Github repo for this project can be found here:
# https://github.com/jmhuwe/rename-computer
#

##################################################################################
# Begin user defined variables
#

# Will this be a test run? If $true, then the script will run through 
# but not rename or restart the computer.
# Set this variable to $true or $false
# Example:
#    $testRun = $true
$testRun = $false

# Will this computer be forced to restart? If $true, then if the script 
# finds a serial number match and is not a test run, it will then rename
# and restart the computer in $rebootTimeoutInSec seconds. 
# Set this variable to $true or $false
# Example:
#    $forceReboot = $false
$forceReboot = $true

# If the computer is being forced to reboot, how many seconds do you 
# want to delay reboot? This number is also used for toast notifcation 
# timeout.
# Set this variable to a positive integer value.
# Example:
#    $rebootTimeoutInSec = 30
$rebootTimeoutInSec = 300

# Do you want to notify the user using the Windows 10 toast notifications?
# If set to $true, it will use the toast notification.  If $false, then it
# will write output to the command line.
# Set this variable to $true or $false
# Example:
#    $notifyUser = $false
$notifyUser = $true

# This variable is the csv of your asset tag numbers, serial numbers, and
# prefixes. Make sure the first line is $csv="Tag,Serial,Prefix
# and make sure the last line is a single ". Make sure there are no single or
# double quotes in any of the individual values.
# Example:
#    $csv="Tag,Serial,Prefix
#    12345,System Serial Number,Test-
#    40001,4CD03809Z4,MDE-
#    40002,4CD0380B1R,MDE-
#    40003,4CD03805LM,MDE-
#    "

$csv="Tag,Serial,Prefix
12345,System Serial Number,Test-
112358,9084-6698-8936-5509-5710-1855-08,Test-
40002,5CD0380B1R,MDE-
40003,5CD03805LM,MDE-
"

#
# End user defined variables
##################################################################################


# This function displays a toast notification.  It appears to require
# Powershell version 5.1 to work as it is Windows specific. Powershell
# versions 6 and 7 are OS agnostic and therefore will not work. Modified
# to set the toaster timeout to $rebootTimeoutInSec 
# More information on this function can be found here:
# https://den.dev/blog/powershell-windows-notification/

function Show-Notification {
    [cmdletbinding()]
    Param (
        [string]
        $ToastTitle,
        [string]
        [parameter(ValueFromPipeline)]
        $ToastText
    )

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    $Template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)

    $RawXml = [xml] $Template.GetXml()
    ($RawXml.toast.visual.binding.text|Where-Object {$_.id -eq "1"}).AppendChild($RawXml.CreateTextNode($ToastTitle)) > $null
    ($RawXml.toast.visual.binding.text|Where-Object {$_.id -eq "2"}).AppendChild($RawXml.CreateTextNode($ToastText)) > $null

    $SerializedXml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $SerializedXml.LoadXml($RawXml.OuterXml)

    $Toast = [Windows.UI.Notifications.ToastNotification]::new($SerializedXml)
    $Toast.Tag = "PowerShell"
    $Toast.Group = "PowerShell"
    $Toast.ExpirationTime = [DateTimeOffset]::Now.AddSeconds($rebootTimeoutInSec)

    $Notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
    $Notifier.Show($Toast);
}

# Take the csv and convert it to a PSObject
$assets = $csv | ConvertFrom-Csv

# Get the serial number from WMI Objects.
$computerSerial = (Get-WmiObject win32_bios).Serialnumber

# Did we find a match?
$matchFound = $false

foreach ($asset in $assets){
    # If we have a match
    if($asset.Serial -eq $computerSerial){
        # Set the $matchFound flag to $true
        $matchFound = $true
        
        # Create the computer name string based off of prefix + tag
        $newComputerName = "$($asset.Prefix)$($asset.Tag)"

        # If this was a test run
        if ($testRun){
            # If we are notifying the user
            if($notifyUser){
                # Display toast notification
                Show-Notification "Test Notification" "This is a test run of the rename-computer.ps1 script. This computer has the serial number $($computerSerial) and would be renamed to $newComputerName."
            }
            # If we are not notifying the user
            else{
                # Write to the command line
                Write-Host "This is a test run of the rename-computer.ps1 script. This computer has the serial number $($computerSerial) and would be renamed to $newComputerName."
            }
        }
        # If not a test run, we make changes for real.
        else {
            # If we are forcing the computer to reboot
            if ($forceReboot){
                # Get the restart time to display
                $restartTime = ([DateTimeOffset]::Now.AddSeconds($rebootTimeoutInSec)).LocalDateTime.ToString("hh:mm tt")
                # If we are notifying the user
                if($notifyUser){
                    # Display toast notification
                    Show-Notification "System Restart Notification" "This computer, $newComputerName, needs to restart for maintenance.  Please save your work and close out any windows.  System restart will happen at $restartTime."
                    Rename-Computer -NewName $newComputerName -Force 
                    Start-Sleep -Seconds $rebootTimeoutInSec
                    Restart-Computer -Force
                }
                # If we are not notifying the user
                else{
                    # Write to the command line
                    Write-Host "This computer, $newComputerName, needs to restart for maintenance.  Please save your work and close out any windows.  System restart will happen at $restartTime."
                    Rename-Computer -NewName $newComputerName -Force 
                    Start-Sleep -Seconds $rebootTimeoutInSec
                    Restart-Computer -Force
                }
            }
            # If we are not forcing the reboot
            else {
                # If we are notifying the user
                if($notifyUser){
                    # Display toast notification
                    Show-Notification "System Restart Notification" "This computer's name will be updated to $newComputerName upon next system restart."
                    Rename-Computer -NewName $newComputerName -Force
                }
                # If we are not notifying the user
                else{
                    # Write to the command line
                    Write-Host "This computer's name will be updated to $newComputerName upon next system restart."
                    Rename-Computer -NewName $newComputerName -Force
                }
            }
        }
    }
}

# If we didn't find a match
if (-not $matchFound){
    # If we are not notifying the user
    if($notifyUser){
        # Display toast notification
        Show-Notification "Serial Number Not Found" "This computer has the serial number $($computerSerial) which could not be found. No computer rename will occur."
    }
    # If we are not notifying the user
    else{
        # Write to the command line
        Write-Host "This computer has the serial number $($computerSerial) which could not be found. No computer rename will occur."
    }
}