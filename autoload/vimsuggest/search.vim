vim9script

# This Vim9 script implements an search suggestion system for Vim's
# command-line. It provides fuzzy matching, asynchronous searching, and a
# customizable popup menu for search results. The script includes functions
# for incsearch highlighting, multi-line searching, and various utility
# functions to enhance the search experience in Vim.

import autoload './popup.vim'
import autoload './utils.vim'
import autoload './keymap.vim' as km

# Configuration options
export var options: dict<any> = {
    enable: true,         # Enable/disable the feature globally
    pum: true,            # 'false' for flat, 'true' for vertically stacked popup menu
    fuzzy: false,         # Enable/disable fuzzy completion
    alwayson: true,       # Open popup menu on <tab> if 'false'
    popupattrs: {         # Attributes passed to the popup window
        maxheight: 12,    # Maximum height for the stacked menu (when pum=true)
    },
    range: 100,           # Number of lines to search in each batch
    timeout: 200,         # Timeout for non-async searches (milliseconds)
    async: true,          # Use async for searching
    async_timeout: 3000,  # Async timeout in milliseconds
    async_minlines: 1000, # Minimum lines to enable async search
    highlight: true,      # Disable menu highlighting (for performance)
    trigger: 't',         # 't' for tab/s-tab, 'n' for ctrl-n/p and up/down arrows
    reverse: false,       # Upside-down menu
    prefixlen: 1,         # The minimum prefix length before the completion menu is displayed
}

# Represents the state of the current search
class State
    public var items = []            # Items to be displayed in the popup menu
    public var candidates = []       # Completion candidates (saved for async invocation)
    public var context = null_string # Cached command-line contents
    public static var saved_searchreg = null_string
    var saved_esc_keymap = null_dict
    var saved_ttimeout: bool
    var saved_ttimeoutlen: number
    var pmenu: popup.PopupMenu = null_object
    var async: bool
    var curpos: list<any>

    def new()
        this.pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs,
            options.pum, options.reverse)
        this.async = line('$') < options.async_minlines ? false : options.async
        if this.async
            this.curpos = getcurpos()
        endif
        if this.async && v:hlsearch
            State.saved_searchreg = getreg('/')
            this.saved_esc_keymap = maparg('<esc>', 'c', 0, 1) # Save <esc> keymap in case it was mapped
        endif
        this.saved_ttimeout = &ttimeout  # Needs to be set, otherwise <esc> delays when closing menu 
        this.saved_ttimeoutlen = &ttimeoutlen
        :set ttimeout ttimeoutlen=100
    enddef

    def Setup()
        if this.async && v:hlsearch
            # RestoreHLSearch requires that this object is already created by new()
            cnoremap <esc> <c-r>=<SID>RestoreHLSearch()<cr><c-c>
        endif
    enddef

    def Clear()
        this.pmenu.Close()
        if this.saved_esc_keymap != null_dict
            mapset('c', 0, this.saved_esc_keymap)
        endif
        IncSearchHighlightClear()
        if this.saved_ttimeout
            :set ttimeout
            &ttimeoutlen = this.saved_ttimeoutlen
        endif
    enddef
endclass

var state: State = null_object

# During async search, <esc> after a failed search (where pattern does not exist
# in buffer) should restore previous hlsearch if any.
def RestoreHLSearch(): string
    if state != null_object && state.pmenu.Hidden() && State.saved_searchreg != null_string
        setreg('/', State.saved_searchreg)
        State.saved_searchreg = null_string
    elseif State.saved_searchreg != null_string # After <c-s>, state is null_object
        setreg('/', State.saved_searchreg)
        State.saved_searchreg = null_string
    endif
    return null_string
enddef

export def Setup()
    if options.enable
        augroup VimSuggestSearchAutocmds | autocmd!
            autocmd CmdlineEnter /,\?  {
                state = State.new()
                state.Setup()
                EnableCmdline()
            }
            autocmd CmdlineChanged /,\?  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave   /,\?  {
                if state != null_object
                    state.Clear()
                    state = null_object
                endif
            }
        augroup END
    endif
enddef

export def Teardown()
    augroup VimSuggestSearchAutocmds | autocmd!
    augroup END
enddef

