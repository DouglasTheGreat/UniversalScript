-- ==========================================
-- CONFIGURATION
-- ==========================================
local WEBHOOK_URL = "" -- Paste your Discord Webhook URL here
local SEND_WEBHOOKS = true 
-- ==========================================

if not game:IsLoaded() then pcall(function() game.Loaded:Wait() end) end

local player = game.Players.LocalPlayer
local http = game:GetService("HttpService")
local replicated = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local vim = game:GetService("VirtualInputManager")
local cam = workspace.CurrentCamera

-- 🕒 PERSISTENT TIMER (Fixed for Rejoin)
if not _G.SessionStart then
    _G.SessionStart = os.time()
end

if _G.DB_RUNNING_GLOBAL then return end
_G.DB_RUNNING_GLOBAL = true

-- 🌐 WEBHOOK FUNCTION
local function sendWebhook(title, desc, color)
    if not SEND_WEBHOOKS or WEBHOOK_URL == "" then return end
    
    local rebs = "0"
    -- Expanded search for Rebirths/Stats
    local stats = player:FindFirstChild("leaderstats") or player:FindFirstChild("Data") or replicated:WaitForChild("Datas"):FindFirstChild(tostring(player.UserId))
    if stats then
        local r = stats:FindFirstChild("Rebirths") or stats:FindFirstChild("Rebirth")
        if r then rebs = tostring(r.Value) end
    end

    local data = {
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = desc .. "\n\n**Current Rebirths:** " .. rebs,
            ["color"] = color or 16753920,
            ["footer"] = {["text"] = "Dragon Ball Auto-Farm • " .. os.date("%X")}
        }}
    }
    
    pcall(function()
        local req = (syn and syn.request) or (http_request) or request
        if req then
            req({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = http:JSONEncode(data)
            })
        end
    end)
end

-- 🖱️ INPUT
local function tap(x, y)
    pcall(function()
        vim:SendMouseButtonEvent(x, y, 0, true, game, 0)
        vim:SendMouseButtonEvent(x, y, 0, false, game, 0)
        vim:SendTouchEvent(1, Enum.UserInputState.Begin, x, y)
        vim:SendTouchEvent(1, Enum.UserInputState.End, x, y)
    end)
end

-- 📊 THE HUD
local function createHighVisGUI()
    local old = player.PlayerGui:FindFirstChild("DB_HUD")
    if old then old:Destroy() end
    local gui = Instance.new("ScreenGui", player.PlayerGui)
    gui.Name = "DB_HUD"
    gui.ResetOnSpawn = false
    local mainFrame = Instance.new("Frame", gui)
    mainFrame.Size = UDim2.new(0, 210, 0, 260) 
    mainFrame.Position = UDim2.new(0, 15, 0.1, 0)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    mainFrame.BackgroundTransparency = 0.1
    mainFrame.BorderSizePixel = 0
    Instance.new("UICorner", mainFrame)
    local title = Instance.new("TextLabel", mainFrame)
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Text = "DB TRACKER"
    title.TextColor3 = Color3.new(1,1,1)
    title.Font = Enum.Font.SourceSansBold
    title.TextSize = 20
    title.BackgroundTransparency = 1
    local content = Instance.new("TextLabel", mainFrame)
    content.Size = UDim2.new(1, -25, 1, -85)
    content.Position = UDim2.new(0, 15, 0, 45)
    content.BackgroundTransparency = 1
    content.TextColor3 = Color3.new(1, 1, 1)
    content.Font = Enum.Font.Code
    content.TextSize = 16 
    content.TextXAlignment = Enum.TextXAlignment.Left
    content.TextYAlignment = Enum.TextYAlignment.Top
    content.RichText = true
    local status = Instance.new("TextLabel", mainFrame)
    status.Size = UDim2.new(1, 0, 0, 40)
    status.Position = UDim2.new(0, 0, 1, -40)
    status.BackgroundColor3 = Color3.fromRGB(255, 140, 0)
    status.TextColor3 = Color3.new(0, 0, 0)
    status.Font = Enum.Font.SourceSansBold
    status.TextSize = 16
    status.Text = "LOADING..."
    return content, status
