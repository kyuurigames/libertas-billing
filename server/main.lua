local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS billing_system (
            id INT AUTO_INCREMENT PRIMARY KEY,
            sender_citizenid VARCHAR(50) NOT NULL,
            receiver_citizenid VARCHAR(50) NOT NULL,
            amount INT NOT NULL,
            reason TEXT NOT NULL,
            status ENUM('unpaid', 'paid') DEFAULT 'unpaid',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            paid_at TIMESTAMP NULL,
            due_date TIMESTAMP NOT NULL,
            INDEX idx_receiver (receiver_citizenid),
            INDEX idx_sender (sender_citizenid),
            INDEX idx_status (status)
        )
    ]])
end)

function DateStringToTimestamp(dateValue)
    if type(dateValue) == "number" then
        return dateValue
    end

    if type(dateValue) ~= "string" then
        return 0
    end
    
    local year, month, day, hour, min, sec = dateValue:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    if year and month and day and hour and min and sec then
        return os.time({
            year = tonumber(year),
            month = tonumber(month),
            day = tonumber(day),
            hour = tonumber(hour),
            min = tonumber(min),
            sec = tonumber(sec)
        })
    end
    return 0
end

function IsOverdue(dueDate, status)
    if status ~= 'unpaid' then
        return false
    end
    
    local dueDateTimestamp = DateStringToTimestamp(dueDate)
    local currentTime = os.time()
    
    return currentTime > dueDateTimestamp
end

RegisterNetEvent('billing:server:createBill', function(targetId, amount, reason)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications['invalid_player'], 'error')
        return
    end
    
    if amount < Config.MinBillAmount or amount > Config.MaxBillAmount then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications['invalid_amount'], 'error')
        return
    end

    local currentTime = os.time()
    local deadlineTime = currentTime + (Config.PaymentDeadline * 24 * 60 * 60)
    local dueDate = os.date('%Y-%m-%d %H:%M:%S', deadlineTime)
    
    if Config.Debug then
        print('[BILLING] Current time: ' .. os.date('%Y-%m-%d %H:%M:%S', currentTime))
        print('[BILLING] Deadline: ' .. dueDate)
        print('[BILLING] Days added: ' .. Config.PaymentDeadline)
    end
    
    MySQL.insert('INSERT INTO billing_system (sender_citizenid, receiver_citizenid, amount, reason, due_date) VALUES (?, ?, ?, ?, ?)', {
        Player.PlayerData.citizenid,
        TargetPlayer.PlayerData.citizenid,
        amount,
        reason,
        dueDate
    }, function(insertId)
        if insertId then
            TriggerClientEvent('billing:client:billCreated', src)
            TriggerClientEvent('billing:client:billReceived', TargetPlayer.PlayerData.source, {
                id = insertId,
                amount = amount,
                reason = reason,
                sender = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
            })
        end
    end)
end)

