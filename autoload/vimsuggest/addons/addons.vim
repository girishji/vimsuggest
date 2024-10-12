vim9script

# This script provides a set of commands that perform:

# - Fuzzy file finding using async job (VSFind)
# - Fuzzy buffer, MRU, keymap, changelist, mark, and register searching
# - Live grep (glob/regex) searching using async job (VSGrep)
# - Live (glob/regex) file searching using async job (VSFindL)
# - Search within buffer using :global (VSGlobal)
# - Include file search using :ilist (VSInclSearch)
# - Custom shell command execution (VSExec)

# Use commands defined in this file directly, or bind them to your favorite
# keys. Use this file as a boilerplate to define customized alternatives.
# Note: Legacy script users can also use ':import' (see :h import-legacy).

# Usage:
#
# 1. Fuzzy Find Files
#
#  :VSFind [dirpath] [fuzzy_pattern]
#
#  Uses 'find' command in a separate job to asynchronously gather files once
#  and executes fuzzy search. First argument is optional directory (to
#  search for files). Hidden files and directories are excluded.
#
#  Map it to your favorite key:
#    nnoremap <key> :VSFind<space>
#    nnoremap <key> :VSFind ~/.vim<space>
#    nnoremap <key> :VSFind $VIMRUNTIME<space>
#
#  Note: To define your own 'find' command with custom options, use
#  fuzzy.FindComplete().
#
# 2. Fuzzy Find Buffers, MRU (:h v:oldfiles), Keymaps, Changelist, Marks, and
#    Registers
#
#  :VSBuffer [fuzzy_pattern]
#  :VSMru [fuzzy_pattern]
#  :VSKeymap [fuzzy_pattern]
#  :VSChangelist [fuzzy_pattern]
#  :VSMark [fuzzy_pattern]
#  :VSRegister [fuzzy_pattern]
#
#  VSKeymap opens file where keymap is defined when <CR> is pressed. VSMark
#  jumps to the mark. VSRegister pastes the contents of the register. Rest
#  of them do as expected.
#
#  Map them to your favorite keys:
#    nnoremap <key> :VSBuffer<space>
#    nnoremap <key> :VSMru<space>
#    nnoremap <key> :VSKeymap<space>
#    nnoremap <key> :VSMark<space>
#    nnoremap <key> :VSRegister<space>
#
# 3. (Live) Grep
#
#  :VSGrep {pattern} [directory]
#
#  Execute 'grep' command every time a user types a key and show the results.
#  {pattern} is the shell glob pattern. Better to enclose the pattern in quotes
#  to avoid backslashes to escape special characters and spaces. Optional
#  [directory] can be specified.
#  Command string is obtained from g:vimsuggest_grepprg variable or `:h 'grepprg'`
#  option. If the string contains '$*', it is replaced with arguments typed on
#  command line. For example:
#    g:vimsuggest_grepprg = 'ggrep -REIHins $* --exclude-dir=.git --exclude=".*"'
#
#  Map it to your favorite key:
#    nnoremap <key> :VSGrep ""<left>
#    nnoremap <key> :VSGrep "<c-r>=expand('<cword>')<cr>"<left>
#
#  NOTE: Instead of 'grep', 'rg' or 'ag' can be used.
#        ':VSExec' can also perform live find. See below.
#
# 4. (Live) Find
#
#  :VSFindL {pattern} [directory]
#
#  Execute 'find' command every time a user types a key and show the results.
#  {pattern} is the glob pattern that should be enclosed in quotes if there are
#  wildcards.
#  'grep' command string is obtained from g:vimsuggest_findprg. If the string contains
#  '$*', it is replaced with '{pattern} [directory]'. If it contains two '$*'s,
#  they are replaced by '{pattern}' and '[directory]' (or '.' if empty) in that
#  order. For example:
#    g:vimsuggest_findprg = 'find -EL $* \! \( -regex ".*\.(swp\|git\|zsh_.*)" -prune \) -type f -name $*'
#
#  Map it to your favorite key:
#    nnoremap <leader>ff :VSFindL "*"<left><left>
#
#  NOTE: ':VSExec' can also perform live grep. See below.
#
# 5. Global (:h :global) Search (Search Within Buffer)
#
#  :VSGlobal {regex_pattern}
#
#  This is a surprisingly useful command. {regex_pattern} is the powerful Vim
#  regex. For example, to quickly list all the functions in a file and target by
#  typing few letters, use the following keymap (:h pattern.txt):
#  Python:
#    nnoremap <buffer> <key> :VSGlobal \v(^\|\s)(def\|class).{-}
#  Vim9 script functions, commands, highlights:
#    nnoremap <buffer> <key> :VSGlobal \v\c(^<bar>\s)(def<bar>:?com%[mand]<bar>:?hi%[ghlight])!?\s.{-}
#  NOTE: Wrap the above keymaps in ':h :autocmd' based on ":h 'filetype'"
#  Search anything:
#    nnoremap <key> :VSGlobal<space>
#
# 6. Search in Included Files (:h include-search)
#
#  :VSInclSearch {regex_pattern}
#
#  Same as above, except both current buffer and included files are searched.
#  Results are from ':h :ilist' command. Can be mapped as follows:
#    nnoremap <key> :VSInclSearch<space>
#
# 7. Execute Shell Command (ex. grep, find, etc.)
#
#  :VSExec {shell_command}
#
#  {shell_command} is executed within your '$SHELL' environment. This way, brace
#  expansion ({,}) and globbing wildcards ('**', '***', '**~') work if
#  your shell support them. Errors are ignored.
#
#  Map it to your favorite key:
#    nnoremap <key> :VSExec grep -RIHins "" . --exclude-dir={.git,"node_*"} --exclude=".*"<c-left><c-left><c-left><left><left>
#    nnoremap <key> :VSExec grep -IHins "" **/*<c-left><left><left> # Slower
#
#   Note:
#   1. <Tab>/<S-Tab> to select the menu item. If no item is selected <CR> visits
#      the first item in the menu.
#   2. If above commands are not adequate, you can define your own command
#      using the boilerplate examples in this file.

