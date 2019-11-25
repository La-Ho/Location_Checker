#
# Audit/GADSS report for all users
#
# Missing: LastLogoff (not available), logonServer (not available), BadPasswordTime (useless, binary format), BadPwdCount, lockoutTime (useless, binary format), userAccountControl (not available)

param([string] $domainlink = ".")

$cnt = 1
$list= @()
$user = $null
$shortdate = "yyyy-MM-dd"
$ad = $null

Function ModOU($cn)
{
  $i=[string]($cn).toupper().indexof(",CN=BUILTIN")
  if ($i -eq -1) {
    $i = $cn.IndexOf(",OU=")+4
    if ($i -le 5) { $i= $cn.Indexof(",CN=")+4 }
    $c = $cn.substring($i)  # strip leading CNs (for accounts in "Users", there are two
    $ou = ""
    $i = $c.IndexOf(",DC=")
    if ($i -ge 1) { $c = $c.Substring(0,$i) } # strip domain
    $i = $c.Indexof(",OU=")
    if ($i -ge 1) { # extract OU in reverse order
      $ou = $c.Substring($i+4)
      $c = $c.Substring(0,$i)
      Do {
        $i = $ou.indexof(",OU")
        if ($i -ge 0) { $ou = $ou.substring($i+4) + "\" + $ou.substring(0,$i) }
      } while ($i -gt 0)
    }
    $c = $ou + "\" + $c
  } else {
    $c = "BUILTIN\" +$cn.substring(3,$i-3)
  }
  return $c
}

Function ModCN([string]$cn)
{
  $c = $cn
  if ($c.length -gt 0) {
  $ou = ""
  $i = $c.IndexOf(",DC=")
  if ($i -ge 1) {
    $c = $c.Substring(0,$i)
  }
  $i = $c.Indexof(",OU=")
  if ($i -ge 1) {
    $ou = $c.Substring($i+4)
    $c = $c.Substring(0,$i)
    Do {
      $i = $ou.indexof(",OU")
      if ($i -ge 0) {
        $ou = $ou.substring($i+4) + "\" + $ou.substring(0,$i)
      }
    } while ($i -gt 0)
  }
  if ($c.substring(0,3) -eq "CN=") {
    $c = $c.substring(3)
  }
  $i = $c.indexof(",CN")
  if ($i -ge 0) {
    $c = $c.substring($i+4) + "\" + $c.substring(0,$i)
  }
  Do {
    $i = $c.indexof("`\,")
    if ($i -gt 0) { $c = $c.substring(0,$i) + $c.substring($i+1) }
  } while ($i -gt 0)
  if ($ou.length -gt 0) {
    $c = $ou + "\" + $c
  }
  }
  return $c
}

function Get-ADUserLastLogon($user)
{
  $utime = $user.LastLogonDate
  if ($utime.length -eq 0) { $dt = "<never used>" } else { $dt = $utime.ToString($shortdate) }
  return $dt
}

function Get-ShortDate($d)
{
  if ($d -eq $null) {
    return "<empty>"
  } else {
  if ($d.GetType().Name -eq "DateTime") {
    return [string] $d.ToString($shortdate)
  } else { return $d } }
}

function RemoveCRLF([string] $txt) {
  $txt = $txt.Replace("`r",";")
  $txt = $txt.Replace("`n"," ")
  $txt = $txt.Replace([char]34,"'")
  return $txt
}


try {
  Write-Host "Querying domain ..."
  if ($domainlink -eq ".") {
    $ad = Get-ADDomain
  } else {
    $ad = get-addomain -Server $domainlink
  }
  $addn = $ad.DistinguishedName
  $adshort = $ad.NetBIOSName
  Write-Host "Querying domain $addn"
} catch {
  write-host "Error: $Error"
  Write-Host "Active Directory module not available. Unable to continue." -ForegroundColor DarkRed
  write-host "Use: Install-Windowsfeature RSAT-AD-Powershell"
  exit
}

write-host "Reading all user accounts from domain $adshort" -ForegroundColor Gray
$ulist = (get-aduser -filter * -Server $ad.pdcemulator | select -Property Name,SamAccountName,SmartcardLogonRequired | sort -Property Name)
$cntmax = $ulist.Count
write-host "Found $cntmax User accounts" -ForegroundColor Gray
$ulist | ForEach-Object -Process {
    $username = $_.SamAccountName
    $user = get-aduser "$username" -properties * -Server $ad.pdcemulator 
    Write-Progress -Activity "Processing" -Status "$cnt/$cntmax = $username" -ParentId -1 -PercentComplete (($cnt/$cntmax)*100)
    $cn=ModCN([string]$user.DistinguishedName)
    if (($cn -notlike "*Recycle*")) # -and (-not ($cn -like "*Microsoft Exchange System Objects*")) -and ($user.Name -notlike "svc*") -and ($user.Name -notlike "srv*") -and ($user.Name -notlike "*svc"))
    {
        $Prop = @{'Name' = [string]$user.DisplayName
			      'SamAccountName' = [string]$user.SamAccountName
			      'SurName' = [string]$user.SurName
			      'GivenName' = [string]$user.GivenName
			      'Enabled' = [string]$user.Enabled
                  'OU' = (ModOU $user.DistinguishedName)
                  'City' = (RemoveCRLF $user.City)
                  'StreetAddress' = (RemoveCRLF $user.StreetAddress)
                  'LastLogonDate' = (Get-AdUserLastLogon $user)
                  'LogonCount' = $user.LogonCount
                  'AccountExpirationDate' = (Get-ShortDate $user.AccountExpirationDate)
                  'PasswordLastSet' = [string] (Get-ShortDate $user.PasswordLastSet)
                  'PassWordExpired' = [string] (Get-ShortDate $user.PassWordExpired)
                  'PasswordNeverExpires' = $user.PasswordNeverExpires
                  'Manager' = (ModCN $user.Manager)
                  'Departement' = [string] $user.extensionAttribute3
                  'LegalEntity' = [string] $user.Company
                  'Division' = [string] $user.Division
                  'Team' = [string] $user.Department
                  'EmailAddress' = $user.EmailAddress
                  'Description' = (RemoveCRLF $user.Description)
                  'RoamingProfile' = $user.ProfilePath
                  'HomeDirectory' = $user.HomeDirectory
                  'SmartCardRequired' = $user.SmartcardLogonRequired
                  'WhenCreated' = [string] (Get-ShortDate $user.WhenCreated)
                  'WhenChanged' = [string] (Get-ShortDate $user.WhenChanged)
                }
        $cnt += 1
	    $list += New-Object -TypeName PSObject -Property $Prop
    }
}
$cnt--
$d = (Get-Date -f $shortdate)
$file = ("AllUsers-{0}-{1}.csv" -f $adshort, $d)
Write-Progress "Writing to file" -Completed
Write-Host $cnt accounts found and exporting now to $file
$list| select -Property Name,SamAccountName,SurName,GivenName,Enabled,OU,LastLogonDate,LogonCount,AccountExpirationDate,PasswordLastSet,PasswordExpired,PasswordNeverExpires,Manager,Departement,LegalEntity,Division,Team,EmailAddress,Description,City,StreetAddress,WhenCreated,WhenChanged,RoamingProfile,SmartcardRequired,HomeDirectory | Export-Csv -NoTypeInformation -Delimiter "`t" -Path $file