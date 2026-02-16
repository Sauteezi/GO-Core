fx_version 'cerulean'
game 'gta5'

name 'pa-economy'
author 'Port Aurora'
description 'Port Aurora resource: pa-economy'
version '0.3.0'

server_scripts {
    'server/dependency_check.lua',
    'server/economy_service.lua',
    'server/payout_guarded.lua',
}