def EnableCmdline()
    autocmd! VimSuggestSearchAutocmds CmdlineChanged /,\? options.alwayson ? Complete() : TabComplete()
enddef

def DisableCmdline()
    autocmd! VimSuggestSearchAutocmds CmdlineChanged /,\?
enddef

def TabComplete()
    var lastcharpos = getcmdpos() - 2
    var cmdline = getcmdline()
    var lastchar = cmdline[lastcharpos]
    if lastchar ==? "\<tab>" || lastchar ==? "\<C-d>"
        setcmdline(cmdline->slice(0, lastcharpos) .. cmdline->slice(lastcharpos + 1))
        # Note: setcmdpos() does not work here, since it puts cursor at the beginning.
        # XXX: Comment out the following. Causes E1360 intermittently. Side
        # effect is that if '/a<cursor>a' then <tab> will cause cursor to jump
        # to the end and it tries to complete 'aa' instead of 'a'.
        # if getcmdpos() != lastcharpos + 1
        #     foreach(range(lastcharpos), (_, _) => feedkeys("\<right>", 'in'))
        #     feedkeys("\<home>", 'in')
        #     timer_start(1, (_) => Complete())
        # else
            Complete()
        # endif
    else
        :redraw
    endif
enddef

def Complete()
    var context = Context()
    if context == '' || context =~ '^\s\+$' || strlen(context) < options.prefixlen
        :redraw
        return
    endif
    # Note:
    # 1) When pasting text from clipboard, CompleteChanged event is called
    #    only once instead of for every character pasted.
    # 2) When pasting a long line of text, search appears to be slow for the first time
    #    (likely because functions are getting compiled). it will be fast afterwards.
    state.context = context
    state.candidates = []
    state.items = []
    const withspace = state.context =~ '[^\\]\+\\n\|^\\n' # Pattern contains spaces, resort to searchpos().
    const MatchFn = withspace ? BufMatchMultiLine : BufMatchLine
    if state.context =~# '^\\%' # \%V to search visual region only, etc.
        state.items = BufMatchMultiLine()->MakeUnique()->Itemify()
    elseif options.fuzzy
        state.items = BufFuzzyMatches()
    elseif !state.async
        state.items = MatchFn()->MakeUnique()->Itemify()
    else  # async
        var attr = {
            starttime: reltime(),
            context: context,
            batches: Batches(),
            index: 0,
        }
        if &incsearch
            attr->extend({firstmatch: GetFirstMatch()})
        endif
        # If hlsearch highlighting from a previous search is present, temporarily remove it.
        # Otherwise, highlights from both the current and previous searches will be displayed simultaneously.
        if v:hlsearch
            setreg('/', '')
        endif
        SearchWorker(attr, MatchFn)
        return
    endif
    if state.items[0]->len() > 0
        ShowPopupMenu()
    else
        :redraw  # To hide the popup menu
    endif
enddef

def ShowPopupMenu()
    state.pmenu.SetText(state.items)
    state.pmenu.Show()
    :redraw  # Menu will not show otherwise, during noincsearch.
    # Note: If command-line is not disabled here, it will intercept key inputs
    # before the popup does. This prevents the popup from handling certain keys,
    # such as <Tab> properly.
    DisableCmdline()
enddef

def SelectItemPost(index: number, dir: string)
    var replacement = state.items[0][index]->escape('~/')
    var cmdline = getcmdline()
    setcmdline(replacement .. cmdline->slice(getcmdpos() - 1))
    var newpos = replacement->len()
    # XXX: setcmdpos() does not work here, vim put cursor at the end.
    if getcmdpos() != newpos + 1
        feedkeys("\<home>", 'n')
        for _ in range(newpos)
            feedkeys("\<right>", 'n')
        endfor
    endif
enddef

