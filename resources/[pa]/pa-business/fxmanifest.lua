fx_version 'cerulean'
game 'gta5'

name 'pa-business'
author 'Port Aurora'
description 'Port Aurora business economy glue'
version '0.1.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/dependency_check.lua',
    'server/business_service.lua',
}
