#Persistent
SetTimer, ActivateWinUM, 100
return

ActivateWinUM:
MouseGetPos,,, WinUMID
WinGetClass, winClass, ahk_id %WinUMID%  ; Get the class of the window

; FileAppend, Window Class: %winClass%`n, Output.txt  ; for debug

if (winClass = "#32769") ;  (dropdown menu)
    return

if (winClass = "Shell_TrayWnd") ; (taskbar)
    return

if (winClass = "MozillaDropShadowWindowClass") ; firefox
    return

if (winClass = "#32768") ;  (dropdown menu)
    return


; Check if the window is already active
if (!WinActive("ahk_id " WinUMID)) {
    WinActivate, ahk_id %WinUMID%
}
return
