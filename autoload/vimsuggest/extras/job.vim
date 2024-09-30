vim9script

# import autoload '../cmd.vim'

export class Job
    var jobid: job
    var items = []

            # out_cb: (ch, str) => { # Invoked when channel reads a line
                # items->add(str)
                # if start->reltime()->reltimefloat() * 1000 > 100 # Update menu every 100ms
                #     if cmd.allprops->has_key(win_getid())
                #         var p = cmd.allprops[win_getid()]
                #         if p.pmenu.Hidden()
                #             Stop()
                #         endif
                #     else
                #         Stop()
                #     endif
                #     ProcessItems(items, max_items)
                #     start = reltime()
                # endif
            # },
    def Execute(cmdstr: string, shellprefix: string = null_string, max_items: number = 1000): list<any>
        var cmdparts: any
        cmdparts = shellprefix == null_string ? cmdstr : shellprefix->split() + [cmdstr]
        this.Stop('kill')
        var start = reltime()
   # jobid[win_getid()] = job_start(cmdparts, {
   #     # out_cb: (ch, str) => ProcessItem(str, start),
   #     close_cb: (ch) => { # Invoked when no more output is available
   #         ProcessItems(items, max_items)
   #     },
   #     # Do not print error here since it will stop the job.
   #     # 'find' can throw 'Operation not permitted' error.
   #     # Can use '2>/dev/null' with 'find' but need ['sh', '-c', cmd] to handle '2>'.
   #     # err_cb: (chan: channel, msg: string) => {
   #     #     :echoerr $'error: {msg}'
   #     # },
   # })
        # return items
        return systemlist(cmdstr)
    enddef

# def ProcessItem(item: string, start: list<any>)
#     var items = allitems[win_getid()]
#     items->add(item)
#     if start->reltime()->reltimefloat() * 1000 > 100 # Update menu every 100ms
#         if cmd.allprops->has_key(win_getid())
#             var p = cmd.allprops[win_getid()]
#             if p.pmenu.Hidden()
#                 Stop()
#             endif
#         else
#             Stop()
#         endif
#         # ProcessItems(items, max_items)
#         ProcessItems(items, 1000)
#         # start = reltime()
#     endif
# enddef

    def Items(): list<any>
        return items
    enddef

    # def _ProcessItems(items: list<any>, max_items: number)
    #     if cmd.allprops->has_key(win_getid())
    #         var p = cmd.allprops[win_getid()]
    #         if p.pmenu.Closed()
    #             this.Stop()
    #         endif
    #         cmd.SetPopupMenu(this.items)
    #         if this.items->len() > max_items
    #             this.Stop()
    #         endif
    #     else
    #         this.Stop()
    #     endif
    # enddef

    def Stop(how: string = null_string)
        if this.jobid->job_status() ==# 'run'
            if how == null_string
                this.jobid->job_stop()
            else
                this.jobid->job_stop(how)
            endif
        endif
    enddef
endclass

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab
