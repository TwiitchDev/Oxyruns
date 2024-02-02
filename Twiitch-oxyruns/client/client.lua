local QBCore = exports['qb-core']:GetCoreObject()

local data = {}
local BuyerSpawned = false
local CurrentCops = 0
local SupplierSpawned = false
local OnDelivery = false
local GotPackages = false
local PackagesCollected = 0
local DeliveredPackages = 0
local InZone = false
local NoPackage = false
local DropZone
local StartZone
local HasBox = false
local prop = nil

RegisterNetEvent('police:SetCopCount', function(amount)
    CurrentCops = amount
end)

CreateThread(function()
    QBCore.Functions.LoadModel(Config.PedModel)
    local jobped = CreatePed(0, Config.PedModel, Config.PedLocation.x, Config.PedLocation.y, Config.PedLocation.z-1.0, Config.PedLocation.w, false, false)
	TaskStartScenarioInPlace(jobped, 'WORLD_HUMAN_CLIPBOARD', true)
	FreezeEntityPosition(jobped, true)
	SetEntityInvincible(jobped, true)
	SetBlockingOfNonTemporaryEvents(jobped, true)

    exports['qb-target']:AddTargetEntity(jobped, {
        options = {
            {
                icon = 'fas fa-circle',
                label = 'Check In',
                canInteract = function()
                    if not OnDelivery then return true end
                    return false
                end,
                action = function()
                    TriggerEvent('kevin-oxyruns:initiate')
                end,
            },
        },
        distance = 2.0
    })
end)

RegisterNetEvent('kevin-oxyruns:initiate', function ()
    if CurrentCops >= Config.CopsNeeded then
        TriggerEvent('animations:client:EmoteCommandStart', {"clipboard"})
        QBCore.Functions.Progressbar("start_delivery", 'Getting Information', 10000, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {
        }, {}, function() -- Done
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            if Config.UseStartPayment == 'true' then
                QBCore.Functions.TriggerCallback("kevin-oxyruns:Haspayment",function(money)
                    if money then
                        TriggerServerEvent("kevin-oxyruns:coolout")
                        TriggerEvent('kevin-oxyruns:OxyStart')
                    end
                end)
            elseif Config.UseStartPayment == 'false' then
                TriggerEvent('kevin-oxyruns:OxyStart')
            end
        end, function() -- Cancel
            TriggerEvent('animations:client:EmoteCommandStart', {"c"})
            QBCore.Functions.Notify("Cancelled", 'error')
        end,"fas fa-boxes-stacked")
    else
        if Config.Notifications == 'phone' then
            if Config.Phone == 'qb' then
                TriggerEvent('qb-phone:client:CustomNotification', 'NOTIFICATION', 'No deliveries available at this time', 'fas fa-bars', '#86F9A1', 4000)
            elseif Config.Phone == 'gks' then
                TriggerEvent('gksphone:notifi', {title = "NOTIFICATION", message = 'No deliveries available at this time', img= '/html/static/img/icons/messages.png'})
            end
        elseif Config.Notifications == 'qbcore' then
            QBCore.Functions.Notify('No deliveries available at this time', 'error')
        end
    end
end)

