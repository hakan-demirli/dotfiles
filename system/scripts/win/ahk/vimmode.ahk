#Include %A_ScriptDir%\lib\myGui.ahk

showgMenu() {
    items =
    (
    Keybindings:
    g: go to beginning of file
    h: go to beginning of the line
    e: go to end of the file
    l: go to end of the line
    p: go to previous window
    n: go to next window
    d: go to definition
    r: go to reference
    )
    CreatePersistentGUI(items, A_ScreenWidth / 5, A_ScreenHeight / 5, A_ScreenWidth / 15, A_ScreenHeight / 1.3)
}

showSpaceMenu() {
    items =
    (
    Keybindings:
    t: open terminal
    f: open file picker
    g: open global search
    )
    CreatePersistentGUI(items, A_ScreenWidth / 5, A_ScreenHeight / 5, A_ScreenWidth / 15, A_ScreenHeight / 1.3)
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

    SearchString := """terminal.integrated.cursorStyle"": """ . from . ""","
    ReplacementString := """terminal.integrated.cursorStyle"": """ . to . ""","

    ReplaceStringInFile(InputFilePath, SearchString, ReplacementString)
}

changeMode(new_mode) {
    global current_mode
    current_mode := new_mode
    createIndicator((mode == 0) ? "I" : "V", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
    changeVSCodeCursor((mode == 0) ? "block" : "line",(mode == 0) ? "line" : "block")
}

mode := "normal"
changeVSCodeCursor("line","block")
; You cannot nest #if directives

#If WinActive("ahk_exe code.exe") && (mode = "command")
    Esc::
        Send, {Esc}
        mode := "normal"
    return
    Enter::
        Send, {Enter}
        mode := "normal"
    return

#If WinActive("ahk_exe code.exe") && (mode = "command_search")
    Esc::
        Send, {Esc}
        mode := "normal"
    return
    Enter::
        Send, {Enter}
        mode := "normal"
    return

#If WinActive("ahk_exe code.exe") && (mode = "command_substitute")
    Esc::
        Send, {Esc}
        mode := "normal"
    return
    Enter::
        Send, ^+l
        Send, {Esc}
        mode := "insert"
        KillPersistentGUI()
        createIndicator("I", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        changeVSCodeCursor("block","line")
    return

#If WinActive("ahk_exe code.exe") && (mode = "space")
    Esc::
        mode := "normal"
        KillPersistentGUI()
        Send, {Esc}
    return
    f::
        mode := "command_search"
        KillPersistentGUI()
        Send ^+j ; Ctrl+shift+j
    return
    g::
        mode := "command_search"
        KillPersistentGUI()
        Send ^+u ; Ctrl+shift+u
    return
    t::
        mode := "insert"
        KillPersistentGUI()
        createIndicator("I", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        changeVSCodeCursor("block","line")
        Send ^`` ; Ctrl+`
    return
    Space::return ; Reserved
    a::return ; Reserved
    b::return ; Reserved
    c::return ; Reserved
    d::return ; Reserved
    e::return ; Reserved
    h::return ; Reserved
    j::return ; Reserved
    k::return ; Reserved
    l::return ; Reserved
    m::return ; Reserved
    n::return ; Reserved
    o::return ; Reserved
    p::return ; Reserved
    r::return ; Reserved
    s::return ; Reserved
    u::return ; Reserved
    v::return ; Reserved
    y::return ; Reserved
    z::return ; Reserved
    x::return ; Reserved
    0::return ; Reserved
    1::return ; Reserved
    2::return ; Reserved
    3::return ; Reserved
    4::return ; Reserved
    5::return ; Reserved
    6::return ; Reserved
    7::return ; Reserved
    8::return ; Reserved
    9::return ; Reserved
    Enter::return ; Reserved
    Backspace::return ; Reserved

#If WinActive("ahk_exe code.exe") && (mode = "g")
    Esc::
        mode := "normal"
        KillPersistentGUI()
        Send, {Esc}
    return
    g::
        mode := "normal"
        KillPersistentGUI()
        Send, ^{Home}
    return
    e::
        mode := "normal"
        KillPersistentGUI()
        Send, ^{End}
    return
    p::
        mode := "normal"
        KillPersistentGUI()
        Send ^{PgUp}
    return
    n::
        mode := "normal"
        KillPersistentGUI()
        Send ^{PgDn}
    return
    d::
        mode := "normal"
        KillPersistentGUI()
        Send {F12}
    return
    r::
        mode := "normal"
        KillPersistentGUI()
        Send +{F12} ; Shift+F12
    return
    h::
        mode := "normal"
        KillPersistentGUI()
        Send {Home}
    return
    l::
        mode := "normal"
        KillPersistentGUI()
        Send {End}
    return
    q::return ; Reserved
    z::return ; Reserved
    v::return ; Reserved
    x::return ; Reserved
    0::return ; Reserved
    1::return ; Reserved
    2::return ; Reserved
    3::return ; Reserved
    4::return ; Reserved
    5::return ; Reserved
    6::return ; Reserved
    7::return ; Reserved
    8::return ; Reserved
    9::return ; Reserved
    Enter::return ; Reserved
    Backspace::return ; Reserved

#If WinActive("ahk_exe code.exe") && (mode = "column")
    gui_SearchEnter:
        Gui, Submit
        ; Close the GUI
        Gui, Destroy
        ; Switch case based on the content of testVar
        switch testVar
        {
        ; case "w":
            ; Send ^s
        default:
            createIndicator("?", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        }
        mode := "normal"
    return

#If WinActive("ahk_exe code.exe") && (mode = "insert")
    Esc::
        mode := "normal"
        createIndicator("N", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        changeVSCodeCursor("line","block")
        Send, {Esc}
    return
    !t::Send, ^``
    return ; terminal

#If WinActive("ahk_exe code.exe") && (mode = "normal")
    i::
        mode := "insert"
        createIndicator("I", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        changeVSCodeCursor("block","line")
    return
    c::
        mode := "insert"
        createIndicator("I", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        changeVSCodeCursor("block","line")
        Send, {Delete}
    return
    a::
        mode := "insert"
        createIndicator("I", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        changeVSCodeCursor("block","line")
        Send, {Right}
    return
    o::
        mode := "insert"
        createIndicator("I", A_ScreenWidth / 16, A_ScreenHeight / 8, A_ScreenWidth / 2.1, A_ScreenHeight / 1.3)
        changeVSCodeCursor("block","line")
        Send ^{Enter} ; Ctrl+Enter
    return
    h::Send , {Left}
    +h::Send , +{Left}
    !h::Send , !{Left}
    ^h::Send , ^{Left}
    ^!h::Send, ^!{Left}
    +!h::Send, +!{Left}
    return
    j::Send , {Down}
    +j::Send , +{Down}
    !j::Send , !{Down}
    ^j::Send , ^{Down}
    ^!j::Send, ^!{Down}
    +!j::Send, +!{Down}
    return
    k::Send , {Up}
    +k::Send , +{Up}
    !k::Send , !{Up}
    ^k::Send , ^{Up}
    ^!k::Send, ^!{Up}
    +!k::Send, +!{Up}
    return
    l::Send , {Right}
    +l::Send , +{Right}
    !l::Send , !{Right}
    ^l::Send , ^{Right}
    ^!l::Send, ^!{Right}
    +!l::Send, +!{Right}
    return
    u::Send, ^z ; Ctrl+z
    +u::Send, ^+z ; Ctrl+Shift+z
    ^u::Send, ^u
    return
    d::Send, {Delete}
    +d::Send, {Backspace}
    ^d::Send, ^d
    return
    w::Send, ^+{Right}
    +w::Send, ^+{Left}
    return ; Ctrl+Shift+Right
    y::Send, ^c
    return ; Ctrl+c
    p::Send, ^v
    return ; Ctrl+v
    ^x::Send, ^x
    return
    ^w::Send, ^w
    return ; Ctrl+w
    ^b::Send, ^b
    return ; Ctrl+b
    f::Send,!m
    return ; Alt+m
    CapsLock::Send {Esc}
    return
    /::
        Send, ^f
        mode := "command_search"
    return
    ^/::Send, ^/
    return ; Ctrl+/
    !t::Send, ^``
    return ; terminal
    Space::
        mode := "space"
        showSpaceMenu()
    return
    g::
        mode := "g"
        showgMenu()
    return
    +`;::
        Gui, -Caption +AlwaysOnTop +ToolWindow
        Gui, 1: Color, 000000 ; Black-out blinds
        Gui, Color, 0x1f1f1f
        Gui, Font, cWhite s14, Courier New
        Gui, Add, Text,,
        Gui, Add, Edit, vtestVar BackgroundTransBlack -VScroll -E0x200
        Gui, Add, Button, x-10 y-10 w1 h1 +default ggui_SearchEnter ; hidden button
        Gui, Color,, 000000
        Gui, Show, % "x" A_ScreenWidth / 16 " y" A_ScreenHeight / 16

        mode := "column"
    return
    +,::Send, ^[
    +.::Send, ^]
    return
    s::
        Send, ^f
        Send, !l
        mode := "command_substitute"
    return
    b::return ; Reserved
    e::return ; Reserved
    ^e::return ; Reserved
    r::return ; Reserved
    q::return ; Reserved
    z::return ; Reserved
    v::return ; Reserved
    x::return ; Reserved
    0::return ; Reserved
    1::return ; Reserved
    2::return ; Reserved
    3::return ; Reserved
    4::return ; Reserved
    5::return ; Reserved
    6::return ; Reserved
    7::return ; Reserved
    8::return ; Reserved
    9::return ; Reserved
    Enter::return ; Reserved
    Backspace::return ; Reserved
