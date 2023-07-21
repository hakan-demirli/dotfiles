#Include %A_ScriptDir%\lib\myGui.ahk

global mode := 1 ; 0 = regular mode, 1 = vim mode
toggleMode()

processKey(key_i, key_o) {
    global mode
    if (0 == mode) {
        if ("{Capslock}" == key_i){
            SetCapsLockState % !GetKeyState("Capslock", "T")
        }else{
            SendInput, %key_i%
        }
    } else {
        SendInput, %key_o%
    }
}

toggleMode() {
    global mode
    mode := (mode == 0) ? 1 : 0
    createIndicator((mode == 0) ? "I" : "V", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
    changeVSCodeCursor((mode == 0) ? "block" : "line",(mode == 0) ? "line" : "block")
}

::3{Down}::
::9am::
    StringTrimRight, TimeNumber, A_ThisLabel, 2
    StringTrimLeft, TimeNumber, TimeNumber, 2

    Loop, % TimeNumber
    {
        Send, test
    }
    Send, {Space}a.m. ; Add a space before 'a.m.' for readability
return

;  $ symbol to prevent the hotkey from triggering itself
$h::processKey("h", "{Left down}")
$j::processKey("j", "{Down down}")
$k::processKey("k", "{Up down}")
$l::processKey("l", "{Right down}")
$+h::processKey("+h", "+{Left down}")
$+j::processKey("+j", "+{Down down}")
$+k::processKey("+k", "+{Up down}")
$+l::processKey("+l", "+{Right down}")
$!h::processKey("!h", "!{Left down}")
$!j::processKey("!j", "!{Down down}")
$!k::processKey("!k", "!{Up down}")
$!l::processKey("!l", "!{Right down}")
$^h::processKey("^h", "^{Left down}")
$^j::processKey("^j", "^{Down down}")
$^k::processKey("^k", "^{Up down}")
$^l::processKey("^l", "^{Right down}")
$^!h::processKey("^!h", "^!{Left down}")
$^!j::processKey("^!j", "^!{Down down}")
$^!k::processKey("^!k", "^!{Up down}")
$^!l::processKey("^!l", "^!{Right down}")

$x::processKey("x", "{Delete}")
$0::processKey("0", "{Home}")
$$::processKey("$", "{End}")
Capslock::processKey("{Capslock}", "{Escape}")

!i::toggleMode()

ReplaceStringInFile(inputFile, searchString, replacementString) {
    FileRead, fileContents, %inputFile%
    fileContents := StrReplace(fileContents, searchString, replacementString)
    FileDelete, %inputFile%
    FileAppend, %fileContents%, %inputFile%
}

changeVSCodeCursor(from, to) {
    InputFilePath := A_AppData . "\Code\User\settings.json"

    SearchString := """editor.cursorStyle"": """ . from . ""","
    ReplacementString := """editor.cursorStyle"": """ . to . ""","

    ReplaceStringInFile(InputFilePath, SearchString, ReplacementString)
}
