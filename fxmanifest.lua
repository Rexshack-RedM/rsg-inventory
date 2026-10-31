fx_version 'cerulean'
rdr3_warning 'I acknowledge that this is a prerelease build of RedM, and I am aware my resources *will* become incompatible once RedM ships.'
game 'rdr3'

description 'rsg-inventory'
version '3.1.0'

shared_scripts {
    '@rsg-core/shared/locale.lua',
    'shared/config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/shops.lua',
    'server/compat.lua',
    'server/versionchecker.lua',
}

client_scripts {
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'locales/*.json',
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/images/*.png',
}

dependencies {
    'rsg-core',
    'oxmysql',
}

lua54 'yes'
