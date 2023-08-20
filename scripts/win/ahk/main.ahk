#MaxHotkeysPerInterval 9999 ; Disable 71 hotkey have been receiced in... warning

#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory.
#NoEnv

#Include %A_ScriptDir%\lib\windowControl.ahk
#Include %A_ScriptDir%\lib\desktop_switcher.ahk
#Include %A_ScriptDir%\lib\vimmode.ahk
#Include %A_ScriptDir%\lib\winMouseScroll.ahk

; If btw+enter then by the way is inserted.
; ::btw::by the way
; If btw then by the way is inserted.
; :*:btw::by the way

; SetWorkingDir, D:\software\win\komorebi\
; RunWait,komorebic.exe start -a, Detached
; RunWait,komorebic.exe alt-focus-hack "enable"
; RunWait,komorebic.exe focus-follows-mouse "enable"
; RunWait,komorebic.exe window-hiding-behaviour "cloak"
; RunWait,komorebic.exe cross-monitor-move-behaviour "Insert"
; RunWait,komorebic.exe invisible-borders 7 0 14 7 ; left, top, right, bottom
; RunWait,komorebic.exe active-window-border-colour 66 165 245 --window-kind "single"
; RunWait,komorebic.exe ensure-named-workspaces 0, "I II III IV V"
; RunWait,komorebic.exe named-workspace-container-padding "I", 2
; RunWait,komorebic.exe named-workspace-padding "I", 2
; RunWait,komorebic.exe complete-configuration, Detached
; SetWorkingDir, %A_WorkingDir%
Run, %ComSpec% /k %A_ScriptDir%\..\..\python\venv\Scripts\python %A_ScriptDir%\..\..\python\windowsApplet.py,, hide

; BINDINGS BELOW
;-------------------------------------------------
; General
#q::Send, !{F4}
#+f::Send, {F11}
#f::Run, explorer
#w::Run, firefox
#t::Run, wt
#WheelUp::SendInput #^{Left} ; Win+Scroll to change virtual desktop.
#WheelDown::SendInput #^{Right}

;-------------------------------------------------
; winMouseScroll.ahk
WheelUp::mouseInRange(1860, 70, "#^{Left}", "{WheelUp}")
WheelDown::mouseInRange(1860, 70, "#^{Right}", "{WheelDown}")

;-------------------------------------------------
; window_drag.ahk
#RButton::resizeWindow()
#LButton::dragWindow()

;-------------------------------------------------
; desktop_switcher.ahk
SetKeyDelay, 75
mapDesktopsFromRegistry()
OutputDebug, [loading] desktops: %DesktopCount% current: %CurrentDesktop%
LWin & 1::switchDesktopByNumber(1)
LWin & 2::switchDesktopByNumber(2)
LWin & 3::switchDesktopByNumber(3)
LWin & 4::switchDesktopByNumber(4)
LWin & 5::switchDesktopByNumber(5)
LWin & 6::switchDesktopByNumber(6)
LWin & 7::switchDesktopByNumber(7)
LWin & 8::switchDesktopByNumber(8)
LWin & 9::switchDesktopByNumber(9)

;-------------------------------------------------
; vimmode.ahk
; $ symbol to prevent the hotkey from triggering itself
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

;-------------------------------------------------
; komorebi.ahk

