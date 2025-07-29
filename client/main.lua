local QBCore = exports['qb-core']:GetCoreObject()
local isNUIOpen = false

RegisterKeyMapping(Config.KeyMappingName, '請求書システムを開く', 'keyboard', Config.OpenKey)

RegisterCommand(Config.KeyMappingName, function()
    if not isNUIOpen then
        OpenBillingNUI()
    end
end, false)

function OpenBillingNUI()
    local PlayerData = QBCore.Functions.GetPlayerData()
    
    if not PlayerData then return end
    
    if isNUIOpen then return end
    
    isNUIOpen = true
    SetNuiFocus(true, true)

    SendNUIMessage({
        action = 'openUI',
        resourceName = GetCurrentResourceName(),
        playerData = {
            citizenid = PlayerData.citizenid,
            name = PlayerData.charinfo.firstname .. ' ' .. PlayerData.charinfo.lastname,
            job = PlayerData.job.name,
            isPolice = IsPolice(PlayerData.job.name),
            isAdmin = IsAdmin()
        }
    })

    QBCore.Functions.TriggerCallback('billing:server:getBills', function(bills)
        SendNUIMessage({
            action = 'loadBills',
            bills = bills
        })
    end)
end

function CloseBillingNUI()
    isNUIOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'closeUI'
    })
end

function IsPolice(job)
    for _, policeJob in pairs(Config.PoliceJobs) do
        if job == policeJob then
            return true
        end
    end
    return false
end

function IsAdmin()
    local PlayerData = QBCore.Functions.GetPlayerData()
    if not PlayerData then return false end
    
    if Config.AdminJobs then
        for _, job in pairs(Config.AdminJobs) do
            if PlayerData.job and PlayerData.job.name == job then
                return true
            end
        end
    end
    
    if PlayerData.metadata and PlayerData.metadata.group then
        for _, group in pairs(Config.AdminGroups) do
            if PlayerData.metadata.group == group then
                return true
            end
        end
    end

    
    return false
end

function GetNearbyPlayers()
    local players = {}
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= PlayerId() then
            local targetPed = GetPlayerPed(playerId)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(playerCoords - targetCoords)
            
            if distance <= Config.NearbyPlayerDistance then
                local serverId = GetPlayerServerId(playerId)
                local playerName = GetPlayerName(playerId)
                
                if playerName and serverId then
                    table.insert(players, {
                        id = serverId,
                        name = playerName,
                        distance = math.floor(distance * 100) / 100
                    })
                end
            end
        end
    end

    table.sort(players, function(a, b) return a.distance < b.distance end)
    
    return players
end

function CheckNearbyPlayerBills(targetId)
    TriggerServerEvent('billing:server:checkPlayerBills', targetId)
end

RegisterNUICallback('closeBilling', function(data, cb)
    CloseBillingNUI()
    cb('ok')
end)

RegisterNUICallback('createBill', function(data, cb)
    local amount = tonumber(data.amount)
    local reason = data.reason
    local targetId = tonumber(data.targetId)
    
    if not amount or amount < Config.MinBillAmount or amount > Config.MaxBillAmount then
        QBCore.Functions.Notify(Config.Notifications['invalid_amount'], 'error')
        cb('error')
        return
    end
    
    if not reason or reason == '' then
        QBCore.Functions.Notify('理由を入力してください', 'error')
        cb('error')
        return
    end
    
    TriggerServerEvent('billing:server:createBill', targetId, amount, reason)
    cb('ok')
end)

RegisterNUICallback('payBill', function(data, cb)
    local billId = tonumber(data.billId)
    TriggerServerEvent('billing:server:payBill', billId)
    cb('ok')
end)

RegisterNUICallback('refreshBills', function(data, cb)
    QBCore.Functions.TriggerCallback('billing:server:getBills', function(bills)
        SendNUIMessage({
            action = 'loadBills',
            bills = bills
        })
    end)
    cb('ok')
end)

RegisterNUICallback('getUnpaidBills', function(data, cb)
    QBCore.Functions.TriggerCallback('billing:server:getUnpaidBills', function(bills)
        cb(bills)
    end)
end)

RegisterNUICallback('getNearbyPlayers', function(data, cb)
    QBCore.Functions.TriggerCallback('billing:server:getNearbyPlayers', function(players)
        cb(players)
    end)
end)

RegisterNUICallback('checkPlayerBills', function(data, cb)
    local targetId = tonumber(data.targetId)
    if targetId then
        CheckNearbyPlayerBills(targetId)
    end
    cb('ok')
end)

RegisterNetEvent('billing:client:billCreated', function()
    QBCore.Functions.Notify(Config.Notifications['bill_sent'], 'success')

    if isNUIOpen then
        QBCore.Functions.TriggerCallback('billing:server:getBills', function(bills)
            SendNUIMessage({
                action = 'loadBills',
                bills = bills
            })
        end)
    end
end)

RegisterNetEvent('billing:client:billReceived', function(bill)
    QBCore.Functions.Notify(Config.Notifications['bill_received'], 'primary', 5000)

    if isNUIOpen then
        QBCore.Functions.TriggerCallback('billing:server:getBills', function(bills)
            SendNUIMessage({
                action = 'loadBills',
                bills = bills
            })
        end)
    end
end)

RegisterNetEvent('billing:client:billPaid', function()
    QBCore.Functions.Notify(Config.Notifications['bill_paid'], 'success')
    if isNUIOpen then
        QBCore.Functions.TriggerCallback('billing:server:getBills', function(bills)
            SendNUIMessage({
                action = 'loadBills',
                bills = bills
            })
        end)
    end
end)

RegisterNetEvent('billing:client:paymentReceived', function(amount, from)
    QBCore.Functions.Notify(from .. 'から' .. amount .. '円の支払いを受け取りました', 'success')
    if isNUIOpen then
        QBCore.Functions.TriggerCallback('billing:server:getBills', function(bills)
            SendNUIMessage({
                action = 'loadBills',
                bills = bills
            })
        end)
    end
end)

RegisterNetEvent('billing:client:overdueReminder', function(count)
    QBCore.Functions.Notify('未払いの請求書が' .. count .. '件あります', 'error', 5000)
end)

RegisterNetEvent('billing:client:playerBillsInfo', function(playerName, bills)
    if isNUIOpen then
        SendNUIMessage({
            action = 'showPlayerBills',
            playerName = playerName,
            bills = bills
        })
    else
        local unpaidCount = 0
        local totalAmount = 0
        
        for _, bill in pairs(bills) do
            if bill.status == 'unpaid' then
                unpaidCount = unpaidCount + 1
                totalAmount = totalAmount + bill.amount
            end
        end
        
        if unpaidCount > 0 then
            TriggerEvent('chat:addMessage', {
                color = { 255, 0, 0 },
                multiline = true,
                args = { "請求書確認", playerName .. "の未払い請求書: " .. unpaidCount .. "件 (合計: ¥" .. totalAmount .. ")" }
            })
        else
            TriggerEvent('chat:addMessage', {
                color = { 0, 255, 0 },
                multiline = true,
                args = { "請求書確認", playerName .. "には未払い請求書はありません" }
            })
        end
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if isNUIOpen then
            CloseBillingNUI()
        end
    end
end)