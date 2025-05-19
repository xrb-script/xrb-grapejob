fx_version 'cerulean'
game 'gta5'

author 'xResul Albania'
description 'Grape Harvesting, Wine Crafting, and Selling Script (ESX/QBCore)'
version '2.1.0'
discord 'discord.gg/CAyUh9su2s'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

dependencies {
    'ox_lib',
    'ox_target',
    'ox_inventory',
}
