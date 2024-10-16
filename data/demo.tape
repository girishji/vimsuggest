# VHS documentation
#
# Output:
#   Output <path>.gif               Create a GIF output at the given <path>
#   Output <path>.mp4               Create an MP4 output at the given <path>
#   Output <path>.webm              Create a WebM output at the given <path>
#
# Require:
#   Require <string>                Ensure a program is on the $PATH to proceed
#
# Settings:
#   Set FontSize <number>           Set the font size of the terminal
#   Set FontFamily <string>         Set the font family of the terminal
#   Set Height <number>             Set the height of the terminal
#   Set Width <number>              Set the width of the terminal
#   Set LetterSpacing <float>       Set the font letter spacing (tracking)
#   Set LineHeight <float>          Set the font line height
#   Set LoopOffset <float>%         Set the starting frame offset for the GIF loop
#   Set Theme <json|string>         Set the theme of the terminal
#   Set Padding <number>            Set the padding of the terminal
#   Set Framerate <number>          Set the framerate of the recording
#   Set PlaybackSpeed <float>       Set the playback speed of the recording
#   Set MarginFill <file|#000000>   Set the file or color the margin will be filled with.
#   Set Margin <number>             Set the size of the margin. Has no effect if MarginFill isn't set.
#   Set BorderRadius <number>       Set terminal border radius, in pixels.
#   Set WindowBar <string>          Set window bar type. (one of: Rings, RingsRight, Colorful, ColorfulRight)
#   Set WindowBarSize <number>      Set window bar size, in pixels. Default is 40.
#   Set TypingSpeed <time>          Set the typing speed of the terminal. Default is 50ms.
#
# Sleep:
#   Sleep <time>                    Sleep for a set amount of <time> in seconds
#
# Type:
#   Type[@<time>] "<characters>"    Type <characters> into the terminal with a
#                                   <time> delay between each character
#
# Keys:
#   Escape[@<time>] [number]        Press the Escape key
#   Backspace[@<time>] [number]     Press the Backspace key
#   Delete[@<time>] [number]        Press the Delete key
#   Insert[@<time>] [number]        Press the Insert key
#   Down[@<time>] [number]          Press the Down key
#   Enter[@<time>] [number]         Press the Enter key
#   Space[@<time>] [number]         Press the Space key
#   Tab[@<time>] [number]           Press the Tab key
#   Left[@<time>] [number]          Press the Left Arrow key
#   Right[@<time>] [number]         Press the Right Arrow key
#   Up[@<time>] [number]            Press the Up Arrow key
#   Down[@<time>] [number]          Press the Down Arrow key
#   PageUp[@<time>] [number]        Press the Page Up key
#   PageDown[@<time>] [number]      Press the Page Down key
#   Ctrl+<key>                      Press the Control key + <key> (e.g. Ctrl+C)
#
# Display:
#   Hide                            Hide the subsequent commands from the output
#   Show                            Show the subsequent commands in the output

Output demo.gif

Set Margin 6
Set MarginFill "#ffffff"
Set BorderRadius 3
Set Padding 2

# Set TypingSpeed 200ms
Set FontSize 14
Set Width 800
Set Height 500
Set Shell "zsh"
# https://github.com/charmbracelet/vhs/blob/main/themes.json
Set Theme "Builtin Tango Dark"
# Set Theme "Builtin Dark"
# Set Theme "Builtin Light"

Hide
Type "vi -Nn -u ./data/vimrc" Enter
Show
Sleep 1
Type `:cd /tmp/vim  " Change to Vim source directory` Sleep 2s Enter

# Search autocompletion

Hide
Type ":e AGENDA" Enter
Type "i"
Show
Type "SEARCH ('/' AND '?') AUTO-COMPLETION" Enter Sleep 1
Type "  * Single word, multi word, regex pattern search, and" Enter
Type "        search across line boundary" Enter Sleep 1
Escape
Type ":e ./LI" Sleep 1 Tab Sleep 2 Enter Sleep 2
Hide
Type ":set hls" Enter Type ":nohls" Enter
Show
Type "/ar" Sleep 2 Tab Sleep 1 Tab Sleep 1 Sleep 2 Enter Sleep 2
Type@200ms "/ts of Vim" Sleep 2 Enter Sleep 2
Hide
Type ":nohls" Enter
Type "gg"
Show
Type@200ms "/res.* e" Sleep 3 Tab Sleep 2 Enter Sleep 2
Hide
Type ":nohls" Enter
Type "gg"
Show
Type@200ms "/cl.*n\n\s*t" Sleep 3 Tab Sleep 2 Enter Sleep 2
Hide
Type ":nohls" Enter
Type "gg"
Show

