vim9script

var slead = 's\%[ubstitute]!\?'
var glead = 'g\%[lobal]!\?'
var sep = '[^"\!|a-zA-Z0-9]'

# Completion candidates for :s// and :g//
export def GetCompletionSG(ctx: string): dict<any>
    var insertion_point = -1
    var pat = null_string
    var range = null_string
    var isglobal = false
    var m = matchstrlist([ctx], $'^\(.\{{-}}\)\({glead}\)\({sep}\)\(.*\)$', {submatches: true})
    if m != []  # :g// :g//s//
        isglobal = true
        range = m[0].submatches[0]
        var [startl, endl] = GetRange(range, isglobal)
        if startl <= 0  # Issue #24
            return {compl: [], ip: insertion_point}
        endif
        var sepchar = m[0].submatches[2]
        pat = m[0].submatches[3]
        insertion_point = range->len() + len(m[0].submatches[1]) + 1
        if pat != null_string && pat->stridx(sepchar) != -1 # check for g//s//
            m = matchstrlist([pat], $'^\(.*{sepchar}\)\({slead}\)\({sep}\)\(.*\)$', {submatches: true})
            if m != []
                sepchar = m[0].submatches[2]
                pat = m[0].submatches[3]
                if pat != null_string && pat->stridx(sepchar) != -1
                    pat = null_string
                else
                    range = '%'
                    insertion_point += len(m[0].submatches[0]) + len(m[0].submatches[1]) + 1
                endif
            endif
        endif
    endif
    if pat == null_string
        isglobal = false
        m = matchstrlist([ctx], $'^\(.\{{-}}\)\({slead}\)\({sep}\)\(.*\)$', {submatches: true})
        if m != []  # :s//
            range = m[0].submatches[0]
            var sepchar = m[0].submatches[2]
            pat = m[0].submatches[3]
            insertion_point = range->len() + len(m[0].submatches[1]) + 1
            if pat != null_string && pat->stridx(sepchar) != -1
                pat = null_string
            endif
        endif
    endif
    pat = pat->substitute('^\\%V', '', '')
    if pat != null_string
        var [startl, endl] = GetRange(range, isglobal)
        if startl <= 0
            return {compl: [], ip: insertion_point}
        endif
        var word = '\%(\w\|[^\x00-\x7F]\)'  # Covers non-ascii mutli-byte chars.
        pat = (pat =~ '\(\\s\| \)' ? '\(\)' : $'\({word}*\)') .. $'\({pat}\)\({word}*\)'
        try
            m = bufnr()->matchbufline(pat, startl, endl, {submatches: true})
            if m->len() > 0 && m[0].submatches[1] !~ '^\s*$' # ignore searches for only space characters
                var found = {}
                var matches = []
                for item in m
                    if !found->has_key(item.text)
                        found[item.text] = 1
                        matches->add(item.text)
                    endif
                endfor
                return {compl: matches, ip: insertion_point}
            endif
        catch # '\' throws E55
        endtry
    endif
    return {compl: [], ip: insertion_point}
enddef

