-- [[ VARIABLES & INITIALIZATION ]]
local Framework = nil
local QBCore, ESX = nil, nil
local PlayerData = {}
local collecting = false
local currentProps = {} -- Holds props for each collection zone { entity, coords, available, respawnTimer }
local MAX_SPAWN_ATTEMPTS_PER_PROP = 25 -- Sa herë të provojë të gjejë vend të lirë për një prop
local MIN_SEPARATION_DISTANCE = 1.8 -- Distanca minimale midis qendrave të propseve

-- Initial framework check
CreateThread(function()
    if Config.Framework == 'qb-core' and exports['qb-core'] then
        QBCore = exports['qb-core']:GetCoreObject()
        Framework = 'qb-core'
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() PlayerData = QBCore.Functions.GetPlayerData() end)
        RegisterNetEvent('QBCore:Player:SetPlayerData', function(val) PlayerData = val end)
        Citizen.Wait(1000)
        if not PlayerData or not PlayerData.citizenid then PlayerData = QBCore.Functions.GetPlayerData() end
    elseif Config.Framework == 'esx' and exports.es_extended then
        ESX = exports.es_extended:getSharedObject()
        Framework = 'esx'
        while ESX.GetPlayerData().job == nil do Citizen.Wait(10) end
        PlayerData = ESX.GetPlayerData()
        RegisterNetEvent('esx:playerLoaded', function(xPlayer) PlayerData = xPlayer end)
        RegisterNetEvent('esx:setJob', function(job) PlayerData.job = job end)
    else
        print(("^1ERROR: Configured framework ('%s') not found or not supported! Script will not function correctly.^0"):format(Config.Framework))
        return
    end
    print(("^2INFO: Framework '%s' detected and loaded for grape script.^0"):format(Framework))

    InitializeZones()
    InitializeSellLocations()
    InitializeBlips()
end)



function InitializeZones()
    local modelHash = GetHashKey(Config.CollectProps.model)

    CreateThread(function() 
        RequestModel(modelHash)
        local attempts = 0
        while not HasModelLoaded(modelHash) and attempts < 200 do Wait(50); attempts = attempts + 1 end
        if not HasModelLoaded(modelHash) then print(("^1ERROR: Failed to load grape prop model '%s'!^0"):format(Config.CollectProps.model)); return end
        print(("^2INFO: Grape prop model '%s' loaded.^0"):format(Config.CollectProps.model))

        for zoneName, zoneData in pairs(Config.CollectZones) do
            currentProps[zoneData.name] = {}
            local maxProps = zoneData.maxProps or 10 
            local createdCount = 0
            local totalAttempts = 0
            local maxTotalAttempts = maxProps * MAX_SPAWN_ATTEMPTS_PER_PROP * 2

            print(("^2INFO: Initializing random props for zone '%s' (Max: %d)...^0"):format(zoneData.name, maxProps))

            while createdCount < maxProps and totalAttempts < maxTotalAttempts do

                local success, propEntity, propCoords = CreateRandomPropInZone(zoneData, currentProps[zoneData.name], modelHash)

                if success then
                    table.insert(currentProps[zoneData.name], { entity = propEntity, coords = propCoords, available = true, respawnTimer = nil })
                    createdCount = createdCount + 1
                end
                totalAttempts = totalAttempts + 1
                Wait(15) 
            end

            if createdCount < maxProps then print(("^3WARNING: Could only place %d/%d props in zone '%s'.^0"):format(createdCount, maxProps, zoneData.name))
            else print(("^2INFO: Successfully placed %d props in zone '%s'.^0"):format(createdCount, zoneData.name)) end
        end
        SetModelAsNoLongerNeeded(modelHash) 
    end)
end


