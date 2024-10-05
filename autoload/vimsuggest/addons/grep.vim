vim9script

# Usage:
# :<Command> Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...

import autoload '../cmd.vim'
import autoload './live.vim'

export def DoComplete(context: string, line: string, cursorpos: number,
        async: bool = true, timeout: number = 2000,
        max_items: number = 1000): list<any>
    var items = live.DoComplete(context, line, cursorpos, '', 'sh -c', async, timeout, max_items)
    SetupHooks(cmd.CmdLead())
    return items
enddef

def SetupHooks(name: string)
    # Overwrite the HighlightHook set in live.vim. grep command can have a dir
    # argument at the end. In this case, syntax pattern should be the argument
    # before that.
    def MatchGrepLine(line: string, pat: string): list<any> # Match grep output
        # Remove " and ' around pattern, if any.
        var p = pat->substitute('^"', '', '')->substitute('"$', '', '')
        if p ==# pat
            p = p->substitute("^'", '', '')->substitute("'$", '', '')
        endif
        return line->matchstrpos($'.*:.\{{-}}\zs{p}')
    enddef
    cmd.AddHighlightHook(name, (_: string, itms: list<any>): list<any> => {
        var pat
        if suffix != null_string && !itms->empty()
            return cmd.Highlight(suffix, itms,
                itms[0]->filereadable() ? null_function : MatchGrepLine)
        endif
        return [itms]
    })
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
