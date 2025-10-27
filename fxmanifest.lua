fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'
ox_lib 'locale'
lua54 'yes'

description 'rsg-inventory'
version '2.7.1'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/helpers.lua',
}

client_scripts {
    'client/drops/functions.lua',
    'client/functions.lua',
    'client/commands.lua',
    'client/exports.lua',
    'client/events.lua',
    'client/drops/events.lua',
    'client/ui/events.lua',
    'client/ui/callbacks.lua',
    'client/drops/ui/callbacks.lua',
    'client/main.lua',
    'client/drops/loops.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/functions.lua',
    'server/shops/functions.lua',
    'server/exports.lua',
    'server/shops/exports.lua',
    'server/main.lua',
    'server/events/*.lua',
    'server/drops/events/*.lua',
    'server/shops/events/*.lua',
    'server/commands.lua',
    'server/versionchecker.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/main.css',
    'html/app.js',
    "shared/*.lua", --- for lib.load
    'locales/*.json',
    'html/images/*.png',
    'html/assets/*.*',
}