RegisterNetEvent('kevin-oxyruns:OxyStart', function ()
    if Config.Notifications == 'phone' then
        if Config.Phone == 'qb' then
            TriggerEvent('qb-phone:client:CustomNotification', 'NOTIFICATION', 'Meet With supplier and collect packages', 'fas fa-bars', '#86F9A1', 4000)
        elseif Config.Phone == 'gks' then
            TriggerEvent('gksphone:notifi', {title = "NOTIFICATION", message = 'Meet With supplier and collect packages', img= '/html/static/img/icons/messages.png'})
        end
    elseif Config.Notifications == 'qbcore' then
        QBCore.Functions.Notify('Meet With supplier and collect packages', 'primary')
    end

    loc = Config.PickUpLocations[math.random(#Config.PickUpLocations)]
    SupBlip = AddBlipForCoord(loc.x, loc.y, loc.z)

    SetBlipSprite(SupBlip, Config.OxySupplierBlip)
    SetBlipColour(SupBlip, Config.OxyBlipsColor)
    SetBlipScale(SupBlip, Config.OxySupplierBlipScale)
    SetBlipRoute(SupBlip, Config.UseGpsRoute)
    SetBlipRouteColour(SupBlip, Config.OxySupplierBlipRouteColor)

    StartZone = BoxZone:Create(vector3(loc.x, loc.y, loc.z), 65.5, 65.5, {
        heading = loc.w,
        name = 'Meet Location',
        debugPoly = false,
        -- minZ = 53.64,
        -- maxZ = 56.24
    })
    StartZone:onPlayerInOut(function(isPointInside)
        if isPointInside then
            if not GotPackages and not SupplierSpawned then
                StartZone:destroy()
                SpawnSupplier()
            end
        end
    end)
end)

function SpawnSupplier()
    local SupplierHash = Config.SupplierPeds[math.random(#Config.SupplierPeds)]
    QBCore.Functions.LoadModel(SupplierHash)
    QBCore.Functions.LoadModel(`prop_cs_cardbox_01`)
    Supplier = CreatePed(0, SupplierHash, loc.x, loc.y, loc.z-1.0, loc.w, true, true)
    pedprop = CreateObject(`prop_cs_cardbox_01`, 0, 0, 0, true, true, true)
    FreezeEntityPosition(Supplier, true)
    SetEntityInvincible(Supplier, true)
    AttachEntityToEntity(pedprop, Supplier, GetPedBoneIndex(Supplier, 0xEB95), 0.075, -0.10, 0.255, -130.0, 105.0, 0.0, true, true, false, false, 0, true)
    LoadAnim('anim@heists@box_carry@')
    TaskPlayAnim(Supplier, 'anim@heists@box_carry@', 'idle', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
    SupplierSpawned = true
    OnDelivery = true
    CreateThread(function ()
        exports['qb-target']:AddTargetEntity(Supplier, {
            options = {
                {
                    icon = 'fas fa-circle',
                    label = 'Take Packages',
                    canInteract = function()
                        if not GotPackages then return true end
                        return false
                    end,
                    action = function()
                        Collect()
                    end,
                },
            },
            distance = 2.0
        })
    end)
end

function Collect()
    RecievedPackages = Config.Packages
    PackagesCollected = PackagesCollected +1

    if Config.Notifications == 'phone' then
        if Config.Phone == 'qb' then
            TriggerEvent('qb-phone:client:CustomNotification', 'NOTIFICATION', PackagesCollected..' / '..RecievedPackages..' Collected Packages.', 'fas fa-bars', '#86F9A1', 4000)
        elseif Config.Phone == 'gks' then
            TriggerEvent('gksphone:notifi', {title = "NOTIFICATION", message = PackagesCollected..' / '..RecievedPackages..' Collected Packages.', img= '/html/static/img/icons/messages.png'})
        end
    elseif Config.Notifications == 'qbcore' then
        QBCore.Functions.Notify(PackagesCollected..' / '..RecievedPackages..' Collected Packages.', 'primary')
    end

    TriggerServerEvent('kevin-oxyruns:giveoxypackages')
    if PackagesCollected == RecievedPackages then
        RemoveBlip(SupBlip)
        GotPackages = true
        DeleteEntity(pedprop)
        ClearPedTasks(Supplier)
        Wait(500)
        SetPedAsNoLongerNeeded(Supplier)
        GetLocation()
    end
end

function GetLocation()
    if not NoPackage then
        data = Config.OxyLocations[math.random(#Config.OxyLocations)]
        DropBlip = AddBlipForCoord(data.Location)
        SetBlipSprite(DropBlip, Config.OxyDropBlip)
        SetBlipColour(DropBlip, Config.OxyBlipsColor)
        SetBlipScale(DropBlip, Config.OxyDropBlipScale)
        SetBlipRoute(DropBlip, Config.UseGpsRoute)
        SetBlipRouteColour(DropBlip, Config.OxyBlipsColor)

        if Config.Notifications == 'phone' then
            if Config.Phone == 'qb' then
                TriggerEvent('qb-phone:client:CustomNotification', 'NOTIFICATION', 'Go to the area on the gps to sell package', 'fas fa-bars', '#86F9A1', 4000)
            elseif Config.Phone == 'gks' then
                TriggerEvent('gksphone:notifi', {title = "NOTIFICATION", message = 'Go to the area on the gps to sell package', img= '/html/static/img/icons/messages.png'})
            end
        elseif Config.Notifications == 'qbcore' then
            QBCore.Functions.Notify('Go to the area on the gps to sell package', 'primary')
        end

        DropZone = BoxZone:Create(vector3(data.Location.x, data.Location.y, data.Location.z), 25.5, 25.5, {
            heading = data.Location.w,
            name = 'Drop Location',
            debugPoly = false,
            -- minZ = 53.64,
            -- maxZ = 56.24
        })
        DropZone:onPlayerInOut(function(isPointInside)
            if isPointInside then
                if GotPackages and not BuyerSpawned then
                    DropZone:destroy()
                    SpawnBuyers()
                end
            end
        end)
    end
end

function SpawnBuyers()
    if Config.Notifications == 'phone' then
        if Config.Phone == 'qb' then
            TriggerEvent('qb-phone:client:CustomNotification', 'NOTIFICATION', 'Buyers have been notified...now you wait.', 'fas fa-bars', '#86F9A1', 4000)
        elseif Config.Phone == 'gks' then
            TriggerEvent('gksphone:notifi', {title = "NOTIFICATION", message = 'Buyers have been notified...now you wait.', img= '/html/static/img/icons/messages.png'})
        end
    elseif Config.Notifications == 'qbcore' then
        QBCore.Functions.Notify('Buyers have been notified...now you wait.', 'primary')
    end

    local chance = math.random(1, 100)
    if chance <= Config.AlertChance then
        Alert()
    end
    
    Wait(Config.BuyerTimer)
    local VehicleHash =  data.Vehicles[math.random(#data.Vehicles)]
    QBCore.Functions.LoadModel(VehicleHash)
    BuyerVehicle = CreateVehicle(VehicleHash, data.CarSpawn.x, data.CarSpawn.y, data.CarSpawn.z, data.CarSpawn.w, true, true)

    local BuyerHash = data.Peds[math.random(#data.Peds)]
    QBCore.Functions.LoadModel(BuyerHash)
    Buyer = CreatePed(0,BuyerHash, data.CarSpawn.x, data.CarSpawn.y, data.CarSpawn.z, data.CarSpawn.w, true, true)
    BuyerSpawned = true
    SetEntityAsMissionEntity(Buyer, true, true)
    SetEntityAsMissionEntity(BuyerVehicle, true, true)
    SetPedIntoVehicle(Buyer, BuyerVehicle, -1)
    SetDriverAbility(Buyer, 1.0)
    TaskVehicleDriveToCoord(Buyer, BuyerVehicle, data.Location.x, data.Location.y, data.Location.z, Config.PedDrivingSpeed, 1, 0, Config.PedDrivingStyle, 1.0, true)
    SetPedKeepTask(Buyer, true)

    CreateThread(function ()
        exports['qb-target']:AddTargetEntity(BuyerVehicle, {
            options = {
                {
                    icon = 'fas fa-box',
                    label = 'Give Package',
                    canInteract = function()
                        if HasBox and BuyerSpawned then return true end
                        return false
                    end,
                    action = function()
                        GivePackage()
                    end,
                },
            },
            distance = 2.0
        })
    end)
end

function GivePackage()
    TriggerServerEvent('kevin-oxyruns:removeoxypackages')
    DeliveredPackages = DeliveredPackages +1
    SetPedAsNoLongerNeeded(Buyer)
    BuyerSpawned = false
    NoPackage = false
    RemoveBlip(DropBlip)
    Wait(15000)
    DeleteEntity(Buyer)
    DeleteEntity(BuyerVehicle)
    GetLocation()

    if DeliveredPackages == RecievedPackages then
        ClearPedTasks(PlayerPedId())
        RemoveBlip(DropBlip)

        if Config.Notifications == 'phone' then
            if Config.Phone == 'qb' then
                TriggerEvent('qb-phone:client:CustomNotification', 'NOTIFICATION', 'All packages sold.', 'fas fa-bars', '#86F9A1', 4000)
            elseif Config.Phone == 'gks' then
                TriggerEvent('gksphone:notifi', {title = "NOTIFICATION", message = "All packages sold.", img= '/html/static/img/icons/messages.png'})
            end
        elseif Config.Notifications == 'qbcore' then
            QBCore.Functions.Notify('All packages sold.', 'primary')
        end
        TriggerEvent('kevin-oxyruns:clean')
    end
end

RegisterNetEvent('kevin-oxyruns:clean', function ()
    SupplierSpawned = false
    OnDelivery = false
    GotPackages = false
    BuyerSpawned = false
    NoPackage = false
    PackagesCollected = 0
    DeliveredPackages = 0
    NoPackage = false
    HasBox = false
end)

CreateThread(function()
    while true do
        if OnDelivery then
            QBCore.Functions.TriggerCallback('kevin-oxyruns:hasPackage', function(Package)
                local ped = PlayerPedId()
                if Package then
                    if prop == nil then
                        HasBox = true
                        LoadAnim('anim@heists@box_carry@')
                        TaskPlayAnim(ped, 'anim@heists@box_carry@', 'idle', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
                        CarryAnimation()
                        QBCore.Functions.LoadModel(`prop_cs_cardbox_01`)
                        prop = CreateObject(`prop_cs_cardbox_01`, 0, 0, 0, true, true, true)
                        AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 0xEB95), 0.075, -0.10, 0.255, -130.0, 105.0, 0.0, true, true, false, false, 0, true)
                        DisableControls()
                    end
                else
                    if prop ~= nil then
                        ClearPedTasks(ped)
                        DeleteEntity(prop)
                        HasBox = false
                        prop = nil
                    end
                end
            end)
        end
        Wait(1000)
    end
end)

function DisableControls()
    CreateThread(function ()
        while true do
            if HasBox then
                DisableControlAction(0, 21, true) -- sprinting
                DisableControlAction(0, 22, true) -- Jumping
            end
            Wait(1)
        end
    end)
end

function  CarryAnimation()
    CreateThread( function ()
        while true do
            if HasBox then
                if not IsEntityPlayingAnim(PlayerPedId(), 'anim@heists@box_carry@', 'idle', 3) then
                    TaskPlayAnim(PlayerPedId(), 'anim@heists@box_carry@', 'idle', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
                end
            end
            Wait(2500)
        end
    end)
end

function LoadAnim(dict)
    while not HasAnimDictLoaded(dict) do
        RequestAnimDict(dict)
        Wait(1)
    end
end

----- ALERTS PORTION
function Alert()
    if Config.Dispatch == 'ps-dispatch' then
        exports['ps-dispatch']:Oxy()
    elseif Config.Dispatch == 'cd-dispatch' then
        local data = exports['cd_dispatch']:GetPlayerInfo()
        TriggerServerEvent('cd_dispatch:AddNotification', {
            job_table = {'police'},
            coords = data.coords,
            title = '10-31 - Drug Activity',
            message = 'Drug Activity at '..data.street,
            flash = 0,
            unique_id = tostring(math.random(0000000,9999999)),
            blip = {
                sprite = 67,
                scale = 1.5,
                colour = 2,
                flashes = false,
                text = '911 - Drug Activity',
                time = (5*60*1000),
                sound = 1,
            }
        })
    end
end