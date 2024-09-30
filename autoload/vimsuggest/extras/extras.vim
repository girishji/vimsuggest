vim9script

import '../cmd.vim'
import './vsbuf.vim'
import './vsmru.vim'
import './vsfindfz.vim'

export def Setup()
    cmd.AddOnspaceHook('VSBuf')
    cmd.AddOnspaceHook('VSMru')
    cmd.AddOnspaceHook('VSFindFz')
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