# Given a string specifying range, obtain start and end lines.
def GetRange(rstr: string, isglobal: bool = false): list<number>

    def Increment(linenum: number, val: string): number
        var lnum = linenum
        if lnum > 0
            var c = val
            while c != null_string
                var sign = c->matchstr('^\s*\zs[+-]')
                if sign == null_string
                    break
                endif
                c = c->matchstr('^\s*[+-]\zs.*')
                var n: string
                if c =~ '^\s*[+-]' || c =~ '^\s*$'
                    n = '1'
                else
                    n = c->matchstr('^\s*\zs\d\+')
                    if n == null_string
                        break
                    else
                        c = c->matchstr('^\s*\d\+\zs.*')
                    endif
                endif
                if sign == '+'
                    lnum += str2nr(n)
                elseif sign == '-'
                    lnum -= str2nr(n)
                endif
            endwhile
        endif
        return lnum
    enddef

    def LnumFromPat(pat: string, incr: string, isfwd: bool): number
        if pat == null_string
            return -1
        endif
        var lnum = search(pat, isfwd ? 'nW' : 'bnW')
        return Increment(lnum, incr)
    enddef

    var str = rstr->substitute('\%(:\+\s*\|:*\)$', '', '')  # Can have :1,$:s// (:h cmdline-lines)
    if str == null_string
        return [line('.'), (isglobal ? line('$') : line('.'))]
    endif
    var rangefrom = null_string
    var rangeto = null_string
    var startl = -1
    var endl = -1
    # see :h 10.3, /foo/+2,xxx or ?foo?-3, not supporting /foo//bar/
    var m = matchstrlist([str], '\v^\s*\/(%(\\.|[^/])+)\/(.{-})%([,;]|\ze$)', {submatches: true})
    if m->len() > 0
        startl = LnumFromPat(m[0].submatches[0], m[0].submatches[1], true)
        startl = max([1, startl])
        rangeto = str->strpart(len(m[0].text))
    else
        m = matchstrlist([str], '\v^\s*\?(%(\\.|[^?])+)\?(.{-})%([,;]|\ze$)', {submatches: true})
        if m->len() > 0
            startl = LnumFromPat(m[0].submatches[0], m[0].submatches[1], false)
            startl = max([1, startl])
            rangeto = str->strpart(len(m[0].text))
        endif
    endif
    if rangeto == null_string
        var s = str->split('[,;]')
        if s->len() == 2
            [rangefrom, rangeto] = s
        elseif s->len() == 1
            rangefrom = s[0]
        endif
    endif
    if rangeto != null_string
        m = matchstrlist([rangeto], '\v^\s*\/(%(\\.|[^/])+)%(\/\s*(.*))?\s*$', {submatches: true})
        if m->len() > 0
            endl = LnumFromPat(m[0].submatches[0], m[0].submatches[1], true)
            endl = (endl <= 0) ? line('$') : endl
        else
            m = matchstrlist([rangeto], '\v^\s*\?(%(\\.|[^?])+)%(\?\s*(.*))?\s*$', {submatches: true})
            if m->len() > 0
                endl = LnumFromPat(m[0].submatches[0], m[0].submatches[1], false)
                endl = (endl <= 0) ? line('$') : endl
            endif
        endif
    endif

    def GetLineNum(rng: string): number
        if rng =~# '^\s*\.'
            return Increment(line('.'), rng->matchstr('^\s*\.\zs.*'))
        elseif rng =~# '^\s*\$'
            return Increment(line('$'), rng->matchstr('^\s*\$\zs.*'))
        else
            m = matchstrlist([rng], '\v^\s*(\d+)\s*(.*)', {submatches: true})
            if m->len() > 0
                return Increment(str2nr(m[0].submatches[0]), m[0].submatches[1])
            endif
            m = matchstrlist([rng], '\v^\s*(''\S)\s*(.*)', {submatches: true})  # mark
            if m->len() > 0
                var [bufnum, lnum] = getpos(m[0].submatches[0])[0 : 1]
                if bufnum == 0 || bufnum == bufnr()
                    return Increment(lnum, m[0].submatches[1])
                endif
            endif
            if rng =~ '^\s*[+-]'
                return Increment(line('.'), rng)
            endif
            m = matchstrlist([rng], '\v^\s*(\\/)\s*(.*)', {submatches: true})  # /foo
            if m->len() > 0
                return LnumFromPat(getreg("/"), m[0].submatches[1], v:searchforward) + 1
            endif
            m = matchstrlist([rng], '\v^\s*(\\\?)\s*(.*)', {submatches: true})  # ?foo
            if m->len() > 0
                return LnumFromPat(getreg("/"), m[0].submatches[1], v:searchforward) - 1
            endif
            m = matchstrlist([rng], '\v^\s*(\\\&)\s*(.*)', {submatches: true})
            if m->len() > 0
                var hidx = -1
                var hcmd = histget(':', -1)
                var pat = null_string
                while hidx > -300 && hcmd != null_string
                    var mt = matchstrlist([hcmd], $'^\(.\{{-}}\)\({slead}\)\({sep}\)\(.*\)$', {submatches: true})
                    if mt != []  # :s//
                        var sepchar = mt[0].submatches[2]
                        pat = mt[0].submatches[3]
                        var sepidx = pat->stridx(sepchar)
                        if sepidx != -1
                            pat = pat->strpart(0, sepidx)
                        endif
                        break
                    endif
                    hidx -= 1
                    hcmd = histget(':', hidx)
                endwhile
                if pat != null_string
                    return LnumFromPat(pat, m[0].submatches[1], true) + 1
                endif
            endif
        endif
        return -1
    enddef

    if startl == -1 && rangefrom != null_string
        if rangefrom =~# '%'
            [startl, endl] = [1, line('$')]
        else
            startl = GetLineNum(rangefrom)
        endif
    endif
    if endl == -1 && rangeto != null_string
        endl = GetLineNum(rangeto)
    endif
    if endl <= 0 && startl > 0
        endl = startl
    endif
    if endl < startl
        [startl, endl] = [endl, startl]
    endif
    if (endl - startl) > 2000
        endl = startl + 2000
    endif
    return [startl, endl]