import autoload '../cmd.vim'
# Debug: Avoid autoloading the following scrits to prevent delaying compilation
# until the autocompletion phase. A Vim bug is causing commands to die silently
# when compilation errors are present. Also, use :defcompile.
import './fuzzy.vim'
import './exec.vim'

var enable_hook = []

# export def Enable()
#     ## (Fuzzy) Find Files
#     command! -nargs=* -complete=customlist,fuzzy.FindComplete VSFind fuzzy.DoFindAction(<f-args>)
#     ## (Live) Grep and Find
#     command! -nargs=+ -complete=customlist,exec.GrepComplete VSGrep exec.DoAction(null_function, <f-args>)
#     command! -nargs=+ -complete=customlist,exec.FindComplete VSFindL exec.DoAction(null_function, <f-args>)
#     ## Execute Shell Command (ex. grep, find, etc.)
#     command! -nargs=* -complete=customlist,exec.Complete VSExec exec.DoAction(null_function, <f-args>)
#     ## Global (:h :g) (Search Within Buffer)
#     command! -nargs=* -complete=customlist,GlobalComplete VSGlobal exec.DoAction(JumpToLine, <f-args>)
#     ## Include Search (:h include-search) (Search for keywords in the included files)
#     command! -nargs=* -complete=customlist,InclSearchComplete VSInclSearch exec.DoAction(JumpToDef, <f-args>)
#     ## Others
#     command! -nargs=* -complete=customlist,BufferComplete VSBuffer DoBufferAction(<f-args>)
#     command! -nargs=* -complete=customlist,MRUComplete VSMru DoMRUAction(<f-args>)
#     command! -nargs=* -complete=customlist,KeymapComplete VSKeymap DoKeymapAction(<f-args>)
#     command! -nargs=* -complete=customlist,MarkComplete VSMark DoMarkAction(<f-args>)
#     command! -nargs=* -complete=customlist,RegisterComplete VSRegister DoRegisterAction(<f-args>)
#     command! -nargs=* -complete=customlist,ChangelistComplete VSChangelist DoChangeListAction(<f-args>)
# enddef

