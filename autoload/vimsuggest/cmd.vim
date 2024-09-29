vim9script

# Autocomplete Vimscript commands, functions, variables, help, filenames, buffers, etc.

import autoload './options.vim' as opt
import autoload './popup.vim'
import autoload './extras/vsbuffer.vim'
import autoload './extras/vsfind.vim'

var options = opt.options.cmd

class Properties
    var pmenu: popup.PopupMenu = null_object
    var abbreviations: list<any>
    var save_wildmenu: bool
    public var items: list<any>
    var setup_hook = {}  # 'cmd' -> Callback()
    var setup_hook_done = {}  # 'cmd' -> bool
    var highlight_hook = {}
    var onspace_hook = {}
    var teardown_hook = {}
    var post_select_hook = {}

    def new()
        this.abbreviations = this.GetAbbrevs()
        this.save_wildmenu = &wildmenu
        :set nowildmenu
        foreach(this.setup_hook->keys(), 'this.setup_hook_done[v:val] = false')
        this.pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs, options.pum)
    enddef

    def Clear()
        var cmdname = CmdStr()->matchstr('^\S\+')
        if this.teardown_hook->has_key(cmdname)
            this.teardown_hook[cmdname](this.pmenu.SelectedItem())
        endif
        if this.save_wildmenu
            :set wildmenu
        endif
        this.pmenu.Close()
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
endclass

var allprops: dict<Properties> = {}  # one per windid

export def Setup()
    if options.enable
        augroup VimSuggestCmdAutocmds | autocmd!
            autocmd CmdlineEnter    :  {
                allprops[win_getid()] = Properties.new()
                EnableCmdline()
                if options.extras
                    vsbuffer.Setup()
                    vsfind.Setup()
                endif
            }
            autocmd CmdlineChanged  :  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave    :  {
                if allprops->has_key(win_getid())
                    allprops[win_getid()].Clear()
                    remove(allprops, win_getid())
                endif
            }
        augroup END
    endif
enddef

export def Teardown()
    augroup VimSuggestCmdAutocmds | autocmd!
    augroup END
enddef

def EnableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged : options.alwayson ? Complete() : TabComplete()
enddef

def DisableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged :
enddef

def TabComplete()
    var lastcharpos = getcmdpos() - 2
    if getcmdline()[lastcharpos] ==? "\<tab>"
        setcmdline(getcmdline()->slice(0, lastcharpos))
        Complete()
    endif
enddef

def Complete()
    var p = allprops[win_getid()]
    var context = getcmdline()
    if context == '' || context =~ '^\s\+$'
        :redraw  # Needed to hide popup after <bs> and cmdline is empty
                 # popup_hide() already called in FilterFn, redraw to hide the popup
        return
    endif
    timer_start(1, function(DoComplete, [context]))
enddef

def DoComplete(oldcontext: string, timer: number)
    var context = getcmdline()
    if context !=# oldcontext
        # Likely pasted text or coming from a keymap (if {rhs} is, say, 'nohls',
        # then this function gets called for every letter).
        return
    endif
    # Note: If <esc> is mapped to Ex cmd (say 'nohls') in normal mode, then Vim
    # calls DoComplete after CmdlineLeave (because of timer), and props will not
    # be available. Use allprops[win_getid()] only after 'oldcontext' above.
    if !allprops->has_key(win_getid())  # Additional check
        return
    endif
    var p = allprops[win_getid()]
    for pat in options.exclude
        if context =~ pat
            return
        endif
    endfor
    var cmdstr = CmdStr()
    if cmdstr[-1] =~ '\s'
        var prompt = cmdstr->trim()
        if p.abbreviations->index(prompt) != -1 ||
                (options.alwayson && options.onspace->index(prompt) == -1 &&
                !p.onspace_hook->has_key(prompt))
            return
        endif
    endif
    var cmdname = cmdstr->matchstr('^\S\+')
    if p.setup_hook->has_key(cmdname) && !p.setup_hook_done[cmdname]  # call Callback() only once
        p.setup_hook[cmdname]()
        p.setup_hook_done[cmdname] = true
    endif
    var completions: list<any> = []
    if options.wildignore && cmdstr =~# '\(^\|\s\)\(e\%[dit]!\?\|fin\%[d]!\?\)\s'
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
        :redraw  # popup_hide() already called in FilterFn, redraw to hide the popup
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
    var p = allprops[win_getid()]
    var context = getcmdline()
    var cmdname = CmdStr()->matchstr('^\S\+')
    var cmdsuffix = context->matchstr('\S\+$')
    if !options.highlight || context[-1] =~ '\s'
        p.items = [completions]
    elseif p.highlight_hook->has_key(cmdname)
        p.items = p.highlight_hook[cmdname](cmdsuffix, completions)
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
        p.items = success ? [completions, cols, mlens] : [completions]
    endif
    # '&' and '$' completes Vim options and env variables respectively.
    var pos = max([' ', '&', '$']->mapnew((_, v) => context->strridx(v)))
    p.pmenu.SetText(p.items, options.pum ? pos + 2 : 1)
    p.pmenu.Show()
    # Note: If command-line is not disabled here, it will intercept key inputs
    # before the popup does. This prevents the popup from handling certain keys,
    # such as <Tab> properly.
    DisableCmdline()
enddef

def PostSelectItem(index: number)
    var p = allprops[win_getid()]
    var cmdname = CmdStr()->matchstr('^\S\+')
    if !p.post_select_hook->has_key(cmdname) || !p.post_select_hook[cmdname](p.items[0][index])
        var context = getcmdline()
        setcmdline(context->matchstr('^.*\s\ze') .. p.items[0][index])
    endif
    :redraw  # Needed for <tab> selected menu item highlighting to work
enddef

def FilterFn(winid: number, key: string): bool
    var p = allprops[win_getid()]
    # Note: Do not include arrow keys since they are used for history lookup.
    if key == "\<Tab>" || key == "\<C-n>"
        p.pmenu.SelectItem('j', PostSelectItem) # Next item
    elseif key == "\<S-Tab>" || key == "\<C-p>"
        p.pmenu.SelectItem('k', PostSelectItem) # Prev item
    elseif key == "\<C-e>"
        p.pmenu.Hide()
        :redraw
        # XXX make index -1
        EnableCmdline()
    elseif key == "\<CR>" || key == "\<ESC>"
        return false # Let Vim process these keys further
    else
        p.pmenu.Hide()
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
    allprops[win_getid()].setup_hook[cmd] = Callback
enddef

export def AddTeardownHook(cmd: string, Callback: func(string))
    allprops[win_getid()].teardown_hook[cmd] = Callback
enddef

export def AddPostSelectHook(cmd: string, Callback: func(string): bool)
    allprops[win_getid()].post_select_hook[cmd] = Callback
enddef

export def AddHighlightHook(cmd: string, Callback: func(string, list<any>): list<any>)
    allprops[win_getid()].highlight_hook[cmd] = Callback
enddef

export def AddOnspaceHook(cmd: string)
    allprops[win_getid()].onspace_hook[cmd] = 1
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
