fx_version 'cerulean'
game 'gta5'

name 'pa-hud'
author 'Port Aurora'
description 'Port Aurora resource: pa-hud'
version '0.2.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

client_scripts {
    'client/hud_client.lua',
}

server_scripts {
    'server/dependency_check.lua',
    'server/needs_service.lua',
}
