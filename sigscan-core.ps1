param([string]$hex, 
    [string]$filepath
)

If([string]::IsNullOrEmpty($filepath)){
	Write-Host "Error: No filepath supplied"
	Exit
}

If([string]::IsNullOrEmpty($hex)){
	Write-Host "Error: No hex supplied"
	Exit
}

$TargetDevice = $filepath

function Resolve-Path-Internal() 
{
   $inv = (Get-Variable MyInvocation -Scope 1).Value
   $Path1 = Split-Path $inv.scriptname
   Return $Path1
}

function Get-ScriptDirectory {
    [String]$TmpPath = "";
    if ($psise) {$TmpPath = Split-Path $psise.CurrentFile.FullPath}
    else {$TmpPath = Resolve-Path-Internal}
    Return $TmpPath;
}

$currentdir = Get-ScriptDirectory

$deviceScript = $currentdir + "\ReadFromDevice.ps1";
& $deviceScript

#Require -Version 5
Invoke-Expression -Command "using namespace ReadFromDevice";


If($TargetDevice.Contains("PhysicalDrive")){
    # physical device
    $DiskNumber = $TargetDevice.Substring(13)
    $disk = Get-PhysicalDisk | Where-Object {$_.DeviceId -eq $DiskNumber}
    $file_size = $disk.AllocatedSize
}ElseIf($TargetDevice.Contains("Harddisk") -and $TargetDevice.Contains("Partition")){
    # partition not mounted
    $pattern1 = 'Harddisk(.*?)Partition'
    $harddisknum = [regex]::Match($TargetDevice,$pattern1).Groups[1].Value
    $pattern2 = '(?<=.+Partition).*'
    $partitionnum = [regex]::Match($TargetDevice,$pattern2).Groups[0].Value
    $partition = Get-Partition | where-object {$_.DiskNumber -eq $harddisknum -and $_.PartitionNumber -eq $partitionnum}
    $file_size = $partition.Size
}ElseIf(($TargetDevice.Length -eq 2 -OR $TargetDevice.Length -eq 6) -AND $TargetDevice -match ":"){
    # mounted volume
    $disk = Get-WmiObject Win32_LogicalDisk -ComputerName "localhost" -Filter "DeviceID='$TargetDevice'" | Select-Object Size,FreeSpace
    $file_size = $disk.Size
}Else{
    # file
    If(!(Test-Path $TargetDevice)){Throw "Could not find file: $TargetDevice"}
    $file_size = (Get-Item $TargetDevice).length
}
#write-host "file_size: $file_size"

# do not add if unc path
If($TargetDevice.Substring(0, 2) -ne "\\"){
    $TargetDevice = "\\.\" + $TargetDevice
}

$Stream = [DeviceStream]::new("$TargetDevice");
If($Stream -eq $null){
	Write-Host "Error: Stream failure"
	Exit
}
$Encoding = [Text.Encoding]::GetEncoding(28591);
$BinaryReader  = New-Object System.IO.BinaryReader -ArgumentList $Stream, $Encoding

$MyRegex = [Regex]::New($hex)

$chunk_size = 67108864 #4096, 65536, 262144, 1048576, 4194304, 16777216, 67108864

$step = 0
$offset = 0

$Matches = foreach($chunk in (0..[math]::Ceiling($file_size/$chunk_size))){

            # reset $data
            $BinaryText = $null

            if($offset -ge $file_size){break}
            if($offset + $chunk_size -gt $file_size){
                $chunk_size = $file_size - $offset
            }

            # Initialize the buffer to be save size as the data block
            $buffer = [System.Byte[]]::new($chunk_size)
                        
            # Read each offset to the buffer
            [Void]$BinaryReader.Read($buffer,0,$chunk_size)

            # Convert the buffer data to byte
            $BinaryText = [System.Text.Encoding]::GetEncoding(28591).getstring($buffer)
            if($step -gt 0){
                if(!!$MyRegex.Matches($BinaryText).success){foreach($index in $MyRegex.Matches($BinaryText).index){$index + $step*$chunk_size}}
            }else{
                if(!!$MyRegex.Matches($BinaryText).success){$MyRegex.Matches($BinaryText).index}
            }
            $step=$step+1
            $offset += $chunk_size
            }
            
$Stream.Dispose()

$MatchCount = $Matches.Count

If ($MatchCount -eq 0){
	#Write-Output "Error: No hits."
	Exit
}

$Matches|ForEach-Object {$_}