def FilterFn(winid: number, key: string): bool
    if utils.TriggerKeys(options.trigger, options.reverse)->index(key) != -1
        state.pmenu.SelectItem('j', SelectItemPost) # Next item
    elseif utils.TriggerKeys(options.trigger, options.reverse, false)->index(key) != -1
        state.pmenu.SelectItem('k', SelectItemPost) # Prev item
    elseif km.Equal(key, 'page_up')
        state.pmenu.PageUp()
    elseif km.Equal(key, 'page_down')
        state.pmenu.PageDown()
    elseif km.Equal(key, 'dismiss')
        IncSearchHighlightClear()
        setcmdline('')
        feedkeys(state.context, 'n')
        if State.saved_searchreg != null_string
            setreg('/', State.saved_searchreg) # Needed by <c-s><esc> to restore previous hlsearch
        endif
        # Remove the popup menu and resign from autocompletion.
        state.Clear()
        state = null_object
    elseif km.Equal(key, 'hide')
        IncSearchHighlightClear()
        state.pmenu.Hide()
        setcmdline('')
        feedkeys(state.context, 'n')
        if State.saved_searchreg != null_string
            setreg('/', State.saved_searchreg) # Restore previous hlsearch
        endif
        timer_start(1, (_) => EnableCmdline())
    elseif key == "\<CR>"
        IncSearchHighlightClear()
        return false
    elseif key == "\<ESC>" || key == "\<C-[>"
        IncSearchHighlightClear()
        if State.saved_searchreg != null_string
            setreg('/', State.saved_searchreg) # Restore previous hlsearch
        endif
        return false  # 'false' causes search to be abandoned, and trigger CmdlineLeave
    elseif utils.CursorMovementKey(key)
        return false
    else
        IncSearchHighlightClear()
        state.pmenu.Hide()
        # Note: Enable command-line handling to process key inputs first.
        # This approach is safer as it avoids the need to manage various
        # control characters and the up/down arrow keys used for history recall.
        EnableCmdline()
        return false # Let vim's usual mechanism (ex. search highlighting) handle this
    endif
    return true
enddef

def CallbackFn(winid: number, result: any)
    IncSearchHighlightClear()
    if result == -1 # Popup force closed due to <c-c> or cursor mvmt
        feedkeys("\<c-c>", 'n')
        if State.saved_searchreg != null_string
            setreg('/', State.saved_searchreg) # Restore previous hlsearch
        endif
    endif
enddef

def MakeUnique(lst: list<any>): list<any>
    var unq = []
    var found = {} # uniq() does not work when list is not sorted, so remove duplicates using a set
    for item in lst
        if !found->has_key(item.text)
            found[item.text] = 1
            unq->add(item)
        endif
    endfor
    return unq
enddef

def Itemify(matches: list<any>): list<any>
    var text = []
    var colnum = []
    var mlen = []
    var items = []
    if !options.highlight || matches->empty()
        items = [matches->mapnew('v:val.text')]
    elseif matches[0]->has_key('submatches')
        for item in matches
            text->add(item.text)
            colnum->add([item.submatches[0]->len()])
            mlen->add(item.submatches[1]->len())
        endfor
        items = [text, colnum, mlen]
    else
        items = [matches->mapnew('v:val.text')]
    endif
    return items
enddef

def GetFirstMatch(): list<any>
    var pos = []
    var saved_cursor = getcurpos()
    setpos('.', state.curpos)
    try
        var [blnum, bcol] = state.context->searchpos(v:searchforward ? 'nw' : 'nwb')
        if [blnum, bcol] != [0, 0]
            var [elnum, ecol] = state.context->searchpos(v:searchforward ? 'nwe' : 'nwbe')
            if [elnum, ecol] != [0, 0]
                if blnum == elnum
                    pos = [[blnum, bcol, ecol - bcol + 1]]
                else
                    pos = [[blnum, bcol, 1000]]
                    for lnum in range(blnum + 1, elnum - 1)
                        pos->add([lnum])
                    endfor
                    pos->add([elnum, 1, ecol])
                endif
            endif
        endif
    catch
        # E33 is thrown when '~' is the first character of search.
        # '~' stands for previously substituted pattern in ':s'.
    endtry
    setpos('.', saved_cursor)
    return pos
enddef

# Return a list containing range of lines to search.
def Batches(): list<any>
    var range = max([10, options.range])
    var ibelow = []
    var iabove = []
    var startl = line('.')
    while startl <= line('$')
        if v:searchforward
            ibelow->add({startl: startl, endl: min([startl + range, line('$')])})
        else
            ibelow->insert({startl: startl, endl: min([startl + range, line('$')])})
        endif
        startl += range
    endwhile
    startl = 1
    while startl <= line('.')
        if v:searchforward
            iabove->add({startl: startl, endl: min([startl + range, line('.')])})
        else
            iabove->insert({startl: startl, endl: min([startl + range, line('.')])})
        endif
        startl += range
    endwhile
    return v:searchforward ? ibelow + iabove : iabove + ibelow
