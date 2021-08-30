param(
	[string]$inputFile = "",
    [string]$outputFile = ""
)

If([string]::IsNullOrEmpty($inputFile)){
	Throw "Error: Missing inputFile"
}
If([string]::IsNullOrEmpty($outputFile)){
	Throw "Error: Missing outputFile"
}

$hexPatterns = @(
"\xB4\xBB\xB4\xBB", # WINDOW
"\xE4\x00\x13\x13\x16\x0E\xE1", # [Arrow 
"\xEA\x02\x0D\x13\x15\xDA", # [Ctrl+
"\xEA\xFD\x1C\x15\x1C\x0D\x1C\xE4", # [Delete]
"\xEA\x03\x20\x22\x1A\x12\x11\x20\x22\x1C\xE4", # [Backspace]
"\xEA\xFC\x17\x0D\x1C\x13\xE4", # [Enter]
"\xEA.{2}\xD6.{2}\xD6.{4}\xE1.{2}\xCB.{2}\xCB.{2}\xE4", # [04/09/2020 11:53:01]
"\xE4\xE1\xD4\xE1\xEA", # ] - [
"\xE1\xF5\x16\x22\x1A\xE4" # Lock]
);


$ExecutionTime = [DateTime]::UtcNow.ToString("o");
$ExecutionTime = $ExecutionTime.Replace(":", ".")

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

function Log([string]$text)
{
   $date = Get-Date
   "$date $text" | Out-File -Append -Force -FilePath:$outputFile -Encoding:utf8;
}

$stopwatch =  [system.diagnostics.stopwatch]::StartNew();

$ScanScript = $currentdir + "\sigscan-core.ps1";

Log "Started: $(Get-Date)";
Log "Script: $ScanScript";
Log "Input: $inputFile";

$counter = 0

ForEach($pattern in $hexPatterns){

    Log "Regex: $pattern";
    $Matches = & $ScanScript -filepath $inputFile -hex $pattern;
    $Matches | ForEach-Object {Log $_; Log "0x$(([uint64]$_).ToString('X16'))"}
    $counter += $Matches.Count

}
Log "Matches: $counter"
Log "Finished parsing in $($stopwatch.Elapsed)";

$hexPatterns = $null;

Return $counter