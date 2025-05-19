-- [[ VARIABLES & INITIALIZATION ]]
local Framework = nil
local QBCore, ESX = nil, nil

-- Initial framework check
CreateThread(function()
    if Config.Framework == 'qb-core' and exports['qb-core'] then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = 'qb-core'
    elseif Config.Framework == 'esx' and exports.es_extended then
        ESX = exports.es_extended:getSharedObject()
        Framework = 'esx'
    else
        print(("^1ERROR: Configured framework ('%s') not found or not supported! Script will not function correctly.^0"):format(Config.Framework))
        return
    end
    print(("^2INFO: Framework '%s' detected and loaded for grape script (Server).^0"):format(Framework))
end)

-- [[ FRAMEWORK HELPER FUNCTIONS ]]
function GetPlayer(source)
    if Framework == 'qb-core' then return QBCore.Functions.GetPlayer(source)
    elseif Framework == 'esx' then return ESX.GetPlayerFromId(source) end
    return nil
end

function GetIdentifier(source)
    local player = GetPlayer(source); if not player then return nil end
    if Framework == 'qb-core' then return player.PlayerData.citizenid
    elseif Framework == 'esx' then return player.identifier end
    return nil
end

function AddItem(source, item, count)
    local player = GetPlayer(source); if not player then return false end
    count = tonumber(count) or 1; if count <= 0 then return true end

    if Framework == 'qb-core' then
        local itemData = QBCore.Shared.Items[item:lower()]
        if not itemData then print(("^1ERROR: Item '%s' not found in QBCore.Shared.Items.^0"):format(item)); return false end
        if player.Functions.AddItem(item, count) then TriggerClientEvent('inventory:client:ItemBox', source, itemData, 'add', count); return true end
    elseif Framework == 'esx' then
        player.addInventoryItem(item, count)
        return true
    end
    return false
end

function RemoveItem(source, item, count)
    local player = GetPlayer(source); if not player then return false end
    count = tonumber(count) or 1; if count <= 0 then return true end
    local hasEnough = GetItemCount(source, item) >= count
    if not hasEnough then return false end

    if Framework == 'qb-core' then
        if player.Functions.RemoveItem(item, count) then TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item:lower()], 'remove', count); return true end
    elseif Framework == 'esx' then
        player.removeInventoryItem(item, count)
        return true
    end
    return false
end

function GetItemCount(source, item)
    local player = GetPlayer(source); if not player then return 0 end
    local itemCount = 0
    if Framework == 'qb-core' then
        local itemData = player.Functions.GetItemByName(item)
        if itemData then itemCount = itemData.amount end
    elseif Framework == 'esx' then
        local success, inv = pcall(player.getInventory)
        if success and inv then
            for _, invItem in pairs(inv) do if invItem.name == item then itemCount = invItem.count; break end end
        else
            local itemData = player.getInventoryItem(item)
            if itemData and itemData.count then itemCount = itemData.count end
        end
    end
    return itemCount or 0
end

function AddMoney(source, amount)
    local player = GetPlayer(source); if not player or amount <= 0 then return end
    amount = math.floor(amount)
    if Framework == 'qb-core' then player.Functions.AddMoney('cash', amount)
    elseif Framework == 'esx' then player.addMoney(amount) end
end

function ServerNotify(source, message, type)
    TriggerClientEvent('grapes:client:Notify', source, message, type)
end

-- [[ GRAPE COLLECTION REWARD ]]
RegisterNetEvent('grapes:server:giveReward', function(amount)
    local src = source
    local player = GetPlayer(src); if not player then return end
    amount = tonumber(amount) or 0; if amount <= 0 then return end

    -- Zgjidh llojin e rrushit bazuar në shanset
    local randomChance = math.random(1, 100); local cumulativeChance = 0; local chosenGrape = nil
    for _, rewardData in ipairs(Config.CollectProps.rewards) do
        cumulativeChance = cumulativeChance + rewardData.chance
        if randomChance <= cumulativeChance then chosenGrape = rewardData.item; break end
    end
    if not chosenGrape and #Config.CollectProps.rewards > 0 then chosenGrape = Config.CollectProps.rewards[1].item end -- Fallback

    if chosenGrape then
        local itemLabel = exports.ox_inventory:Items(chosenGrape)?.label or chosenGrape

        --! SHTUAR KONTROLLIN E INVENTARIT KËTU
        local canCarry = exports.ox_inventory:CanCarryItem(src, chosenGrape, amount)

        if canCarry then
            if AddItem(src, chosenGrape, amount) then
                 ServerNotify(src, ("Collected %d %s"):format(amount, itemLabel), 'success')
            else
                 ServerNotify(src, ("Could not add %s. Error occurred."):format(itemLabel), 'error')
                 print(("^1ERROR: AddItem failed for player %s item %s amount %d even though CanCarryItem passed.^0"):format(src, chosenGrape, amount))
            end
        else
             ServerNotify(src, ("Inventory full. Cannot collect %d %s."):format(amount, itemLabel), 'error')
        end
    else
        ServerNotify(src, "You failed to collect any grapes this time.", 'error')
    end
end)


-- [[ GRAPE SELLING ]]
RegisterNetEvent('grapes:server:sellGrapes', function()
    local src = source
    local player = GetPlayer(src); if not player then return end

    local totalEarnings = 0
    local soldSomething = false
    local oxInv = exports.ox_inventory

    for grapeItem, pricePerGrape in pairs(Config.SellPrices) do
        local itemCount = GetItemCount(src, grapeItem)

        if itemCount > 0 then
            local itemLabel = oxInv:Items(grapeItem)?.label or grapeItem
            if not itemLabel then
                 print(("^1ERROR: Cannot sell item '%s' - not found in ox_inventory definitions.^0"):format(grapeItem))
                 goto continue
            end

            local price = tonumber(pricePerGrape) or 0
            if price <= 0 then goto continue end

            local earnings = itemCount * price

            if RemoveItem(src, grapeItem, itemCount) then
                AddMoney(src, earnings)
                totalEarnings = totalEarnings + earnings
                soldSomething = true
                ServerNotify(src, ("Sold %d %s for $%s"):format(itemCount, itemLabel, FormatMoney(earnings)), 'success')
                Wait(50)
            else
                ServerNotify(src, ("Failed to sell %s. Inventory might be busy."):format(itemLabel), 'error')
            end
        end
        ::continue::
    end

    if not soldSomething then
        ServerNotify(src, "You have no grapes to sell.", 'info')
    end
end)

-- [[ MONEY FORMATTING FUNCTION (OPTIONAL) ]]
function FormatMoney(amount)
  local formatted = tostring(math.floor(amount))
  local k = 0
  while true do formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2'); if k == 0 then break end end
  return formatted
end
