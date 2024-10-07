vim9script

# Use commands defined in this file directly, or bind them to your favorite
# keys. Use this file as a boilerplate to define customized alternatives.
# Note: Legacy script users can also use ':import' (see :h import-legacy).
#
# Usage:
#
#   Note:
#     <Tab>/<S-Tab> to select the menu item. If no item is selected <CR> visits
#     the first item in the menu.
#
# 1. Fuzzy Find Files
#
#  :VSFind [dirpath/.../][fuzzy_pattern]
#     Uses 'find' command in a separate job to asynchronously gather files once
#     and executes fuzzy search. '/.../' separates optional directory (to
#     search for files) from pattern. Hidden files and directories are excluded.
#
#  Map it to your favorite key:
#    nnoremap <key> :VSFind<space>
#    nnoremap <key> :VSFind ~/.vim/.../
#    nnoremap <key> :VSFind $VIMRUNTIME/.../
#
#  Note: Define your own command using the boilerplate below if you prefer to
#  use 'find' with your favorite options or other alternatives like 'fd'.
#
# 2. (Live) Grep
#
#     Execute 'grep' command every time a user types a key and show the results.
#
#  Option 1:
#
#  :VSGrep [fuzzy_pattern]
#
#  Execute 'grep' in the current directory. Exclude hidden files and directories
#  from being searched.
#
#  Map it to your favorite key:
#    nnoremap <key> :VSGrep ""<left>
#    nnoremap <key> :VSGrep "<c-r>=expand('<cword>')<cr>"<left>
#
#  Option 2:
#
#  :VSExec {grep_shell_command}
#
#     Define your own 'grep' command. You can use alternatives like 'rg', 'ag', etc.
#     {grep_shell_command} is executed within your '$SHELL'. This way, brace
#     expansion ({,}), globbing wildcards ('**', '***', '**~'), etc. work if
#     your shell support them. File read errors are ignored.
#
#  Map it to your favorite key:
#    nnoremap <key> :VSExec grep -RIHins "" . --exclude-dir={.git,"node_*"} --exclude=".*"<c-left><c-left><c-left><left><left>
#    nnoremap <key> :VSExec grep -IHins "" **/*<c-left><left><left> # Slower
#
#  Options 3:
#
#  :VSExecDo {vim_command} {grep_shell_command}
#
#      Same as Option #2 but takes additional argument. {vim_command} can be one of:
#      'b'        -> Open file in current window
#      'sb'       -> Open file in split window
#      'vert\ sb' -> Open file in vertical split
#      'tab\ sb'  -> Open file in tab window
#      Spaces should be escaped by '\'.
#
#  Note: If above options are not adequate, you can define your own command
#  using the boilerplate examples in this file.
#
# 3. Live Find
#
#    var cmd = {"\<C-j>": 'split', "\<C-v>": 'vert split', "\<C-t>": 'tabe'}
# 4. Fuzzy Find Buffers, MRU (:h v:oldfiles), Keymaps, Marks, and Registers
#
#  :VSBuffer [fuzzy_pattern]
#  :VSMru [fuzzy_pattern]
#  :VSKeymap [fuzzy_pattern]
#  :VSMark [fuzzy_pattern]
#  :VSRegister [fuzzy_pattern]
#
#      VSKeymap opens file where keymap is defined when <CR> is pressed. VSMark
#      jumps to the mark. VSRegister pastes the contents of the register.
#
#  Map it to your favorite key:
#    nnoremap <key> :VSBuffer<space>
#    nnoremap <key> :VSMru<space>
#    nnoremap <key> :VSKeymap<space>
#    nnoremap <key> :VSMark<space>
#    nnoremap <key> :VSRegister<space>
#
# 4. Artifacts
#

    # nnoremap <leader>fk :VSKeymap<space>
    # nnoremap <leader>fr :VSRegister<space>
    # nnoremap <leader>fm :VSMark<space>

import autoload '../cmd.vim'
# Debug: Avoid autoloading (in combination with :defcompile) the following
# scrits to prevent delaying compilation until the autocompletion phase. A Vim
# bug is causing commands to die silently when compilation errors are present.
import './fuzzy.vim'
import './exec.vim'

