vim9script

# This Vim9 script implements command-line auto-completion for the ':' command.
# It uses 'getcompletion()' to gather completion candidates and show them in a
# popup window.

import autoload './popup.vim'
import autoload './utils.vim'
import autoload './keymap.vim' as km

export var options: dict<any> = {
    enable: true,      # Enable/disable the completion functionality
    pum: true,         # 'true' for stacked popup menu, 'false' for flat
    exclude: [],       # List of (regex) patterns to exclude from completion
    onspace: ['colo\%[rscheme]', 'b\%[uffer]', 'sy\%[ntax]'],
                       # Complete after the space after the command
    alwayson: true,    # If 'false', press <tab> to open the popup menu manually
    popupattrs: {},    # Attributes for configuring the popup window
    wildignore: true,  # Exclude wildignore patterns during file completion
    addons: true,      # Enable additional completion addons (like fuzzy file finder)
    trigger: 't',      # 't' for tab/s-tab, 'n' for ctrl-n/p and up/down arrows
    reverse: false,    # Upside-down menu
    auto_first: false, # Automatically select first item from menu if none selected
    prefixlen: 1,      # The minimum prefix length before the completion menu is displayed
    complete_sg: true, # Complete :s// :g//
}

class State
    var pmenu: popup.PopupMenu = null_object
    var saved_wildchar: number
    var saved_ttimeout: bool
    var saved_ttimeoutlen: number
    public var cmdline = null_string # Cached command-line contents
    # Following characters often do not provide meaningful completions.
    const exclude = ['~', '!', '%', '(', ')', '+', '=', '<', '>', '?', ',']
    public var items: list<list<any>> = [[]]
    public var insertion_point: number
    public var exit_key: string = null_string # Key pressed before closing the menu
    public var char_removed: bool
    # Following callbacks are used by addons.
    public static var onspace_hook = {}  # Complete after space anywhere (unlike options.onspace)
    public var highlight_hook = {}
    public var select_item_hook = {}
    public var cmdline_leave_hook = {}
    public static var cmdline_enter_hook = []
    public static var cmdline_abort_hook = []  # Cmdline contents not available when <c-c> aborted
    var saved_tab_keymap = null_dict
    var saved_s_tab_keymap = null_dict

    def new()
        this.saved_ttimeout = &ttimeout  # Needs to be set, otherwise <esc> delays when closing menu 
        this.saved_ttimeoutlen = &ttimeoutlen
        :set ttimeout ttimeoutlen=100
        this.saved_wildchar = &wildchar
        :set wildchar=<C-z>
        this.saved_tab_keymap = maparg('<tab>', 'c', 0, 1) # Save <tab> keymap in case it was mapped
        this.saved_s_tab_keymap = maparg('<s-tab>', 'c', 0, 1)
        this.pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs,
            options.pum, options.reverse)
    enddef

    def Clear()
        :exec $'set wildchar={this.saved_wildchar}'
        if this.saved_ttimeout
            :set ttimeout
            &ttimeoutlen = this.saved_ttimeoutlen
        endif
        if this.saved_tab_keymap != null_dict
            mapset('c', 0, this.saved_tab_keymap)
        endif
        if this.saved_s_tab_keymap != null_dict
            mapset('c', 0, this.saved_s_tab_keymap)
        endif
        this.pmenu.Close()
    enddef
endclass

export var state: State = null_object

export def Setup()
    if options.enable
        augroup VimSuggestCmdAutocmds | autocmd!
            autocmd CmdlineEnter    :  {
                state = State.new()
                if options.alwayson
                    EnableCmdline()
                else
                    MapTabKey()
                endif
                for Hook in State.cmdline_enter_hook
                    Hook()
                endfor
            }
            autocmd CmdlineLeave    :  {
                if state != null_object # <c-s> removes this object
                    CmdlineLeaveHook(state.pmenu.SelectedItem(),
                        state.pmenu.FirstItem(), state.exit_key)
                    DisableCmdline()
                    state.Clear()
                    state = null_object
                endif
            }
        augroup END
        if options.addons
            if exists('#User#VimSuggestCmdSetup')
                doautocmd User VimSuggestCmdSetup
            endif
        endif
    endif
enddef

