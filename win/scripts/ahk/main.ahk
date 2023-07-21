#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory.
#NoEnv
#Include %A_ScriptDir%\lib\window_drag.ahk
#Include %A_ScriptDir%\lib\win_num_vd.ahk
#Include %A_ScriptDir%\lib\desktop_switcher.ahk
#Include %A_ScriptDir%\lib\vimmode.ahk

; Win+Scroll to change virtual desktop.
#WheelUp::SendInput #^{Left}
#WheelDown::SendInput #^{Right}

mouseInRange(x, y, keyCombination, defaultAction)
{
    ; Activate key combination if mouse is within specified coordinates.
    CoordMode, Mouse
    MouseGetPos, mouseX, mouseY
    if ((mouseX > x) && (mouseY < y))
    {
        SendInput %keyCombination%
    }
    else
    {
        SendInput %defaultAction%
    }
}

WheelUp::mouseInRange(1860, 70, "#^{Left}", "{WheelUp}")
WheelDown::mouseInRange(1860, 70, "#^{Right}", "{WheelDown}")

#q::Send, !{F4}
#f::Run, explorer
#w::Run, firefox
#t::Run, wt

; If btw+enter then by the way is inserted.
; ::btw::by the way
; If btw then by the way is inserted.
; :*:btw::by the way
