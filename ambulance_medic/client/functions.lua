Initialized = function()
    SpawnMedics()
end

GlobalFunction = function(event, data)
    local options = {
        event = event,
        data = data
    }

    TriggerServerEvent("chames_ambulance_medic:globalEvent", options)
end

TryToGetMedicalTreatment = function(medicIndex)
    if not Default.OnlyAllowHelpWhenThereIsNoMedicsAvailable then return GetMedicalTreatment(medicIndex) end

    Heap.ESX.TriggerServerCallback("chames_ambulance_medic:requiredAmount", function(required)
        if required then
            GetMedicalTreatment(medicIndex)
        else
           -- Heap.ESX.ShowNotification("Има активни лекари.")
            exports['mythic_notify']:DoHudText('inform', 'Има активни лекари.')
        end
    end)
end

GetMedicalTreatment = function(medicIndex)
    local medic = Medics[medicIndex]

    if not medic.Sequence then return Heap.ESX.ShowNotification("There are no route available for the medic, contact a staff or developer.")  end
    if not medic.Beds then return Heap.ESX.ShowNotification("There are no beds available, contact a staff or developer.") end

    if IsEntityDead(Heap.Ped) then
        TreatPlayer()

        Citizen.Wait(500)
    end

    if IsEntityAttached(Heap.Ped) then
        DetachEntity(Heap.Ped, true, true)
    end

    GlobalFunction("MEDIC_UNAVAILABLE", {
        Medic = medicIndex,
        Bool = true
    })

    local ped = GetPed(medicIndex)

    if ped then
        SetEntityVisible(ped.Handle, false)
    end

    LoadModels({
        medic.Hash
    })

    local pedHandle = CreatePed(5, medic.Hash, medic.Location - vector3(0.0, 0.0, 0.985), medic.Heading, true)

    while not DoesEntityExist(pedHandle) do
        Citizen.Wait(0)
    end

    if ped then
        SetEntityNoCollisionEntity(pedHandle, ped.Handle)
        SetEntityNoCollisionEntity(ped.Handle, pedHandle)
    end

    TaskSetBlockingOfNonTemporaryEvents(pedHandle, true)
    SetNetworkIdCanMigrate(PedToNet(pedHandle), false)

    PlayAnimation(Heap.Ped, "amb@world_human_bum_slumped@male@laying_on_right_side@base", "base", {
        flag = 9
    })

    AttachEntityToEntity(Heap.Ped, pedHandle, GetPedBoneIndex(pedHandle, 57005), -0.32, -0.6, -0.35, 240.0, 35.0, 149.0, true, true, false, true, 1, true)

    PlayAnimation(pedHandle, "anim@heists@box_carry@", "idle", {
        flag = 49
    })

    GlobalFunction("SYNC_ANIMATION", {
        Ped = PedToNet(pedHandle)
    })

    for _, sequence in ipairs(medic.Sequence) do
        local isAtPos = _TaskGoStraightToCoord(pedHandle, sequence.Location - vector3(0.0, 0.0, 0.985), 1.0, 15000, sequence.Heading, 2.0)

        if isAtPos then
            if not IsEntityPlayingAnim(pedHandle, "anim@heists@box_carry@", "idle", 3) then
                PlayAnimation(pedHandle, "anim@heists   @box_carry@", "idle", {
                    flag = 49
                })
            end
        end
    end

    local bed = medic.Beds[math.random(#medic.Beds)]

    if not bed then return end

    local bedHandle = GetClosestObjectOfType(bed.Location, 2.0, bed.Hash)

    if DoesEntityExist(bedHandle) then
        local standingLocation = GetOffsetFromEntityInWorldCoords(bedHandle, vector3(0.0, -2.0, 0.0))
        local standingHeading = GetEntityHeading(bedHandle)

        local _ = _TaskGoStraightToCoord(pedHandle, standingLocation - vector3(0.0, 0.0, 0.985), 1.0, 10000, standingHeading, 2.0)
    end

    GlobalFunction("MEDIC_UNAVAILABLE", {
        Medic = medicIndex,
        Bool = false
    })

    DetachEntity(Heap.Ped, true, true)

    DeleteEntity(pedHandle)

    CleanupModels({
        medic.Hash
    })

    BedThread(medicIndex, bed, bedHandle)
end

BedThread = function(medicIndex, bed, bedHandle)
    Heap.InBed = GetGameTimer()

    local standingLocation = bed.Location
    local standingHeading = bed.Heading

    if DoesEntityExist(bedHandle) then
        standingLocation = GetOffsetFromEntityInWorldCoords(bedHandle, vector3(0.0, -2.0, 0.0))
        standingHeading = GetEntityHeading(bedHandle)
    end

    SetEntityCoords(Heap.Ped, bed.Location - vector3(0.0, 0.0, 0.985))
    SetEntityHeading(Heap.Ped, bed.Heading)

    Citizen.Wait(500)

    PlayAnimation(Heap.Ped, "dead", "dead_a", {
        flag = 1
    })

    while GetGameTimer() - Heap.InBed < Default.HelpTime do
        Citizen.Wait(0)

        DisableAllControlActions(0)

        local timePercent = math.floor((GetGameTimer() - Heap.InBed) / Default.HelpTime * 100)

        DisableFControls()

        DrawScriptText(bed.Location, "~b~Лекуване...~s~ " .. timePercent .. "%")
    end

    SetEntityCoordsNoOffset(Heap.Ped, standingLocation, false, false, false, true)
    SetEntityHeading(Heap.Ped, standingHeading - 180.0)
    SetPlayerInvincible(PlayerId(), false)

    SetEntityHealth(Heap.Ped, GetEntityMaxHealth(Heap.Ped))

    TriggerServerEvent("esx_ambulancejob:setDeathStatus", false)
    TriggerServerEvent("chames_ambulance_medic:removeMoney", medicIndex)

    -- Here would you add all events that would remove damage if you have any custom resource handling that.

    --Heap.ESX.ShowNotification("Вие бяхте излекуван !")
    exports['mythic_notify']:DoHudText('inform', 'Вие бяхте излекуван !')
end

TreatPlayer = function()
    StopScreenEffect("DeathFailOut")
    NetworkResurrectLocalPlayer(GetEntityCoords(Heap.Ped) - vector3(0.0, 0.0, 0.985), 180.0, true, false)
    SetPlayerInvincible(PlayerId(), false)
    ClearPedBloodDamage(Heap.Ped)

	TriggerServerEvent("esx:onPlayerSpawn")
	TriggerEvent("esx:onPlayerSpawn")
	TriggerEvent("playerSpawned")
end

SpawnMedics = function()
    Heap.Peds = {}

    for pedIndex, pedData in ipairs(Medics) do
        LoadModels({ pedData.Hash })

        local pedHandle = CreatePed(5, pedData.Hash, pedData.Location - vector3(0.0, 0.0, 0.985), pedData.Heading, false)

        SetEntityAsMissionEntity(pedHandle, true, true)
        SetBlockingOfNonTemporaryEvents(pedHandle, true)
        SetPedDefaultComponentVariation(pedHandle)

        PlayAnimation(pedHandle, "amb@code_human_cross_road@female@idle_a", math.random(5) > 2 and "idle_a" or "idle_b", {
            flag = 11
        })

        table.insert(Heap.Peds, {
            Index = pedIndex,
            Data = pedData,
            Handle = pedHandle
        })

        

        

        CleanupModels({
            pedData.Hash
        })
    end
end

GetPed = function(pedIndex)
    for _, ped in ipairs(Heap.Peds) do
        if ped.Index == pedIndex then
            return ped
        end
    end

    return false
end

DrawButtons = function(buttonsToDraw)
	local instructionScaleform = RequestScaleformMovie("instructional_buttons")

	while not HasScaleformMovieLoaded(instructionScaleform) do
		Wait(0)
	end

	PushScaleformMovieFunction(instructionScaleform, "CLEAR_ALL")
	PushScaleformMovieFunction(instructionScaleform, "TOGGLE_MOUSE_BUTTONS")
	PushScaleformMovieFunctionParameterBool(0)
	PopScaleformMovieFunctionVoid()

	for buttonIndex, buttonValues in ipairs(buttonsToDraw) do
		PushScaleformMovieFunction(instructionScaleform, "SET_DATA_SLOT")
		PushScaleformMovieFunctionParameterInt(buttonIndex - 1)

		PushScaleformMovieMethodParameterButtonName(buttonValues["button"])
		PushScaleformMovieFunctionParameterString(buttonValues["label"])
		PopScaleformMovieFunctionVoid()
	end

	PushScaleformMovieFunction(instructionScaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
	PushScaleformMovieFunctionParameterInt(-1)
	PopScaleformMovieFunctionVoid()
	DrawScaleformMovieFullscreen(instructionScaleform, 255, 255, 255, 255)
end

DrawBusySpinner = function(text)
    SetLoadingPromptTextEntry("STRING")
    AddTextComponentSubstringPlayerName(text)
    ShowLoadingPrompt(3)
end

PlayAnimation = function(ped, dict, anim, settings)
	if dict then
        RequestAnimDict(dict)

        while not HasAnimDictLoaded(dict) do
            Citizen.Wait(0)
        end

        if settings == nil then
            TaskPlayAnim(ped, dict, anim, 1.0, -1.0, 1.0, 0, 0, 0, 0, 0)
        else 
            local speed = 1.0
            local speedMultiplier = -1.0
            local duration = 1.0
            local flag = 0
            local playbackRate = 0

            if settings["speed"] then
                speed = settings["speed"]
            end

            if settings["speedMultiplier"] then
                speedMultiplier = settings["speedMultiplier"]
            end

            if settings["duration"] then
                duration = settings["duration"]
            end

            if settings["flag"] then
                flag = settings["flag"]
            end

            if settings["playbackRate"] then
                playbackRate = settings["playbackRate"]
            end

            TaskPlayAnim(ped, dict, anim, speed, speedMultiplier, duration, flag, playbackRate, 0, 0, 0)

            while not IsEntityPlayingAnim(ped, dict, anim, 3) do
                Citizen.Wait(0)
            end
        end
    
        RemoveAnimDict(dict)
	else
		TaskStartScenarioInPlace(ped, anim, 0, true)
	end
end

LoadModels = function(models)
	for index, model in ipairs(models) do
		if IsModelValid(model) then
			while not HasModelLoaded(model) do
				RequestModel(model)
	
				Citizen.Wait(10)
			end
		else
			while not HasAnimDictLoaded(model) do
				RequestAnimDict(model)
	
				Citizen.Wait(10)
			end    
		end
	end
end

CleanupModels = function(models)
	for index, model in ipairs(models) do
		if IsModelValid(model) then
			SetModelAsNoLongerNeeded(model)
		else
			RemoveAnimDict(model)  
		end
	end
end

DrawScriptMarker = function(markerData)
    DrawMarker(markerData["type"] or 1, markerData["pos"] or vector3(0.0, 0.0, 0.0), 0.0, 0.0, 0.0, (markerData["type"] == 6 and -90.0 or markerData["rotate"] and -180.0) or 0.0, 0.0, 0.0, markerData["size"] or vector3(1.0, 1.0, 1.0), markerData["rgb"] or vector3(255, 255, 255), 100, markerData["bob"] and true or false, true, 2, false, false, false, false)
end

DrawScriptText = function(coords, text)
    local onScreen, _x, _y = World3dToScreen2d(coords.x, coords.y, coords.z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)

    local factor = (string.len(text)) / 370

    DrawRect(_x, _y + 0.0125, 0.015 + factor, 0.03, 41, 11, 41, 68)
end

_TaskGoStraightToCoord = function(ped, coords, speed, timeout, heading, distanceToSlide)
    TaskGoStraightToCoord(ped, coords.x, coords.y, coords.z, speed, timeout, heading, distanceToSlide)

    while GetScriptTaskStatus(ped, 0x7d8f4411) ~= 7 do
        Citizen.Wait(0)
    end

    return true
end

ClaimNetwork = function(handle)
    local timeout = 0

    NetworkRequestControlOfEntity(handle)

    while not NetworkHasControlOfEntity(handle) or timeout > 250 do
        Citizen.Wait(0)

        timeout = timeout + 1
    end
end

OpenInput = function(label, type)
	AddTextEntry(type, label)

	DisplayOnscreenKeyboard(1, type, "", "", "", "", "", 30)

	while UpdateOnscreenKeyboard() == 0 do
		DisableAllControlActions(0)
		Wait(0)
	end

	if GetOnscreenKeyboardResult() then
	  	return GetOnscreenKeyboardResult()
	end
end

DisableFControls = function()
    DisableControlAction(0, 69, true) -- INPUT_VEH_ATTACK
    DisableControlAction(0, 92, true) -- INPUT_VEH_PASSENGER_ATTACK
    DisableControlAction(0, 114, true) -- INPUT_VEH_FLY_ATTACK
    DisableControlAction(0, 140, true) -- INPUT_MELEE_ATTACK_LIGHT
    DisableControlAction(0, 141, true) -- INPUT_MELEE_ATTACK_HEAVY
    DisableControlAction(0, 142, true) -- INPUT_MELEE_ATTACK_ALTERNATE
    DisableControlAction(0, 257, true) -- INPUT_ATTACK2
    DisableControlAction(0, 263, true) -- INPUT_MELEE_ATTACK1
    DisableControlAction(0, 264, true) -- INPUT_MELEE_ATTACK2
    DisableControlAction(0, 24, true) -- INPUT_ATTACK
    DisableControlAction(0, 25, true) -- INPUT_AIM
    DisableControlAction(0, 21, true) -- SHIFT
    DisableControlAction(0, 22, true) -- SPACE
    DisableControlAction(0, 288, true) -- F1
    DisableControlAction(0, 289, true) -- F2
    DisableControlAction(0, 170, true) -- F3
    DisableControlAction(0, 167, true) -- F6
    DisableControlAction(0, 168, true) -- F7
    DisableControlAction(0, 57, true) -- F10
    DisableControlAction(0, 71, true) -- W
    DisableControlAction(0, 72, true) -- S
    DisableControlAction(0, 73, true) -- X
    DisableControlAction(0, 63, true) -- A
    DisableControlAction(0, 64, true) -- D
end