export def Teardown()
    augroup VimSuggestCmdAutocmds | autocmd!
    augroup END
    if exists('#User#VimSuggestCmdTeardown')
        doautocmd User VimSuggestCmdTeardown
    endif
    UnMapTabKey()
enddef

def EnableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged : Complete()
    if options.alwayson
        if "<C-D>"->mapcheck('c') == null_string
            cnoremap <expr> <C-D> Complete(true)
        endif
    else
        MapTabKey()
    endif
enddef

def DisableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged :
    if options.alwayson
        if "<C-D>"->mapcheck('c') != null_string
            cunmap <C-D>
        endif
    else
        UnMapTabKey()
    endif
enddef

def MapTabKey()
    # Note: Use only <tab> and <C-d> for triggering manually. Using <C-n> or
    # arrows will disable them from doing history recall.
    for k in ["<tab>", "<c-d>"]
        if k->mapcheck('c') == null_string
            exec 'cnoremap <expr>' k 'Complete(true)'
        endif
    endfor
enddef

def UnMapTabKey()
    for k in ["<tab>", "<c-d>"]
        if k->mapcheck('c') != null_string
            exec 'cunmap' k
        endif
    endfor
enddef

def Complete(from_keymap = false): string
    if state.char_removed
        state.char_removed = false
        return null_string
    endif
    var context = Context()
    var skip_completion = false
    var cmdline = getcmdline()
    var lastcharpos = getcmdpos() - 2
    var lastchar = cmdline[lastcharpos]
    if context->strlen() < options.prefixlen || (lastchar ==? "\<tab>" &&
            context->strlen() == options.prefixlen)
        if lastchar ==? "\<tab>"
            setcmdline(cmdline->slice(0, lastcharpos) .. cmdline->slice(lastcharpos + 1))
            context = Context()
        else
            skip_completion = true
        endif
    endif
    if context == null_string || context =~ '^\s\+$' || skip_completion
        HideMenu()  # Needed to hide popup after <bs> and cmdline is empty
        return null_string
    endif
    timer_start(1, function(DoComplete, [context, from_keymap]))
    return null_string
enddef

def HideMenu()
    :redraw # popup_hide() already called in FilterFn, redraw to hide the popup
    state.items = [[]]
enddef

