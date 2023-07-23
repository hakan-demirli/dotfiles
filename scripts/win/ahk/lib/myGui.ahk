createIndicator(letter, windowWidth, windowHeight, windowX, windowY)
{
    ; Create the windowugh, thus no transparency control
    Gui, -Caption +AlwaysOnTop
    Gui, Color, 0x1f1f1f
    Gui, +Resize +ToolWindow -Caption
    WinSet, AlwaysOnTop, On
    Gui, Font, cWhite s80, Arial ; Add "cWhite" to set the text color to white
    Gui, Add, Text, x0 y0 w%windowWidth% h%windowHeight% center, %letter%
    Gui, Show, % "x" windowX " y" windowY " w" windowWidth " h" windowHeight " noactivate"

    WinSet, Transparent, 150, % "ahk_id " hwnd

    ; Set a timer to close the window after 1 second
    SetTimer, CloseWindow, -100 ; Set a negative time to run the CloseWindow label asynchronously
    return

    CloseWindow:
        ; Close the window and kill the timer
        Gui, Destroy
    return
}
