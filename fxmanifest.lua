fx_version 'cerulean'
game 'gta5'

author 'Libertas'
description 'JP請求書システム'
version '1.0.0'

shared_scripts {
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/script.js',
}

dependencies {
    'qb-core',
    'oxmysql'
}