function CreateRandomPropInZone(zoneData, existingPropsInZone, modelHash)
    if not HasModelLoaded(modelHash) then RequestModel(modelHash); Wait(100) end
    if not HasModelLoaded(modelHash) then print("^1ERROR: Prop model not loaded for random creation.^0"); return false end

    local zoneCenter = zoneData.coords
    local zoneRotationRad = math.rad(zoneData.rotation or 0)
    local propHeading = zoneData.propHeading or 0.0 
    local minSeparationSq = MIN_SEPARATION_DISTANCE * MIN_SEPARATION_DISTANCE

    for attempt = 1, MAX_SPAWN_ATTEMPTS_PER_PROP do
        local angle = math.random() * 2 * math.pi
        local radius = math.sqrt(math.random()) * (math.min(zoneData.width, zoneData.height) / 2)
        local relX = radius * math.cos(angle)
        local relY = radius * math.sin(angle)


        local rotatedX = relX * math.cos(zoneRotationRad) - relY * math.sin(zoneRotationRad)
        local rotatedY = relX * math.sin(zoneRotationRad) + relY * math.cos(zoneRotationRad)
        local candidateX = zoneCenter.x + rotatedX
        local candidateY = zoneCenter.y + rotatedY


        local locationClear = true
        for _, existingPropData in ipairs(existingPropsInZone) do
            if existingPropData.coords then
                local distSq = Vdist2(candidateX, candidateY, zoneCenter.z, existingPropData.coords.x, existingPropData.coords.y, existingPropData.coords.z)
                if distSq < minSeparationSq then locationClear = false; break end
            end
        end


        if locationClear then
            local rayStart = vector3(candidateX, candidateY, zoneCenter.z + 15.0)
            local rayEnd = vector3(candidateX, candidateY, zoneCenter.z - 15.0)
            local rayHandle = StartShapeTestRay(rayStart.x, rayStart.y, rayStart.z, rayEnd.x, rayEnd.y, rayEnd.z, 1, 0, 7) 

            local rayAttempts = 0; local result, hit, endCoords = 1
            while result == 1 and rayAttempts < 50 do Wait(0); result, hit, endCoords = GetShapeTestResult(rayHandle); rayAttempts = rayAttempts + 1 end

            if result == 2 and hit then
                local groundZ = endCoords.z


                local prop = CreateObject(modelHash, candidateX, candidateY, groundZ, true, false, false)
                Wait(0)

                if DoesEntityExist(prop) then
                    SetEntityHeading(prop, propHeading)
                    Wait(0)
                    PlaceObjectOnGroundProperly(prop) -- Rregullim final
                    Wait(5)
                    FreezeEntityPosition(prop, true)

                    exports.ox_target:addLocalEntity(prop, {
                        { name = "collect_grapes_" .. zoneData.name .. "_" .. prop, icon = "fas fa-hand-paper", label = "Collect Grapes", distance = 1.5,
                          canInteract = function()
                              local foundPropData = nil; for _, pData in ipairs(currentProps[zoneData.name] or {}) do if pData.entity == prop then foundPropData = pData; break end end
                              return not collecting and (foundPropData and foundPropData.available)
                          end,
                          onSelect = function() CollectGrapes(prop, zoneData) end }
                    })

                    return true, prop, GetEntityCoords(prop)
                else
                    print(("^1ERROR: Failed to create prop entity after raycast success at %.1f, %.1f^0"):format(candidateX, candidateY))
                end

            end 
        end 
        Wait(5)
    end 


    return false, nil, nil
end

--! FUNKSION I PËRDITËSUAR PËR RESPAWN
function RespawnProp(propData, zoneData, modelHash)
    local entityToReplace = propData.entity


    if DoesEntityExist(entityToReplace) then
        exports.ox_target:removeLocalEntity(entityToReplace)
        DeleteEntity(entityToReplace)
    end
    propData.respawnTimer = nil


    local oldPropIndex = -1
    if currentProps[zoneData.name] then
        for i, pData in ipairs(currentProps[zoneData.name]) do
            if pData.entity == entityToReplace then
                oldPropIndex = i
                break
            end
        end
        if oldPropIndex > -1 then
            table.remove(currentProps[zoneData.name], oldPropIndex)
        end
    end

  
    local success, newProp, newCoords = CreateRandomPropInZone(zoneData, currentProps[zoneData.name] or {}, modelHash or GetHashKey(Config.CollectProps.model))

    if success then
        table.insert(currentProps[zoneData.name], {
            entity = newProp,
            coords = newCoords,
            available = true,
            respawnTimer = nil
        })
    else
        print(("^3WARNING: Failed to respawn a new prop in zone '%s'. Zone might be full or terrain difficult.^0"):format(zoneData.name))
    end
end