def DoComplete(oldcontext: string, from_keymap: bool, timer: number)
    var context = Context()
    if context !=# oldcontext
        # Likely pasted text or coming from a keymap (if {rhs} is, say, 'nohls',
        # then this function gets called for every letter).
        return
    endif
    # Note: If <esc> is mapped to Ex cmd (say 'nohls') in normal mode, then Vim
    # calls DoComplete (for 'n', 'o', 'h', etc.) after CmdlineLeave (because of
    # timer), and state will not be available. Checking 'oldcontext' catches this.
    if state == null_object  # Additional check
        return
    endif
    state.cmdline = getcmdline()
    var cmdstr = context->CmdStr()
    var cmdlead = CmdLead()
    if !from_keymap
        var excl_list = (options.exclude->type() == v:t_list) ? options.exclude : [options.exclude]
        var excl_pattern_present =
            excl_list->reduce((a, v) => a || (cmdstr->match(v) != -1), false)
        var onspace_list = (options.onspace->type() == v:t_list) ? options.onspace : [options.onspace]
        var onspace_pattern_present =
            onspace_list->reduce((a, v) => a || (cmdlead->match(v) != -1), false)
        if excl_pattern_present ||
                (cmdstr =~ '^\s*\S\+\s\+$' && !onspace_pattern_present &&
                !State.onspace_hook->has_key(cmdlead))
            # Note: Second space in ':VSGrep "foo "' should be completed. Spaces
            # after cursor are not relevant. (Use 'context' instead of getcmdline()).
            HideMenu()
            return
        endif
        var unfiltered = ['h\%[elp]!\?', 'ta\%[g]!\?', 'e\%[dit]!\?', 'fin\%[d]!\?', 'b\%[uffer]!\?',
            'let', 'call', 'VSGrep', 'VSFind', 'VSGitFind']
        if cmdstr !~# $'^\s*\({unfiltered->join("\\|")}\)\s' &&
                state.exclude->index(context[-1]) != -1
            HideMenu()
            return
        endif
    endif

    var completions: list<any> = []
    var insertion_point = -1
    try
        var cmdpat = '\%(e\%[dit]!\?\|fin\%[d]!\?\)'
        if options.wildignore && cmdstr =~# $'^\s*{cmdpat}\s' && cmdstr !~ '\$'
            # 'file_in_path' respects wildignore, 'cmdline' does not.
            # ':VSxxx edit' and ':e $VIM' should not be completed this way.
            completions = cmdstr->matchstr('^\S\+\s\+\zs.*')->getcompletion('file_in_path')
            completions->map((_, v) => fnameescape(v))
            insertion_point = context->match($'.\{{-}}{cmdpat}\s\+\zs.*')
        endif
        if completions->empty()
            completions = context->getcompletion('cmdline')
            if cmdstr =~ '\$' && !completions->empty() && completions[0]->getftype() != ''
                insertion_point = RightmostUnescapedCharIdx(context, '$')
            endif
        endif
    catch # Catch (for ex.) -> E1245: Cannot expand <sfile> in a Vim9 function
    endtry
    if options.complete_sg && completions->len() == 0  # Try completing :s// and :g/
        var compl = utils.GetCompletionSG(context)
        completions = compl.compl
        insertion_point = compl.ip
        if completions->len() > 0 && &hlsearch && &incsearch
            # Restore 'hls' and 'incsearch' hightlight (removed when popup_show() redraws).
            var cmdline = getcmdline()
            var numchars = context->strcharlen()
            setcmdline(cmdline->strcharpart(0, numchars - 1) .. cmdline->strcharpart(numchars))
            var lastchar = context->strcharpart(numchars - 1)
            var cursorpos = context->len() - lastchar->len()
            if getcmdpos() != cursorpos + 1
                feedkeys("\<home>", 'n')
                var cursorcharpos = numchars - 1
                for _ in range(cursorcharpos)
                    feedkeys("\<right>", 'n')
                endfor
            endif
            state.char_removed = true
            feedkeys(lastchar, 'n')
        endif
    endif
    if insertion_point == -1 && !completions->empty()
        var needles = cmdstr->tolower()->split('\zs')
        var haystack = completions[0]->tolower()
        if needles->filter((_, v) => haystack->stridx(v) >= 0)->empty()
            # If auto_first is set, then :10 will not jump to line 10 since first
            # item is something else. In cases where first item does not even match
            # any character in command-line, do not show menu.
            completions = []
        endif
    endif
    if completions->len() == 0 || (completions->len() == 1 && context->strridx(completions[0]) != -1)
        # No completions found, or this completion is already inserted.
        HideMenu()
        return
    endif
    SetPopupMenu(completions, insertion_point)
enddef

export def SetPopupMenu(items: list<any>, insertion_point = -1)
    var context = Context()  # Popup should be next to cursor
    var cmdname = CmdLead()
    var arglead = context->matchstr('\S\+$')
    if state.highlight_hook->has_key(cmdname)
        state.items = state.highlight_hook[cmdname](arglead, items)
    else
        state.items = [items]
        if state.items[0]->len() > 0
            DoHighlight($'\c{arglead}')
        endif
    endif
    state.insertion_point = insertion_point
    if insertion_point == -1 && state.items[0]->len() > 0
        state.insertion_point = InsertionPoint(state.items[0][0])
    endif
    var pos = state.insertion_point + 1
    state.pmenu.SetText(state.items, options.pum ? pos : 1)
    if state.items[0]->len() > 0
        state.pmenu.Show()
        # Note: If command-line is not disabled here, it will intercept key inputs
        # before the popup does. This prevents the popup from handling certain keys,
        # such as <Tab> properly.
        DisableCmdline()
    endif
enddef

def RightmostUnescapedCharIdx(str: string, char: string): number
    for n in range(str->len() - 1, 0, -1)
        if str[n] ==# char && (n == 0 || str[n - 1] !=# '\\')
            return n
        endif
    endfor
    return -1
enddef

