vim9script

# This script offers a powerful suite of commands for fuzzy searching and shell
# command execution. Key features include:

# * Fuzzy File Search - with asynchronous jobs (`VSFind`)
# * Fuzzy Searching - for buffers, MRU, keymaps, changelists, marks, and registers
# * Live Grep Search - (glob/regex) using asynchronous jobs (`VSGrep`)
# * Live File Search - (glob/regex) using asynchronous jobs (`VSFindL`)
# * In-Buffer Search - using `:global` (`VSGlobal`)
# * Include File Search - using `:ilist` (`VSInclSearch`)
# * Custom Shell Command Execution - (`VSExec`)

# This script can be customized to create your own variations. Legacy script users
# can import using `:import` (see `:h import-legacy`).

import autoload '../cmd.vim'
# Debug: Avoid autoloading the following scrits to prevent delaying compilation
# until the autocompletion phase. A Vim bug is causing commands to die silently
# when compilation errors are present. Also, use :defcompile.
import './fuzzy.vim'
import './exec.vim'

var enable_hook = []

## (Fuzzy) Find Files
#
#    Command:
#    `:VSFind [dir] [fuzzy_pattern]`
#
#    This runs the `find` command asynchronously to gather files for fuzzy
#    searching. The optional first argument is the directory to search within.
#
#    'find' command can be specified through g:vimsuggest_fzfindprg variable.
#    If this variable is not defined, a default command is used (that ignores
#    hidden files and directories).
#
#    Example key mappings:
#    ```
#    nnoremap <key> :VSFind<space>
#    nnoremap <key> :VSFind ~/.vim<space>
#    nnoremap <key> :VSFind $VIMRUNTIME<space>
#    ```
enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,fuzzy.FindComplete VSFind fuzzy.DoFindAction(null_function, <f-args>)
})
cmd.AddOnSpaceHook('VSFind')

## (Fuzzy) Find Git Files
#
#    Command:
#    `:VSGitFind [dir] [fuzzy_pattern]`
#
#    This runs the `git ls-tree` or `find` command asynchronously to gather
#    files for fuzzy searching. If searching in a Git repository, it searches
#    tracked files in the whole tree. Outside Git, or if 'dir' is specified, it
#    falls back to regular file search (like `VSFind`).
#
#    Example key mappings:
#    ```
#    nnoremap <key> :VSGitFind<space>
#    ```
enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,GitFindComplete VSGitFind fuzzy.DoFindAction(GitFindAction, <f-args>)
})
cmd.AddOnSpaceHook('VSGitFind')
def GitFindComplete(A: string, L: string, C: number): list<any>
    if fuzzy.ExtractDir() != null_string
        return fuzzy.FindComplete(A, L, C)
    else
        system('git rev-parse --is-inside-work-tree')
        return fuzzy.FindComplete(A, L, C, v:shell_error == 0 ?
            'git ls-tree --full-tree -r --name-only HEAD' : null_string)
    endif
enddef
def GitFindAction(key: string, fpath: string)
    var gitdir = system('git rev-parse --show-toplevel')
    if v:shell_error == 0
        gitdir = gitdir->substitute('\%x00', '', '')  # remove ^@ (null char)
        exec.VisitFile(key, $"{gitdir}{has('win32') ? '\' : '/'}{fpath}")
    else
        exec.VisitFile(key, fpath)
    endif
enddef

## Live Grep
#
#    Command:
#    `:VSGrep {pattern} [directory]`
#
#    Executes a `grep` command live, showing results as you type. `{pattern}` is a
#    glob pattern, and it’s best to enclose it in quotes to handle special
#    characters. You can also specify an optional directory.
#
#    The grep command is taken from `g:vimsuggest_grepprg` or the `:h 'grepprg'`
#    option. If it contains `$*`, it gets replaced by the command-line arguments.
#
#    Example key mappings:
#    ```
#    g:vimsuggest_grepprg = 'ggrep -REIHins $* --exclude-dir=.git --exclude=".*"'
#    nnoremap <key> :VSGrep ""<left>
#    nnoremap <key> :VSGrep "<c-r>=expand('<cword>')<cr>"<left>
#    ```
#
#    Note: You can substitute `grep` with `rg` or `ag`. For more advanced needs, see `:VSExec`.
#
enable_hook->add(() => {
    :command! -nargs=+ -complete=customlist,exec.GrepComplete VSGrep exec.DoAction(null_function, <f-args>)
})

## Live File Search
#
#    Command:
#    `:VSFindL {pattern} [directory]`
#
#    This command runs `find` live, showing results as you type. `{pattern}` is a
#    glob pattern that should be enclosed in quotes if it contains wildcards. The
#    `find` command is customized via `g:vimsuggest_findprg`.
#
#    Example key mappings:
#    ```
#    g:vimsuggest_findprg = 'find -EL $* \! \( -regex ".*\.(swp\|git\|zsh_.*)" -prune \) -type f -name $*'
#    nnoremap <leader>ff :VSFindL "*"<left><left>
#    ```
enable_hook->add(() => {
    :command! -nargs=+ -complete=customlist,exec.FindComplete VSFindL exec.DoAction(null_function, <f-args>)
})

