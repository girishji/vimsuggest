vim9script

# Autocomplete Vimscript commands, functions, variables, help, filenames, buffers, etc.

import autoload './options.vim' as opt
import autoload './popup.vim'
import autoload './extras/vsbuffer.vim'
import autoload './extras/vscmd.vim'

export var pmenu: popup.PopupMenu = null_object
var options = opt.options.cmd
var abbreviations: list<any>
var save_wildmenu: bool
var autoexclude = ["'>", '^\a/', '^\A'] # Keywords excluded from completion
var items: list<any>
var setup_hook = {}  # 'cmd' -> Callback()
var setup_hook_done = {}  # 'cmd' -> bool
var highlight_hook = {}
var onspace_hook = {}

export def Setup()
    if options.enable
        augroup VimSuggestCmdAutocmds | autocmd!
            autocmd CmdlineEnter    :  {
                pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs, options.pum)
                EnableCmdline()
                abbreviations = GetAbbrevs()
                save_wildmenu = &wildmenu
                :set nowildmenu
                foreach(setup_hook->keys(), 'setup_hook_done[v:val] = false')
            }
            autocmd CmdlineChanged  :  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave    :  {
                if pmenu != null_object
                    pmenu.Close()
                    pmenu = null_object
                endif
                if save_wildmenu
                    :set wildmenu
                endif
            }
        augroup END
        if options.extras
            vsbuffer.Setup()
            vscmd.Setup()
        endif
    endif
enddef

export def Teardown()
    augroup VimSuggestCmdAutocmds | autocmd!
    augroup END
    setup_hook = {}
    highlight_hook = {}
    onspace_hook = {}
enddef

def EnableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged : options.alwayson ? Complete() : TabComplete()
enddef

def DisableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged :
enddef

def GetAbbrevs(): list<any>
    var lines = execute('ca', 'silent!')
    if lines =~? gettext('No abbreviation found')
        return []
    endif
    var abb = []
    for line in lines->split("\n")
        abb->add(line->matchstr('\v^c\s+\zs\S+\ze'))
    endfor
    return abb
enddef

def TabComplete()
    var lastcharpos = getcmdpos() - 2
    if getcmdline()[lastcharpos] ==? "\<tab>"
        setcmdline(getcmdline()->slice(0, lastcharpos))
        Complete()
    endif
enddef

def Complete()
    var context = getcmdline()
    if context == '' || context =~ '^\s\+$'
        pmenu.Hide()
        :redraw
        return
    endif
    timer_start(1, function(DoComplete, [context]))
enddef

def DoComplete(oldcontext: string, timer: number)
    var context = getcmdline()
    if context !=# oldcontext
        # Likely pasted text or coming from keymap.
        return
    endif
    for pat in (options.exclude + autoexclude)
        if context =~ pat
            return
        endif
    endfor
    var cmdstr = CmdStr()
    if cmdstr[-1] =~ '\s'
        var prompt = cmdstr->trim()
        if abbreviations->index(prompt) != -1 ||
                (options.alwayson && options.onspace->index(prompt) == -1 &&
                !onspace_hook->has_key(prompt))
            return
        endif
    endif
    var cmdname = cmdstr->matchstr('^\S\+')
    if setup_hook->has_key(cmdname) && !setup_hook_done[cmdname]  # call Callback() only once
        setup_hook[cmdname]()
        setup_hook_done[cmdname] = true
    endif
    var completions: list<any> = []
    if options.wildignore && cmdstr =~# '^\(e\%[dit]!\?\|fin\%[d]!\?\)\s'
        # 'file_in_path' respects wildignore, 'cmdline' does not. However, it is
        # slower than wildmenu <tab> completion.
        completions = cmdstr->matchstr('^\S\+\s\+\zs.*')->getcompletion('file_in_path')
    else
        completions = context->getcompletion('cmdline')
    endif
    if completions->len() == 0
        return
    endif
    if completions->len() == 1 && context->strridx(completions[0]) != -1
        # This completion is already inserted
        return
    endif
    SetPopupMenu(completions)
enddef

def CmdStr(): string
    return getcmdline()->substitute('\(^\|\s\)vim9\%[cmd]!\?\s*', '', '')
enddef

export def SetPopupMenu(completions: list<any>)
    if completions->empty()
        return
    endif
    var context = getcmdline()
    var cmdname = CmdStr()->matchstr('^\S\+')
    var cmdsuffix = context->matchstr('\S\+$')
    if !options.highlight || context[-1] =~ '\s'
        items = [completions]
    elseif highlight_hook->has_key(cmdname)
        items = highlight_hook[cmdname](cmdsuffix, completions)
    else  # Add properties for syntax highlighting
        var success = true
        var cols = []
        var mlens = []
        var mlen = cmdsuffix->len()
        for text in completions
            var cnum = text->stridx(cmdsuffix)
            if cnum == -1
                success = false
                break
            endif
            cols->add([cnum])
            mlens->add(mlen)
        endfor
        items = success ? [completions, cols, mlens] : [completions]
    endif
    # '&' and '$' completes Vim options and env variables respectively.
    var pos = max([' ', '&', '$']->mapnew((_, v) => context->strridx(v)))
    pmenu.SetText(items, options.pum ? pos + 2 : 1)
    pmenu.Show()
    # Note: If command-line is not disabled here, it will intercept key inputs
    # before the popup does. This prevents the popup from handling certain keys,
    # such as <Tab> properly.
    DisableCmdline()
enddef

def PostSelectItem(index: number)
    var context = getcmdline()
    setcmdline(context->matchstr('^.*\s\ze') .. items[0][index])
    :redraw  # Needed for <tab> selected menu item highlighting to work
enddef

def FilterFn(winid: number, key: string): bool
    # Note: Do not include arrow keys since they are used for history lookup.
    if key == "\<Tab>" || key == "\<C-n>"
        pmenu.SelectItem('j', PostSelectItem) # Next item
    elseif key == "\<S-Tab>" || key == "\<C-p>"
        pmenu.SelectItem('k', PostSelectItem) # Prev item
    elseif key == "\<C-e>"
        pmenu.Hide()
        :redraw
        EnableCmdline()
    elseif key == "\<CR>" || key == "\<ESC>"
        return false # Let Vim process these keys further
    else
        pmenu.Hide()
        # Note: Redrawing after Hide() causes the popup to disappear after
        # <left>/<right> arrow keys are pressed. Arrow key events are not
        # captured by this function. Calling Hide() without triggering a redraw
        # ensures that EnableCmdline works properly, allowing the command line
        # to handle the keys first, and decide it popup needs to be updated.
        # This approach is safer as it avoids the need to manage various
        # control characters and the up/down arrow keys used for history recall.
        EnableCmdline()
        return false # Let Vim handle process this and handle search highlighting
    endif
    return true
enddef

def CallbackFn(winid: number, result: any)
    if result == -1 # Popup force closed due to <c-c> or cursor mvmt
        feedkeys("\<c-c>", 'n')
    endif
enddef

export def AddSetupHook(cmd: string, Callback: func())
    setup_hook[cmd] = Callback
enddef

export def AddHighlightHook(cmd: string, Callback: func(string, list<any>): list<any>)
    highlight_hook[cmd] = Callback
enddef

export def AddOnspaceHook(cmd: string)
    onspace_hook[cmd] = 1
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4
