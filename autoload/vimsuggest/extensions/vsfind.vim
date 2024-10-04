vim9script

# Usage:
#   VSfind <pattern1> <pattern2> ... <pattern5>
#   When <pattern2> is typed it abandons <pattern1>, and so on. No need to erase
#   the pattern if it is not working, simply type space and start typing a new pattern.

import autoload './find.vim'

command! -nargs=* -complete=customlist,DoComplete VSfind find.DoCommand(<f-args>)

export def DoComplete(A: string, L: string, C: number): list<any>
    return find.DoComplete(A, L, C, 'find . \! \( -path "*/.*" -prune \) -type f')
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