# When ':range' is present, insertion of completion text should happen at the
# end of range. Similary, :s// and :g//.
def InsertionPoint(replacement: string): number
    var context = Context()
    # '&' and '$' completes Vim options and env variables respectively.
    var pos = max([' ', '&', '$']->mapnew((_, v) => RightmostUnescapedCharIdx(context, v))) + 1
    if pos == context->len() || &wildoptions =~# 'fuzzy'
        return pos
    endif
    var word = context->strpart(pos)
    var wordlen = word->len()
    for i in range(wordlen)
        if word->strpart(i) ==? replacement->strpart(0, wordlen - i)
            return i + pos
        endif
    endfor
    return pos
enddef

export def SelectItemPost(index: number, dir: string)
    var cmdname = CmdLead()
    if !state.select_item_hook->has_key(cmdname) ||
            !state.select_item_hook[cmdname](state.items[0][index], dir)
        var replacement = state.items[0][index]
        var cmdline = getcmdline()
        setcmdline(cmdline->strpart(0, state.insertion_point) ..
            replacement .. cmdline->strpart(getcmdpos() - 1))
        var newpos = state.insertion_point + replacement->len()
        # Note: setcmdpos() does not work here, vim puts cursor at the end.
        # workaround:
        var newcharpos = state.insertion_point + replacement->strcharlen()
        if getcmdpos() != newpos + 1
            for _ in range(newcharpos)
                feedkeys("\<right>", 'in')
            endfor
            feedkeys("\<home>", 'in')
        endif
    endif
    if !state.highlight_hook->has_key(cmdname)
        # Since cmdline has selected item, match highlight has no meaning.
        win_execute(state.pmenu.Winid(), "syn clear VimSuggestMatch")
    endif
enddef

def FilterFn(winid: number, key: string): bool
    # <C-n> sends :h t_kb (down arrow) and <C-p> sends t_ku (up arrow)
    if utils.TriggerKeys(options.trigger, options.reverse)->index(key) != -1
        state.pmenu.SelectItem('j', SelectItemPost) # Next item
    elseif utils.TriggerKeys(options.trigger, options.reverse, false)->index(key) != -1
        state.pmenu.SelectItem('k', SelectItemPost) # Prev item
    elseif km.Equal(key, 'page_up')
        var cmdname = CmdLead()
        if state.select_item_hook->has_key(cmdname)  # stop async job, if any
            state.select_item_hook[cmdname](null_string, null_string)
        endif
        state.pmenu.PageUp()
    elseif km.Equal(key, 'page_down')
        var cmdname = CmdLead()
        if state.select_item_hook->has_key(cmdname)  # stop async job, if any
            state.select_item_hook[cmdname](null_string, null_string)
        endif
        state.pmenu.PageDown()
    elseif km.Equal(key, 'dismiss') # Dismiss auto-completion
        state.pmenu.Hide()
        :redraw
        state.Clear()
        CmdlineAbortHook()
        state = null_object
    elseif km.Equal(key, 'hide') # Dismiss popup but keep auto-completion state
        state.pmenu.Hide()
        setcmdline(state.cmdline)
        :redraw
        EnableCmdline()
    elseif km.Equal(key, 'send_to_qflist') # Add to quickfix list
        SendToQickfixList()
        state.pmenu.Close(-1)
    elseif km.Equal(key, 'send_to_arglist') # Add to arglist
        execute($'argadd {state.items[0]->join(" ")}')
        state.pmenu.Close(-1)
    elseif km.Equal(key, 'send_to_clipboard') # Add to system clipboard ("+ register)
        setreg('+', state.items[0]->join("\n"))
        state.pmenu.Close(-1)
    elseif km.Equal(key, 'split_open') || km.Equal(key, 'vsplit_open') ||
            km.Equal(key, 'tab_open')
        state.exit_key = key
        feedkeys("\<cr>", 'n')
    elseif key == "\<CR>"
        if options.auto_first && state.cmdline_leave_hook == null_dict &&
                getcmdline()->len() + 1 == getcmdpos() &&
                state.pmenu.SelectedItem() == null_string &&
                state.pmenu.FirstItem() != null_string
            state.pmenu.SelectItem('j', SelectItemPost) # Select first item
            feedkeys("\<CR>", 'in')
            return true
        endif
        # Note: When <cr> simply opens the message window (ex :filt Menu hi), popup
        # lingers unless it is explicitly hidden.
        state.pmenu.Hide()
        :redraw
        return false # Let Vim process these keys further
    elseif key == "\<ESC>" || key == "\<C-[>"
        CmdlineAbortHook()
        return false
    elseif key == "\<C-d>"
    elseif utils.CursorMovementKey(key)
        return false
    else
        if state.char_removed
            state.char_removed = false
            return false
        endif
        state.pmenu.Hide()
        # Note: Redrawing after Hide() causes the popup to disappear after
        # <left>/<right> arrow keys are pressed. Arrow key events are not
        # captured by this function. Calling Hide() without triggering a redraw
        # ensures that EnableCmdline works properly, allowing the command line
        # to handle the keys first, and decide if popup needs to be updated.
        # This approach is safer as it avoids the need to manage various
        # control characters and the up/down arrow keys used for history recall.
        EnableCmdline()
        return false # Let Vim process this further
    endif
    return true