## (Fuzzy) Find Files

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,fuzzy.FindComplete VSFind fuzzy.DoFindAction(<f-args>)
})
cmd.AddOnSpaceHook('VSFind')

## (Live) Grep and Find
enable_hook->add(() => {
    :command! -nargs=+ -complete=customlist,exec.GrepComplete VSGrep exec.DoAction(null_function, <f-args>)
    :command! -nargs=+ -complete=customlist,exec.FindComplete VSFindL exec.DoAction(null_function, <f-args>)
})

## Global Search (:h :g)

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,GlobalComplete VSGlobal exec.DoAction(JumpToLine, <f-args>)
})
def GlobalComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    var lines = exec.CompleteExCmd(arglead, cmdline, cursorpos, (args) => {
        var saved_incsearch = &incsearch
        set noincsearch
        var saved_cursor = getcurpos()
        try
            return execute($'g/{args}')->split("\n")
        finally
            if saved_incsearch
                set incsearch
            else
                set noincsearch
            endif
            setpos('.', saved_cursor)
        endtry
        return []
    })
    cmd.AddHighlightHook(cmd.CmdLead(), (_: string, itms: list<any>): list<any> => {
        exec.DoHighlight(exec.ArgsStr())
        exec.DoHighlight('^\s*\d\+', 'VimSuggestMute')
        return [itms]
    })
    return lines
enddef
def JumpToLine(line: string, _: string)
    var lnum = line->matchstr('\d\+')->str2nr()
    Jump(lnum)
enddef

## Search for Keywords in the Current Buffer and Included Files (:h :il)

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,InclSearchComplete VSInclSearch exec.DoAction(JumpToDef, <f-args>)
})
var incl_search_pattern = null_string
def InclSearchComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    incl_search_pattern = exec.ArgsStr()
    var lines = exec.CompleteExCmd(arglead, cmdline, cursorpos, (args) => {
        return execute($'ilist /{args}/')->split("\n")
            ->copy()->filter((_, v) => v !~? 'includes previously listed match')
    })
    if !lines->empty()
        var cmdlead = cmd.CmdLead()
        cmd.AddSelectItemHook(cmdlead, SelectItemPostCallback)
        cmd.AddHighlightHook(cmdlead, (_: string, itms: list<any>): list<any> => {
            exec.DoHighlight(exec.ArgsStr())
            exec.DoHighlight('^\(\S\+$\|\s*\d\+:\s\+\d\+\)', 'VimSuggestMute')
            return [itms]
        })
    endif
    return lines
enddef
def SelectItemPostCallback(line: string, dir: string): bool
    if line->expandcmd()->filereadable()
        cmd.state.pmenu.SelectItem(dir, cmd.SelectItemPost)
    endif
    return true
enddef
def JumpToDef(line: string, _: string)
    var jnum = line->matchstr('\d\+')->str2nr()
    :exe $'ijump {jnum} /{incl_search_pattern}/'
enddef

## Buffers

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,BufferComplete VSBuffer DoBufferAction(<f-args>)
})
cmd.AddOnSpaceHook('VSBuffer')
def BufferComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, function(Buffers, [false]))
enddef
def DoBufferAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (it, key) => {
        exec.VisitBuffer(key, it.bufnr)
    })
enddef
def Buffers(list_all_buffers: bool): list<any>
    var blist = list_all_buffers ? getbufinfo({buloaded: 1}) : getbufinfo({buflisted: 1})
    var buffer_list = blist->mapnew((_, v) => {
        return {bufnr: v.bufnr,
            text: (bufname(v.bufnr) ?? $'[{v.bufnr}: No Name]'),
            lastused: v.lastused}
    })->sort((i, j) => i.lastused > j.lastused ? -1 : i.lastused == j.lastused ? 0 : 1)
    # Alternate buffer first, current buffer second.
    if buffer_list->len() > 1 && buffer_list[0].bufnr == bufnr()
        [buffer_list[0], buffer_list[1]] = [buffer_list[1], buffer_list[0]]
    endif
    return buffer_list
