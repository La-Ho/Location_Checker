###############################################################################
# Created by laho@ch.ibm.com - latest update 01.11.2013                       #
#                                                                             #        
#  Updated with Archive of logs - PHIL@05.11.2013                             #   
#                                                                             #                     
# this script checks all filers listed in $filerlist for                      #
# volumes with usage over 90%, broken disks, vscanner status, list of users   #
###############################################################################
# location of Dropbox
$Dropbox_db = Join-Path (Split-Path (Get-ItemProperty HKCU:\Software\Dropbox).InstallPath) "host.db"
$Dropbox= [System.Convert]::FromBase64String((Get-Content $Dropbox_db)[1])
$dropbox= [System.Text.Encoding]::UTF8.GetString($Dropbox)##
# location of file with filers to check 
$filerlist =  $dropbox + '\NAS Basel\Tools\nas_phys_ch.txt'
# where to store the information
$Filedate  = Get-Date -Format "yyyy_MM_dd_HHmm"
$scriptlocation =  $dropbox + '\NAS Basel\Script_out'
$scriptarchivelocation =  $dropbox + '\NAS Basel\Script_out\Archive'
$disklist  = $dropbox + '\NAS Basel\Script_out\broken_disk_list_'+$filedate+'.txt'
$vol90list = $dropbox + '\NAS Basel\Script_out\vol_over_90_list_'+$filedate+'.txt'
$Userlist  = $dropbox + '\NAS Basel\Script_out\User_list_'+$filedate+'.txt'
$Vscanlist = $dropbox + '\NAS Basel\Script_out\Vscan_list_'+$filedate+'.txt'
# read list of filers to check 
$Heads=Get-Content $filerlist
# who wants to run the script and get credentials 
# clear-scre
switch ($env:username)
    {
    "Laurent"  {$User="cht02339";$Rname="Laurent";$known=$true}
    "FC038822" {$User="ch038822";$Rname="Patrick";$known=$true}
    default {$known=$false}
    }

if (-not $known) { 
# I do not know you, Userid and password required
    $User = Read-Host $env:username 'which username should I use to connect ?' 
    if ($User.Length -eq 0) {Write-Host "No user specified, exiting"; exit}
    $Pass = Read-Host $Rname 'and the password for'$User 'is?' -AsSecureString
    if ($Pass.Length-eq 0) {Write-Host "No password specified, exiting"; exit}
        }
else{
# I know you, just give me the pasword
    $Pass = Read-Host $Rname 'I need your password for '$User -AsSecureString
    if ($Pass.Length-eq 0) {Write-Host $Rname "you did not enter a password, exiting"; exit}
}
# create credential set with name and password
$Headcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $User,$Pass
# write header to out put files
$mydate =  Get-Date -Format "dd.mm.yyyy @ HH:mm"
$outtext= 'List generated on ' +$mydate
Write-Output  $outtext | out-file $disklist
write-Output  $outtext | out-file $vol90list

foreach ($Head in $Heads)
{ 
    Write-Host 'connecting to'$Head.Substring(0,12)
    # connecting to Filer
    $connection = Connect-NaController -Name $Head -Credential $Headcred -ErrorAction stop
    # broken disks starts here 
    Write-Host 'looking for broken disks'
    # retrieving some filerinfo
    $Filerinfo = Get-NaSystemInfo | Select-Object -Property SystemModel, SystemMachineType, SystemSerialNumber 
    $outtext= 'NAS-Head: '+$Head.Substring(0,12)+ ' Model: ' + $Filerinfo.systemmodel + ' Type: ' + $Filerinfo.SystemMachineType +' Serial: ' +$Filerinfo.SystemSerialNumber
    Write-Output $outtext | out-file $disklist -Append
    # getting list of failed disks, only a few fields needed 
    $faileddisks= Get-NaDisk | where Status -Like "broken" #| Select-Object -Property  Name, DiskModel, DiskType
    # no failed disk, happy mnan
    if($faileddisks.count -eq 0){$outtext= 'Zero failed disks, congrats.' | out-file $disklist -Append}
    # for every failed disk we generate a text line
    foreach($faileddisk in $faileddisks)
        {
         $outtext='disk: '+$faileddisk.Name + ' model: '+$faileddisk.DiskModel +' type: '+$faileddisk.DiskType 
         Write-Output $outtext |Format-Table -AutoSize | out-file $disklist -Append
        }
    # empty line to improve readability 
    Write-Output ' ' | out-file $disklist -Append
    # broken disks ends here 
    #
    # vol over 90 starts here
    Write-Host 'looking for volumes over 90%'
    $outtext= ' '
    Write-Output $outtext | out-file $vol90list -Append
    $outtext= 'NAS-Head: '+$Head.Substring(0,12)
    Write-Output $outtext | out-file $vol90list -Append
    # getting list of volumes
    $volumes= Get-Navol | where used -GT 90 | sort used -Descending
    
    if($volumes.count -eq 0){$outtext= 'No Volumes over 90%' | out-file $vol90list -Append}
    # for every Volume over 90% we generate a text line
    foreach($volume in $volumes)
        {                                                 #{[math]::truncate($_.freespace / 1GB)}   
         $vols =$Volume.Totalsize/1GB
         $vols ="{0:N0}" -f $vols 
         $outtext='Volume: '+$Volume.Name + ' Totalsize: '+$vols +' used: '+$Volume.used+'%'  
         Write-Output $outtext |Format-Table -AutoSize | out-file $vol90list -Append
        }
    # empty line to improve readability 
    Write-Output ' ' | out-file $vol90list -Append
    # vol over 90 ends here
    #
    # Vscan check starts here 
    Write-Host 'looking for vscanners'
    $outtext= ' '
    Write-Output $outtext | out-file $Vscanlist -Append
    $outtext= 'NAS-Head: '+$Head.Substring(0,12)
    Write-Output $outtext | out-file $Vscanlist -Append
    $outtext= Invoke-nassh vscan |findstr '\\' 
    Write-Output $outtext | out-file $Vscanlist -Append
    $outtext= Invoke-nassh vscan |findstr 'throttled' 
    Write-Output $outtext | out-file $Vscanlist -Append
        # empty line to improve readability 
    Write-Output ' ' | out-file $Vscanlist -Append
    # Vscan check ends here 
    #
    # User list generation starts here
    Write-Host 'generating user list'
    $outtext= ' '
    Write-Output $outtext | out-file $Userlist -Append
    $outtext= 'NAS-Head: '+$Head.Substring(0,12)
    Write-Output $outtext | out-file $Userlist -Append
    $outtext= get-nauser 
    Write-Output $outtext | out-file $Userlist -Append
    # empty line to improve readability 
    Write-Output ' ' | out-file $Userlist -Append
    # User list generation ends here
    }
Write-Host 'Completed.'
Write-Host 'List of broken disks stored in: ' $disklist
Write-Host 'opening file with Notepad' 
notepad $disklist
Write-Host 'List of Volumes over 90% usage stored in: ' $Vol90list
Write-Host 'opening file with Notepad' 
notepad $Vol90list
Write-Host 'List of Vscanners stored in: ' $Vscanlist
Write-Host 'opening file with Notepad' 
notepad $Vscanlist
#Write-Host 'List of Users stored in: ' $Userlist
#Write-Host 'opening file with Notepad' 
#notepad $Userlist
Write-Host 'Clean Up Logs'
get-childitem -Path $scriptlocation |
    where-object {$_.LastWriteTime -lt (get-date).AddDays(-31)} | 
    move-item -destination $scriptarchivelocation