enddef

# :call g:vimsuggest#utils#TestRange() while editing ../../LICENSE.
export def TestRange()
    :normal gg
    assert_equal([-1, -1], GetRange('Foo has_a'))
    assert_equal([line('.'), line('.')], GetRange(''))
    assert_equal([line('.'), line('.')], GetRange('.'))
    assert_equal([1, line('$')], GetRange('%'))
    assert_equal([line('$'), line('$')], GetRange('$'))
    assert_equal([4, 5], GetRange('4,5'))
    assert_equal([4, 5], GetRange(' 4 , 5 '))
    assert_equal([6, 9], GetRange('4+2+4-1 , 5 +'))
    assert_equal([line('.') + 2, line('$') - 4], GetRange('.+2;$-4'))
    assert_equal([line('.') + 2, line('.') + 2], GetRange('+2'))
    assert_equal([line('.') + 2, line('.') + 2], GetRange('.+2'))
    assert_equal([line('.'), line('.') + 2], GetRange('.,+2'))
    assert_equal([line('.') + 2, line('.') + 2], GetRange(';+2'))
    assert_equal([line('.') + 2, line('.') + 2], GetRange('+2,'))
    assert_equal([line('.'), line('.')], GetRange(':::'))
    assert_equal([line('.'), line('$')], GetRange(':', true))
    assert_equal([line('.') + 2, line('.') + 3], GetRange('.+2,.+3 :: '))
    :normal v3j<esc>u
    assert_equal([1, 4], GetRange("'<,'>"))
    :normal gg
    assert_equal([1, 12], GetRange('.,/\Cpermission '))
    assert_equal([1, 13], GetRange('.,/\Cpermission/+1'))
    assert_equal([12, 15], GetRange('/\Cpermission/;/\CPROVIDED/'))
    setreg("/", "hereby")
    assert_equal([6, 6], GetRange('\/'))
    assert_equal([8, 8], GetRange('\/+2'))
    assert_equal([3, 3], GetRange('\?-1'))
    :normal gg
    histadd(':', 's/Lic/Lic')
    assert_equal([4, 4], GetRange('\&+2'))
    :normal G
    assert_equal([11, 11], GetRange('?\Cpermission?-1'))
    assert_equal([14, line('$') - 1], GetRange('?\Cpermission?+2,$-1'))
    # foreach(v:errors, 'echom "Fail:" v:val')
    for er in v:errors
       echom "Fail:" er
    endfor
enddef

export def TriggerKeys(trigger: string, reverse: bool, fwd = true): list<string>
    var lst = []
    var trg = trigger ?? 't'
    lst->extend(trg =~ 't' ? (fwd ? ["\<Tab>"] : ["\<S-Tab>"]) : [])
    # Note: <C-n> sends <Down> for first time when popup is open. For consistent
    # behavior use these keys synonymously.
    if reverse
        lst->extend(trg =~ 'n' ? (fwd ? ["\<C-n>", "\<Up>"] : ["\<C-p>", "\<Down>"]) : [])
    else
        lst->extend(trg =~ 'n' ? (fwd ? ["\<C-n>", "\<Down>"] : ["\<C-p>", "\<Up>"]) : [])
    endif
    return lst
enddef

export def CursorMovementKey(key: string): bool
    return [
        "\<Left>",
        "\<Right>",
        "\<C-Left>",
        "\<C-Right>",
        "\<S-Left>",
        "\<S-Right>",
        "\<C-b>",
        "\<Home>",
        "\<C-e>",
        "\<End>",
    ]->index(key) != -1
enddef