end

local hudContent, hudStatus = createHighVisGUI()

-- 🔄 THE RELIABLE REJOIN
local function refresh(reason)
    hudStatus.Text = "REFRESHING..."
    task.wait(0.5)
    
    -- We use standard Kick to trigger the rejoin loop
    pcall(function() player:Kick("\n[AUTO-REFRESH]\n" .. reason) end)
    
    task.wait(2)
    
    -- Force Rejoin Loop (This works on all executors)
    while true do
        pcall(function() 
            TeleportService:Teleport(game.PlaceId, player)
        end)
        task.wait(2)
    end
end

-- 🐉 HUNTING LOGIC
local function runFarm()
    local userId = tostring(player.UserId)
    local dataRoot = replicated:WaitForChild("Datas", 20)
    local myData = dataRoot and dataRoot:WaitForChild(userId, 20)
    if not myData then refresh("Data Fail") return end

    task.spawn(function()
        while task.wait(1) do
            local str = ""
            local count = 0
            for i = 1, 7 do
                local has = myData:FindFirstChild(i.."Star") and myData[i.."Star"].Value
                if has then
                    str = str .. '<font color="rgb(255,215,0)">⭐ Star '..i..'</font>\n'
                    count += 1
                else
                    str = str .. '<font color="rgb(80,80,80)">⚫ Star '..i..'</font>\n'
                end
            end
            hudContent.Text = str
            hudStatus.Text = (count == 7 and "READY!" or "HUNTING: "..count.."/7")
        end
    end)

    local function collect(obj)
        local num = obj.Name:match("^(%d)StarDb$")
        if not num then return end
        local key = num.."Star"
        if myData[key].Value == true then refresh("Duplicate") return end

        hudStatus.Text = "TARGETING: " .. num .. "*"
        local startTry = tick()
        while myData[key].Value == false and (tick() - startTry) < 15 do
            local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if hrp and obj:IsDescendantOf(workspace) then
                hrp.CFrame = obj:GetPivot() * CFrame.new(0, 3, 0)
                local screen, vis = cam:WorldToViewportPoint(obj:GetPivot().Position)
                if vis then tap(screen.X, screen.Y) end
            end
            task.wait(0.8)
        end

        if myData[key].Value == true then
            sendWebhook("Ball Found", "Collected the **" .. num .. " Star Ball**.", 5754855)
            
            local count = 0
            for i=1,7 do if myData[i.."Star"].Value then count += 1 end end
            if count == 7 then
                local duration = os.time() - _G.SessionStart
                local minutes = math.floor(duration / 60)
                local seconds = duration % 60
                
                hudStatus.Text = "SUMMONING..."
                sendWebhook("🐉 SHENRON SUMMONED", "Full set achieved!\n**Total Session Time:** " .. minutes .. "m " .. seconds .. "s", 16711680)
                
                replicated.Events.Summon:FireServer(2)
                task.wait(8)
                _G.SessionStart = os.time() -- Reset timer ONLY after successful summon
                refresh("Wish Complete!")
            else
                refresh("Server Cleaned")
            end
        end
    end

    workspace.DescendantAdded:Connect(function(v) if v.Name:match("^%dStarDb$") then collect(v) end end)
    for _, v in pairs(workspace:GetDescendants()) do if v.Name:match("^%dStarDb$") then task.spawn(collect, v) end end
end

-- Auto-Play Bypass
task.spawn(function()
    local pGui = player:WaitForChild("PlayerGui", 20)
    for i = 1, 30 do
        for _, v in pairs(pGui:GetDescendants()) do
            if v:IsA("TextButton") and v.Text:lower():match("play") and v.Visible then
                tap(v.AbsolutePosition.X + (v.AbsoluteSize.X/2), v.AbsolutePosition.Y + (v.AbsoluteSize.Y/2) + 58)
                return
            end
        end
        task.wait(0.5)
    end
end)

task.spawn(runFarm)
