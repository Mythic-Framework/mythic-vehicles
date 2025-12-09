local enteringVehicle = false

AddEventHandler('Vehicles:Client:CharacterLogin', function()
    CreateThread(function() -- Vehicle Events Thread
        while _characterLoaded do
            GLOBAL_PED = PlayerPedId()
            if VEHICLE_INSIDE then

                -- Exiting Vehicle
                if not IsPedInAnyVehicle(GLOBAL_PED, false) then 
                    TriggerEvent('Vehicles:Client:ExitVehicle', VEHICLE_INSIDE)
                    VEHICLE_INSIDE = false
                    VEHICLE_SEAT = false
                end
    
                -- Seat Switching
                if VEHICLE_SEAT ~= GetPedSeatInVehicle(VEHICLE_INSIDE, GLOBAL_PED) then 
                    VEHICLE_SEAT = GetPedSeatInVehicle(VEHICLE_INSIDE, GLOBAL_PED)
                    TriggerEvent('Vehicles:Client:SwitchVehicleSeat', VEHICLE_INSIDE, VEHICLE_SEAT, VEHICLE_CLASS)

                    if VEHICLE_SEAT == -1 then 
                        TriggerEvent('Vehicles:Client:BecameDriver', VEHICLE_INSIDE, VEHICLE_SEAT, VEHICLE_CLASS)
                    end
                end

            -- Enter Vehicle
            elseif not VEHICLE_INSIDE and IsPedInAnyVehicle(GLOBAL_PED, false) then 
                VEHICLE_INSIDE = GetVehiclePedIsIn(GLOBAL_PED, false)
                VEHICLE_SEAT = GetPedSeatInVehicle(VEHICLE_INSIDE, GLOBAL_PED)
                VEHICLE_CLASS = GetVehicleClass(VEHICLE_INSIDE)
                TriggerEvent('Vehicles:Client:EnterVehicle', VEHICLE_INSIDE, VEHICLE_SEAT, VEHICLE_CLASS)

                if VEHICLE_SEAT == -1 then 
                    TriggerEvent('Vehicles:Client:BecameDriver', VEHICLE_INSIDE, VEHICLE_SEAT, VEHICLE_CLASS)
                end
            end

            if not VEHICLE_INSIDE then 
                local enter = GetVehiclePedIsTryingToEnter(GLOBAL_PED)
                if enter ~= 0 and DoesEntityExist(enter) then
                    if not enteringVehicle or enteringVehicle ~= enter then
                        enteringVehicle = enter

                        local populationType = GetEntityPopulationType(enter)
                        if populationType == 2 or populationType == 3 or populationType == 5 then
                            local vehEnt = Entity(enter)
                            if vehEnt.state.VIN == nil then
                                TriggerServerEvent("Vehicles:Server:RequestGenerateVehicleInfo", VehToNet(enter))
                            end

                            if vehEnt and vehEnt.state.Locked == nil then -- Hasn't Been Set Yet
                                local lockedChance = 45 -- %
                                if populationType == 2 then
                                    lockedChance = 65
                                end
                    
                                if math.random(0, 100) <= lockedChance then
                                    vehEnt.state:set("Locked", true, true)
                                    SetVehicleDoorsLocked(enter, 2)
                                else
                                    vehEnt.state:set("Locked", false, true)
                                    SetVehicleDoorsLocked(enter, 1)
                                end
                            else
                                if vehEnt.state.Locked then
                                    SetVehicleDoorsLocked(enter, 2)
                                else
                                    SetVehicleDoorsLocked(enter, 1)
                                end
                            end
                        end

                        SetEntityAsMissionEntity(enter, true, true)
                        local vehEnt = Entity(enter)

                        if vehEnt.state.VEH_IGNITION == nil and NetworkGetEntityIsNetworked(enter) then
                            Vehicles.Engine:Force(enter, GetIsVehicleEngineRunning(enter))
                        end

                        SetVehicleNeedsToBeHotwired(enter, false)
                    end
                elseif enteringVehicle then
                    enteringVehicle = false
                end
            end
    
            Wait(250)
        end
    end)
end)

RegisterNetEvent("Vehicles:Client:SetDespawnStuff", function(v)
    if v == 0 then return end
    local nv = NetToVeh(v)
    SetNetworkIdCanMigrate(v, true)
    SetVehicleHasBeenOwnedByPlayer(nv, true)
    SetEntityCleanupByEngine(nv, false)
    SetVehicleNeedsToBeHotwired(nv, false)
    SetVehRadioStation(nv, "OFF")
end)

AddStateBagChangeHandler('Locked', nil, function(bagName, key, value, _unused, replicated)
    if not LocalPlayer.state.loggedIn then return; end

    local entity, count = bagName:gsub('entity:', '')
    if count > 0 then
        if NetworkDoesEntityExistWithNetworkId(tonumber(entity)) then
            local veh = NetToVeh(tonumber(entity))
            if DoesEntityExist(veh) then
                SetVehicleDoorsLocked(veh, value and 2 or 1)
            end
        end
    end
end)