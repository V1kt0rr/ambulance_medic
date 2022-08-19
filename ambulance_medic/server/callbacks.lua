Citizen.CreateThread(function()
    Heap.ESX.RegisterServerCallback("chames_ambulance_medic:requiredAmount", function(source, callback)
        local character = Heap.ESX.GetPlayerFromId(source)

        if not character then return callback(false) end

        local playersInJob = GetPlayersWithJob("ambulance")

        callback(playersInJob <= 0)
    end)
end)