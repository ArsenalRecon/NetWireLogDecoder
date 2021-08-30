#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=C:\Program Files (x86)\AutoIt3\Icons\au3.ico
#AutoIt3Wrapper_UseX64=n
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_AU3Check_Parameters=-w 3 -w 5
#AutoIt3Wrapper_Run_Au3Stripper=y
#Au3Stripper_Parameters=/sf /sv /rm
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****

#Include <WinAPIEx.au3>
#include <File.au3>
#include <Array.au3>

$startPath = FileSelectFolder("Select input folder", @ScriptDir)
If @error Then
	Exit
EndIf

ConsoleWrite("Listing files.." & @CRLF)
Local $aDirList = _FileListToArray($startPath, "*", $FLTA_FILES, False)

Local $TimestampStart = @YEAR & "-" & @MON & "-" & @MDAY & "_" & @HOUR & "-" & @MIN & "-" & @SEC
Local $sOutFile = @ScriptDir & "\merged_output_" & $TimestampStart & ".bin"

Local $hOutFile = _WinAPI_CreateFile("\\.\" & $sOutFile, 3, 6, 7)
If Not $hOutFile Then
	ConsoleWrite("Error in CreateFile for " & $sOutFile & " " & _WinAPI_GetLastErrorMessage() & @CRLF)
	Exit
EndIf

For $i = 1 To $aDirList[0]
	$targetFile = $startPath & "\" & $aDirList[$i]
	ConsoleWrite("Targeting: " & $targetFile & @CRLF)
	_ParseFileAndMerge($targetFile, $hOutFile)
Next

_WinAPI_CloseHandle($hOutFile)

Func _ParseFileAndMerge($sInputFile, $hOutput)
	Local $hFile = _WinAPI_CreateFileEx("\\.\" & $sInputFile, $OPEN_EXISTING, $GENERIC_READ, BitOR($FILE_SHARE_READ,$FILE_SHARE_WRITE))
	If Not $hFile Then
		ConsoleWrite("Error in CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Exit
	EndIf
	Local $nBytes
	Local $FileSize = _WinAPI_GetFileSizeEx($hFile)
	_WinAPI_SetFilePointerEx($hFile, 0, $FILE_BEGIN)
	Local $tBuffer = DllStructCreate("byte[" & $FileSize & "]")
	If Not _WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $FileSize, $nBytes) Then
		ConsoleWrite("Error in ReadFile." & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Exit
	EndIf
	$data = DllStructGetData($tBuffer,1)
	$data = StringTrimLeft($data, 2)

	While 1
		If StringRight($data, 16) = "FFFFFFFF82794711" Then
			$data = StringTrimRight($data, 16)
			ContinueLoop
		EndIf
		If StringRight($data, 8) = "82794711" Then
			$data = StringTrimRight($data, 8)
			ContinueLoop
		EndIf
		If StringRight($data, 8) = "00000000" Then
			$data = StringTrimRight($data, 8)
			ContinueLoop
		EndIf
		If StringRight($data, 4) = "4711" Then
			$data = StringTrimRight($data, 4)
			ContinueLoop
		EndIf
		ExitLoop
	WEnd

	Local $binlength = StringLen($data)/2
	Local $buff = DllStructCreate("byte[" & $binlength & "]")
	DllStructSetData($buff, 1, "0x" & $data)

	_WinAPI_WriteFile($hOutput, DllStructGetPtr($buff), $binlength, $nBytes)
	_WinAPI_CloseHandle($hFile)

	ConsoleWrite("Bytes removed: " & $FileSize - $binlength & @CRLF)
	ConsoleWrite("Bytes written: " & $binlength & @CRLF)
EndFunc