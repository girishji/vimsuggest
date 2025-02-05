vim9script

# PopupMenu class to handle both stacked (pum=true) and flat (pum=false) pop-up menus in Vim9
# - Supports custom filtering and callback functions
# - Stacked mode displays items vertically, similar to Vim's built-in popup menu
# - Flat mode displays items horizontally for a more compact presentation
# - Implements navigation functions for selecting, moving, and highlighting items
# - Includes methods for showing, hiding, and closing the menu
# - Handles scrolling (PageUp/PageDown) and adjusting the menu layout dynamically

export class PopupMenu
    var _winid: number
    var _winid_bg: number
    var _pum: bool
    var _matchsel_id: number = 0
    var _items: list<list<any>> = [[]]
    var _index: number = -1 # index to items array
    var _hmenu = {text: '', ibegin: 0, iend: 0, selHiId: 0}
    var _reverse: bool

    def new(FilterFn: func(number, string): bool, CallbackFn: func(number, any),
            attributes: dict<any>, pum: bool, reverse: bool = false)
        this._pum = pum
        this._reverse = reverse
        if this._winid->popup_getoptions() == {} # popup does not exist
            var attr = {
                cursorline: false, # do not automatically select the first item
                pos: 'botleft',
                line: &lines - &cmdheight,
                col: 1,
                drag: false,
                border: [0, 0, 0, 0],
                filtermode: 'c',
                filter: FilterFn,
                mapping: false,
                hidden: true,
                callback: CallbackFn,
            }
            if pum
                attr->extend({ minwidth: 14 })
            else
                attr->extend({ scrollbar: 0, padding: [0, 0, 0, 0] })
            endif
            attr->extend(attributes)
            this._winid = popup_menu([], attr)
        endif
        if !this._pum && this._winid_bg->popup_getoptions() == {}
            this._winid_bg = popup_create(' ',
                {line: &lines - &cmdheight, col: 1, minwidth: winwidth(0), hidden: true})
        endif
    enddef

    def _Printify(): list<any>
        var items = this._items
        if items->len() <= 1
            def MakeDict(idx: number, v: string): dict<any>
                return {text: v}
            enddef
            var itemslist = this._reverse ? items[0]->copy()->reverse() : items[0]
            return this._pum ? itemslist->mapnew(MakeDict) : [{text: this._hmenu.text}]
        endif
        if this._pum
            var formatted = items[0]->mapnew((idx, v) => {
                var mlen = items[2][idx]
                return {text: v, props: items[1][idx]->mapnew((_, c) => {
                    return {col: c + 1, length: mlen, type: 'VimSuggestMatch'}
                })}
            })
            return this._reverse ? formatted->copy()->reverse() : formatted
        else
            var offset = this._hmenu.offset + 1
            var props = []
            for idx in range(this._hmenu.ibegin, this._hmenu.iend)
                var word = items[0][idx]
                var pos = items[1][idx]
                var mlen = items[2][idx]
                for c in pos
                    var colnum = c + offset
                    props->add({col: colnum, length: mlen, type: 'VimSuggestMatch'})
                endfor
                offset += word->len() + 2
            endfor
            return [{text: this._hmenu.text, props: props}]
        endif
    enddef

    def _ClearMatchSel()
        if this._matchsel_id > 0
            matchdelete(this._matchsel_id, this._winid)
            this._matchsel_id = 0
        endif
    enddef

    def _ClearMatches()
        this._winid->clearmatches()
        this._hmenu.selHiId = 0
        this._matchsel_id = 0
    enddef

    def SetText(items: list<any>, moveto = 0)
        this._items = items
        this._ClearMatches()
        if this._pum
            if moveto > 0
                this._winid->popup_move({col: moveto})
            endif
            this._winid->popup_settext(this._Printify())
            this._winid->popup_setoptions({cursorline: false})
            win_execute(this._winid, this._reverse ? "norm! ggG" : "norm! gg")
            # Note: ggG vs G: Without 'gg' before 'G' menu shrinks to 1 line (VSGrep)
        else
            this._HMenu(0, 'left')
            try
                this._winid->popup_settext(this._Printify())
            catch /^Vim\%((\a\+)\)\=:E964:/ # E964 is thrown for some non-ascii wide chars
            endtry
        endif
        this._index = -1
        this._matchsel_id = 0
    enddef

    def _HMenu(startidx: number, position: string)
        const items = this._items
        const words = items[0]
        var selected = [words[startidx]]
        var atleft = position ==# 'left'
        var overflowl = startidx > 0
        var overflowr = startidx < words->len() - 1
        var idx = startidx
        var hmenuMaxWidth = winwidth(0) - 4
        while (atleft && idx < words->len() - 1) ||
                (!atleft && idx > 0)
            idx += (atleft ? 1 : -1)
            var last = (atleft ? idx == words->len() - 1 : idx == 0)
            if selected->join('  ')->len() + words[idx]->len() + 1 <
                    hmenuMaxWidth - (last ? 0 : 4)
                if atleft
                    selected->add(words[idx])
                else
                    selected->insert(words[idx])
                endif
            else
                idx -= (atleft ? 1 : -1)
                break
            endif
        endwhile
        if atleft
            overflowr = idx < words->len() - 1
        else
            overflowl = idx > 0
        endif
        var htext = (overflowl ? '< ' : '') .. selected->join('  ') .. (overflowr ? ' >' : '')
        this._hmenu->extend({text: htext, ibegin: atleft ? startidx : idx,
            iend: atleft ? idx : startidx, offset: overflowl ? 2 : 0})
    enddef

    # select next/prev item in popup menu; wrap around at end of list
    def SelectItem(direction: string, CallbackFn: func(number, string))
        const count = this._items[0]->len()
        const items = this._items

        def SelectVert()
            var realdirn = this._reverse ? (direction == 'j' ? 'k' : 'j') : direction
            if !this._winid->popup_getoptions().cursorline
                this._winid->popup_setoptions({cursorline: true})
                var up = direction ==# "k"
                var jumpto = this._reverse ? (up ? "gg" : "G") : (up ? "G" : "gg")
                win_execute(this._winid, $'normal! {jumpto}')
            else
                this._winid->popup_filter_menu(realdirn)
            endif
            if this._reverse
                this._index = line('$', this._winid) - line('.', this._winid)
            else
                this._index = line('.', this._winid) - 1
            endif
            if items->len() > 1
                var mlen = items[2][this._index]
                var lnum = this._reverse ? count - this._index : this._index + 1
                var pos = items[1][this._index]->mapnew((_, v) => [lnum, v + 1, mlen])
                if !pos->empty()
                    this._matchsel_id = matchaddpos('VimSuggestMatchSel', pos, 13, -1, {window: this._winid})
                endif
            endif
        enddef

        def SelectHoriz()
            var rotate = false
            if this._index == -1
                this._index = direction ==# 'j' ? 0 : count - 1
                rotate = true
            else
                if this._index == (direction ==# 'j' ? count - 1 : 0)
                    this._index = (direction ==# 'j' ? 0 : count - 1)
                    rotate = true
                else
                    this._index += (direction ==# 'j' ? 1 : -1)
                endif
            endif
            if this._index < this._hmenu.ibegin || this._index > this._hmenu.iend
                if direction ==# 'j'
                    this._HMenu(rotate ? 0 : this._index, rotate ? 'left' : 'right')
                else
                    this._HMenu(rotate ? count - 1 : this._index, rotate ? 'right' : 'left')
                endif
                this._ClearMatches()
                this._winid->popup_settext(this._Printify())
            endif

            # highlight selected word
            if this._hmenu.selHiId > 0
                matchdelete(this._hmenu.selHiId, this._winid)
                this._hmenu.selHiId = 0
            endif
            var offset = 1 + this._hmenu.offset
            if this._index > 0
                offset += items[0][this._hmenu.ibegin : this._index - 1]->reduce((acc, v) => acc + v->len() + 2, 0)
            endif
            this._hmenu.selHiId = matchaddpos(hlexists('PopupSelected') ? 'PopupSelected' : 'PmenuSel',
                [[1, offset, items[0][this._index]->len()]], 12, -1, {window: this._winid})

            # highlight matched pattern of selected word
            if items->len() > 1
                var mlen = items[2][this._index]
                var pos = items[1][this._index]->mapnew((_, v) => [1, v + offset, mlen])
                if !pos->empty()
                    this._matchsel_id = matchaddpos('VimSuggestMatchSel', pos, 13, -1, {window: this._winid})
                endif
            endif
        enddef

        this._ClearMatchSel()
        this._pum ? SelectVert() : SelectHoriz()
        if CallbackFn != null_function
            CallbackFn(this._index, direction)
        endif
        :redraw  # Needed for <tab> selected menu item highlighting to work
    enddef

    def Closed(): bool
        return this._winid->popup_getoptions() == {}
    enddef

    def Close(result = 0)
        if this._winid->popup_getoptions() != {} # popup exists
            this._winid->popup_close(result)
        endif
        if !this._pum && this._winid_bg->popup_getoptions() != {}
            this._winid_bg->popup_close(result)
        endif
    enddef

    def Show()
        this._winid->popup_show()
        if !this._pum
            this._winid_bg->popup_show()
        endif
    enddef

    def Hide()
        if !this.Hidden()
            this._winid->popup_hide()
            if !this._pum
                this._winid_bg->popup_hide()
            endif
        endif
    enddef

    def Hidden(): bool
        var opts = this._winid->popup_getpos()
        return opts == null_dict || !opts.visible
    enddef

    def SelectedItem(): string
        return (this._index != -1) ? this._items[0][this._index] : null_string
    enddef

    def FirstItem(): string
        return (this._items[0]->len() > 0) ? this._items[0][0] : null_string
    enddef

    def PageUp()
        if this._pum
            # win_execute(this._winid, 'normal! ' ..
            #     (this._reverse ? "\<C-d>" : "\<C-u>"))
            # win_execute(this._winid, 'normal! ' .. "\<C-u>")
            win_execute(this._winid, 'normal! ' .. "\<PageUp>")
            :redraw
        endif
    enddef

    def PageDown()
        if this._pum
            # win_execute(this._winid, 'normal! ' ..
            #     (this._reverse ? "\<C-u>" : "\<C-d>"))
            # win_execute(this._winid, 'normal! ' .. "\<C-d>")
            win_execute(this._winid, 'normal! ' .. "\<PageDown>")
            :redraw
        endif
    enddef

    def Index(): number
        return this._index
    enddef

    def Winid(): number
        return this._winid
    enddef
endclass

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