## Execute Shell Command (ex. grep, find, etc.)
#
#    Command:
#    `:VSExec {shell_command}`
#
#    This command runs any shell command within your `$SHELL` environment,
#    allowing features like brace expansion and globbing. Errors are ignored.
#
#    Example key mappings:
#    ```
#    nnoremap <key> :VSExec grep -RIHins "" . --exclude-dir={.git,"node_*"} --exclude=".*"<c-left><c-left><c-left><left><left>
#    nnoremap <key> :VSExec grep -IHins "" **/*<c-left><left><left>
#    ```
enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,exec.Complete VSExec exec.DoAction(null_function, <f-args>)
})

## Global In-Buffer Search (`:h :global`)
#
#    Command:
#    `:VSGlobal {regex_pattern}`
#
#    Use this for a powerful in-buffer search with Vim's regex. For example, to
#    list all functions in a Python file and search quickly:
#    ```
#    nnoremap <buffer> <key> :VSGlobal \v(^\|\s)(def\|class).{-}
#    ```
#    Or, to list various artifacts in a vim9 script:
#    ```
#    nnoremap <buffer> <key> :VSGlobal \v\c(^<bar>\s)(def<bar>com%[mand]<bar>:?hi%[ghlight])!?\s.{-}
#    ```
#    You can search specific file types by wrapping the keymaps in autocmds (see
#    `:h :autocmd`).
#    Search anything (like `:vimgrep // %`}
#    ```
#    nnoremap <key> :VSGlobal<space>
#    ```
enable_hook->add(() => {
    :command! -nargs=* -complete=customlist,GlobalComplete VSGlobal exec.DoAction(JumpToLine, <f-args>)
})
def GlobalComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    var lines = exec.CompleteExCmd(arglead, cmdline, cursorpos, (args) => {
        # Note: String match ('=~') operator can be used instead of 'g://'
        var saved_incsearch = &incsearch
        set noincsearch
        var saved_number = &number
        set number
        var saved_cursor = getcurpos()
        try
            return execute($'g/{args}')->split("\n")
        finally
            if saved_incsearch
                set incsearch
            endif
            if !saved_number
                set nonumber
            endif
            setpos('.', saved_cursor)
        endtry
        return []
    })
    cmd.AddHighlightHook(cmd.CmdLead(), (_: string, itms: list<any>): list<any> => {
        cmd.DoHighlight(exec.ArgsStr())
        cmd.DoHighlight('^\s*\d\+', 'VimSuggestMute')
        return [itms]
    })
    return lines
enddef
def JumpToLine(line: string, _: string)
    var lnum = line->matchstr('\d\+')->str2nr()
    Jump(lnum)
enddef

## Search in Included Files (`:h include-search`)
#
#    Command:
#    `:VSInclSearch {regex_pattern}`
#
#    Similar to `VSGlobal`, but searches both the current buffer and included
#    files. The results are gathered using the `:ilist` command.
#
#    Example key mappings:
#    ```
#    nnoremap <key> :VSInclSearch<space>
#    ```
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
            cmd.DoHighlight(exec.ArgsStr())
            cmd.DoHighlight('^\(\S\+$\|\s*\d\+:\s\+\d\+\)', 'VimSuggestMute')
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

## Fuzzy Search for Buffers, MRU (`v:oldfiles`), Keymaps, Changelists, Marks, and Registers
#
#    Commands:
#    ```
#    :VSBuffer [fuzzy_pattern]
#    :VSMru [fuzzy_pattern]
#    :VSKeymap [fuzzy_pattern]
#    :VSChangelist [fuzzy_pattern]
#    :VSMark [fuzzy_pattern]
#    :VSRegister [fuzzy_pattern]
#    ```
#
#    - `VSKeymap` opens the file containing the keymap when pressed.
#    - `VSMark` jumps to a specific mark.
#    - `VSRegister` pastes the register's content.
#
#    Example key mappings:
#    ```
#    nnoremap <key> :VSBuffer<space>
#    nnoremap <key> :VSMru<space>
#    nnoremap <key> :VSKeymap<space>
#    nnoremap <key> :VSMark<space>
#    nnoremap <key> :VSRegister<space>
#    ```

## Fuzzy Search Buffers

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

## Fuzzy Search MRU - Most Recently Used Files

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
    var mru = []
    if has("win32")
        # Windows is very slow checking if file exists. use non-filtered v:oldfiles.
        mru = v:oldfiles
    else
        mru = v:oldfiles->copy()->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    endif
    mru->map((_, v) => v->fnamemodify(':.'))
    return mru
enddef

## Fuzzy Search Keymap

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

## Fuzzy Search Global and Local Marks

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

## Fuzzy Search Registers

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

## Fuzzy Search Changelist

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

## Fuzzy Search Code Artifacts (Use VSGlobal instead)

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

augroup VimSuggestCmdInit | autocmd!
    def Enable()
        for fn in enable_hook
            function(fn)()
        endfor
    enddef
    autocmd User VimSuggestCmdSetup Enable()

    def Disable()
        for c in ['VSFind', 'VSGrep', 'VSFindL', 'VSExec', 'VSGlobal',
                'VSInclSearch', 'VSBuffer', 'VSMru', 'VSKeymap', 'VSMark',
                'VSRegister', 'VSChangelist']
            if exists($":{c}") == 2
                :exec $'delcommand {c}'
            endif
        endfor
    enddef
    autocmd User VimSuggestCmdTeardown Disable()
augroup END

:defcompile  # Debug: See note above.

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
