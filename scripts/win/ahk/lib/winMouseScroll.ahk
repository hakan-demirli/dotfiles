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