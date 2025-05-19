Config = {}

--! CHOOSE YOUR FRAMEWORK HERE: 'qb-core' or 'esx'
Config.Framework = 'esx' -- Can be changed to 'qb-core'

-- [[ GRAPE COLLECTION ]]
Config.CollectZones = {
    {
        name = "Grapes",
        coords = vec3(2021.0, 4892.0, 43.0),
        width = 50.0,
        height = 50.0,
        rotation = 140.0,
        propHeading = 140.0,
        maxProps = 20,
        blip = { title = "Grape Field", colour = 50, id = 140, scale = 0.8 }
    }
    -- You can add more zones here
}
Config.CollectProps = {
    model = "prop_bush_grape_01",
    rewards = {
        { item = "chardonnaygrape", chance = 35 }, 
        { item = "pinotnoirgrape", chance = 30 },
        { item = "zinfandelgrape", chance = 25 }, 
        { item = "sauvignonblancgrape", chance = 15 },
        { item = "cabernetsauvignongrape", chance = 10 }
    }
}
Config.CollectRewardCount = { min = 1, max = 3 }
Config.PropRespawnTime = 40 * 1000
Config.CollectTime = 2000
Config.CollectAnimation = "amb@world_human_gardener_plant@male@base"
Config.CollectAnimationDict = "amb@world_human_gardener_plant@male@base"

-- [[ GRAPE SELLING ]]
Config.SellLocations = {
    { coords = vector4(-1877.6056, 2056.2664, 141.0063, 69.4138), ped_model = "s_m_m_gardener_01",
      blip = { title = "Wine Buyer", colour = 7, id = 827, scale = 0.8 } }
}
Config.SellPrices = {
    chardonnaybottle = 80, 
    pinotnoirbottle = 90, 
    zinfandelbottle = 110,
    sauvignonblancbottle = 130, 
    cabernetsauvignonbottle = 150
}

-- [[ NOTIFICATIONS & MISC ]]
Config.UseOxLibNotifications = (Config.Framework ~= 'qb-core')
function Notify(source, message, type)
    type = type or 'info'; local title = 'Information'; if type == 'error' then title = 'Error'; elseif type == 'success' then title = 'Success' end
    if Config.UseOxLibNotifications then exports.ox_lib:notify({ source=source, title=title, description=message, type=type })
    elseif Config.Framework == 'qb-core' then local qbType='primary'; if type=='error' then qbType='error'; elseif type=='success' then qbType='success' end; TriggerClientEvent('QBCore:Notify', source or -1, message, qbType, 5000)
    elseif Config.Framework == 'esx' then TriggerClientEvent('esx:showNotification', source or -1, message)
    else print(('[%s] %s: %s'):format(source or 'GLOBAL', title, message)) end
end