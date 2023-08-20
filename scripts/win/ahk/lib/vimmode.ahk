#Include %A_ScriptDir%\lib\myGui.ahk

global mode := 1 ; 0 = regular mode, 1 = vim mode
toggleMode()

; vUpper := Format("{:U}", vText)
; vTitle := Format("{:T}", vText)
; vLower := Format("{:L}", vText)

processKey(key_i, key_o) {
    global mode
    if (0 == mode) {
        if ("{Capslock}" == key_i) {
            SetCapsLockState, % !GetKeyState("Capslock", "T")
        } else {
            ; Check if Caps Lock is active
            if (GetKeyState("Capslock", "T")) {
                ; Convert key_i to uppercase before sending it as output
                SendInput, % Format("{:U}", key_i)
            } else {
                SendInput, % key_i
            }
        }
    } else {
        SendInput, % key_o
    }
}

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

toggleMode() {
    global mode
    mode := (mode == 0) ? 1 : 0
    createIndicator((mode == 0) ? "I" : "V", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
    changeVSCodeCursor((mode == 0) ? "block" : "line",(mode == 0) ? "line" : "block")
}
