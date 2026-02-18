fx_version 'cerulean'
game 'gta5'

name 'pa-ui'
author 'Port Aurora'
description 'Port Aurora resource: pa-ui'
version '0.2.0'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/theme.json'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/dependency_check.lua'
}
