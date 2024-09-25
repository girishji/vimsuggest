vim9script

export var options: dict<any> = {
    search: {
        enable: true,
        pum: true,         #   'false' for flat and 'true' for stacked popup menu
        fuzzy: false,      #   fuzzy completion
        alwayson: true,    #   when 'false' press <tab> to open popup menu
        popupattrs: {      #   dictionary of attributes passed to popup window
            maxheight: 12, #   line count of stacked menu (pum=true)
        },
        range: 100,        #   line count per search attemp
        timeout: 200,      #   millisec to search, when non-async is specified
        async: true,       #   async search
        asynctimeout: 3000,
        asyncminlines: 1000,
        highlight: true,
    },
    cmd: {
        enable: true,
        pum: true,         #   'false' for flat and 'true' for stacked popup menu
        fuzzy: false,   # fuzzy completion
        exclude: [],    # keywords excluded from completion (use \c for ignorecase)
        onspace: [],    # show menu for keyword+space (ex. :find , :buffer , etc.)
        timeout: 500,   # max time in ms to search when '**' is specified in path
        alwayson: true, # when 'false' press <tab> to open popup menu
        popupattrs: {      #   dictionary of attributes passed to popup window
            maxheight: 12, #   line count of stacked menu (pum=true)
        },
        wildignore: true,
        highlight: true,
        extras: true,
    }
}

# vim: tabstop=8 shiftwidth=4 softtabstop=4
