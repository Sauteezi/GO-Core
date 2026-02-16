fx_version 'cerulean'
game 'gta5'

name 'pa-police'
author 'Port Aurora'
description 'Port Aurora police operations, MDT, and evidence-lite services.'
version '0.2.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/dependency_check.lua',
    'server/police_service.lua'
}
