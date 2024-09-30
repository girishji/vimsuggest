vim9script

# Autocomplete Vimscript commands, functions, variables, help, filenames, buffers, etc.

import autoload './options.vim' as opt
import autoload './popup.vim'
# import autoload './extras/vsbuffer.vim'
import autoload './extras/extras.vim'

var options = opt.options.cmd

class Properties
    var pmenu: popup.PopupMenu = null_object
    var abbreviations: list<any>
    var save_wildmenu: bool
    public var items: list<any>
    # Following callbacks are for customizing commands.
    var highlight_hook = {}
    var onspace_hook = []
    var cmdline_leave_hook = {}
    var select_item_hook = {}

    def new()
        this.abbreviations = this.GetAbbrevs()
        this.save_wildmenu = &wildmenu
        :set nowildmenu
        this.pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs, options.pum)
    enddef

    def Clear()
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

var allprops: dict<Properties> = {}  # One per winid

export def Setup()
    if options.enable
        augroup VimSuggestCmdAutocmds | autocmd!
            autocmd CmdlineEnter    :  {
                allprops[win_getid()] = Properties.new()
                EnableCmdline()
                if options.extras
                    extras.Setup()
                    # vsbuffer.Setup()
                    # vsfind.Setup()
                endif
            }
            autocmd CmdlineChanged  :  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave    :  {
                if allprops->has_key(win_getid())
                    var p = allprops[win_getid()]
                    CmdlineLeaveHook(p.pmenu.SelectedItem(), p.pmenu.FirstItem())
                    allprops[win_getid()].Clear()
                    remove(allprops, win_getid())
                else # During <c-e>
                    CmdlineLeaveHook(null_string, null_string)
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
    var context = Context()
    if context == '' || context =~ '^\s\+$'
        :redraw  # Needed to hide popup after <bs> and cmdline is empty
                 # popup_hide() already called in FilterFn, redraw to hide the popup
        return
    endif
    timer_start(1, function(DoComplete, [context]))
enddef

def DoComplete(oldcontext: string, timer: number)
    var context = Context()
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
                p.onspace_hook->index(prompt) == -1)
            return
        endif
    endif
    var cmdname = cmdstr->matchstr('^\S\+')
    var completions: list<any> = []
    if options.wildignore && cmdstr =~# '\(^\|\s\)\(e\%[dit]!\?\|fin\%[d]!\?\)\s'
        # 'file_in_path' respects wildignore, 'cmdline' does not.
        completions = cmdstr->matchstr('^\S\+\s\+\zs.*')->getcompletion('file_in_path')
    else
        completions = context->getcompletion('cmdline')
    endif
    if completions->len() == 0 || (completions->len() == 1 && context->strridx(completions[0]) != -1)
        # No completions found, or this completion is already inserted.
        :redraw  # popup_hide() already called in FilterFn, redraw to hide the popup
        return
    endif
    SetPopupMenu(completions)
enddef

export def SetPopupMenu(items: list<any>)
    var p = allprops[win_getid()]
    var context = getcmdline()
    var cmdname = CmdStr()->matchstr('^\S\+')
    var cmdsuffix = context->matchstr('\S\+$')
    if !options.highlight || context[-1] =~ '\s'
        p.items = [items]
    elseif p.highlight_hook->has_key(cmdname)
        p.items = p.highlight_hook[cmdname](cmdsuffix, items)
    else  # Add properties for syntax highlighting
        var cols = []
        var mlens = []
        for text in items
            var [_, st, en] = text->matchstrpos(cmdsuffix)
            if st == -1
                break
            endif
            cols->add([st])
            mlens->add(en - st)
        endfor
        p.items = items->len() == cols->len() ? [items, cols, mlens] : [items]
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

def SelectItemPost(index: number)
    var p = allprops[win_getid()]
    var cmdname = CmdStr()->matchstr('^\S\+')
    if !p.select_item_hook->has_key(cmdname) || !p.select_item_hook[cmdname](p.items[0][index])
        var context = Context()
        setcmdline(context->matchstr('^.*\s\ze') .. p.items[0][index])
    endif
enddef

def FilterFn(winid: number, key: string): bool
    var p = allprops[win_getid()]
    # Note: Do not include arrow keys since they are used for history lookup.
    if key ==? "\<Tab>" || key ==? "\<C-n>"
        p.pmenu.SelectItem('j', SelectItemPost) # Next item
    elseif key ==? "\<S-Tab>" || key ==? "\<C-p>"
        p.pmenu.SelectItem('k', SelectItemPost) # Prev item
    elseif key ==? "\<PageUp>"
        p.pmenu.PageUp()
    elseif key ==? "\<PageDown>"
        p.pmenu.PageDown()
    elseif key ==? "\<C-e>" || key ==? "\<End>" # Vim bug: <C-e> sends <End>(<80>@7, :h t_@7)) due to timer_start.
        p.pmenu.Hide()
        :redraw
        p.Clear()
        remove(allprops, win_getid())
    elseif key ==? "\<CR>"
        return false # Let Vim process these keys further
    elseif key ==? "\<ESC>"
        CmdlineLeaveHook(null_string, null_string)
        return false
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
        CmdlineLeaveHook(null_string, null_string)
        allprops[win_getid()].Clear()
        remove(allprops, win_getid())
        feedkeys("\<c-c>", 'n')
    endif
enddef

def Context(): string
    return getcmdline()->strpart(0, getcmdpos() - 1)
enddef

def CmdStr(): string
    return getcmdline()->substitute('\(^\|\s\)vim9\%[cmd]!\?\s*', '', '')
enddef

def CmdlineLeaveHook(selected_item: string, first_item: string)
    var cmdname = CmdStr()->matchstr('^\S\+')
    var p = allprops[win_getid()]
    if p.cmdline_leave_hook->has_key(cmdname)
        p.cmdline_leave_hook[cmdname](selected_item, first_item)
    endif
enddef

export def AddCmdlineLeaveHook(cmd: string, Callback: func(string, string))
    allprops[win_getid()].cmdline_leave_hook[cmd] = Callback
enddef

export def AddSelectItemHook(cmd: string, Callback: func(string): bool)
    allprops[win_getid()].select_item_hook[cmd] = Callback
enddef

export def AddHighlightHook(cmd: string, Callback: func(string, list<any>): list<any>)
    allprops[win_getid()].highlight_hook[cmd] = Callback
enddef

export def AddOnspaceHook(cmd: string)
    allprops[win_getid()].onspace_hook->add(cmd)
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
