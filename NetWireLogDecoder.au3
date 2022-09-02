#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=C:\Program Files (x86)\AutoIt3\Icons\au3.ico
#AutoIt3Wrapper_Outfile=netwiredecoder32.exe
#AutoIt3Wrapper_Outfile_x64=netwiredecoder64.exe
#AutoIt3Wrapper_Compile_Both=y
#AutoIt3Wrapper_UseX64=y
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=NetWire Log Decoder
#AutoIt3Wrapper_Res_Description=NetWire Log Decoder
#AutoIt3Wrapper_Res_Fileversion=1.0.0.1
#AutoIt3Wrapper_AU3Check_Parameters=-w 3 -w 5
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/sf /sv /rm
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <EditConstants.au3>
#include <GuiEdit.au3>
#include <FontConstants.au3>
#include <ButtonConstants.au3>
#include <WinAPIEx.au3>
#Include <Array.au3>
#include <File.au3>

Global $sectorsize = 512
Global $outputPrefix = "netwire"
Global $sPSScript = '"' & @ScriptDir & "\scan-launch-netwire.ps1" & '"'

Global $detectInvalid = 0 ; attempt to skip invalid data within sector. see notes
Global $skipScanAndTrim = 0 ; only useful with carved data etc, not necessary wiht healthy logs
Global $minHits = 5 ; minimum signature hits per sector, used in validation
; signatures used in validation
Global $signature1 = "B4BBB4BB" ;WINDOW
Global $signature2 = "EA020D1315DA"  ; [Ctrl+
Global $signature3 = "EAFD1C151C0D1CE4"  ; [Delete]
Global $signature4 = "E4EA"  ; ][
Global $signature5 = "E4E1D4E1EA"  ; ] - [
Global $signature6 = "E4001313160EE1" ; [Arrow
Global $signature7 = "EAFC170D1C13E4" ; [Enter]
Global $signature8 = "EA0320221A121120221CE4" ; [Backspace]
Global $signature9 = "E1F516221AE4"  ; Lock]


Global $parsingMode ;0=file, 1=device
Global $AddedSector=0 ; currently not used in this scenario
Global $decodedOutput

Global $AdlibInterval = 5000 ;Millisec for the script to halt and update progress bar
Global $ProgressBar2, $CurrentProgress2 = 0, $ProgressTotal2 = 0
Global $ProgressBar3, $CurrentProgress3 = 0, $ProgressTotal3 = 10

Global $ButtonColor = 0x2f4e57, $active = False
Global $myctredit, $ButtonCancel, $ButtonStart, $ButtonOpenOutput, $LabelProgress3, $ButtonOutput, $OutputField, $LabelOutput, $LabelDevice, $DeviceField
Global $ButtonInput, $InputField, $Form, $ButtonOpenDecode, $radioFile, $radioDevice
Global $file_input, $folder_output = @ScriptDir, $OutPutPath = @ScriptDir
Global $CommandlineMode, $mainlogfile, $TargetInput, $hCsv

Const $sRootSlash = "\\.\"

If $cmdline[0] > 0 Then
	$CommandlineMode = 1
	_GetInputParams()
	_Init()
	Exit
Else
	DllCall("kernel32.dll", "bool", "FreeConsole")
	$CommandlineMode = 0
	OnAutoItExitRegister("_GuiExitMessage")

	Opt("GUIOnEventMode", 1)
	$Form = GUICreate("NetWire Log Decoder", 830, 500, -1, -1)
	GUISetOnEvent($GUI_EVENT_CLOSE, "_HandleExit")

	$radioFile = GUICtrlCreateRadio("Source is file", 20, 20, 100, 20)
	$InputField = GUICtrlCreateInput("", 140, 20, 510, 20)
	GUICtrlSetState($InputField, $GUI_DISABLE)
	$ButtonInput = GUICtrlCreateButton("Browse", 700, 20, 100, 30)
	GUICtrlSetOnEvent($ButtonInput, "_HandleEvent")
	GUICtrlSetBkColor(-1, $ButtonColor)
	GUICtrlSetFont(-1, 9, $FW_SEMIBOLD,  $GUI_FONTNORMAL, "",  $CLEARTYPE_QUALITY)
	GUICtrlSetColor(-1, 0xFFFFFF)

	$radioDevice = GUICtrlCreateRadio("Source is device", 20, 70, 100, 20)
	$comboDevice = GUICtrlCreateCombo("", 140, 70, 510, 21)
	$ButtonRefreshDevice = GUICtrlCreateButton("Refresh", 700, 70, 100, 30)
	GUICtrlSetOnEvent($ButtonRefreshDevice, "_HandleEvent")
	GUICtrlSetBkColor(-1, $ButtonColor)
	GUICtrlSetFont(-1, 9, $FW_SEMIBOLD,  $GUI_FONTNORMAL, "",  $CLEARTYPE_QUALITY)
	GUICtrlSetColor(-1, 0xFFFFFF)

	$checkDetectInvalid = GUICtrlCreateCheckbox("DetectInvalid", 20, 120, 150, 20)
	GUICtrlSetTip($checkDetectInvalid, "Attempt to skip invalid data, typically with carved data")

	$checkSkipScanAndTrim = GUICtrlCreateCheckbox("SkipScanAndTrim", 190, 120, 150, 20)
	GUICtrlSetTip($checkSkipScanAndTrim, "Only activate when input is a healthy log")
	GUICtrlSetState($checkSkipScanAndTrim, $GUI_UNCHECKED)

	$LabelOutput = GUICtrlCreateLabel("Select output folder:", 20, 170, 120, 20)
	$OutputField = GUICtrlCreateInput("Optional. Defaults to program directory", 140, 170, 510, 20)
	GUICtrlSetState($OutputField, $GUI_DISABLE)
	$ButtonOutput = GUICtrlCreateButton("Browse", 700, 170, 100, 30)
	GUICtrlSetOnEvent($ButtonOutput, "_HandleEvent")
	GUICtrlSetBkColor(-1, $ButtonColor)
	GUICtrlSetFont(-1, 9, $FW_SEMIBOLD,  $GUI_FONTNORMAL, "",  $CLEARTYPE_QUALITY)
	GUICtrlSetColor(-1, 0xFFFFFF)

	;$LabelProgress2 = GUICtrlCreateLabel("Progress scanning and filtering:", 10, 210, 200, 20)
	$LabelProgress2 = GUICtrlCreateLabel("", 10, 210, 200, 20)
	$ProgressBar2 = GUICtrlCreateProgress(10, 230, 810, 30)
	;$LabelProgress3 = GUICtrlCreateLabel("Progress decoding:", 10, 270, 200, 20)
	$LabelProgress3 = GUICtrlCreateLabel("Progress:", 10, 270, 200, 20)
	$ProgressBar3 = GUICtrlCreateProgress(10, 290, 810, 30)

	$ButtonStart = GUICtrlCreateButton("Start Parsing", 20, 450, 150, 40, $BS_BITMAP)
	GUICtrlSetOnEvent($ButtonStart, "_HandleEvent")
	GUICtrlSetBkColor(-1, $ButtonColor)
	GUICtrlSetFont(-1, 9, $FW_SEMIBOLD,  $GUI_FONTNORMAL, "",  $CLEARTYPE_QUALITY)
	GUICtrlSetColor(-1, 0xFFFFFF)
	$ButtonCancel = GUICtrlCreateButton("Exit", 175, 450, 150, 40)
	GUICtrlSetOnEvent($ButtonCancel, "_HandleCancel")
	GUICtrlSetBkColor(-1, $ButtonColor)
	GUICtrlSetFont(-1, 9, $FW_SEMIBOLD,  $GUI_FONTNORMAL, "",  $CLEARTYPE_QUALITY)
	GUICtrlSetColor(-1, 0xFFFFFF)
	$ButtonOpenOutput = GUICtrlCreateButton("Open Output", 330, 450, 150, 40)
	GUICtrlSetOnEvent($ButtonOpenOutput, "_HandleOpenOutput")
	GUICtrlSetBkColor(-1, $ButtonColor)
	GUICtrlSetFont(-1, 9, $FW_SEMIBOLD,  $GUI_FONTNORMAL, "",  $CLEARTYPE_QUALITY)
	GUICtrlSetColor(-1, 0xFFFFFF)
	$ButtonOpenDecode = GUICtrlCreateButton("Open Decode", 485, 450, 150, 40)
	GUICtrlSetOnEvent($ButtonOpenDecode, "_HandleOpenDecode")
	GUICtrlSetBkColor(-1, $ButtonColor)
	GUICtrlSetFont(-1, 9, $FW_SEMIBOLD,  $GUI_FONTNORMAL, "",  $CLEARTYPE_QUALITY)
	GUICtrlSetColor(-1, 0xFFFFFF)

	$myctredit = GUICtrlCreateEdit("", 0, 330, 830, 100, BitOR($ES_AUTOVSCROLL, $WS_VSCROLL, $ES_READONLY))
	GUICtrlSetBkColor($myctredit, 0xFFFFFF)
	_GUICtrlEdit_SetLimitText($myctredit, 128000)

	GUISetState(@SW_SHOW)

	_RefreshDevices()

	While Not $active
		;Wait for event. The $active variable is set when parsing and reset when done in order for multiple parsing executions to run subsequently

		Sleep(500)
		If $active Then
			_HandleParsing()
			$active = False
		EndIf
	WEnd

EndIf

Func _Init()

	$TargetVolume = $TargetInput
	$decodedOutput = ""

	_UpdateProgress3(20)

	Local $sTimestampStart = @YEAR & "-" & @MON & "-" & @MDAY & "_" & @HOUR & "-" & @MIN & "-" & @SEC

	$OutPutPath = $folder_output & "\NetWireDecoder-" & $sTimestampStart
	If DirCreate($OutputPath) = 0 Then
		_DisplayWrapper("Error creating: " & $OutputPath & @CRLF)
		Return
	EndIf


	Local $sDebugLog = $OutPutPath & "\" & $outputPrefix & ".log"
	If FileExists($sDebugLog) Then
		_DisplayWrapper("Error: Output file already exist: " & $sDebugLog & @CRLF)
		Return
	EndIf
	Global $hDebugLog = FileOpen($sDebugLog, 2+32)

	_DebugOut("Input: " & $TargetVolume & @CRLF)
	_DebugOut("SkipScanAndTrim: " & $skipScanAndTrim & @CRLF)
	_DebugOut("DetectInvalid: " & $detectInvalid & @CRLF)

	If Not $skipScanAndTrim Then

		_DebugOut("Attention: Scanning of larger disks may take some time (hours).." & @CRLF)
		_DisplayWrapper("Attention: Scanning of larger disks may take some time (hours).." & @CRLF)

		Local $sOutTxt =  $OutPutPath & "\" & $outputPrefix & ".txt"

		Local $Timerstart = TimerInit()

		Local $matches = _RunPsScript($TargetVolume, $sOutTxt)
		$matches = StringStripCR($matches)
		_DebugOut("Total signature matches: " & $matches & @CRLF)
		_DisplayWrapper("Total signature matches: " & $matches & @CRLF)
		If $matches = 0 Then
			_DisplayWrapper("Nothing to parse.." & @CRLF)
			Return
		EndIf
		_UpdateProgress3(50)
		_DebugOut("Scanning for signatures took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)) & @CRLF)
		_DisplayWrapper("Scanning for signatures took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)) & @CRLF)

		Local $sOutFile = $OutPutPath & "\" & $outputPrefix & "_stage1_scanned.bin"
		If FileExists($sOutFile) Then
			_DisplayWrapper("Error: Output file already exist: " & $sOutFile & @CRLF)
			Return
		EndIf
		Global $hOutFile = _WinAPI_CreateFile($sOutFile, 3, 6, 7)
		If Not $hOutFile Then
			_DebugOut("Error in CreateFile for " & $sOutFile & " " & _WinAPI_GetLastErrorMessage() & @CRLF)
			_DisplayWrapper("Error in CreateFile for " & $sOutFile & " " & _WinAPI_GetLastErrorMessage() & @CRLF)
			Return
		EndIf

		Local $sOutCsv = $OutPutPath & "\" & $outputPrefix & ".csv"
		Local $hOutCsv = FileOpen($sOutCsv, 2+32)

		Global $hVol
		If Not StringLeft($TargetVolume, 2) = "\\" Then
			$hVol = _WinAPI_CreateFileEx("\\.\" & $TargetVolume, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ,$FILE_SHARE_WRITE,$FILE_SHARE_DELETE), $FILE_ATTRIBUTE_NORMAL)
		Else
			$hVol = _WinAPI_CreateFileEx($TargetVolume, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ,$FILE_SHARE_WRITE,$FILE_SHARE_DELETE), $FILE_ATTRIBUTE_NORMAL)
		EndIf
		If Not $hVol Then
			_DebugOut("Error in CreateFile for " & $TargetVolume & " " & _WinAPI_GetLastErrorMessage() & @CRLF)
			_DisplayWrapper("Error in CreateFile for " & $TargetVolume & " " & _WinAPI_GetLastErrorMessage() & @CRLF)
			Return
		EndIf

		_DebugOut("Reading offsets from: " & $sOutTxt & @CRLF)
		_DebugOut("Reading sector bytes from: " & $TargetVolume & @CRLF)
		_DebugOut("Writing data to: " & $sOutFile & @CRLF)

		$Timerstart = TimerInit()

		_DebugOut(@CRLF & "Started parsing input txt file.." & @CRLF)

		$aFinal = _ParseTxt($sOutTxt)
		_UpdateProgress3(60)
		_DebugOut("Parsing of txt and array sorting took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)) & @CRLF)

		_DebugOut("Sectors to extract data from: " & UBound($aFinal) & @CRLF)
		_DebugOut("Bytes to extract: " & UBound($aFinal) * $sectorsize & @CRLF)
		_DisplayWrapper("Bytes to extract: " & UBound($aFinal) * $sectorsize & @CRLF)

		_DebugOut("Writing array content to " & $sOutCsv & @CRLF)
		_FileWriteFromArray($hOutCsv, $aFinal)

		$Timerstart = TimerInit()

		_WriteSectorsFromArray($aFinal, $hVol, $hOutFile)

		_DebugOut("Writing data from array took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)) & @CRLF)

		_WinAPI_CloseHandle($hOutFile)
		_WinAPI_CloseHandle($hVol)
		FileClose($hOutCsv)

		Local $filteredOutput = $OutPutPath & "\" & $outputPrefix & "_stage2_filtered.bin"
		_DebugOut("Writing filtered binary output to " & $filteredOutput & @CRLF)

		Local $falsePositives = _FilterOutput($sOutFile, $filteredOutput)
		_DebugOut("False positive sectors removed: " & $falsePositives & @CRLF)
		_DebugOut("Core bytes to parse: " & (UBound($aFinal) * $sectorsize) - ($falsePositives * $sectorsize) & @CRLF)
		_DisplayWrapper("Core bytes to parse: " & (UBound($aFinal) * $sectorsize) - ($falsePositives * $sectorsize) & @CRLF)

	Else
		$filteredOutput = $TargetInput
		_DebugOut("Core bytes to parse: " & FileGetSize($filteredOutput) & @CRLF)
		_DisplayWrapper("Core bytes to parse: " & FileGetSize($filteredOutput) & @CRLF)
	EndIf

	_UpdateProgress3(70)

	$Timerstart = TimerInit()

	_DisplayWrapper("Started decoding.." & @CRLF)
	_DebugOut("Parsing: " & $filteredOutput & @CRLF)

	$decodedOutput = $OutPutPath & "\" & $outputPrefix & "_stage3_decoded.txt"
	_DecodeNetWire($filteredOutput, $decodedOutput)
	_UpdateProgress3(100)

	_DebugOut("Decode written to: " & $decodedOutput & @CRLF)
	_DebugOut("Decoding took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)) & @CRLF & @CRLF)
	_DisplayWrapper("Decoding took " & _WinAPI_StrFromTimeInterval(TimerDiff($Timerstart)) & @CRLF & @CRLF)

	FileClose($hDebugLog)

	$OutPutPath = '"' & $OutPutPath & '"'

EndFunc

Func _WriteSectorsFromArray($aInput, $hVol, $hOutFile)
	; Each entry/offset in the array is sector size aligned
	Local $nBytes
	Local $pBuff = DllStructCreate("byte[" & $sectorsize & "]")
	$arraysize = UBound($aInput)
	For $i = 0 To $arraysize - 1

		_WinAPI_SetFilePointerEx($hVol, $aInput[$i], $FILE_BEGIN)
		If Not _WinAPI_ReadFile($hVol, DllStructGetPtr($pBuff), DllStructGetSize($pBuff), $nBytes) Then
			_DebugOut("Error in ReadFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
			Exit
		EndIf
		If Not _WinAPI_WriteFile($hOutFile, DllStructGetPtr($pBuff), DllStructGetSize($pBuff), $nBytes) Then
			_DebugOut("Error in WriteFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
			Exit
		EndIf

	Next
EndFunc

Func _ParseTxt($sOutTxt)

	If Not FileExists($sOutTxt) Then
		_DebugOut("Error file not found" & @CRLF)
		Return
	EndIf
	Local $aArray = FileReadToArray($sOutTxt)
	Local $iLineCount = @extended
	If @error Then
		_DebugOut("Error reading file: " & $sOutTxt & @CRLF)
		Return
	EndIf

	_DebugOut("Lines to parse: " & $iLineCount & @CRLF)

	Local $aOffsetsAligned[Ceiling($iLineCount / 2)]
	_DebugOut("Setting target array to size: " & UBound($aOffsetsAligned) & @CRLF)
	Local $hits=0

	For $i = 1 To $iLineCount - 1

		If $aArray[$i] = "" Then
			ContinueLoop
		EndIf

		$split = StringSplit($aArray[$i], " ")

		If Not IsArray($split) Then
			ContinueLoop
		EndIf
		$Entry = $split[3]

		If StringIsDigit($Entry) = 0 Then
			ContinueLoop
		EndIf

		$ValueAligned = _OffsetAlignToSector($Entry)

		$aOffsetsAligned[$hits] = $ValueAligned

		$hits += 1

	Next

	ReDim $aOffsetsAligned[$hits]
	_DebugOut("Adjusted target array to size: " & UBound($aOffsetsAligned) & @CRLF)

	_DebugOut("Removing duplicates from array.." & @CRLF)

	_ArraySort($aOffsetsAligned, 0, 0, 0, 0, 1)
	$aUnique = _MyArrayUnique0($aOffsetsAligned)
	_DebugOut("Done" & @CRLF)

	_DebugOut("Sorting the array.." & @CRLF)

	_ArraySort($aUnique, 0, 0, 0, 0, 1)
	If @error Then
		_DebugOut("Error sorting array $aUnique" & @CRLF)
		Exit
	EndIf

	If Not $AddedSector Then
		_DebugOut("Done" & @CRLF)
		Return $aUnique
	EndIf

	_DebugOut("Adding additional sectors..." & @CRLF)

	Local $aModified = _ArrayAddDoubleSector($aUnique)

	_ArraySort($aModified, 0, 0, 0, 0, 1)
	If @error Then
		_DebugOut("Error sorting array $aModified" & @CRLF)
		Exit
	EndIf

	$aUnique2 = _MyArrayUnique0($aModified)
	_DebugOut("Done" & @CRLF)

	_DebugOut("Sorting the array.." & @CRLF)

	_ArraySort($aUnique2)
	If @error Then
		_DebugOut("Error sorting array $aUnique2" & @CRLF)
		Exit
	EndIf

	_DebugOut("Done" & @CRLF)

	Return $aUnique2
EndFunc

Func _OffsetAlignToSector($dec)
	If Mod($dec, 0x200) Then
		While 1
			$dec -= 1
			If Mod($dec, 0x200) = 0 Then
				ExitLoop
			EndIf
		WEnd
	EndIf
	Return $dec
EndFunc

Func _ArrayAddDoubleSector($aArray)

	Local $inputArraySize = UBound($aArray) * 3

	Local $aNewArray[$inputArraySize]
	Local $counter = 0

	If $aArray[0] >= 512 Then
		$aNewArray[$counter] = $aArray[0] - 512
		$counter += 1
	EndIf

	$aNewArray[$counter] = $aArray[0]
	$counter += 1

	For $i = 1 To UBound($aArray) - 1

		Select
			Case $aArray[$i - 1] + 512 = $aArray[$i]
				$aNewArray[$counter] = $aArray[$i]
				$counter += 1

			Case $aArray[$i - 1] + 1024 = $aArray[$i]
				$aNewArray[$counter] = $aArray[$i] - 512
				$counter += 1
				$aNewArray[$counter] = $aArray[$i - 1] + 512
				$counter += 1
				$aNewArray[$counter] = $aArray[$i]
				$counter += 1

			Case $aArray[$i - 1] + 1024 < $aArray[$i]
				$aNewArray[$counter] = $aArray[$i] - 512
				$counter += 1
				$aNewArray[$counter] = $aArray[$i - 1] + 512
				$counter += 1
				$aNewArray[$counter] = $aArray[$i]
				$counter += 1

		EndSelect

	Next

	$aNewArray[$counter] = $aArray[$i - 1] + 512
	$counter += 1

	ReDim $aNewArray[$counter]
	Return $aNewArray
EndFunc

Func _MyArrayUnique0(Const ByRef $aArray)
	; just to work around a bug in the obfuscator
	; currently only 1 dimensional arrays
	; will be slow for large arrays

	Local $aNewArray[UBound($aArray)]
	Local $counter = 0

	For $i = 0 To UBound($aArray) - 1

		If $counter > 0 Then
			If $aArray[$i] = $aNewArray[$counter - 1] Then
				ContinueLoop
			EndIf
		EndIf
		$counter += 1
		$aNewArray[$counter - 1] = $aArray[$i]

	Next
	ReDim $aNewArray[$counter]
	Return $aNewArray
EndFunc

Func _DebugOut($text)
   FileWrite($hDebugLog, $text)
EndFunc

Func _RunPsScript($FilePath, $OutputFile)

	Local $sCMD = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File " & $sPSScript & " -inputFile " & '"' & $FilePath & '"' & " -OutputFile " & '"' & $OutputFile & '"'

	Local $pid = Run($sCMD, @SystemDir, @SW_HIDE, $STDIN_CHILD + $STDOUT_CHILD + $STDERR_CHILD)
	If @error Then
		_DebugOut("Error: Could not execute external script" & @CRLF)
		Exit
	EndIf

	StdinWrite($pid)
	Local $AllOutput = "", $sOutput = ""

	While 1
		$sOutput = StdoutRead($pid)
		If @error Then ExitLoop
		If $sOutput <> "" Then $AllOutput &= $sOutput
		If Not ProcessExists($pid) Then ExitLoop
		; exit the loop if processing is +10 min
		;If TimerDiff($hTimer) > 600000 Then ExitLoop
	WEnd

	Return $AllOutput

EndFunc

Func _TestIfDataIsFalsePositive($hFile, $Offset, $hFileOut)
	Local $TestData, $nBytes

	_WinAPI_SetFilePointerEx($hFile, $Offset, $FILE_BEGIN)
	Local $tBuffer = DllStructCreate("byte[" & $sectorsize & "]")
	If Not _WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $sectorsize, $nBytes) Then
		ConsoleWrite("Error in ReadFile." & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Exit
	EndIf
	$TestData = DllStructGetData($tBuffer,1)
	$TestData = StringTrimLeft($TestData,2)


	StringReplace($TestData, $signature1, $signature1)
	Local $nbOccurences1 = @extended
;	ConsoleWrite("$nbOccurences1: " & $nbOccurences1 & @CRLF)

	StringReplace($TestData, $signature2, $signature2)
	Local $nbOccurences2 = @extended
;	ConsoleWrite("$nbOccurences2: " & $nbOccurences2 & @CRLF)

	StringReplace($TestData, $signature3, $signature3)
	Local $nbOccurences3 = @extended
;	ConsoleWrite("$nbOccurences3: " & $nbOccurences3 & @CRLF)

	StringReplace($TestData, $signature4, $signature4)
	Local $nbOccurences4 = @extended
;	ConsoleWrite("$nbOccurences4: " & $nbOccurences4 & @CRLF)

	StringReplace($TestData, $signature5, $signature5)
	Local $nbOccurences5 = @extended
;	ConsoleWrite("$nbOccurences5: " & $nbOccurences5 & @CRLF)

	StringReplace($TestData, $signature6, $signature6)
	Local $nbOccurences6 = @extended
;	ConsoleWrite("$nbOccurences6: " & $nbOccurences6 & @CRLF)

	StringReplace($TestData, $signature7, $signature7)
	Local $nbOccurences7 = @extended
;	ConsoleWrite("$nbOccurences7: " & $nbOccurences7 & @CRLF)

	StringReplace($TestData, $signature8, $signature8)
	Local $nbOccurences8 = @extended
;	ConsoleWrite("$nbOccurences8: " & $nbOccurences8 & @CRLF)

	StringReplace($TestData, $signature9, $signature9)
	Local $nbOccurences9 = @extended
;	ConsoleWrite("$nbOccurences9: " & $nbOccurences9 & @CRLF)

	Local $allOccurrences = $nbOccurences1 + $nbOccurences2 + $nbOccurences3 + $nbOccurences4 + $nbOccurences5 + $nbOccurences6 + $nbOccurences7 + $nbOccurences8 + $nbOccurences9
;	ConsoleWrite("$allOccurrences: " & $allOccurrences & @CRLF)

	If $allOccurrences < $minHits Then
		_DebugOut("Skipping false positive sector at 0x" & Hex($Offset) & @CRLF)
		Return 1
	Else
		_WinAPI_WriteFile($hFileOut, DllStructGetPtr($tBuffer), $sectorsize, $nBytes)
		Return 0
	EndIf
EndFunc

Func _FilterOutput($inputFile, $filteredOutput)

	Local $hFile = _WinAPI_CreateFileEx("\\.\" & $inputFile, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ,$FILE_SHARE_WRITE))
	If Not $hFile Then
		_DebugOut("Error in CreateFile on " & $inputFile & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Exit
	EndIf

	Local $hFileOut = _WinAPI_CreateFile("\\.\" & $filteredOutput,3,6,7)
	If $hFileOut = 0 Then
		_DebugOut("CreateFile error on " & $filteredOutput & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
		Exit
	EndIf
	Local $FileSize = _WinAPI_GetFileSizeEx($hFile)

	Local $PageCounter=0, $TargetOffset=0, $falsePositives=0

	While 1
		$TargetOffset = $PageCounter * $sectorsize
		If $TargetOffset >= $FileSize Then ExitLoop
		$falsePositives += _TestIfDataIsFalsePositive($hFile, $TargetOffset, $hFileOut)

		$PageCounter += 1
	WEnd

	_WinAPI_CloseHandle($hFile)
	_WinAPI_CloseHandle($hFileOut)

	Return $falsePositives
EndFunc

Func _HexPrecheck($hex)
	Local $retArr[2]
	Select
		Case StringMid($hex, 1, 12) = "EA020D1315DA"
			; CTRL + SHIFT + x
			If StringMid($hex, 13, 2) = "2A" Then
				$retArr[0] = 14
				$retArr[1] = "["
				Return $retArr
			EndIf
			If StringMid($hex, 13, 2) = "24" Then
				$retArr[0] = 14
				$retArr[1] = "]"
				Return $retArr
			EndIf
			If StringMid($hex, 13, 2) = "4A" Then
				$retArr[0] = 14
				$retArr[1] = "{"
				Return $retArr
			EndIf
			If StringMid($hex, 13, 2) = "44" Then
				$retArr[0] = 14
				$retArr[1] = "}"
				Return $retArr
			EndIf
			If StringMid($hex, 13, 2) = "41" Then
				$retArr[0] = 14
				$retArr[1] = "@"
				Return $retArr
			EndIf
			If StringMid($hex, 13, 2) = "A2" Then
				$retArr[0] = 14
				$retArr[1] = "£"
				Return $retArr
			EndIf
			If StringMid($hex, 13, 2) = "1D" Then
				$retArr[0] = 14
				$retArr[1] = "$"
				Return $retArr
			EndIf
			If StringMid($hex, 13, 2) = "81" Then
				$retArr[0] = 14
				$retArr[1] = "€"
				Return $retArr
			EndIf
		Case StringMid($hex, 1, 10) = "EAED2023E4"
			$retArr[0] = 10
			$retArr[1] = @TAB
			Return $retArr
		Case StringMid($hex, 1, 6) = "B4BBB4"
			$retArr[0] = 6
			$retArr[1] = @CRLF & @CRLF & "<WINDOW>"
			Return $retArr
		Case StringMid($hex, 1, 4) = "B4BB"
			$retArr[0] = 4
			$retArr[1] = " </WINDOW>" & @CRLF
			Return $retArr
		Case StringMid($hex, 1, 4) = "E4E1"
			$retArr[0] = 4
			$retArr[1] = "] "
			Return $retArr
		Case StringMid($hex, 1, 4) = "E1EA"
			$retArr[0] = 4
			$retArr[1] = " ["
			Return $retArr
		Case StringMid($hex, 1, 4) = "BBEA"
			$retArr[0] = 4
			$retArr[1] = " ["
			Return $retArr
	EndSelect
	Return SetError(1, 0, "")
EndFunc

Func _keyRemapper($char)
	;ConsoleWrite("Char: " & $char & @CRLF)
	Select

		Case $char = "EA"
			Return "["
		Case $char = "E4"
			Return "]"
		Case $char = "D0"
			Return "1"
		Case $char = "D3"
			Return "2"
		Case $char = "D2"
			Return "3"
		Case $char = "CD"
			Return "4"
		Case $char = "CC"
			Return "5"
		Case $char = "CF"
			Return "6"
		Case $char = "CE"
			Return "7"
		Case $char = "C9"
			Return "8"
		Case $char = "C8"
			Return "9"
		Case $char = "D1"
			Return "0"
		Case $char = "20"
			Return "a"
		Case $char = "23"
			Return "b"
		Case $char = "22"
			Return "c"
		Case $char = "1D"
			Return "d"
		Case $char = "1C"
			Return "e"
		Case $char = "1F"
			Return "f"
		Case $char = "1E"
			Return "g"
		Case $char = "19"
			Return "h"
		Case $char = "18"
			Return "i"
		Case $char = "1B"
			Return "j"
		Case $char = "1A"
			Return "k"
		Case $char = "15"
			Return "l"
		Case $char = "14"
			Return "m"
		Case $char = "17"
			Return "n"
		Case $char = "16"
			Return "o"
		Case $char = "11"
			Return "p"
		Case $char = "10"
			Return "q"
		Case $char = "13"
			Return "r"
		Case $char = "12"
			Return "s"
		Case $char = "0D"
			Return "t"
		Case $char = "0C"
			Return "u"
		Case $char = "0F"
			Return "v"
		Case $char = "0E"
			Return "w"
		Case $char = "09"
			Return "x"
		Case $char = "08"
			Return "y"
		Case $char = "0B"
			Return "z"
		Case $char = "9F"
			Return "æ"
		Case $char = "89"
			Return "ø"
		Case $char = "9C"
			Return "å"
		Case $char = "00"
			Return "A"
		Case $char = "03"
			Return "B"
		Case $char = "02"
			Return "C"
		Case $char = "FD"
			Return "D"
		Case $char = "FC"
			Return "E"
		Case $char = "FF"
			Return "F"
		Case $char = "FE"
			Return "G"
		Case $char = "F9"
			Return "H"
		Case $char = "F8"
			Return "I"
		Case $char = "FB"
			Return "J"
		Case $char = "FA"
			Return "K"
		Case $char = "F5"
			Return "L"
		Case $char = "F4"
			Return "M"
		Case $char = "F7"
			Return "N"
		Case $char = "F6"
			Return "O"
		Case $char = "F1"
			Return "P"
		Case $char = "F0"
			Return "Q"
		Case $char = "F3"
			Return "R"
		Case $char = "F2"
			Return "S"
		Case $char = "ED"
			Return "T"
		Case $char = "EC"
			Return "U"
		Case $char = "EF"
			Return "V"
		Case $char = "EE"
			Return "W"
		Case $char = "E9"
			Return "X"
		Case $char = "E8"
			Return "Y"
		Case $char = "EB"
			Return "Z"
		Case $char = "7F"
			Return "Æ"
		Case $char = "69"
			Return "Ø"
		Case $char = "7C"
			Return "Å"
		Case $char = "C5"
			Return "<"
		Case $char = "C7"
			Return ">"
		Case $char = "D5"
			Return ","
		Case $char = "D7"
			Return "."
		Case $char = "D4"
			Return "-"
		Case $char = "CA"
			Return ";"
		Case $char = "CB"
			Return ":"
		Case $char = "E6"
			Return "_"
		Case $char = "E0"
			Return "!"
		Case $char = "E3"
			Return '"'
		Case $char = "E2"
			Return "#"
		Case $char = "5D"
			Return "¤"
		Case $char = "DC"
			Return "%"
		Case $char = "DF"
			Return "&"
		Case $char = "D6"
			Return "/"
		Case $char = "D9"
			Return "("
		Case $char = "D8"
			Return ")"
		Case $char = "C4"
			Return "="
		Case $char = "C6"
			Return "?"
		Case $char = "E5"
			Return "\"
		Case $char = "DE"
			Return "'"
		Case $char = "DB"
			Return "*"
		Case $char = "05"
			Return "|"
		Case $char = "DA"
			Return "+"
		Case $char = "E1"
			Return " "
		Case $char = "01"
			Return "@"
		Case $char = "2F"
			Return "-"
		Case $char = "BB"
			Return " "
		Case $char = "07"
			Return "~"
		Case Else
			;ConsoleWrite("Unknown: " & $char & @CRLF)
			Return ""

	EndSelect
	ConsoleWrite("Error: Should not be here!!" & @CRLF)
EndFunc

Func _DecodeNetWire($inputfile, $outputFile)

	ConsoleWrite("Parsing: " & $inputfile & @CRLF)
	Local $logfile = FileOpen($outputFile, 2+32)

	Local $hFile = FileOpen($inputfile, 16)
	Local $rFile = FileRead($hFile)
	Local $fileSize = FileGetSize($inputfile)
	Local $length = StringLen($rFile)
	Local $out = "", $str = "", $outChunks

	Select
		Case $length < 100000
			$outChunks = 100
		Case $length < 1000000
			$outChunks = 1000
		Case $length < 10000000
			$outChunks = 10000
		Case $length < 100000000
			$outChunks = 100000
		Case $length < 1000000000
			$outChunks = 1000000
		Case Else
			$outChunks = 10000000
	EndSelect

	Local $outChunk = 0, $outChunkSize = Int($length / $outChunks)
	Local $aOut[$outChunks]

	If Mod($outChunkSize, 2) = 0 Then
		$outChunkSize += 1
	EndIf

	Local $inChunkSize = 32768
	Local $inChunks = $fileSize / $inChunkSize
	$inChunks = Int($inChunks)
	Local $remainder = Mod($fileSize, $inChunkSize)

	Local $invalidCounter = 0, $testArr
	Local $currOffset = 3, $currLength = 0

	For $inChunk = 0 To $inChunks

		If $inChunk = $inChunks Then
			$currLength = $remainder * 2
		Else
			$currLength = $inChunkSize * 2
		EndIf

		$inChunkData = StringMid($rFile, $currOffset, $currLength)

		For $i = 1 To $currLength Step 2

			If Mod($i, $outChunkSize) = 0 Then
				;ConsoleWrite(Round((($currOffset + $i - 1) / $length) * 100, 2) & " %" & @CRLF)
				$aOut[$outChunk] = $out
				$outChunk += 1
				$out = ""
			EndIf

			If $currLength - $i > 16 Then
				$testArr = _HexPrecheck(StringMid($inChunkData, $i, 16))
				If Not @error And IsArray($testArr) Then
					$str  = $testArr[1]
					$out &= $str
					$i += $testArr[0] - 2
					ContinueLoop
				EndIf
			EndIf

			;ConsoleWrite("$hex: " & StringFormat("%s", $hex) & @CRLF)
			$str = _keyRemapper(StringMid($inChunkData, $i, 2))
			If $str = "" Then
				If $detectInvalid Then
					$invalidCounter += 1
					If $invalidCounter > 3 Then
						$i = $i + (1024 - Mod($i-3, 1024))
						_DebugOut("Jumping to string offset: " & $i & @CRLF)
						$invalidCounter = 0
						$out &= @CRLF
						ContinueLoop
					EndIf
				EndIf
				$out &= @CRLF
				ContinueLoop
			EndIf
			If $detectInvalid Then
				If $str == "A" Then
					; check for sequence of 00's
					If StringMid($inChunkData, $i, 8) = "00000000" Then
						$i = $i + (1024 - Mod($i-3, 1024))
						_DebugOut("Jumping to string offset: " & $i & @CRLF)
						$out &= @CRLF
						$invalidCounter = 0
						ContinueLoop
					EndIf
					;$invalidCounter += 1
					;ContinueLoop
				EndIf
				If $str == "F" Then
					; check for sequence of FF's
					If StringMid($inChunkData, $i, 8) = "FFFFFFFF" Then
						$i = $i + (1024 - Mod($i-3, 1024))
						_DebugOut("Jumping to string offset: " & $i & @CRLF)
						$out &= @CRLF
						$invalidCounter = 0
						ContinueLoop
					EndIf
				EndIf
			EndIf
			;ConsoleWrite($hex & " = " & $str & @CRLF)
			$out &= $str
		Next
		$currOffset += $inChunkSize * 2
	Next

	Local $sFinal = ""
	For $i = 0 To $outChunk
		$sFinal &= $aOut[$i]
	Next
	$sFinal &= $out

	FileWrite($logfile, $sFinal)

	FileClose($hFile)
	FileClose($logfile)
EndFunc

Func _HandleCancel()
	Exit
EndFunc

Func _HandleExit()
	Exit
EndFunc

Func _ResetProgress($ProgressBar)
	GUICtrlSetData($ProgressBar, 0)
EndFunc


;Func _UpdateProgress3()
;    GUICtrlSetData($ProgressBar3, 100 * $CurrentProgress3 / $ProgressTotal3)
;EndFunc
Func _UpdateProgress3($value)
    GUICtrlSetData($ProgressBar3, $value)
EndFunc

Func _PrintBeforeExit($input)
	_DebugOut($input)
	_DisplayWrapper($input)
EndFunc

Func _DisplayWrapper($input)

	If $CommandlineMode Then
		ConsoleWrite($input)
	Else
		_DisplayInfo($input)
	EndIf

EndFunc

Func _DisplayInfo($DebugInfo)
	_GUICtrlEdit_AppendText($myctredit, $DebugInfo)
EndFunc

Func _GuiExitMessage()
	If Not $CommandlineMode Then
		If @exitCode Then
			MsgBox(0, "Error", "An error was triggered. Check the output buffer.")
		EndIf
	EndIf
EndFunc

Func _HandleEvent()
	If Not $active Then
		Switch @GUI_CtrlId
			Case $ButtonInput
				_HandleFileInput()
			Case $ButtonRefreshDevice
				_RefreshDevices()
			Case $ButtonOutput
				_HandleOutput()
			Case $ButtonStart
				$active = True
			Case $ButtonCancel
				_HandleCancel()
			Case $ButtonOpenOutput
				_HandleOpenOutput()
			Case $ButtonOpenDecode
				_HandleOpenDecode()
			Case $GUI_EVENT_CLOSE
				_HandleExit()
		EndSwitch
	EndIf
EndFunc

Func _HandleFileInput()
	$file_input = FileOpenDialog("Select input file", @ScriptDir, "All (*.*)")
	If $file_input Then
		GUICtrlSetData($InputField, $file_input)
	EndIf

	_ResetProgress($ProgressBar2)
	_ResetProgress($ProgressBar3)
EndFunc

Func _HandleOpenDecode()
	If FileExists($decodedOutput) Then
		Run("notepad " & $decodedOutput)
	Else
		_DisplayWrapper("Could not find: " & $decodedOutput & @CRLF)
	EndIf
EndFunc

Func _HandleOpenOutput()
	Run("explorer.exe " & $OutPutPath)
EndFunc

Func _HandleOutput()
	$folder_output = FileSelectFolder("Select output folder", @ScriptDir)
	If $folder_output Then
		GUICtrlSetData($OutputField, $folder_output)
	EndIf

	_ResetProgress($ProgressBar2)
	_ResetProgress($ProgressBar3)
EndFunc

Func _HandleParsing()
	_ResetProgress($ProgressBar2)
	_ResetProgress($ProgressBar3)
	If _GuiGetSettings() Then
		_SetControlState($GUI_DISABLE)
		_Init()
		_SetControlState($GUI_ENABLE)
	EndIf
EndFunc

Func _SetControlState($ctrlState)
	GUICtrlSetState($ButtonStart, $ctrlState)
	GUICtrlSetState($ButtonInput, $ctrlState)
	GUICtrlSetState($comboDevice, $ctrlState)
	GUICtrlSetState($ButtonRefreshDevice, $ctrlState)
	GUICtrlSetState($checkDetectInvalid, $ctrlState)
	GUICtrlSetState($checkSkipScanAndTrim, $ctrlState)
	GUICtrlSetState($ButtonOutput, $ctrlState)
	GUICtrlSetState($radioFile, $ctrlState)
	GUICtrlSetState($radioDevice, $ctrlState)
	GUICtrlSetState($ButtonOpenDecode, $ctrlState)
EndFunc

Func _GuiGetSettings()

	If Int(GUICtrlRead($radioFile) + GUICtrlRead($radioDevice)) <> 5 Then
		_DisplayInfo("Error: You must configure file or device mode" & @CRLF)
		Return
	EndIf

	Select
		Case Int(GUICtrlRead($radioFile)) = 1
			$parsingMode = 0
			_DisplayInfo("File mode" & @CRLF)
			$TargetInput = $file_input
		Case Int(GUICtrlRead($radioDevice)) = 1
			$parsingMode = 1
			_DisplayInfo("Device mode" & @CRLF)
			$TargetInput = _CorrectVolume(GUICtrlRead($comboDevice))
	EndSelect

	If $TargetInput = "" Then
		_DisplayInfo("Error: Input was empty." & @CRLF)
		Return
	EndIf

	_DisplayInfo("Input: " & $TargetInput & @CRLF)
	$TargetInput = StringReplace($TargetInput, "\\.\", "")

	Local $hDrive
	If StringMid($TargetInput, 1, 4) <> "\\.\" Then
		$hDrive = _WinAPI_CreateFileEx("\\.\" & $TargetInput, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ, $FILE_SHARE_WRITE, $FILE_SHARE_DELETE), $FILE_ATTRIBUTE_NORMAL)
	Else
		$hDrive = _WinAPI_CreateFileEx($TargetInput, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ, $FILE_SHARE_WRITE, $FILE_SHARE_DELETE), $FILE_ATTRIBUTE_NORMAL)
	EndIf

	If Not $hDrive Then
		_DisplayInfo(_WinAPI_GetLastErrorMessage() & @CRLF)
		_DisplayInfo("Error: input not valid: " & $TargetInput & @CRLF)
		Return
	Else
		_WinAPI_CloseHandle($hDrive)
	EndIf

	If Not FileExists($OutPutPath) Then
		_DisplayInfo("Error: output directory not found: " & $OutPutPath & @CRLF)
		Return
	EndIf

	If GUICtrlRead($checkDetectInvalid) = 1 Then
		$detectInvalid = 1
	Else
		$detectInvalid = 0
	EndIf

	If GUICtrlRead($checkSkipScanAndTrim) = 1 Then
		$skipScanAndTrim = 1
	Else
		$skipScanAndTrim = 0
	EndIf

	If $parsingMode = 1 And $skipScanAndTrim = 1 Then
		_DisplayInfo("Error: The settings of device mode and skipping of scan and trim will not work" & @CRLF)
		Return
	EndIf

	Return 1

EndFunc

Func _GUI_Disable_Control()
	GUICtrlSetData($myctredit, "Processing started.." & @CRLF)
	GUICtrlSetState($ButtonInput, $GUI_DISABLE)
	GUICtrlSetState($ButtonOutput, $GUI_DISABLE)
	GUICtrlSetState($ButtonStart, $GUI_DISABLE)
EndFunc

Func _GUI_Enable_Controls()
	GUICtrlSetState($ButtonInput, $GUI_ENABLE)
	GUICtrlSetState($ButtonOutput, $GUI_ENABLE)
	GUICtrlSetState($ButtonStart, $GUI_ENABLE)
EndFunc

Func _RefreshDevices()
	GUICtrlSetData($comboDevice, "", "")
	_GetVolumes()
EndFunc

Func _GetVolumes()
	_DisplayInfo("Reading drive list... " & @CRLF)

	$asDrives = DriveGetDrive("All")
	For $i=1 To $asDrives[0]
		$asDrives[$i]=StringUpper($asDrives[$i])
	Next

	Const $iDrives = 16
	For $i=0 To $iDrives-1
		For $j=1 To $iDrives
			$sDrive = $sRootSlash & "Harddisk" & $i & "Partition" & $j
			If _VolumeFound($sDrive) Then
				_AddVolume($asDrives, $sDrive)
			EndIf
		Next
	Next

	For $i=0 To $iDrives-1
		$sDrive = $sRootSlash & "PhysicalDrive" & $i
		If _VolumeFound($sDrive) Then
			_AddVolume($asDrives, $sDrive)
		EndIf
	Next

	$sDrives = ""
	For $i = 1 to $asDrives[0]
		$iDriveBusType    = _WinAPI_GetDriveBusType($asDrives[$i])
		$sDriveType       = DriveGetType($asDrives[$i])
		$sDriveFileSystem = DriveGetFileSystem($asDrives[$i])
		$sDriveLabel      = DriveGetLabel($asDrives[$i])
		Select
			Case StringInStr($asDrives[$i], "\\.\PhysicalDrive")
				$num = StringReplace($asDrives[$i], "\\.\PhysicalDrive", "")
				$nDriveCapacity = _WinAPI_GetDriveGeometryEx($num)
				If Not @error And IsArray($nDriveCapacity) Then
					$nDriveCapacity = $nDriveCapacity[5]/1024/1024
				Else
					$nDriveCapacity = 0
				EndIf
			Case StringInStr($asDrives[$i], "Harddisk") And StringInStr($asDrives[$i], "Partition")
				$nDriveCapacity = _getPartitionSize($asDrives[$i])
				If Not @error And $nDriveCapacity > 0 Then
					$nDriveCapacity = $nDriveCapacity/1024/1024
				Else
					$nDriveCapacity = 0
				EndIf
			Case Else
				$nDriveCapacity   = DriveSpaceTotal($asDrives[$i])
		EndSelect

		Switch $iDriveBusType
			Case $DRIVE_BUS_TYPE_UNKNOWN
				$sDriveBusType = "UNKNOWN"
			Case $DRIVE_BUS_TYPE_SCSI
				$sDriveBusType = "SCSI"
			Case $DRIVE_BUS_TYPE_ATAPI
				$sDriveBusType = "ATAPI"
			Case $DRIVE_BUS_TYPE_ATA
				$sDriveBusType = "ATA"
			Case $DRIVE_BUS_TYPE_1394
				$sDriveBusType = "1394"
			Case $DRIVE_BUS_TYPE_SSA
				$sDriveBusType = "SSA"
			Case $DRIVE_BUS_TYPE_FIBRE
				$sDriveBusType = "FIBRE"
			Case $DRIVE_BUS_TYPE_USB
				$sDriveBusType = "USB"
			Case $DRIVE_BUS_TYPE_RAID
				$sDriveBusType = "RAID"
			Case $DRIVE_BUS_TYPE_ISCSI
				$sDriveBusType = "ISCSI"
			Case $DRIVE_BUS_TYPE_SAS
				$sDriveBusType = "SAS"
			Case $DRIVE_BUS_TYPE_SATA
				$sDriveBusType = "SATA"
			Case $DRIVE_BUS_TYPE_SD
				$sDriveBusType = "SD"
			Case $DRIVE_BUS_TYPE_MMC
				$sDriveBusType = "MMC"
			Case Else
				$sDriveBusType = ""
		EndSwitch
		$sDrive = $asDrives[$i] & " (" & $sDriveType & ", " & $sDriveBusType & ", " & _
			$sDriveFileSystem & ", " & $sDriveLabel & ", " & Round($nDriveCapacity, 0) & " MB)"
		$sDrives &= $sDrive & "|"
	Next
	GUICtrlSetData($comboDevice, $sDrives, StringMid($sDrive, 1, StringLen($sDrive)-1))
	_DisplayInfo(UBound($asDrives) & " drives populated into the dropdown" & @CRLF & @CRLF)
EndFunc

Func _VolumeFound(ByRef Const $sDrive)
	$hDrive = _WinAPI_CreateFileEx($sDrive, $OPEN_EXISTING, BitOR($GENERIC_READ, $GENERIC_WRITE), _
		BitOR($FILE_SHARE_READ, $FILE_SHARE_WRITE, $FILE_SHARE_DELETE))
	If $hDrive Then
		_WinAPI_CloseHandle($hDrive)
		Return True
	Else
		Return False
	EndIf
EndFunc

Func _AddVolume(ByRef $asDrives, ByRef Const $sDrive)
	ReDim $asDrives[UBound($asDrives) + 1]
	$asDrives[0] += 1
	$asDrives[UBound($asDrives)-1] = $sDrive
EndFunc

Func _CorrectVolume(ByRef Const $sVolume0)
	$sVolume = StringStripWS($sVolume0, BitOR($STR_STRIPLEADING, $STR_STRIPTRAILING, $STR_STRIPSPACES))

	$iSpacePos = StringInStr($sVolume, " ")
	If ($iSpacePos>1) Then
		$sVolume = StringLeft($sVolume, $iSpacePos-1)
	EndIf

	$iSlashPos = StringInStr($sVolume, "\")
	If ($iSlashPos<>1) Then
		$sVolume = $sRootSlash & $sVolume
	EndIf

	Return $sVolume
EndFunc

Func _getPartitionSize($sPartition)
	Local Const $tagGUID1 = "uint Data1;ushort Data2;ushort Data3;ubyte Data4[8];"
	Local Const $tagPARTITION_INFORMATION_GPT = $tagGUID1 & $tagGUID1 & "uint64 Attributes;wchar Name[36];"

	Local Const $tagPARTITION_INFORMATION_EX_GPT = _
	  "int PartitionStyle;" & _
	  "int64 StartingOffset;" & _
	  "int64 PartitionLength;" & _
	  "uint PartitionNumber;" & _
	  "ubyte RewritePartition;" & _
	   $tagPARTITION_INFORMATION_GPT

	Local $tPIX = DllStructCreate($tagPARTITION_INFORMATION_EX_GPT)

	Local $hDevice
	Local $a_hCall, $a_iCall

	If Not StringLeft($sPartition, 4) = "\\.\" Then
		$sPartition = "\\.\" & $sPartition
	EndIf

	$a_hCall = DllCall("kernel32.dll", "hwnd", "CreateFile", _
			"str", $sPartition, _
			"dword", 0, _
			"dword", 0, _
			"ptr", 0, _
			"dword", 3, _; OPEN_EXISTING
			"dword", 128, _; FILE_ATTRIBUTE_NORMAL
			"ptr", 0)

	$hDevice = $a_hCall[0]
	If Not $hDevice Then
		Return SetError(1)
	EndIf

	$a_iCall = DllCall("kernel32.dll", "int", "DeviceIoControl", _
			"hwnd", $hDevice, _
			"dword", 0x70048, _; IOCTL_DISK_GET_PARTITION_INFO_EX
			"ptr", 0, _
			"dword", 0, _
			"ptr", DllStructGetPtr($tPIX), _
			"dword", DllStructGetSize($tPIX), _
			"dword*", 0, _
			"ptr", 0)

	If Not $a_iCall[0] Or @error Then
		Return SetError(2)
	EndIf

	DllCall("kernel32.dll", "int", "CloseHandle", "hwnd", $hDevice)

	Return DllStructGetData($tPIX, "PartitionLength")
EndFunc

Func _GetInputParams()
	Local $TmpInputPath, $TmpOutPath, $TmpMode
	For $i = 1 To $cmdline[0]
		;ConsoleWrite("Param " & $i & ": " & $cmdline[$i] & @CRLF)
		If StringLeft($cmdline[$i],2) = "/?" Or StringLeft($cmdline[$i],2) = "-?" Or StringLeft($cmdline[$i],2) = "-h" Then _PrintHelp()
		If StringLeft($cmdline[$i],7) = "/Input:" Then $TmpInputPath = StringMid($cmdline[$i],8)
		If StringLeft($cmdline[$i],8) = "/Output:" Then $TmpOutPath = StringMid($cmdline[$i],9)
		If StringLeft($cmdline[$i],6) = "/Mode:" Then $TmpMode = StringMid($cmdline[$i],7)
		If $cmdline[$i] = "/StripInvalid" Then $detectInvalid = 1
		If $cmdline[$i] = "/SkipScan" Then $skipScanAndTrim = 1
	Next

	If StringLen($TmpOutPath) > 0 Then

		If FileExists($TmpOutPath) Then
			$folder_output = $TmpOutPath
		Else
			ConsoleWrite("Warning: The specified Output path could not be found: " & $TmpOutPath & @CRLF)
			ConsoleWrite("Relocating output to current directory: " & @ScriptDir & @CRLF)
			$folder_output = @ScriptDir
		EndIf
	EndIf

	If StringLen($TmpMode) > 0 Then
		Select
			Case $TmpMode = "file"
				$parsingMode = 0
			Case $TmpMode = "device"
				$parsingMode = 1
			Case Else
				ConsoleWrite("Error: Could not validate arch: " & $TmpMode & @CRLF)
				Exit
		EndSelect
	Else
		ConsoleWrite("Error: missing mode" & @CRLF)
		Exit
	EndIf

	If StringLen($TmpInputPath) > 0 Then
		Local $hDrive
		If Not StringLeft($TmpInputPath, 2) = "\\" Then
			$hDrive = _WinAPI_CreateFileEx("\\.\" & $TmpInputPath, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ, $FILE_SHARE_WRITE, $FILE_SHARE_DELETE))
		Else
			$hDrive = _WinAPI_CreateFileEx($TmpInputPath, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ, $FILE_SHARE_WRITE, $FILE_SHARE_DELETE))
		EndIf

		If Not $hDrive Then
			ConsoleWrite("Error: input not valid: " & $TmpInputPath & @CRLF)
			Exit
		Else
			_WinAPI_CloseHandle($hDrive)
		EndIf
		$TargetInput = $TmpInputPath
	Else
		ConsoleWrite("Error: missing input file/device" & @CRLF)
		Exit
	EndIf

	If $parsingMode = 1 And $skipScanAndTrim = 1 Then
		ConsoleWrite("Error: The settings of device mode and skipping of scan and trim will not work" & @CRLF)
		Exit
	EndIf

EndFunc

Func _PrintHelp()
	ConsoleWrite("Syntax:" & @CRLF)
	ConsoleWrite("netwiredecoder.exe /Input: /Output: /Mode: /SkipScan /StripInvalid" & @CRLF)
	ConsoleWrite("   Input: Full path to the file or device name to parse" & @CRLF)
	ConsoleWrite("   Output: Optionally set path for the output. Defaults to program directory." & @CRLF)
	ConsoleWrite("   Mode: The mode of operation. Must be file or device." & @CRLF)
	ConsoleWrite("   SkipScan: A switch to deactivate scan and trim. Use with healthy logs. See notes." & @CRLF)
	ConsoleWrite("   StripInvalid: A switch to attempt skipping invalid data. See notes." & @CRLF & @CRLF)
	ConsoleWrite("Examples:" & @CRLF)
	ConsoleWrite("netwiredecoder.exe /Input:D:\temp\02-05-2017 /Mode:file /SkipScan /Output:D:\nwout" & @CRLF)
	ConsoleWrite("netwiredecoder.exe /Input:D:\temp\merged_output.bin /Mode:file /SkipScan" & @CRLF)
	ConsoleWrite("netwiredecoder.exe /Input:F: /Mode:device /StripInvalid" & @CRLF)
	ConsoleWrite("netwiredecoder.exe /Input:Harddisk3Partition1 /Mode:device /StripInvalid" & @CRLF)
	ConsoleWrite("netwiredecoder.exe /Input:PhysicalDrive2 /Mode:device /StripInvalid" & @CRLF)
	Exit
EndFunc