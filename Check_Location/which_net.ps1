<#check default gateway to do an educated guess on which network I might be 
        
        LHO 2019-11-18 V0.1 first attempt to check basic funtionality
        LHO 2019-11-18 V0.2 fine tuned using Rolfs Syntax input 
        LHO 2019-11-20 V0.3 Multiple ansewrs for defaultgateway => stronger selection
        LHO 2019-11-20 V0.4 Creating directory and files on first run. Writing to log file
        LHo 2019-11-25 V0.5 Introduced Option Object to store different options
#>

# Get-wmi Info and select nexthop ... most of the times being the default gateway => needs to vaildated in different environments
# $Def_GW = (Get-WmiObject -Class Win32_IP4RouteTable |   Where-Object { $_.destination -eq '0.0.0.0' -and $_.mask -eq '0.0.0.0'}).nexthop 
# => Piping a lot => not ideal for performance
# $Def_GW = (Get-WmiObject -Class Win32_IP4RouteTable -filter "destination='0.0.0.0' and mask='0.0.0.0' and InterfaceIndex=$adapter").nexthop
# only the records matching the selection filter will be processd in Powershell => Less overhead => better performance 

# Initialize stuff

$Def_GW =""
$loc_last = ""
$loc_now = ""
# Pathes 
$work_path = $home+'\loc_check\'
$log = "log.txt"
$known_mac = "known_mac.txt"
$last_location = "Last_location.txt"

#combined path+file
$w_log = $work_path+$log
$w_known_mac = $work_path+$known_mac
$w_last_location = $work_path+$last_location

# Check if working path exists, if not create it and the needed Files

function NOW {
        Get-Date -Format "dd.MM.yyyy @ HH:mm:ss:fff"
}


if(-not (Test-Path $work_path)) {
        New-Item -Path $work_path       -ItemType Directory
        New-Item -Path $w_log           -ItemType "file"
        New-Item -Path $w_known_mac     -ItemType "file"
        New-Item -Path $w_last_location -ItemType "file"
        (now)+" Logfile initialized" | Out-File $w_log 
#add more as needed
}


(NOW)+" **************** new scan ******************" | Out-File $w_log -Append
# Identify Adapters that are 'up' => will also return Adapters from virtual environments     
$Adapters = (Get-NetAdapter | Where-Object {$_.Status -like "up"}).ifIndex
# filter for adapters which point to def-gw => "0.0.0.0"
foreach ($Adapter in $Adapters) {
        $Def_GW = (Get-WmiObject -Class Win32_IP4RouteTable -filter "destination='0.0.0.0' and mask='0.0.0.0' and InterfaceIndex=$adapter").nexthop
        IF ($Def_GW) {
                (NOW)+" Found default gateway: "+$Def_GW +" on Adapter: "+$Adapter | Out-File $w_log -Append
                break
        }
}
# use arp to get the local IP, the MAC and the IP from the default gateway 
foreach ($line in (arp.exe -a $Def_GW)) {
        if ($line -like "*interface:*") { $lcl_IP = ($line.split(":")[1]).Split("-")[0].trim() }
        if ($line -like "*dynamic*") {
            $MAC = $line.Substring(24,17)
            $GWIP = $line.Substring(1,15).Trim()
            break
        }
}
#Write-Host "This is what I recognize: "
#Write-Host "Using Adapter:" $Adapter "with IP:" $lcl_IP "we talk to a Gatway with MAC:" $MAC "and IP:" $GWIP
(now)+" This is what I recognize: " | Out-File $w_log -Append
(now)+" Using Adapter: "+$Adapter+" with IP: "+$lcl_IP+" we talk to a Gatway with MAC: "+$MAC+" and IP: "+$GWIP | Out-File $w_log -Append
                

# Identify location based on MAC of default gateway, add your known macs here as a part of the switch 
switch ($MAC) {
        "b8-af-67-f4-fb-2d"     { $loc_now = "Office"}
        "f0-9f-c2-11-60-a1"     { $loc_now = "Home" }
        # if we cannot identify the network...
        default { $loc_now = "nope" }                
}


<#}
switch ($MAC) {# add your known macs here as a part of the switch 
        "b8-af-67-f4-fb-2d"     {
                                (now)+ " Looks like Office" | Out-File $w_log -Append;
                                # do stuff here like set RDP Permission OFF;
                                Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value '1'
                                # now let's check if we set it properly
                                if((Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server').fDenyTSConnections -eq "1") 
                                        {(NOW)+" Remote Desktop is disabled." | Out-File $w_log -Append }
                                else {(NOW)+"!! Remote Desktop is still enabled !!" | Out-File $w_log -Append
                                write-host "Check log here:" $w_log }
                                }
        "22-4d-a8-4c-96-02"     {
                Write-Host "Looks like your on the way to somewhere using your Nokia Wireless, Caution"
                # things like Screen brightness or similar
        }
        "56-30-44-8f-e2-12"     {
                Write-Host "Looks like your on the way to somewhere using your Nokia USB tethering, nice !"
                # things like Screen brightness or similar
}
        "f0-9f-c2-11-60-a1"     {
                                (NOW)+" Looks like Home" | Out-File $w_log -Append;
                                # do stuff here like set RDP Permission ON;
                                Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name 'fDenyTSConnections' -Value '0'
                                $loc_now = "Home" 
        }
        # if we cannot identify the network...
        default {(NOW)+" not sure which network we are on right now. The MAC of the default GW is: "+$MAC | Out-File $w_log -Append
                $loc_now = "location not identified" 
        }                
}
#>