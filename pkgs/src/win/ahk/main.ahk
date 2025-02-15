#MaxHotkeysPerInterval 9999 ; Disable 71 hotkey have been receiced in... warning

#NoEnv ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir% ; Ensures a consistent starting directory.
#NoEnv

#Include %A_ScriptDir%\lib\windowControl.ahk
#Include %A_ScriptDir%\lib\desktop_switcher.ahk
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

Run, %ComSpec% /k %A_ScriptDir%\..\..\python\venv_w\Scripts\python %A_ScriptDir%\..\..\python\windowsApplet.py,, hide
Run, %ComSpec% /k %A_ScriptDir%\..\..\python\venv_w\Scripts\python %A_ScriptDir%\..\..\python\updateOverlay.py,, hide

; BINDINGS BELOW
;-------------------------------------------------
; General
; $CapsLock::Send {Esc} ; Use sharpkeys registry hack instead of this.
; the rest are probably set on sharpkeys

;-------------------------------------------------
;---XREAMAP----------

; This script is the equivalent of your xremap configuration in AutoHotKey (AHK) script.

; KEY_GRAVE: reserved 
; KEY_RIGHTBRACE: reserved
; KEY_BACKSLASH: reserved
; KEY_LEFTBRACE: KEY_BACKSPACE
; +{[}::Backspace
; Shift-KEY_LEFTBRACE: KEY_DELETE
; +Backspace::Delete
+BS::Send {Del}
; Alt-Shift-KEY_LEFTBRACE: Shift-KEY_MINUS # underscore
 !+BS::Send {Shift Down}{-}{Shift Up}
; KEY_BACKSPACE: reserved
; KEY_ENTER: reserved
; KEY_APOSTROPHE: KEY_ENTER
;'::Enter


; Right Hand
; Shift-Alt-y: KEY_APOSTROPHE
!+y::Send '
; Shift-Alt-u: Shift-KEY_LEFTBRACE # curly
!+u::Send {Shift Down}{[}{Shift Up}
; Shift-Alt-i: Shift-KEY_RIGHTBRACE # curly
!+i::Send {Shift Down}{]}{Shift Up}
; Shift-Alt-o: Shift-KEY_4 # dollar
!+o::Send {Shift Down}4{Shift Up}
; Shift-Alt-p: KEY_PASTE
!+p::Send ^v

; Shift-Alt-h: KEY_HOME
!+h::Home
; Shift-Alt-j: KEY_KPLEFTPAREN
!+j::Send {NumpadMult}
; Shift-Alt-k: KEY_KPRIGHTPAREN
!+k::Send {NumpadDiv}
; Shift-Alt-l: KEY_END
!+l::End
; Shift-Alt-KEY_SEMICOLON: reserved

; Shift-Alt-n: Shift-KEY_APOSTROPHE
!+n::Send {Shift Down}'{Shift Up}
; Shift-Alt-m: KEY_LEFTBRACE
!+m::Send {[}
; Shift-Alt-comma: KEY_RIGHTBRACE
!+,::Send {]}
; Shift-Alt-dot: reserved
; Shift-Alt-slash: reserved

; Alt-y: reserved
; Alt-h: KEY_LEFT
!h::Left
; Alt-j: KEY_DOWN
!j::Down
; Alt-k: KEY_UP
!k::Up
; Alt-l: KEY_RIGHT
!l::Right
; Alt-KEY_SEMICOLON: reserved

; Alt-n: reserved

; Left Hand
; Shift-Alt-q: reserved
; Shift-Alt-w: Shift-KEY_7 # ampersand 
!+w::Send {Shift Down}7{Shift Up}
; Shift-Alt-e: Shift-KEY_8 # star
!+e::Send {Shift Down}8{Shift Up}
; Shift-Alt-r: Shift-KEY_6 # caret
!+r::Send {Shift Down}6{Shift Up}
; Shift-Alt-t: Shift-KEY_2 # at
!+t::Send {Shift Down}2{Shift Up}

; Shift-Alt-a: Shift-KEY_1 # exclamation mark
!+a::Send {Shift Down}1{Shift Up}
; Shift-Alt-s: KEY_MINUS 
!+s::Send -
; Shift-Alt-d: Shift-KEY_EQUAL # plus
!+d::Send {Shift Down}={Shift Up}
; Shift-Alt-f: KEY_EQUAL
!+f::Send `=
; Shift-Alt-g: Shift-KEY_3 # pound
!+g::Send {Shift Down}3{Shift Up}

; Shift-Alt-z: KEY_BACKSLASH
!+z::Send \
; Shift-Alt-x: Shift-KEY_GRAVE # tilda
!+x::Send {Shift Down}``{Shift Up}
; Shift-Alt-c: KEY_GRAVE
!+c::Send ``
; Shift-Alt-v: Shift-KEY_5 # percent
!+v::Send {Shift Down}5{Shift Up}
; Shift-Alt-b: Shift-KEY_BACKSLASH # pipe
!+b::Send {Shift Down}\{Shift Up}

; Alt-w: KEY_7
!w::Send 7
; Alt-e: KEY_8
!e::Send 8
; Alt-r: KEY_9
!r::Send 9
; Alt-t: KEY_0
!t::Send 0

; Alt-s: KEY_4
!s::Send 4
; Alt-d: KEY_5
!d::Send 5
; Alt-f: KEY_6
!f::Send 6
; Alt-g: reserved 

; Alt-x: KEY_1
!x::Send 1
; Alt-c: KEY_2
!c::Send 2
; Alt-v: KEY_3
!v::Send 3

; KEY_1: reserved
; KEY_2: reserved
; KEY_3: reserved
; KEY_4: reserved
; KEY_5: reserved
; KEY_6: reserved
; KEY_7: reserved
; KEY_8: reserved
; KEY_9: reserved
; KEY_0: reserved
; KEY_MINUS: reserved
; KEY_EQUAL: reserved



;-------------------------------------------------

ScrollLock::CapsLock
#q::Send, !{F4}
#f::Send, {F11}
#a::Run, explorer
#z::Run, firefox
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
