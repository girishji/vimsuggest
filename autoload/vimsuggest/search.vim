vim9script

import autoload './options.vim' as opt
import autoload './popup.vim'

var options = opt.options.search

class Properties
    # Note: Variables are read-only by default, except for 'public', which is read/write.
    #       If a variable starts with an underscore ('_'), it is treated as protected
    #       and cannot not be accessed or modified outside the class.
    public var items: list<any>       # Items displayed in the popup menu
    public var candidates: list<any>  # Completion candidates (saved for async invocation)
    public var context = null_string  # Cached command-line contents
    var pmenu: popup.PopupMenu = null_object
    var isfwd: bool                   # True if searching forward ('/'), false for backward ('?')
    var async: bool
    var curpos: list<any>

    def new()
        this.isfwd = getcmdtype() == '/' ? true : false
        this.pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs, options.pum)
        # Issue: Due to Vim issue #12538 (see below), search highlighting
        # must be manually triggered during asynchronous search.
        # Perform asynchronous search only for large files to avoid this complication.
        this.async = line('$') < 1500 ? false : options.async
        if this.async
            this.curpos = getcurpos()
        endif
    enddef

    def Clear()
        this.pmenu.Close()
    enddef
endclass

var props: Properties

export def Setup()
    if options.enable
        augroup VimSuggestSearchAutocmds | autocmd!
            autocmd CmdlineEnter    /,\?  {
                props = Properties.new()
                EnableCmdline()
            }
            autocmd CmdlineChanged  /,\?  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave    /,\?  {
                if props != null_object
                    props.Clear()
                    props = null_object
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
    if getcmdline()[lastcharpos] ==? "\<tab>"
        setcmdline(getcmdline()->slice(0, lastcharpos))
        Complete()
    endif
enddef

def Complete()
    var p = props
    var context = getcmdline()->strpart(0, getcmdpos() - 1)
    if context == '' || context =~ '^\s\+$'
        return
    endif
    # note:
    # 1) when pasting text from clipboard, CompleteChanged event is called
    #    only once instead of for every character pasted.
    # 2) when pasting a long line of text, search appears to be slow for the first time
    #    (likely because functions are getting compiled). it will be fast afterwards.
    p.context = context
    p.candidates = []
    p.items = []
    if p.async
        var attr = {
            starttime: reltime(),
            context: context,
            batches: Batches(),
            index: 0,
        }
        if &incsearch
            attr->extend({firstmatch: GetFirstMatch()})
        endif
        SearchWorker(attr)
    else
        p.items = options.fuzzy ? BufFuzzyMatches() : Batches()->BufMatches()->MakeUnique()->Itemify()
        if len(p.items[0]) > 0
            ShowPopupMenu()
        endif
    endif
enddef

def ShowPopupMenu()
    var p = props
    p.pmenu.SetText(p.items)
    p.pmenu.Show()
    # Note: If command-line is not disabled here, it will intercept key inputs 
    # before the popup does. This prevents the popup from handling certain keys, 
    # such as <Tab> properly.
    DisableCmdline()
enddef

def PostSelectItem(index: number)
    var p = props
    setcmdline(p.items[0][index]->escape('~/'))
    :redraw  # Needed for <tab> selected menu item highlighting to work
enddef

def FilterFn(winid: number, key: string): bool
    var p = props
    # Note: Do not include arrow keys since they are used for history lookup.
    if key == "\<Tab>" || key == "\<C-n>"
        p.pmenu.SelectItem('j', PostSelectItem) # Next item
    elseif key == "\<S-Tab>" || key == "\<C-p>"
        p.pmenu.SelectItem('k', PostSelectItem) # Prev item
    elseif key == "\<C-e>"
        IncSearchHighlightClear()
        p.pmenu.Hide()
        setcmdline('')
        feedkeys(p.context, 'n')
        :redraw!
        timer_start(0, (_) => EnableCmdline()) # Timer will que this after feedkeys
    elseif key == "\<CR>" || key == "\<ESC>"
        IncSearchHighlightClear()
        return false
    else
        IncSearchHighlightClear()
        p.pmenu.Hide()
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
    endif
enddef

# Return a list containing range of lines to search.
def Batches(): list<any>
    var p = props
    var range = max([10, options.range])
    var ibelow = []
    var iabove = []
    var startl = line('.')
    while startl <= line('$')
        if p.isfwd
            ibelow->add({startl: startl, endl: min([startl + range, line('$')])})
        else
            ibelow->insert({startl: startl, endl: min([startl + range, line('$')])})
        endif
        startl += range
    endwhile
    startl = 1
    while startl <= line('.')
        if p.isfwd
            iabove->add({startl: startl, endl: min([startl + range, line('.')])})
        else
            iabove->insert({startl: startl, endl: min([startl + range, line('.')])})
        endif
        startl += range
    endwhile
    return p.isfwd ? ibelow + iabove : iabove + ibelow
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
    var p = props
    var pos = []
    var save_cursor = getcurpos()
    setpos('.', p.curpos)
    try
        var [blnum, bcol] = p.context->searchpos(p.isfwd ? 'nw' : 'nwb')
        if [blnum, bcol] != [0, 0]
            var [elnum, ecol] = p.context->searchpos(p.isfwd ? 'nwe' : 'nwbe')
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
    setpos('.', save_cursor)
    return pos
enddef

# Return a list of strings (can have spaces) that match the pattern.
def BufMatches(batches: list<dict<any>>): list<any>
    var p = props
    if p.context =~ '[^\\]\+\\n\|^\\n'  # Contains a newline char
        var save_cursor = getcurpos()
        if p.async
            var startl = p.isfwd ? max([1, batches[0].startl - 5]) : min([line('$'), batches[0].endl + 5])
            cursor(startl, p.isfwd ? 1 : 1000)
        endif
        var matches = BufMatchMultiLine(batches[0])
        setpos('.', save_cursor)
        return matches
    else
        return BufMatchLine(batches)
    endif
enddef

def BufMatchLine(batches: list<dict<any>>): list<any>
    var p = props
    var pat = (p.context =~ '\(\\s\| \)' ? '\(\)' : '\(\k*\)') .. $'\({p.context}\)\(\k*\)'
    var matches = []
    var timeout = max([10, options.timeout])
    var starttime = reltime()
    try
        for batch in batches
            var m = bufnr()->matchbufline(pat, batch.startl, batch.endl, {submatches: true})
            if m->len() > 0 && m[0].submatches[1] =~ '^\s*$' # ignore searches for only space characters
                break
            endif
            if !p.isfwd
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
# Note: Syntax highlighting is not supported at the moment.
def BufMatchMultiLine(batch: dict<any>): list<any>
    var p = props
    var timeout = max([10, options.timeout])
    var flags = p.async ? (p.isfwd ? '' : 'b') : (p.isfwd ? 'w' : 'wb')
    var pattern = p.context =~ '\s' ? $'{p.context}\k*' : $'\k*{p.context}\k*'
    var [lnum, cnum] = [0, 0]
    var [startl, startc] = [0, 0]
    var stopl = 0
    if p.async
        stopl = p.isfwd ? batch.endl : batch.startl
    endif
    try
        if p.async
            [lnum, cnum] = pattern->searchpos(flags, stopl)
        else
            [lnum, cnum] = pattern->searchpos(flags, 0, timeout)
            [startl, startc] = [lnum, cnum]
        endif
    catch # '*' with magic can throw E871
        # echom v:exception
        return []
    endtry
    var matches = []
    var found = {}
    var starttime = reltime()
    while [lnum, cnum] != [0, 0]
        var [endl, endc] = pattern->searchpos('ceW') # End of matching string
        var lines = getline(lnum, endl)
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
        cursor(lnum, cnum) # Restore cursor to beginning of pattern, otherwise '?' does not work
        [lnum, cnum] = p.async ? pattern->searchpos(flags, stopl) :
            pattern->searchpos(flags, 0, timeout)

        if !p.async && ([startl, startc] == [lnum, cnum] ||
                (starttime->reltime()->reltimefloat() * 1000) > timeout)
            break
        endif
    endwhile
    return matches->mapnew((_, v) => {
        return {text: v}
    })
enddef

# Return a list of strings that fuzzy match the pattern.
def BufFuzzyMatches(): list<any>
    var p = props
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
    var matches = words->matchfuzzypos(p.context, { matchseq: 1, limit: 100 }) # Max 100 matches
    matches[2]->map((_, _) => 1)
    # Convert character positions to byte index (needed by matchaddpos)
    matches[1]->map((idx, v) => {
        return v->mapnew((_, c) => matches[0][idx]->byteidx(c))
    })
    return matches
enddef

# Workaround for Vim issue #12538: https://github.com/vim/vim/issues/12538
# - After `timer_start()` expires, the window is redrawn, causing search
#   highlighting (incsearch, hlsearch) to be lost.
# - This workaround restores both `incsearch` and `hlsearch` highlighting, which
#   are removed on redraw.
# - Note: If previous highlighting exists during a new search, both search
#   patterns may be highlighted simultaneously, which is suboptimal. Using
#   `:nohls` does not resolve this, as the redraw restores the previous search
#   highlighting. A proper solution would require modifying the search history,
#   which is non-trivial.
var matchids = {sid: 0, iid: 0}
def IncSearchHighlight(firstmatch: list<any>, context: string)
    echom 'IncSearchHighlight'
    var show = false
    if &hlsearch
        matchids.sid = matchadd('Search', &ignorecase ? $'\c{context}' : context, 101)
        show = true
    endif
    if &incsearch && firstmatch != null_list
        matchids.iid = matchaddpos('IncSearch', firstmatch, 102)
        show = true
    endif
    if show
        :redraw
    endif
enddef

def IncSearchHighlightClear()
    echom 'IncSearchHighlightClear'
    var p = props
    if p.async
        if matchids.sid > 0
            matchids.sid->matchdelete()
            matchids.sid = 0
        endif
        if matchids.iid > 0
            matchids.iid->matchdelete()
            matchids.iid = 0
        endif
    endif
enddef

# A worker task for async search.
def SearchWorker(attr: dict<any>, timer: number = 0)
    var p = props
    var context = getcmdline()->strpart(0, getcmdpos() - 1)
    var timeoutasync = max([10, options.timeoutasync])
    if context !=# attr.context ||
            (attr.starttime->reltime()->reltimefloat() * 1000) > timeoutasync ||
            attr.index >= attr.batches->len()
        return
    endif
    if attr.index == 0
        IncSearchHighlight(attr.firstmatch, context)
    endif
    var batch = attr.batches[attr.index]
    var matches = BufMatches([batch])
    p.candidates = MakeUnique(p.candidates + matches)
    p.items = Itemify(p.candidates)
    if len(p.items[0]) > 0
        ShowPopupMenu()
    endif
    attr.index += 1
    timer_start(0, function(SearchWorker, [attr]))
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4
