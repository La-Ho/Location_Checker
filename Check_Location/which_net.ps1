<#check default gateway to do an educated guess on which network I might be 
        
        LHO 2019-11-18 V0.1 first attempt to check basic funtionality
        LHO 2019-11-18 V0.2 fine tuned using Rolfs Syntax input 
        LHO 2019-11-20 V0.3 Multiple ansewrs for defaultgateway => stronger selection
        LHO 2019-11-20 V0.4 Creating directory and files on first run. Writing to log file
        LHo 2019-11-25 V0.5 finetuned write to file, identifiy location from stored information 
        LHo 2019-11-26 V0.6 minor glitches fixed 
#>

# Get-wmi Info and select nexthop ... most of the times being the default gateway => needs to vaildated in different environments
# $Def_GW = (Get-WmiObject -Class Win32_IP4RouteTable |   Where-Object { $_.destination -eq '0.0.0.0' -and $_.mask -eq '0.0.0.0'}).nexthop 
# => Piping a lot => not ideal for performance
# $Def_GW = (Get-WmiObject -Class Win32_IP4RouteTable -filter "destination='0.0.0.0' and mask='0.0.0.0' and InterfaceIndex=$adapter").nexthop
# only the records matching the selection filter will be processd in Powershell => Less overhead => better performance 

# Initialize stuff
$is_new_Loc = $true
$Def_GW =""
$loc_last = ""
$loc_now = ""

# definition of files needed. Looks cumbersome to begin with, but allows for flexibility in naming them...
$work_path = $home+'\loc_check\'
$log = "log.txt"
$known_mac = "known_mac.txt"
$last_location = "Last_location.txt"

# combined path+file
$w_log = $work_path+$log
$w_known_mac = $work_path+$known_mac
$w_last_location = $work_path+$last_location

# function for timestamp in Logs etc
function NOW {Get-Date -Format "dd.MM.yyyy @ HH:mm:ss:fff"}

# Check if working path and files exist, if not create 

if(-not (Test-Path $work_path)) { New-Item -Path $work_path -ItemType Directory | out-null }
if(-not (Test-Path $w_log))     { New-Item -Path $w_log -ItemType "file"  | out-null 
        (now)+" Logfile initialized" | Add-Content -Path $w_log
}
if(-not (Test-Path $w_last_location)) { New-Item -Path $w_last_location -ItemType "file"  | out-null 
        (now)+" Last Location File initialized" | Add-Content -Path $w_log
}
if(-not (Test-Path $w_known_mac)){ New-Item -Path $w_known_mac -ItemType "file"  | out-null 
        (now)+" known MAC file initialized" | Add-Content -Path $w_log
}
# read last location
$loc_last = Get-Content $w_last_location
# read list of known macs
$MACs = Get-Content $w_known_mac

# confirm new scan to log file
(NOW)+" **************** new scan ******************" | Add-Content -Path $w_log

# Identify Adapters that are 'up' => will also return Adapters from virtual environments
$Adapters = (Get-NetAdapter | Where-Object {$_.Status -like "up"}).ifIndex
# filter for adapters which point to def-gw => "0.0.0.0"
foreach ($Adapter in $Adapters) {
        $Def_GW = (Get-WmiObject -Class Win32_IP4RouteTable -filter "destination='0.0.0.0' and mask='0.0.0.0' and InterfaceIndex=$adapter").nexthop
        if ($Def_GW) { break }
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
(now)+" This is what I recognize: Adapter:"+$Adapter+" My IP:"+$lcl_IP+" GW MAC:"+$MAC+" GW IP:"+$GWIP | Add-Content -Path $w_log

foreach ($MAC_read in $MACs) {
        if($MAC_read.Split("")[0] -eq $MAC) {
                $loc_now = $MAC_read.Split("")[1]
                $is_new_Loc = $false
                break
        }
}
if ($loc_now -eq $loc_last){
        (now)+" "+$loc_now+": Same location as before, exiting." | Add-Content -Path $w_log
        exit 
}

if ($is_new_Loc){
        (NOW)+" Did not recognise this location. Requesting a name:" | Add-Content -Path $w_log
        Write-Host "What I see:`nUsing Adapter:" $Adapter "with IP:" $lcl_IP "we talk to a Gatway with MAC:" $MAC "and IP:" $GWIP "`nLooks like a new location.`n"        
        $loc_now = (read-Host "How do you want to name this location?").ToLower()
        # writing new Mac and location name to file
        $MAC+" "+$loc_now | Add-Content -Path $w_known_mac
        (NOW)+" Added "+$MAC+" with Name: "+$loc_now+" to File known_mac.txt." | Add-Content -Path $w_log
        # creating empty powershell script file
        if (Test-Path  $($work_path+$loc_now+".ps1")) {
                (NOW)+" Looks like a new def-gw in known env: "+$loc_now | Add-Content -Path $w_log
        } else {
                New-Item -Path $work_path$loc_now".ps1" -ItemType "file"
                # add top comment to file and talk about it
                "<#`n file performing actions in your "+$loc_now+" environment`n#>" | Add-Content -Path $work_path$loc_now".ps1"
                Write-Host "created this options file for you:" $work_path$loc_now".ps1"
                (NOW)+" optionsfile "+$work_path+$loc_now+".ps1 created" | Add-Content -Path $w_log
        }
        $loc_now | Set-Content -Path $w_last_location
} 
else {
        (now)+" Location has changed to "+$loc_now+", applying settings." | Add-Content -Path $w_log
        $loc_now | Set-Content -Path $w_last_location   
        Invoke-Expression $work_path$loc_now".ps1"
        }