enddef

def CallbackFn(winid: number, result: any)
    if result == -1 # Popup force closed due to <c-c> or cursor mvmt
        CmdlineAbortHook()
        state.Clear()
        state = null_object
        feedkeys("\<c-c>", 'n')
    endif
enddef

def SendToQickfixList()
    var title = CmdLead()
    var what: dict<any>
    if state.items[0][0]->filereadable()  # Assume grep output
        var itms = state.items[0]->mapnew((_, v) => {
            return {filename: v, valid: 1}
        })
        what = {nr: '$', title: title, items: itms}
    else
        var test = getqflist({lines: [state.items[0][0]]})
        if test.items[0].valid
            what = {nr: '$', title: title, lines: state.items[0]}
        else
            echom 'Invalid quickfix list format'
            return
        endif
    endif
    setqflist([], ' ', what)
    if exists($'#QuickFixCmdPost#clist')
        timer_start(0, (_) => {
            :execute $'doautocmd <nomodeline> QuickFixCmdPost clist'
        })
    endif
enddef

export def DoHighlight(pattern: string, group = 'VimSuggestMatch')
    win_execute(state.pmenu.Winid(), $"syn clear {group}")
    if pattern != null_string
        try
            win_execute(state.pmenu.Winid(), $'syn match {group} ''{pattern}''')
        catch # ignore any rogue exceptions.
        endtry
    endif
enddef

def Context(): string
    return getcmdline()->strpart(0, getcmdpos() - 1)
enddef

export def CmdStr(s: string = null_string): string
    return (s ?? getcmdline())->substitute('^\s*vim9\%[cmd]!\?\s*', '', '')
enddef

export def CmdLead(): string
    return CmdStr()->matchstr('^\s*\zs\S\+\ze\s')
enddef

def CmdlineLeaveHook(selected_item: string, first_item: string, key: string)
    var cmdname = CmdLead()
    if state.cmdline_leave_hook->has_key(cmdname)
        state.cmdline_leave_hook[cmdname](selected_item, first_item, key)
    endif
enddef

def CmdlineAbortHook()
    for Hook in State.cmdline_abort_hook
        Hook()
    endfor
enddef

export def AddOnSpaceHook(cmd: string)
    State.onspace_hook[cmd] = 1
enddef

export def AddCmdlineLeaveHook(cmd: string, Callback: func(string, string, string))
    state.cmdline_leave_hook[cmd] = Callback
enddef

export def AddCmdlineEnterHook(Callback: func())
    State.cmdline_enter_hook->add(Callback)
enddef

export def AddCmdlineAbortHook(Callback: func())
    State.cmdline_abort_hook->add(Callback)
enddef

export def AddSelectItemHook(cmd: string, Callback: func(string, string): bool)
    state.select_item_hook[cmd] = Callback
enddef

export def AddHighlightHook(cmd: string, Callback: func(string, list<any>): list<any>)
    state.highlight_hook[cmd] = Callback
enddef

export def ValidState(): bool
    return state != null_object
enddef

export def PrintHooks()
    echom State.onspace_hook
    echom State.cmdline_enter_hook
    echom State.cmdline_abort_hook
    echom state.cmdline_leave_hook
    echom state.select_item_hook
    echom state.highlight_hook
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
