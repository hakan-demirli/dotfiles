#Persistent

; windows in windows 10 has thick invisible border

SetTimer, DrawRect, 50
border_thickness = 1
offsetX:=6
offsetY:=0

; set the color of the border
border_color = ffae00

DrawRect:
; Get the current window's position
WinGetPos, x, y, w, h, A
; To avoid the error message
if (x="")
    return

;Gui, +Lastfound +AlwaysOnTop +Toolwindow
Gui, +Lastfound +AlwaysOnTop +ToolWindow ; Add +ToolWindow option here

; set the background for the GUI window
Gui, Color, %border_color%

; remove thick window border of the GUI window
Gui, -Caption

; Retrieves the minimized/maximized state for a window.
WinGet, notMedium , MinMax, A

if (notMedium==0){
; 0: The window is neither minimized nor maximized.

    outerX:=offsetX
    outerY:=offsetY
    outerX2:=w-offsetX
    outerY2:=h-offsetY

    innerX:=border_thickness+offsetX
    innerY:=border_thickness+offsetY
    innerX2:=w-border_thickness-offsetX
    innerY2:=h-border_thickness-offsetY

    newX:=x
    newY:=y
    newW:=w
    newH:=h

    WinSet, Region, %outerX%-%outerY% %outerX2%-%outerY% %outerX2%-%outerY2% %outerX%-%outerY2% %outerX%-%outerY%    %innerX%-%innerY% %innerX2%-%innerY% %innerX2%-%innerY2% %innerX%-%innerY2% %innerX%-%innerY%

    Gui, Show, w%newW% h%newH% x%newX% y%newY% NoActivate, GUI4Boarder
    return
} else {
    WinSet, Region, 0-0 w0 h0
    return
}

return
