vim9script

import autoload '../cmd.vim'

export class Job
    var _jobid: job
    var _items = []

    def Execute(cmdstr: string, shellprefix: string = null_string, max_items: number = 1000): list<any>
        var cmdparts: any
        cmdparts = shellprefix == null_string ? cmdstr : shellprefix->split() + [cmdstr]
        this.Stop('kill')
        var start = reltime()
        this._jobid = job_start(cmdparts, {
            out_cb: (ch, str) => { # Invoked when channel reads a line
                this._items->add(str)
                if start->reltime()->reltimefloat() * 1000 > 100 # Update menu every 100ms
                    if cmd.allprops->has_key(win_getid())
                        var p = cmd.allprops[win_getid()]
                        if p.pmenu.Hidden()
                            this.Stop()
                        endif
                    else
                        this.Stop()
                    endif
                    this._ProcessItems(this._items, max_items)
                    start = reltime()
                endif
            },
            close_cb: (ch) => { # Invoked when no more output is available
                this._ProcessItems(this._items, max_items)
            },
            # Do not print error here since it will stop the job. 'find' can
            # throw 'Operation not permitted' error. Can use '2>/dev/null' to
            # redirect stderr, but need to set shell prefix to 'sh -c'.
            # err_cb: (chan: channel, msg: string) => {
            #     :echoerr $'error: {msg}'
            # },
        })
        return this._items
    enddef

    def _ProcessItems(items: list<any>, max_items: number)
        if cmd.allprops->has_key(win_getid())
            var p = cmd.allprops[win_getid()]
            if p.pmenu.Closed()
                this.Stop()
            endif
            cmd.SetPopupMenu(this._items)
            if this._items->len() > max_items
                this.Stop()
            endif
        else
            this.Stop()
        endif
    enddef

    def Stop(how: string = null_string)
        if this._jobid->job_status() ==# 'run'
            if how == null_string
                this._jobid->job_stop()
            else
                this._jobid->job_stop(how)
            endif
        endif
    enddef
endclass

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
