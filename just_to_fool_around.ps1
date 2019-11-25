<#check default gateway to do an educated guess on which network I might be 
        
        LHO 2019-11-18 V0.1 first attempt to check basic funtionality
        LHO 2019-11-18 V0.2 fine tuned using Rolfs Syntax input 
#>
foreach($line in $(arp.exe -a   $((Get-WmiObject -Class Win32_IP4RouteTable |   Where-Object { $_.destination -eq '0.0.0.0' -and $_.mask -eq '0.0.0.0'}).nexthop)))
{
       if($line -like "*dynamic*") 
        {
                $MAC = $line.Substring(24,17)
        }
}

switch ($MAC) # add your known macs here as a part of the switch 
{ 
        "b8-af-67-f4-fb-2d"     {
                                Write-Host "Looks like Office";
                                # do stuff here like set RDP Permission OFF;
                                Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value '1'
                                # now let's check if we set it properly
                                if((Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections -eq "1") 
                                        { 
                                        Write-Host "Remote Desktop is disabled."
                                        }
                                else 
                                        {  
                                        Write-Host "!! Remote Desktop is still enabled !!"
                                        }
                                }
        
        # if we cannot identify the network...
        default {Write-Host "not sure which network we are on right now. The default GW MAC is: " $MAC}                
}
