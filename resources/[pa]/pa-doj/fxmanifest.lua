fx_version 'cerulean'
game 'gta5'

name 'pa-doj'
author 'Port Aurora'
description 'Port Aurora resource: pa-doj'
version '0.2.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/app.js',
    'web/style.css',
}

client_script 'client/main.lua'

server_scripts {
    'server/dependency_check.lua',
    'server/doj_service.lua',
}
