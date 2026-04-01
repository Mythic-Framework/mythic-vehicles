fx_version 'cerulean'
games { 'gta5' }
lua54 'yes'

version '1.0.0'
repository 'https://github.com/Mythic-Framework/mythic-vehicles'
client_script "@mythic-base/components/cl_error.lua"
client_script "@mythic-pwnzor/client/check.lua"

client_scripts {
    '@mythic-polyzone/client.lua',
    '@mythic-polyzone/BoxZone.lua',
    '@mythic-polyzone/EntityZone.lua',
    'shared/**/*.lua',
    'client/**/*.lua'
}

server_scripts {
    'shared/**/*.lua',
    'server/**/*.lua',
}
