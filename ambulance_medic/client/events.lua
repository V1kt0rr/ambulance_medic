RegisterNetEvent("esx:playerLoaded")
AddEventHandler("esx:playerLoaded", function(response)
    Heap.ESX.PlayerData = response
end)

RegisterNetEvent("chames_ambulance_medic:eventHandler")
AddEventHandler("chames_ambulance_medic:eventHandler", function(event, eventData)
    Trace(event, json.encode(eventData))

    if event == "MEDIC_UNAVAILABLE" then
        Heap.Medics[eventData.Medic] = eventData.Bool

        local ped = GetPed(eventData.Medic)

        if ped then
            SetEntityVisible(ped.Handle, not eventData.Bool)
        end
    elseif event == "SYNC_ANIMATION" then
        if not NetworkDoesNetworkIdExist(eventData.Ped) then
            return
        end

        local pedHandle = NetToPed(eventData.Ped)

        if DoesEntityExist(pedHandle) then
            PlayAnimation(pedHandle, "anim@heists@box_carry@", "idle", {
                flag = 49
            })
        end
    end
end)

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        for _, pedData in pairs(Heap.Peds) do
            if DoesEntityExist(pedData.Handle) then
                DeleteEntity(pedData.Handle)
            end
        end
    end
end)