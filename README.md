# rename-computer.ps1

This script is designed to be pushed out to a batch of computers and rename
them to <prefix><asset> based on their serial number.  The script gets the
information from the $csv variable, which needs to be defined in a csv format.
The design decision to include the csv information in the script instead of a
separate csv file was made in order to easily deploy the script through
Intune's built in powershell functionality which only allows for a single ps1
file to be uploaded.

The $csv variable needs to have the headers $csv="Tag,Serial,Prefix and the
data should follow, one computer per line in that order.  At the end of the
data, it should be closed with a following double quote.  It is important to 
make sure your csv data does not contain any single or double quotes.
Example:
 ```
    $csv="Tag,Serial,Prefix
    12345,System Serial Number,Test-
    40001,4CD03809Z4,MDE-
    40002,4CD0380B1R,MDE-
    40003,4CD03805LM,MDE-
    "
```
The script is controled by several administrator defined variables. 
 * $testRun - provides a way to test the script without rebooting or renaming the computer.  
 * $forceReboot - forces the system to restart after the name change.  
 * $rebootTimeoutInSec - if rebooting, how many seconds do you want to give the end user to save docs, etc. before rebooting.  
 * $notifyUser - notify the user using the Windows 10 toast notifications.  

Please read the comments above each variable for a more detailed description
of each variable.

This script is provided as-is and Josh Huwe nor the Mississippi Department of
Education make any warranty as to its effectiveness, nor that that it won't
destroy your computers and burn them down to the ground.  Use at your own risk!
It is highly recommended that this script is initially deployed to small test
batches of computers to ensure the behavior is expected.

If you run into issues, hit me up in email and I will make a best effort among
my other commitments to help you figure out what is going wrong.

For further reading of using Intune to push out PowerShell scripts  
https://docs.microsoft.com/en-us/mem/intune/apps/intune-management-extension

More information on the Show-Notification function  
 https://den.dev/blog/powershell-windows-notification/

Github repo for this project can be found here:  
https://github.com/jmhuwe/rename-computer
