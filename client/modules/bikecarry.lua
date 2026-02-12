-- Created by Nolix

local carryingBike = false
local carriedBike = nil
local carryThreadActive = false

local carryAnimDict = "anim@heists@box_carry@"
local carryAnimName = "idle"

local pickupAnimDict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@"
local pickupAnimName = "machinic_loop_mechandplayer"

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then
        return true
    end

    RequestAnimDict(dict)
    local timeout = GetGameTimer() + 5000

    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > timeout then
            return false
        end

        Wait(0)
    end

    return true
end

local function ensureNetworkControl(entity)
    if not DoesEntityExist(entity) then
        return false
    end

    if NetworkHasControlOfEntity(entity) then
        return true
    end

    NetworkRequestControlOfEntity(entity)

    local attempts = 0

    while not NetworkHasControlOfEntity(entity) and attempts < 50 do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
        attempts = attempts + 1
    end

    return NetworkHasControlOfEntity(entity)
end

local function resetCarryState()
    carryingBike = false
    carriedBike = nil

    if LocalPlayer and LocalPlayer.state then
        LocalPlayer.state.carryingBike = false
    end
end

local function stopCarryAnimation()
    if DoesEntityExist(LocalPlayer.state.ped) then
        StopAnimTask(LocalPlayer.state.ped, carryAnimDict, carryAnimName, 1.0)
    end
end

local function dropCarriedBike(options)
    options = options or {}

    if not carryingBike then
        resetCarryState()
        return
    end

    local ped = LocalPlayer.state.ped or PlayerPedId()
    local bike = carriedBike

    carryingBike = false

    if bike and DoesEntityExist(bike) then
        ensureNetworkControl(bike)
        DetachEntity(bike, true, true)
        SetEntityCollision(bike, true, true)
        FreezeEntityPosition(bike, false)

        if not options.skipPlacement and DoesEntityExist(ped) then
            local pedCoords = GetEntityCoords(ped)
            local forward = GetEntityForwardVector(ped)
            local dropCoords = vector3(
                pedCoords.x + (forward.x * 1.4),
                pedCoords.y + (forward.y * 1.4),
                pedCoords.z
            )
            SetEntityCoords(bike, dropCoords.x, dropCoords.y, pedCoords.z, false, false, false, true)
            SetEntityHeading(bike, GetEntityHeading(ped))
            SetVehicleOnGroundProperly(bike)
            SetVehicleForwardSpeed(bike, 0.0)
        end
    end

    stopCarryAnimation()
    resetCarryState()
end

local function startCarryThread()
    if carryThreadActive then
        return
    end

    carryThreadActive = true

    CreateThread(function()
        while carryingBike do
            DisableControlAction(0, 21, true) 
            DisableControlAction(0, 22, true) 
            DisableControlAction(0, 23, true) 
            DisableControlAction(0, 24, true) 
            DisableControlAction(0, 25, true) 
            DisableControlAction(0, 44, true) 
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)

            if not carriedBike or not DoesEntityExist(carriedBike) then
                dropCarriedBike({ skipPlacement = true })
                break
            end

            Wait(0)
        end

        carryThreadActive = false
    end)
end

AddEventHandler('Vehicles:Client:CarryBike', function(entityData)
    if carryingBike then
        Notification:Error('You are already carrying a bike', 3000, 'bicycle')
        return
    end

    if not entityData or not entityData.entity or not DoesEntityExist(entityData.entity) then
        Notification:Error('Unable to find that bike', 3000, 'bicycle')
        return
    end

    local bike = entityData.entity

    if GetVehicleClass(bike) ~= 13 then
        Notification:Error('Only bicycles can be picked up', 3000, 'bicycle')
        return
    end

    if LocalPlayer.state.isDead or LocalPlayer.state.doingAction then
        Notification:Error('You cannot do that right now', 3000, 'bicycle')
        return
    end

    if IsPedInAnyVehicle(LocalPlayer.state.ped, false) then
        Notification:Error('Exit your vehicle first', 3000, 'bicycle')
        return
    end

    local ped = LocalPlayer.state.ped
    local pedCoords = GetEntityCoords(ped)
    local bikeCoords = GetEntityCoords(bike)

    if #(pedCoords - bikeCoords) > 3.0 then
        Notification:Error('Get closer to the bike', 3000, 'bicycle')
        return
    end

    if not NetworkGetEntityIsNetworked(bike) then
        NetworkRegisterEntityAsNetworked(bike)
        Wait(0)
    end

    TaskTurnPedToFaceEntity(ped, bike, 750)

    Progress:Progress({
        name = 'vehicle_pickup_bike',
        duration = 2500,
        label = 'Picking Up Bike',
        useWhileDead = false,
        canCancel = true,
        controlDisables = {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        },
        animation = {
            animDict = pickupAnimDict,
            anim = pickupAnimName,
            flags = 16,
        },
    }, function(cancelled)
        if cancelled then
            return
        end

        if carryingBike then
            return
        end

        if not DoesEntityExist(bike) then
            Notification:Error('The bike is no longer here', 3000, 'bicycle')
            return
        end

        if LocalPlayer.state.isDead or IsPedInAnyVehicle(ped, false) then
            return
        end

        if #(GetEntityCoords(ped) - GetEntityCoords(bike)) > 3.0 then
            Notification:Error('You moved too far away from the bike', 3000, 'bicycle')
            return
        end

        if not ensureNetworkControl(bike) then
            Notification:Error('Unable to pick up that bike', 3000, 'bicycle')
            return
        end

        carryingBike = true
        carriedBike = bike
        LocalPlayer.state.carryingBike = true

        ClearPedTasksImmediately(ped)

        if loadAnimDict(carryAnimDict) then
            TaskPlayAnim(ped, carryAnimDict, carryAnimName, 8.0, -8.0, -1, 49, 0.0, false, false, false)
        end

        AttachEntityToEntity(
            bike,
            ped,
            GetPedBoneIndex(ped, 24818),
            -0.150,
            0.45,
            -0.0,
            150.0,
            660.0,
            825.0,
            true,
            true,
            false,
            true,
            1,
            true
        )

        SetEntityCollision(bike, false, false)
        FreezeEntityPosition(bike, true)
        SetVehicleForwardSpeed(bike, 0.0)

        startCarryThread()

        local dropKey = (Keybinds and Keybinds.GetKey and Keybinds:GetKey('secondary_action')) or 'G'
        Notification:Info(string.format('Press %s to drop the bike', dropKey), 4000, 'bicycle')
    end)
end)

AddEventHandler('Keybinds:Client:KeyDown:secondary_action', function()
    if carryingBike then
        dropCarriedBike()
    end
end)

AddEventHandler('Vehicles:Client:EnterVehicle', function()
    if carryingBike then
        dropCarriedBike()
    end
end)

AddEventHandler('Ped:Client:Died', function()
    if carryingBike then
        dropCarriedBike({ skipPlacement = true })
    end
end)

AddEventHandler('Characters:Client:Logout', function()
    if carryingBike then
        dropCarriedBike({ skipPlacement = true })
    end
end)

AddEventHandler('Characters:Client:Spawn', function()
    resetCarryState()
end)
