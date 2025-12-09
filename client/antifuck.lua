local _checkingVehs = {}
local _trackedCount = {}
local _ghostedVehs = {}

local _vehZone = nil
local _pzScale = { 10.0, 5.0, 5.0 }
local _isSpeeding = false

local function CleanupZone()
	if _vehZone ~= nil then
		_vehZone:destroy()
		_vehZone = nil
	end
end

local function DeleteGhostLocal(ent)
	local vState = Entity(ent).state
	if vState.Owned then
		return
	end
	NetSync:DeleteEntity(ent)
end

local function DoTheThing(veh)
    -- poly around your current entitiy. should work.
    _vehZone = EntityZone:Create(veh, {
        scale = _pzScale,
        debugPoly = false
    })
    
    _trackedCount = {}
    _checkingVehs = {}
    _ghostedVehs = {}
    
    Citizen.CreateThread(function()
        while _vehZone do
            local vehicles = GetGamePool("CVehicle")
            for _, v in ipairs(vehicles) do
                if v ~= veh and not _trackedCount[v] and not _checkingVehs[v] then
                    local ped = GetPedInVehicleSeat(v, -1)
                    if ped ~= 0 and not IsPedAPlayer(ped) then
                        _checkingVehs[v] = true
                    end
                end
            end
            Citizen.Wait(_isSpeeding and 0 or 50)
        end
    end)
    
    -- thread to track. I was stupid high and this may not work, fuck it, we ball
    Citizen.CreateThread(function()
        local prevCoords = {}
        while _vehZone do
            for k, v in pairs(_checkingVehs) do
                _trackedCount[k] = (_trackedCount[k] or 0) + 1
                if _trackedCount[k] > 5 then
                    _checkingVehs[k] = nil
                end
            end
            
            for k, v in pairs(_trackedCount) do
                if not DoesEntityExist(k) then
                    _trackedCount[k] = nil
                    _ghostedVehs[k] = nil
                    _checkingVehs[k] = nil
                    goto continue
                end
                
                if v > 5 then
                    local coords = GetEntityCoords(k)
                    if not prevCoords[k] then
                        prevCoords[k] = coords
                    end
                    
                    local change = #(prevCoords[k] - coords)
                    if change > 100.0 then
                        _trackedCount[k] = 0
                        _checkingVehs[k] = true
                    end
                    
                    if _ghostedVehs[k] and not _checkingVehs[k] and not _vehZone:isPointInside(coords) then
                        NetworkConcealEntity(k, false)
                        _ghostedVehs[k] = false
                    end
                    
                    prevCoords[k] = coords
                end
                ::continue::
            end
            Citizen.Wait(500)
        end
    end) -- this whole thread can eat my dick from the back and finger my ass
end

AddEventHandler('Characters:Client:Spawn', function()
	if _vehZone == nil then
		return
	end

	_vehZone:destroy()
	_vehZone = EntityZone:Create(_vehZone.entity, { scale = _pzScale, debugPoly = false })
end)

AddEventHandler('Characters:Client:Logout', CleanupZone)

AddEventHandler('Vehicles:Client:ExitVehicle', CleanupZone)

AddEventHandler('Vehicles:Client:Speeding', function(isSpeeding)
	_isSpeeding = isSpeeding

	if not _isSpeeding then
		return
	end

	_ghostedVehs = {}

	Citizen.CreateThread(function()
		while _isSpeeding and _vehZone do
			for k, v in pairs(_checkingVehs) do
				if not v then
					goto continue
				end

				local coord = GetEntityCoords(k)
				local inside = _vehZone:isPointInside(coord)
				if inside and not _ghostedVehs[k] and (_trackedCount[k] or 0) <= 1 then
					local ped = GetPedInVehicleSeat(k, -1)
					if ped ~= 0 and not IsPedAPlayer(ped) then
						NetworkConcealEntity(k, true)
						_ghostedVehs[k] = true
						DeleteGhostLocal(k)
					end
				elseif not inside and _ghostedVehs[k] then
					NetworkConcealEntity(k, false)
					_ghostedVehs[k] = false
				end
				::continue::
			end
			Citizen.Wait(_isSpeeding and 0 or 50)
		end

		for k, _ in pairs(_ghostedVehs) do -- this should bring them back, if not FUCK THEM!
			if DoesEntityExist(k) then
				NetworkConcealEntity(k, false)
			end
		end
		_ghostedVehs = {}
	end)
end)

AddEventHandler('Vehicles:Client:BecameDriver', DoTheThing)

AddEventHandler('Vehicles:Client:SwitchVehicleSeat', function(veh, seat)
	if seat ~= -1 and _vehZone ~= nil then
		CleanupZone()
	end
end)