enddef

## MRU - Most Recently Used Files

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,MRUComplete VSMru DoMRUAction(<f-args>)
})
cmd.AddOnSpaceHook('VSMru')
def MRUComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, MRU)
enddef
def DoMRUAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item, key) => {
        exec.VisitFile(key, item)
    })
enddef
def MRU(): list<any>
    var mru = v:oldfiles->copy()->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    mru->map((_, v) => v->fnamemodify(':.'))
    return mru
enddef

## Keymap

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,KeymapComplete VSKeymap DoKeymapAction(<f-args>)
})
cmd.AddOnSpaceHook('VSKeymap')
def KeymapComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, (): list<any> => {
        return execute('map')->split("\n")
    })
enddef
def DoKeymapAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item, _) => {
        var m = item->matchlist('\v^(\a)?\s+(\S+)')
        if m->len() > 2
            var cmdstr = $'verbose {m[1]}map {m[2]}'
            var lines = execute(cmdstr)->split("\n")
            for line in lines
                m = line->matchlist('\v\s*Last set from (.+) line (\d+)')
                if !m->empty() && m[1] != null_string && m[2] != null_string
                    exe $"e +{str2nr(m[2])} {m[1]}"
                endif
            endfor
        endif
    })
enddef

## Global and Local Marks

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,MarkComplete VSMark DoMarkAction(<f-args>)
})
cmd.AddOnSpaceHook('VSMark')
def MarkComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, (): list<any> => {
        return 'marks'->execute()->split("\n")->slice(1)
    })
enddef
def DoMarkAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item, _) => {
        var mark = item->matchstr('\v^\s*\zs\S+')
        :exe $"normal! '{mark}"
    })
enddef

## Registers

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,RegisterComplete VSRegister DoRegisterAction(<f-args>)
})
cmd.AddOnSpaceHook('VSRegister')
def RegisterComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, (): list<any> => {
        return 'registers'->execute()->split("\n")->slice(1)
    })
enddef
def DoRegisterAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item, _) => {
        var reg = item->matchstr('\v^\s*\S+\s+\zs\S+')
        :exe $'normal! {reg}p'
    })
enddef

## Changelist

enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,ChangelistComplete VSChangelist DoChangeListAction(<f-args>)
})
cmd.AddOnSpaceHook('VSChangelist')
def ChangelistComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, (): list<any> => {
        return 'changes'->execute()->split("\n")->slice(1)->reverse()
    })
enddef
def DoChangeListAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item, _) => {
        var n = item->matchstr('^\s*\zs\d\+')
        :exe $'normal! {n}g;'
    })
enddef

## Code Artifacts (Use VSGlobal instead)

cmd.AddOnSpaceHook('VSArtifacts')
export def ArtifactsComplete(arglead: string, cmdline: string, cursorpos: number,
        patterns: list<string> = []): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, function(Artifacts, [patterns]))
enddef
export def Jump(lnum: number)
    exe $":{lnum}"
    normal! zz
enddef
export def DoArtifactsAction(arglead = null_string)
    fuzzy.DoAction(arglead, (item, _) => Jump(item.lnum))
enddef
export def Artifacts(patterns: list<string>): list<any>
    var items = []
    for nr in range(1, line('$'))
        var line = getline(nr)
        for pat in patterns
            var name = line->matchstr(pat)
            if name != null_string
                items->add({text: name, lnum: nr})
                break
            endif
        endfor
    endfor
    return items->copy()->filter((_, v) => v.text !~ '^\s*#')
enddef

##

export def Enable()
    for fn in enable_hook
        function(fn)()
    endfor
enddef

export def Disable()
    for c in ['VSFind', 'VSGrep', 'VSFindL', 'VSExec', 'VSGlobal',
            'VSInclSearch', 'VSBuffer', 'VSMru', 'VSKeymap', 'VSMark',
            'VSRegister', 'VSChangelist']
        if exists($":{c}") == 2
            :exec $'delcommand {c}'
        endif
    endfor
enddef

:defcompile  # Debug: See note above.

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