enddef

def BufMatchLine(batch: dict<any> = null_dict): list<any>
    var word = '\%(\w\|[^\x00-\x7F]\)'  # Covers non-ascii mutli-byte chars.
    var pat = (state.context =~ '\(\\s\| \)' ? '\(\)' : $'\({word}*\)') ..
        $'\({state.context}\)\({word}*\)' # \k includes 'foo.' and 'foo,' (not ideal)
    var matches = []
    var timeout = max([10, options.timeout])
    var starttime = reltime()
    var notasync_batches = v:searchforward ?
        [{startl: line('.'), endl: line('$')}, {startl: 1, endl: line('.')}] :
        [{startl: line('.'), endl: 1}, {startl: line('$'), endl: line('.')}]
    var batches = batch == null_dict ? notasync_batches : [batch]
    try
        for b in batches
            var m = bufnr()->matchbufline(pat, b.startl, b.endl, {submatches: true})
            if m->len() > 0 && m[0].submatches[1] =~ '^\s*$' # ignore searches for only space characters
                break
            endif
            if !v:searchforward
                m->reverse()
            endif
            matches->extend(m)
            if (starttime->reltime()->reltimefloat() * 1000) > timeout
                break
            endif
        endfor
    catch # '\' throws E55
        # echom v:exception
    endtry
    return matches
enddef

# Search across line breaks. This is less efficient and likely not very useful.
# Warning: Syntax highlighting inside popup is not supported by this function.
def BufMatchMultiLine(batch: dict<any> = null_dict): list<any>
    var saved_cursor = getcurpos()
    var timeout = max([10, options.timeout])
    var flags = state.async ? (v:searchforward ? '' : 'b') : (v:searchforward ? 'w' : 'wb')
    var word = '\%(\w\|[^\x00-\x7F]\)'
    var pattern = state.context =~ '\s' ? $'{state.context}{word}*' : $'{word}*{state.context}{word}*'
    var [lnum, cnum] = [0, 0]
    var [startl, startc] = [0, 0]
    var dobatch = batch != null_dict
    var stopl = 0
    if dobatch
        var startline = v:searchforward ? max([1, batch.startl - 5]) : min([line('$'), batch.endl + 5])
        cursor(startline, v:searchforward ? 1 : 1000)
        stopl = v:searchforward ? batch.endl : batch.startl
    endif
    try
        if dobatch
            [lnum, cnum] = pattern->searchpos(flags, stopl)
        else
            [lnum, cnum] = pattern->searchpos(flags, 0, timeout)
            [startl, startc] = [lnum, cnum]
        endif
    catch # '*' with magic can throw E871
        # echom v:exception
        setpos('.', saved_cursor)
        return []
    endtry
    var matches = []
    var found = {}
    var starttime = reltime()
    while [lnum, cnum] != [0, 0]
        var [endl, endc] = pattern->searchpos('ceW') # End of matching string
        var lines = getline(lnum, endl)
        if !lines->empty()
            var mstr = '' # Fragment that matches pattern (can be multiline)
            if lines->len() == 1
                mstr = lines[0]->strpart(cnum - 1, endc - cnum + 1)
            else
                var mlist = [lines[0]->strpart(cnum - 1)] + lines[1 : -2] + [lines[-1]->strpart(0, endc)]
                mstr = mlist->join('\n')
            endif
            if !found->has_key(mstr)
                found[mstr] = 1
                matches->add(mstr)
            endif
        endif
        cursor(lnum, cnum) # Restore cursor to beginning of pattern, otherwise '?' does not work
        [lnum, cnum] = dobatch ? pattern->searchpos(flags, stopl) :
            pattern->searchpos(flags, 0, timeout)

        if !dobatch &&
                ([startl, startc] == [lnum, cnum] || (starttime->reltime()->reltimefloat() * 1000) > timeout)
            break
        endif
    endwhile
    setpos('.', saved_cursor)
    return matches->mapnew((_, v) => {
        return {text: v}
    })
enddef

