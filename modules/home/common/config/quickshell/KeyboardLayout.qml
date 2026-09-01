pragma Singleton

import QtQuick

QtObject {
    enum Kind {
        Character,
        Modifier,
        Lock,
        Action
    }

    readonly property int units: 15

    readonly property var rows: [[
            {
                code: 41,
                base: "`",
                shifted: "~"
            },
            {
                code: 2,
                base: "1",
                shifted: "!"
            },
            {
                code: 3,
                base: "2",
                shifted: "@"
            },
            {
                code: 4,
                base: "3",
                shifted: "#"
            },
            {
                code: 5,
                base: "4",
                shifted: "$"
            },
            {
                code: 6,
                base: "5",
                shifted: "%"
            },
            {
                code: 7,
                base: "6",
                shifted: "^"
            },
            {
                code: 8,
                base: "7",
                shifted: "&"
            },
            {
                code: 9,
                base: "8",
                shifted: "*"
            },
            {
                code: 10,
                base: "9",
                shifted: "("
            },
            {
                code: 11,
                base: "0",
                shifted: ")"
            },
            {
                code: 12,
                base: "-",
                shifted: "_"
            },
            {
                code: 13,
                base: "=",
                shifted: "+"
            },
            {
                code: 14,
                icon: "\ue14a",
                kind: KeyboardLayout.Kind.Action,
                width: 2
            }
        ], [
            {
                code: 15,
                label: "Tab",
                kind: KeyboardLayout.Kind.Action,
                width: 1.5
            },
            {
                code: 16,
                base: "q"
            },
            {
                code: 17,
                base: "w"
            },
            {
                code: 18,
                base: "e"
            },
            {
                code: 19,
                base: "r"
            },
            {
                code: 20,
                base: "t"
            },
            {
                code: 21,
                base: "y"
            },
            {
                code: 22,
                base: "u"
            },
            {
                code: 23,
                base: "i"
            },
            {
                code: 24,
                base: "o"
            },
            {
                code: 25,
                base: "p"
            },
            {
                code: 26,
                base: "[",
                shifted: "{"
            },
            {
                code: 27,
                base: "]",
                shifted: "}"
            },
            {
                code: 43,
                base: "\\",
                shifted: "|",
                width: 1.5
            }
        ], [
            {
                code: 58,
                label: "Caps",
                kind: KeyboardLayout.Kind.Lock,
                width: 1.75
            },
            {
                code: 30,
                base: "a"
            },
            {
                code: 31,
                base: "s"
            },
            {
                code: 32,
                base: "d"
            },
            {
                code: 33,
                base: "f"
            },
            {
                code: 34,
                base: "g"
            },
            {
                code: 35,
                base: "h"
            },
            {
                code: 36,
                base: "j"
            },
            {
                code: 37,
                base: "k"
            },
            {
                code: 38,
                base: "l"
            },
            {
                code: 39,
                base: ";",
                shifted: ":"
            },
            {
                code: 40,
                base: "'",
                shifted: "\""
            },
            {
                code: 28,
                icon: "\ue31b",
                kind: KeyboardLayout.Kind.Action,
                width: 2.25
            }
        ], [
            {
                code: 42,
                label: "Shift",
                kind: KeyboardLayout.Kind.Modifier,
                width: 2.25
            },
            {
                code: 44,
                base: "z"
            },
            {
                code: 45,
                base: "x"
            },
            {
                code: 46,
                base: "c"
            },
            {
                code: 47,
                base: "v"
            },
            {
                code: 48,
                base: "b"
            },
            {
                code: 49,
                base: "n"
            },
            {
                code: 50,
                base: "m"
            },
            {
                code: 51,
                base: ",",
                shifted: "<"
            },
            {
                code: 52,
                base: ".",
                shifted: ">"
            },
            {
                code: 53,
                base: "/",
                shifted: "?"
            },
            {
                code: 54,
                label: "Shift",
                kind: KeyboardLayout.Kind.Modifier,
                width: 2.75
            }
        ], [
            {
                code: 1,
                label: "Esc",
                kind: KeyboardLayout.Kind.Action,
                width: 1.25
            },
            {
                code: 29,
                label: "Ctrl",
                kind: KeyboardLayout.Kind.Modifier,
                width: 1.25
            },
            {
                code: 56,
                label: "Alt",
                kind: KeyboardLayout.Kind.Modifier,
                width: 1.25
            },
            {
                code: 125,
                label: "Super",
                kind: KeyboardLayout.Kind.Modifier,
                width: 1.25
            },
            {
                code: 57,
                icon: "\ue256",
                kind: KeyboardLayout.Kind.Action,
                width: 5
            },
            {
                code: 111,
                label: "Del",
                kind: KeyboardLayout.Kind.Action
            },
            {
                code: 105,
                icon: "\ue314",
                kind: KeyboardLayout.Kind.Action
            },
            {
                code: 108,
                icon: "\ue313",
                kind: KeyboardLayout.Kind.Action
            },
            {
                code: 103,
                icon: "\ue316",
                kind: KeyboardLayout.Kind.Action
            },
            {
                code: 106,
                icon: "\ue315",
                kind: KeyboardLayout.Kind.Action
            }
        ]]

    function kindOf(key) {
        return key.kind === undefined ? KeyboardLayout.Kind.Character : key.kind;
    }

    function widthOf(key) {
        return key.width === undefined ? 1 : key.width;
    }

    function isDual(key) {
        return key.shifted !== undefined;
    }

    function baseOf(key) {
        return key.base === undefined ? "" : key.base;
    }

    function shiftedOf(key) {
        if (key.shifted !== undefined)
            return key.shifted;
        return KeyboardLayout.baseOf(key).toUpperCase();
    }
}