RegisterNetEvent('billing:server:payBill', function(billId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    MySQL.single('SELECT * FROM billing_system WHERE id = ? AND receiver_citizenid = ? AND status = "unpaid"', {
        billId,
        Player.PlayerData.citizenid
    }, function(bill)
        if not bill then
            TriggerClientEvent('QBCore:Notify', src, Config.Notifications['bill_not_found'], 'error')
            return
        end
        
        local amount = bill.amount
        local playerMoney = Player.Functions.GetMoney('bank')
        
        if playerMoney < amount then
            TriggerClientEvent('QBCore:Notify', src, Config.Notifications['insufficient_funds'], 'error')
            return
        end

        Player.Functions.RemoveMoney('bank', amount, '請求書支払い')
        
        local SenderPlayer = QBCore.Functions.GetPlayerByCitizenId(bill.sender_citizenid)
        if SenderPlayer then
            SenderPlayer.Functions.AddMoney('bank', amount, '請求書支払い受取')
            TriggerClientEvent('billing:client:paymentReceived', SenderPlayer.PlayerData.source, amount, Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname)
        else
            MySQL.update('UPDATE players SET money = JSON_SET(money, "$.bank", JSON_EXTRACT(money, "$.bank") + ?) WHERE citizenid = ?', {
                amount,
                bill.sender_citizenid
            })
        end
        
        MySQL.update('UPDATE billing_system SET status = "paid", paid_at = NOW() WHERE id = ?', {
            billId
        }, function(affectedRows)
            if affectedRows > 0 then
                TriggerClientEvent('billing:client:billPaid', src)
            end
        end)
    end)
end)

QBCore.Functions.CreateCallback('billing:server:getBills', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end
    
    MySQL.query([[
        SELECT b.*, 
               UNIX_TIMESTAMP(b.due_date) as due_date_timestamp,
               UNIX_TIMESTAMP(b.created_at) as created_at_timestamp,
               UNIX_TIMESTAMP(b.paid_at) as paid_at_timestamp,
               sender_player.charinfo AS sender_charinfo,
               receiver_player.charinfo AS receiver_charinfo
        FROM billing_system b
        LEFT JOIN players sender_player ON BINARY b.sender_citizenid = BINARY sender_player.citizenid
        LEFT JOIN players receiver_player ON BINARY b.receiver_citizenid = BINARY receiver_player.citizenid
        WHERE BINARY b.sender_citizenid = BINARY ? OR BINARY b.receiver_citizenid = BINARY ?
        ORDER BY b.created_at DESC
    ]], {
        Player.PlayerData.citizenid,
        Player.PlayerData.citizenid
    }, function(bills)
        local formattedBills = {}
        
        for _, bill in pairs(bills) do
            local senderCharinfo = json.decode(bill.sender_charinfo or '{}')
            local receiverCharinfo = json.decode(bill.receiver_charinfo or '{}')
            
            -- デバッグ情報
            if Config.Debug then
                print('[BILLING DEBUG] due_date type: ' .. type(bill.due_date))
                print('[BILLING DEBUG] due_date value: ' .. tostring(bill.due_date))
            end
            
            table.insert(formattedBills, {
                id = bill.id,
                amount = bill.amount,
                reason = bill.reason,
                status = bill.status,
                created_at = bill.created_at,
                paid_at = bill.paid_at,
                due_date = bill.due_date,
                sender_name = (senderCharinfo.firstname or '') .. ' ' .. (senderCharinfo.lastname or ''),
                receiver_name = (receiverCharinfo.firstname or '') .. ' ' .. (receiverCharinfo.lastname or ''),
                is_sender = bill.sender_citizenid == Player.PlayerData.citizenid,
                is_overdue = bill.status == 'unpaid' and os.time() > (bill.due_date_timestamp or 0)
            })
        end
        
        cb(formattedBills)
    end)
end)

QBCore.Functions.CreateCallback('billing:server:getNearbyPlayers', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end
    
    local players = {}
    local playerPed = GetPlayerPed(source)
    
    if not playerPed or playerPed == 0 then
        cb({})
        return
    end
    
    local playerCoords = GetEntityCoords(playerPed)
    
    for _, player in pairs(QBCore.Functions.GetQBPlayers()) do
        if player.PlayerData.source ~= source then
            local targetPed = GetPlayerPed(player.PlayerData.source)
            
            if targetPed and targetPed ~= 0 then
                local targetCoords = GetEntityCoords(targetPed)
                local distance = #(playerCoords - targetCoords)
                
                if distance <= Config.NearbyPlayerDistance then
                    table.insert(players, {
                        id = player.PlayerData.source,
                        name = (player.PlayerData.charinfo.firstname or '') .. ' ' .. (player.PlayerData.charinfo.lastname or ''),
                        citizenid = player.PlayerData.citizenid,
                        distance = math.floor(distance * 100) / 100
                    })
                end
            end
        end
    end
    
    table.sort(players, function(a, b) return a.distance < b.distance end)
    
    cb(players)
end)

QBCore.Functions.CreateCallback('billing:server:getUnpaidBills', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb({})
        return
    end

    local isPolice = false
    for _, job in pairs(Config.PoliceJobs) do
        if Player.PlayerData.job.name == job then
            isPolice = true
            break
        end
    end

    local isAdmin = false
    
    if Config.AdminJobs then
        for _, job in pairs(Config.AdminJobs) do
            if Player.PlayerData.job.name == job then
                isAdmin = true
                break
            end
        end
    end
    
    if not isAdmin and Player.PlayerData.metadata and Player.PlayerData.metadata.group then
        for _, group in pairs(Config.AdminGroups) do
            if Player.PlayerData.metadata.group == group then
                isAdmin = true
                break
            end
        end
    end
    
    if not isPolice and not isAdmin then
        TriggerClientEvent('QBCore:Notify', source, Config.Notifications['no_permission'], 'error')
        cb({})
        return
    end
    
    MySQL.query([[
        SELECT b.*, 
               UNIX_TIMESTAMP(b.due_date) as due_date_timestamp,
               UNIX_TIMESTAMP(b.created_at) as created_at_timestamp,
               sender_player.charinfo AS sender_charinfo,
               receiver_player.charinfo AS receiver_charinfo
        FROM billing_system b
        LEFT JOIN players sender_player ON BINARY b.sender_citizenid = BINARY sender_player.citizenid
        LEFT JOIN players receiver_player ON BINARY b.receiver_citizenid = BINARY receiver_player.citizenid
        WHERE b.status = 'unpaid'
        ORDER BY b.due_date ASC
    ]], {}, function(bills)
        local formattedBills = {}
        
        for _, bill in pairs(bills) do
            local senderCharinfo = json.decode(bill.sender_charinfo or '{}')
            local receiverCharinfo = json.decode(bill.receiver_charinfo or '{}')
            
            table.insert(formattedBills, {
                id = bill.id,
                amount = bill.amount,
                reason = bill.reason,
                created_at = bill.created_at,
                due_date = bill.due_date,
                sender_name = (senderCharinfo.firstname or '') .. ' ' .. (senderCharinfo.lastname or ''),
                receiver_name = (receiverCharinfo.firstname or '') .. ' ' .. (receiverCharinfo.lastname or ''),
                is_overdue = bill.status == 'unpaid' and os.time() > (bill.due_date_timestamp or 0)
            })
        end
        
        cb(formattedBills)
    end)
end)

RegisterNetEvent('billing:server:checkPlayerBills', function(targetId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local TargetPlayer = QBCore.Functions.GetPlayer(targetId)
    
    if not Player or not TargetPlayer then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications['invalid_player'], 'error')
        return
    end
    
    local isPolice = false
    for _, job in pairs(Config.PoliceJobs) do
        if Player.PlayerData.job.name == job then
            isPolice = true
            break
        end
    end
    
    local isAdmin = false
    if Config.AdminJobs then
        for _, job in pairs(Config.AdminJobs) do
            if Player.PlayerData.job.name == job then
                isAdmin = true
                break
            end
        end
    end
    
    if not isAdmin and Player.PlayerData.metadata and Player.PlayerData.metadata.group then
        for _, group in pairs(Config.AdminGroups) do
            if Player.PlayerData.metadata.group == group then
                isAdmin = true
                break
            end
        end
    end
    
    if not isPolice and not isAdmin then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications['no_permission'], 'error')
        return
    end
    
    local playerPed = GetPlayerPed(src)
    local targetPed = GetPlayerPed(targetId)
    local distance = #(GetEntityCoords(playerPed) - GetEntityCoords(targetPed))
    
    if distance > Config.NearbyPlayerDistance then
        TriggerClientEvent('QBCore:Notify', src, Config.Notifications['player_too_far'], 'error')
        return
    end
    
    MySQL.query([[
        SELECT b.*, 
               UNIX_TIMESTAMP(b.due_date) as due_date_timestamp,
               UNIX_TIMESTAMP(b.created_at) as created_at_timestamp,
               UNIX_TIMESTAMP(b.paid_at) as paid_at_timestamp,
               sender_player.charinfo AS sender_charinfo
        FROM billing_system b
        LEFT JOIN players sender_player ON BINARY b.sender_citizenid = BINARY sender_player.citizenid
        WHERE BINARY b.receiver_citizenid = BINARY ?
        ORDER BY b.created_at DESC
    ]], {
        TargetPlayer.PlayerData.citizenid
    }, function(bills)
        local formattedBills = {}
        
        for _, bill in pairs(bills) do
            local senderCharinfo = json.decode(bill.sender_charinfo or '{}')
            
            table.insert(formattedBills, {
                id = bill.id,
                amount = bill.amount,
                reason = bill.reason,
                status = bill.status,
                created_at = bill.created_at,
                paid_at = bill.paid_at,
                due_date = bill.due_date,
                sender_name = (senderCharinfo.firstname or '') .. ' ' .. (senderCharinfo.lastname or ''),
                is_overdue = bill.status == 'unpaid' and os.time() > (bill.due_date_timestamp or 0)
            })
        end
        
        local targetName = TargetPlayer.PlayerData.charinfo.firstname .. ' ' .. TargetPlayer.PlayerData.charinfo.lastname
        TriggerClientEvent('billing:client:playerBillsInfo', src, targetName, formattedBills)
    end)
end)

CreateThread(function()
    while true do
        Wait(Config.OverdueNotificationInterval * 60 * 1000)
        
        MySQL.query([[
            SELECT receiver_citizenid, COUNT(*) as count
            FROM billing_system 
            WHERE status = 'unpaid' AND due_date < NOW()
            GROUP BY receiver_citizenid
        ]], {}, function(overdueData)
            for _, data in pairs(overdueData) do
                local Player = QBCore.Functions.GetPlayerByCitizenId(data.receiver_citizenid)
                if Player then
                    TriggerClientEvent('billing:client:overdueReminder', Player.PlayerData.source, data.count)
                end
            end
        end)
    end
end)
