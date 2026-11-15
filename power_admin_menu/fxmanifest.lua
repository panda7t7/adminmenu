fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'power_admin_menu'
author 'Power Admin Menu'
description 'Modular, multi-framework FiveM administration system'
version '1.6.4-managed-props'

ui_page 'html/index.html'

shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/utils.lua',
    'shared/permissions.lua'
}

client_scripts {
    'client/main.lua',
    'client/nui.lua',
    'client/actions.lua',
    'client/spectate.lua',
    'client/vector.lua',
    'client/object_spawner.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'adapters/framework.lua',
    'adapters/esx.lua',
    'adapters/qbcore.lua',
    'adapters/qbox.lua',
    'adapters/standalone.lua',
    'adapters/inventory.lua',
    'integrations/custom_inventory.lua',
    'integrations/custom_framework.lua',
    'integrations/custom_garage.lua',
    'server/vehicle_ownership.lua',
    'server/database.lua',
    'server/permissions.lua',
    'server/audit.lua',
    'server/security.lua',
    'server/catalog.lua',
    'server/actions.lua',
    'server/player_intelligence.lua',
    'server/main.lua',
    'server/vector.lua',
    'server/object_spawner.lua',
    'server/managed_objects.lua'
}

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js',
    'html/assets/*'
}

dependency 'oxmysql'