export def Enable()
    ## (Fuzzy) Find Files
    command! -nargs=* -complete=customlist,fuzzy.FindComplete VSFind fuzzy.DoFindAction('edit', <f-args>)
    ## (Live) Grep
    command! -nargs=+ -complete=customlist,GrepComplete VSGrep exec.DoAction(null_function, <f-args>)
    # Execute Shell Command (ex. grep, find, etc.)
    command! -nargs=* -complete=customlist,exec.Complete VSExec exec.DoAction(null_function, <f-args>)
    command! -nargs=* -complete=customlist,exec.CompleteEx VSExecDo exec.DoActionEx(null_function, <f-args>)
    # Others
    command! -nargs=* -complete=customlist,BufferComplete VSBuffer DoBufferAction(<f-args>)
    command! -nargs=* -complete=customlist,MRUComplete VSMru DoMRUAction(<f-args>)
    command! -nargs=* -complete=customlist,KeymapComplete VSKeymap DoKeymapAction(<f-args>)
    command! -nargs=* -complete=customlist,MarkComplete VSMark DoMarkAction(<f-args>)
    command! -nargs=* -complete=customlist,RegisterComplete VSRegister DoRegisterAction(<f-args>)
enddef

## (Fuzzy) Find Files

cmd.AddOnSpaceHook('VSFind')

## (Live) Grep

def GrepComplete(A: string, L: string, C: number): list<any>
    var cmdstr = $'grep --color=never {has("macunix") ? "-REIHSins" : "-REIHins"}'
    var excl = '--exclude-dir=node_modules --exclude-dir=build --exclude-dir="*/.*" --exclude="*/.*" --exclude=tags'
    return exec.Complete(A, L, C, $'{cmdstr} {excl}')
enddef

## Buffers

cmd.AddOnSpaceHook('VSBuffer')
def BufferComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, function(Buffers, [false]))
enddef
def DoBufferAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (it) => {
        :exe $'b {it.bufnr}'
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

## Code Artifacts

cmd.AddOnSpaceHook('VSArtifacts')
export def ArtifactsComplete(arglead: string, cmdline: string, cursorpos: number,
        patterns: list<string> = []): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, function(Artifacts, [patterns]))
enddef
export def DoArtifactsAction(arglead = null_string)
    fuzzy.DoAction(arglead, (item) => {
        exe $":{item.lnum}"
        normal! zz
    })
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

## MRU - Most Recently Used Files

cmd.AddOnSpaceHook('VSMru')
def MRUComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, MRU)
enddef
def DoMRUAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item) => {
        :exe $'e {item}'
    })
enddef
def MRU(): list<any>
    var mru = v:oldfiles->copy()->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    mru->map((_, v) => v->fnamemodify(':.'))
    return mru
enddef

## Keymap

cmd.AddOnSpaceHook('VSKeymap')
def KeymapComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, (): list<any> => {
        return execute('map')->split("\n")
    })
enddef
def DoKeymapAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item) => {
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

cmd.AddOnSpaceHook('VSMark')
def MarkComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, (): list<any> => {
        return 'marks'->execute()->split("\n")->slice(1)
    })
enddef
def DoMarkAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item) => {
        var mark = item->matchstr('\v^\s*\zs\S+')
        :exe $"normal! '{mark}"
    })
enddef

## Registers

cmd.AddOnSpaceHook('VSRegister')
def RegisterComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Complete(arglead, cmdline, cursorpos, (): list<any> => {
        return 'registers'->execute()->split("\n")->slice(1)
    })
enddef
def DoRegisterAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item) => {
        var reg = item->matchstr('\v^\s*\S+\s+\zs\S+')
        :exe $'normal! {reg}p'
    })
enddef

##

export def Disable()
    for c in ['VSFind', 'VSGrep', 'VSExec', 'VSExecEx', 'VSBuffer', 'VSMru', 'VSKeymap', 'VSMark', 'VSRegister']
        if exists($":{c}") == 2
            :exec $'delcommand {c}'
        endif
    endfor
enddef

:defcompile  # Debug: See note above.

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
