fx_version 'cerulean'
game 'gta5'

name 'pa-target'
author 'Port Aurora'
description 'Port Aurora target adapter (ox_target wrapper)'
version '0.1.0'

server_scripts {
    'server/dependency_check.lua',
}

client_scripts {
    'client/target_adapter.lua',
}