# Return a list of strings that fuzzy match the pattern.
def BufFuzzyMatches(): list<any>
    var found = {}
    var words = []
    var starttime = reltime()
    var batches = []
    const MaxLines = 5000 # On M1 it takes 100ms to process 9k lines
    if line('$') > MaxLines
        var lineend = min([line('.') + MaxLines, line('$')])
        batches->add({start: line('.'), end: lineend})
        var linestart = max([line('.') - MaxLines, 0])
        var remaining = line('.') + MaxLines - line('$')
        if linestart != 0 && remaining > 0
            linestart = max([linestart - remaining, 0])
        endif
        batches->add({start: linestart, end: line('.')})
    else
        batches->add({start: 1, end: line('$')})
    endif
    var timeout = max([10, options.timeout])
    var range = max([10, options.range])
    for batch in batches
        var linenr = batch.start
        for line in getline(batch.start, batch.end)
            for word in line->split('\W\+')
                if !found->has_key(word) && word->len() > 1
                    found[word] = 1
                    words->add(word)
                endif
            endfor
            if timeout > 0 && linenr % range == 0 &&
                    starttime->reltime()->reltimefloat() * 1000 > timeout
                break
            endif
            linenr += 1
        endfor
    endfor
    var matches = words->matchfuzzypos(state.context, { matchseq: 1, limit: 100 }) # Max 100 matches
    matches[2]->map((_, _) => 1)
    matches[1]->map((idx, v) => {
        # Char to byte index (needed by matchaddpos)
        return v->mapnew((_, c) => matches[0][idx]->byteidx(c))
    })
    return matches
enddef

# Workaround for Vim issue #12538: https://github.com/vim/vim/issues/12538
# - During async search, after `timer_start()` expires, the window is redrawn,
#   causing search highlighting (incsearch, hlsearch) to be lost.
# - This workaround restores both `incsearch` and `hlsearch` highlighting, which
#   are removed on redraw.
# - Note: If previous highlighting exists during a new search, both search
#   patterns may be highlighted simultaneously, which is suboptimal. Using
#   `:nohls` does not resolve this, as the redraw restores the previous search
#   highlighting. A proper solution would require modifying the search history,
#   which is non-trivial.
var matchids = {sid: 0, iid: 0}
def IncSearchHighlight(firstmatch: list<any>, context: string)
    IncSearchHighlightClear()
    var show = false
    try
        matchids.winid = win_getid()
        if &hlsearch
            matchids.sid = matchadd('Search', &ignorecase ? $'\c{context}' : context, 101)
            show = true
        endif
        if &incsearch && firstmatch != null_list
            matchids.iid = matchaddpos('IncSearch', firstmatch, 102)
            show = true
        endif
    catch # /\%V throws error
        IncSearchHighlightClear()
    endtry
    if show
        :redraw
    endif
enddef

def IncSearchHighlightClear()
    if state.async
        if matchids.sid > 0
            matchids.sid->matchdelete(matchids.winid)
            matchids.sid = 0
        endif
        if matchids.iid > 0
            matchids.iid->matchdelete(matchids.winid)
            matchids.iid = 0
        endif
    endif
enddef

# A worker task for async search.
def SearchWorker(attr: dict<any>, MatchFn: func(dict<any>): list<any>, timer: number = 0)
    if state == null_object
        return # <cr> (CmdlineLeave) can happen in large files before search finishes
    endif
    var context = Context()
    var timeoutasync = max([10, options.async_timeout])
    if context !=# attr.context ||
            (attr.starttime->reltime()->reltimefloat() * 1000) > timeoutasync ||
            attr.index >= attr.batches->len()
        return
    endif
    if attr.index == 0 && &incsearch
        IncSearchHighlight(attr.firstmatch, context)
    endif
    var batch = attr.batches[attr.index]
    var matches = MatchFn(batch)
    if matches->len() > 0
        state.candidates = MakeUnique(state.candidates + matches)
        state.items = Itemify(state.candidates)
        ShowPopupMenu()
    endif
    if attr.index == attr.batches->len() && state.candidates->len() == 0
        :redraw  # Hide the popup menu
    endif
    attr.index += 1
    timer_start(0, function(SearchWorker, [attr, MatchFn]))
enddef

def Context(): string
    return getcmdline()->strpart(0, getcmdpos() - 1)
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