Hide
Type ":b " Tab Enter Type "i"
Show
Type "  * Fuzzy search" Enter Sleep 1
Escape
Type ":b #" Enter
Type ":call g:VimS" Sleep 1 Tab Type "#{search: #{fuzzy: v:true}})" Sleep 2 Enter
Type "/ar" Sleep 2 Tab Sleep 1 Tab Sleep 2 Enter Sleep 2
Type "gg"

Hide
Type ":b " Tab Enter Type "i"
Show
Type "  * Customize: Flat menu" Enter Sleep 1
Escape
Type ":call g:VimS" Tab Type "#{search: #{pum: v:false}})" Sleep 2 Enter
Type ":b #" Enter
Type "/ar" Sleep 3 Tab Sleep 1 Tab Sleep 1 Tab Sleep 1 Enter Sleep 2
Type "gg"

# Command autocompletion

Hide
Type ":b " Tab Enter Type "i"
Show
Enter
Type "COMMAND (':') AUTO-COMPLETION" Enter Sleep 1
Type "  * Basic examples (:h, :tag, etc.)" Enter Sleep 1
Escape
Type ":h :co" Sleep 2 Tab Sleep 1 Tab Sleep 1 Tab Sleep 1 Enter Sleep 2
Type ":bd" Sleep 1 Enter
Type ":tag " Sleep 2 Type "dat" Sleep 2 Tab Sleep 1 Tab Sleep 1 Tab Sleep 1 Enter Sleep 2
Type ":bd" Sleep 1 Enter

Type "i"
Type "  * Customize: Add border to menu" Enter Sleep 1
Escape
Type ":call g:VimS" Tab Type `#{cmd: #{popupattrs: #{border: [1, 1, 1, 1], highlight: 'Normal'}}})`
Sleep 1 Enter
Hide
Type ":hi VimSuggestMatch ctermfg=213 ctermbg=16" Enter
Type ":hi VimSuggestMatchSel ctermfg=200 ctermbg=253" Enter
Show

Type "i"
Enter
Type "ADDONS" Enter Sleep 1
Type "  * Fuzzy find files and buffers" Enter Sleep 1
Escape
Type ":VSFind " Sleep 2 Type "optio" Sleep 3 Enter Sleep 2
Type ":VSFind " Sleep 2 Type "text" Sleep 2 Tab Sleep 1 Tab Sleep 1 Enter Sleep 2
Type ":VSBuffer " Sleep 1 Type "age" Sleep 1 Enter Sleep 1

Type "i"
Type "  * Find files using glob (or regex) pattern" Enter Sleep 1
Escape
Type ":VSFindL *cpp" Sleep 2 Tab Sleep 1 Tab Sleep 1 Enter Sleep 2
Hide
Type ":VSBuffer age" Enter
Show

Type "i"
Type "  * Add selected files to Arglist, Quickfix list, and paste items to buffer" Enter Sleep 1
Escape
Type ":VSFindL *.c" Sleep 2
Ctrl+r
Type ":ar" Sleep 2 Enter Sleep 2
Type ":VSFindL *.vim" Sleep 2
Ctrl+q
Type ":copen" Sleep 2 Enter Sleep 2
Type ":ccl" Sleep 2 Enter Sleep 2
Type ":VSFindL *.c" Sleep 2
Ctrl+g
Type ":enew" Sleep 1 Enter Sleep 2
Type `"+p` Sleep 2
Hide
Type ":VSBuffer age" Enter
Show

Type "i"
Type "  * Live grep" Enter Sleep 1
Escape
Type `:nnoremap <space>g :VSGrep ""<left>` Sleep 1 Enter
Space Type "g" Sleep 1 Type "getline" Tab Sleep 1 Tab Sleep 1 Tab Sleep 1 Enter Sleep 2
Hide
Type ":VSBuffer age" Enter
Show

Type "i"
Type "  * Search function definitions in a vim script using :global" Enter Sleep 1
Escape
Hide
Type ":VSFind " Type "javascvim" Enter
Show
Type ":nnoremap <space>d :VSGlobal \v\c(^<bar>\s)fu%[nction]!?\s.{-}" Sleep 1 Enter
Space Type "d" Sleep 3 Type "Sy" Sleep 3 Enter Sleep 3
Hide
Type ":VSBuffer age" Enter
Show

Type "i"
Type "  * There's more, see README.md!" Enter Sleep 1
Enter
Escape

Type ":qa!"
Sleep 2s