-- [[ COLLECTION ]]
function CollectGrapes(propEntity, zoneData)
    if collecting then return end
    if IsPedInAnyVehicle(PlayerPedId(), false) then Notify(nil, "You cannot collect while in a vehicle.", "error"); return end

    local propData = nil
    for _, pData in ipairs(currentProps[zoneData.name] or {}) do if pData.entity == propEntity then propData = pData; break end end
    if not propData then Notify(nil, "Cannot process these grapes.", "error"); return end
    if not propData.available then Notify(nil, "Someone else just collected this.", "info"); return end

    propData.available = false
    collecting = true
    local playerPed = PlayerPedId()

    if Config.CollectAnimationDict and Config.CollectAnimation then
        RequestAnimDict(Config.CollectAnimationDict); while not HasAnimDictLoaded(Config.CollectAnimationDict) do Wait(0) end
        TaskPlayAnim(playerPed, Config.CollectAnimationDict, Config.CollectAnimation, 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    local success = exports.ox_lib:progressBar({ duration = Config.CollectTime, label = "Collecting grapes...", useWhileDead = false, canCancel = true, disable = { move = true, car = true, combat = true, mouse = false, }, })

    ClearPedTasks(playerPed)
    collecting = false

    if success then
        local rewardAmount = math.random(Config.CollectRewardCount.min, Config.CollectRewardCount.max)
        TriggerServerEvent('grapes:server:giveReward', rewardAmount)
        if DoesEntityExist(propEntity) then SetEntityVisible(propEntity, false, false); SetEntityCollision(propEntity, false, false); exports.ox_target:removeLocalEntity(propEntity) end
        if propData then
            local modelHash = GetHashKey(Config.CollectProps.model)
            propData.respawnTimer = SetTimeout(Config.PropRespawnTime, function()
                 local found = false; for _, pCheck in ipairs(currentProps[zoneData.name] or {}) do if pCheck == propData then found = true; break end end
                 if found then RespawnProp(propData, zoneData, modelHash) end
            end)
        end
    else
        Notify(nil, "Collection cancelled.", "error")
        if propData then propData.available = true end
    end
end

-- [[ SELL LOCATIONS ]]
function InitializeSellLocations()
    for i, location in ipairs(Config.SellLocations) do
        CreateThread(function()
            local modelHash = GetHashKey(location.ped_model); RequestModel(modelHash)
            local attempts = 0; while not HasModelLoaded(modelHash) and attempts < 100 do Wait(10); attempts = attempts + 1 end
            if not HasModelLoaded(modelHash) then print(("^1ERROR: Seller ped model '%s' could not be loaded.^0"):format(location.ped_model)); return end
            local ped = CreatePed(4, modelHash, location.coords.x, location.coords.y, location.coords.z - 1.0, location.coords.w, false, true)
            SetEntityHeading(ped, location.coords.w); SetEntityCoordsNoOffset(ped, location.coords.x, location.coords.y, location.coords.z - 1.0, false, false, true)
            PlaceObjectOnGroundProperly(ped); FreezeEntityPosition(ped, true); SetEntityInvincible(ped, true); SetBlockingOfNonTemporaryEvents(ped, true)
            SetModelAsNoLongerNeeded(modelHash)
            exports.ox_target:addLocalEntity(ped, { { name = "sell_grapes_" .. i, icon = "fas fa-dollar-sign", label = "Sell Wine", distance = 2.0, onSelect = function() TriggerServerEvent('grapes:server:sellGrapes') end } })
            print(("^2INFO: Grape seller %d created.^0"):format(i))
        end)
    end
end

-- [[ BLIPS ]]
function CreateBlip(data, coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z); SetBlipSprite(blip, data.id); SetBlipDisplay(blip, 4); SetBlipScale(blip, data.scale or 0.8)
    SetBlipColour(blip, data.colour); SetBlipAsShortRange(blip, true); BeginTextCommandSetBlipName("STRING"); AddTextComponentString(data.title); EndTextCommandSetBlipName(blip)
    return blip
end
function InitializeBlips()
    for _, zoneData in pairs(Config.CollectZones) do if zoneData.blip then CreateBlip(zoneData.blip, zoneData.coords) end end
    for _, sellData in pairs(Config.SellLocations) do if sellData.blip then CreateBlip(sellData.blip, sellData.coords) end end
    print("^2INFO: Blips created.^0")
end

-- [[ NOTIFICATIONS (Internal Use) ]]
RegisterNetEvent('grapes:client:Notify', function(message, type) Notify(nil, message, type) end)
