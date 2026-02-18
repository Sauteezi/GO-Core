fx_version 'cerulean'
game 'gta5'

name 'pa-devtools'
author 'Port Aurora'
description 'Port Aurora resource: pa-devtools'
version '0.2.0'

files {
    'sql/pa_schema.sql',
}

server_scripts {
    'server/dependency_check.lua',
    'server/schema_apply.lua',
}
