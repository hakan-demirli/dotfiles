# Movement + Selection

w -> select until beginning of next word
e -> select until end of word
b -> select until beginning of word
W,E,B -> same but only stops at whitespaces
f -> select except find character
t -> select until find character
F,T -> same but backwards
f,t are file scoped. finds in whole file.
x -> select whole line and send cursor to end
s : search in selection.
/ : search in file. press enter. use <n> and <N> to move

# Movement

<ctrl,d>: move half page down
<ctrl,u>: move half page up
<ctrl+s>: save current cursor position to jump list
<ctrl+i>: "in" move forward in jumplist
<crtl+o>: "out" move backwards in jumplist

:sh -> run in terminal and show output
:pipe-to -> run in terminal
:pipe -> run in terminal and paste return value to current file

# Changes

a: append right after cursor
A: append at the end of line
I: insert at first character of the line
o: insert newline below
C: add cursor down.
<alt+S+c>: add cursor up.
y : yank.
p : paste.
d : delete.
<alt+j>: move line down.
<alt+k>: move line up.
& : align selection in columns.
:w<cr>: save file
<S+u> : redo
u -> undo
c -> delete selections and enter insert mode, multi-select->multicursor.
<alt>+s -> add cursor to the end of all selections
v -> enter select mode, use hjkl to select, then esc.
In select mode you can still use w,e,b, 2w etc.
<space> -> <menu will pop up>
how to select upwards? change direction of x?
r<char> -> replace each char in selection with <char>
. -> repeat last insert
<alt>+. -> repeate last f,t

J -> delete newlines in selections

> -> indent
> < -> deindent

ctrl+a -> increment selected number
ctrl+x -> decrement selected number

/smth sets the / register with smth then finds it n/N
you can directly send selection to there via \*.

- -> set / to selected text. Use n/N to move between.

~ -> selection to uppercase
<alt>+`-> selection to uppercase` -> selection to lowercase

<ctrl+c> -> comment selected

g -> goto <menu will popup on the right>
+h: beginning_of_line
+l: end_of_line
+e: end_of_file

select then `:pipe sort`

m -> match select menu
[ -> bracket menu. move between diagnostics
] -> bracket menu. move between diagnostics
<space+d> -> all diagnostics in current file
<space+D> -> all diagnostics in all files

how to search for keybindings?
<space,?> list all possible commands
you can also search for key using () like (m).

## lf file manager

############
hjkl to move
ctrl+u/d as pageup/down fast scroll.
/ to search and n/N to go among
? to back search? wtf
copy with y
cut with d
paste with p
<space> to select wtf
u to unselect all wtf
c to unselect too confusingkk
s +<smth> to sort files
