local Players           = game:GetService("Players")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")
local UIS               = game:GetService("UserInputService")
local LocalPlayer       = Players.LocalPlayer
local PlayerGui         = LocalPlayer:WaitForChild("PlayerGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileData      = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ProfileData"))
local Database         = require(ReplicatedStorage:WaitForChild("Database"):WaitForChild("Sync"))
local ItemPopupService = require(ReplicatedStorage:WaitForChild("ClientServices"):WaitForChild("ItemPopupService"))

local spawnThread = nil
local SPAWN_DELAY = 0.65

-- ── GIVE ITEM ──────────────────────────────────────────────────────────────
local function GiveItem(itemID, itemType)
    pcall(function()
        itemType = itemType or "Weapons"
        if ProfileData[itemType].Owned[itemID] == nil then
            ProfileData[itemType].Owned[itemID] = 1
        else
            ProfileData[itemType].Owned[itemID] += 1
        end
        ItemPopupService.ItemReceived:Fire(itemID, itemType)
        game.ReplicatedStorage.Remotes.Inventory.InventoryDataChanged:Fire()
    end)
end

local function SpawnList(items, label)
    if spawnThread then task.cancel(spawnThread); spawnThread = nil end
    if #items == 0 then
        warn("[MOLLY] No items matched for: " .. (label or "?") .. " — click Debug and send screenshot!")
        return
    end
    warn("[MOLLY] Spawning " .. #items .. " items for: " .. (label or "?"))
    spawnThread = task.spawn(function()
        for _, item in ipairs(items) do
            GiveItem(item.ID, item.Type)
            task.wait(SPAWN_DELAY)
        end
        spawnThread = nil
        warn("[MOLLY] Done!")
    end)
end

-- ── BUILD MASTER LIST ──────────────────────────────────────────────────────
local masterList = nil

local function BuildMasterList()
    local list = {}
    local function scan(tbl, forcedType)
        if type(tbl) ~= "table" then return end
        for id, data in pairs(tbl) do
            if type(data) == "table" then
                local entry = {}
                for k,v in pairs(data) do entry[k] = v end
                entry._ID        = id
                entry._DataType  = "Weapons"
                entry._ForcedWep = forcedType
                table.insert(list, entry)
            end
        end
    end
    pcall(function() scan(Database.Weapons, nil)   end)
    pcall(function() scan(Database.Knives,  "Knife") end)
    pcall(function() scan(Database.Guns,    "Gun")   end)
    return list
end

-- ── TIER DETECTION — STRICT, NO GUESSING ──────────────────────────────────
-- Step 1: look for an explicit field that holds the tier string.
-- We find the right field name automatically from the first item that has one.
local TIER_FIELD = nil  -- discovered at runtime

local TIER_FIELD_CANDIDATES = {
    "Tier","Rarity","Value","Grade","Rank","Quality",
    "ItemTier","ItemRarity","RarityName","TierName","TierStr"
}

local function discoverTierField(list)
    for _, entry in ipairs(list) do
        for _, f in ipairs(TIER_FIELD_CANDIDATES) do
            local v = entry[f]
            if type(v) == "string" and v ~= "" then
                TIER_FIELD = f
                warn("[MOLLY] Tier field found: '" .. f .. "' (value example: '" .. v .. "')")
                return f
            end
        end
    end
    -- Step 2 fallback: tier stored as number
    for _, entry in ipairs(list) do
        for _, f in ipairs({"Tier","TierNum","TierLevel","Level","TierID"}) do
            local v = entry[f]
            if type(v) == "number" then
                TIER_FIELD = f .. "_NUM"
                warn("[MOLLY] Numeric tier field found: '" .. f .. "' (value example: " .. v .. ")")
                return TIER_FIELD
            end
        end
    end
    warn("[MOLLY] WARNING: No tier field found at all! Debug to investigate.")
    return nil
end

-- Get the raw tier value for an entry
local function getRawTier(entry)
    if not TIER_FIELD then return nil end
    if string.sub(TIER_FIELD, -4) == "_NUM" then
        local realField = string.sub(TIER_FIELD, 1, -5)
        return entry[realField]  -- number
    end
    return entry[TIER_FIELD]  -- string
end

-- Compare tier to a target. Handles both string and number formats.
-- CHROMA_VAL and GODLY_VAL are discovered from the actual data.
local CHROMA_VAL = nil
local GODLY_VAL  = nil

local function discoverTierValues(list)
    for _, entry in ipairs(list) do
        local id = tostring(entry._ID):lower()
        local raw = getRawTier(entry)
        if raw ~= nil then
            -- Items whose ID starts with "Chroma" are definitely Chroma
            if string.sub(id, 1, 6) == "chroma" then
                CHROMA_VAL = raw
                warn("[MOLLY] Chroma tier value = " .. tostring(raw))
            end
            -- Items whose ID contains "Godly" or known godly marker
            -- We only use this to discover the VALUE, not to filter with
            if string.find(id, "godly") and GODLY_VAL == nil then
                GODLY_VAL = raw
                warn("[MOLLY] Godly tier value (from ID hint) = " .. tostring(raw))
            end
        end
        if CHROMA_VAL ~= nil and GODLY_VAL ~= nil then break end
    end
end

local function tierMatches(entry, targetVal)
    if targetVal == nil then return false end
    local raw = getRawTier(entry)
    if raw == nil then return false end
    if type(raw) == "string" and type(targetVal) == "string" then
        return raw:lower() == targetVal:lower()
    end
    return raw == targetVal
end

-- ── WEAPON TYPE DETECTION ──────────────────────────────────────────────────
-- Same multi-field approach but capped — no wild guessing on name fragments.
local TYPE_FIELD = nil

local function discoverTypeField(list)
    for _, entry in ipairs(list) do
        for _, f in ipairs({"Type","WType","WeaponType","Category","ItemType","Kind"}) do
            local v = entry[f]
            if type(v) == "string" then
                local l = v:lower()
                if l == "knife" or l == "knives" or l == "gun" or l == "guns" then
                    TYPE_FIELD = f
                    warn("[MOLLY] Weapon type field found: '" .. f .. "' (example: '" .. v .. "')")
                    return f
                end
            end
        end
        -- Boolean flags
        if entry.Knife ~= nil or entry.IsKnife ~= nil then TYPE_FIELD = "BOOL_KNIFE"; return TYPE_FIELD end
        if entry.Gun   ~= nil or entry.IsGun   ~= nil then TYPE_FIELD = "BOOL_GUN";   return TYPE_FIELD end
    end
    warn("[MOLLY] No weapon type field found. Knife/Gun filter will use ID pattern only.")
    return nil
end

local function getWepType(entry)
    -- Forced from separate table (Database.Knives / .Guns)
    if entry._ForcedWep then return entry._ForcedWep end

    if TYPE_FIELD == "BOOL_KNIFE" then
        if entry.Knife == true or entry.IsKnife == true then return "Knife" end
        if entry.Gun   == true or entry.IsGun   == true then return "Gun"   end
    elseif TYPE_FIELD then
        local v = entry[TYPE_FIELD]
        if type(v) == "string" then
            local l = v:lower()
            if l == "knife" or l == "knives" then return "Knife" end
            if l == "gun"   or l == "guns"   then return "Gun"   end
        end
    end

    -- Last resort: only match if the ID *starts with* or *ends with* "knife"/"gun"
    -- Much stricter than before — avoids false positives
    local id = tostring(entry._ID):lower()
    if string.sub(id,1,5) == "knife" or string.sub(id,-5) == "knife" then return "Knife" end
    if string.sub(id,1,3) == "gun"   or string.sub(id,-3) == "gun"   then return "Gun"   end

    return "Unknown"
end

-- ── FILTER ─────────────────────────────────────────────────────────────────
local function GetFiltered(wepType, tierVal)
    if not masterList then
        masterList = BuildMasterList()
        discoverTierField(masterList)
        discoverTierValues(masterList)
        discoverTypeField(masterList)
        warn("[MOLLY] Total items in DB: " .. #masterList)
    end

    local result = {}
    for _, entry in ipairs(masterList) do
        local wOK = (wepType == nil) or (getWepType(entry) == wepType)
        local tOK = (tierVal == nil) or tierMatches(entry, tierVal)
        if wOK and tOK then
            table.insert(result, { ID = entry._ID, Type = entry._DataType })
        end
    end
    return result
end

-- ── DEBUG ──────────────────────────────────────────────────────────────────
local function DebugPrint()
    masterList = BuildMasterList()
    discoverTierField(masterList)
    discoverTierValues(masterList)
    discoverTypeField(masterList)

    warn("=== MOLLY SPAWNER DEBUG ===")
    warn("Total items: " .. #masterList)
    warn("Tier field:  " .. tostring(TIER_FIELD))
    warn("Chroma val:  " .. tostring(CHROMA_VAL))
    warn("Godly val:   " .. tostring(GODLY_VAL))
    warn("Type field:  " .. tostring(TYPE_FIELD))
    warn("--- First 8 items ---")
    local n = 0
    for _, e in ipairs(masterList) do
        if n >= 8 then break end
        local s = "ID=" .. tostring(e._ID)
        for k,v in pairs(e) do
            if not string.find(tostring(k),"^_") then
                s = s .. "  " .. k .. "=" .. tostring(v)
            end
        end
        warn(s)
        n += 1
    end
    warn("=== END DEBUG — send screenshot! ===")
end

-- ── CUSTOM SPAWN ───────────────────────────────────────────────────────────
local function SpawnCustom(query)
    if not masterList then masterList = BuildMasterList() end
    query = query:lower():gsub("^%s+",""):gsub("%s+$","")
    if query == "" then return end
    local matches = {}
    for _, entry in ipairs(masterList) do
        local id   = tostring(entry._ID):lower()
        local name = tostring(entry.ItemName or entry.Name or entry.DisplayName or ""):lower()
        if id == query
        or string.find(name, query, 1, true)
        or string.find(id,   query, 1, true) then
            table.insert(matches, { ID = entry._ID, Type = entry._DataType })
        end
    end
    if #matches == 0 then
        warn("[MOLLY] No match for: '" .. query .. "'")
    else
        SpawnList(matches, "custom:" .. query)
    end
end

-- ── GUI ────────────────────────────────────────────────────────────────────
local old = PlayerGui:FindFirstChild("ZetaScripts(last4zeta on tt))
if old then old:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "ZetaScripts(last4zeta on tt)"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

local MainFrame = Instance.new("Frame")
MainFrame.Name             = "MainFrame"
MainFrame.Size             = UDim2.new(0, 195, 0, 38)
MainFrame.Position         = UDim2.fromOffset(80, 120)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 10, 28)
MainFrame.BorderSizePixel  = 0
MainFrame.Parent           = ScreenGui
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,12); c.Parent = MainFrame end

local Stroke = Instance.new("UIStroke")
Stroke.Thickness       = 3
Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
Stroke.Parent          = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Size             = UDim2.new(1, 0, 0, 26)
TitleBar.BackgroundColor3 = Color3.fromRGB(24, 14, 52)
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 5
TitleBar.Parent           = MainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,12); c.Parent = TitleBar end

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1,-8,1,0); Title.Position = UDim2.new(0,8,0,0)
Title.BackgroundTransparency = 1
Title.Text = "ZetaScripts(last4zeta on tt)
Title.Font = Enum.Font.FredokaOne; Title.TextSize = 10
Title.TextColor3 = Color3.fromRGB(255,255,255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.ZIndex = 6; Title.Parent = TitleBar

-- DRAG
local dragging, dragOffset = false, Vector2.new(0,0)
TitleBar.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        local ap = MainFrame.AbsolutePosition
        dragOffset = Vector2.new(i.Position.X - ap.X, i.Position.Y - ap.Y)
    end
end)
TitleBar.InputEnded:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)
UIS.InputChanged:Connect(function(i)
    if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
        local vp = game.Workspace.CurrentCamera.ViewportSize
        MainFrame.Position = UDim2.fromOffset(
            i.Position.X - dragOffset.X,
            i.Position.Y - dragOffset.Y
        )
    end
end)

-- BUTTON / LABEL FACTORIES
local nextY = 30
local function MakeButton(label, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1,-14,0,24); b.Position = UDim2.new(0,7,0,nextY)
    b.BackgroundColor3 = color; b.BorderSizePixel = 0
    b.Text = label; b.Font = Enum.Font.FredokaOne; b.TextSize = 10
    b.TextColor3 = Color3.fromRGB(255,255,255); b.AutoButtonColor = false; b.ZIndex = 4
    b.Parent = MainFrame
    do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = b end
    b.MouseEnter:Connect(function()    TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0.3}):Play() end)
    b.MouseLeave:Connect(function()    TweenService:Create(b,TweenInfo.new(0.1),{BackgroundTransparency=0}):Play() end)
    b.MouseButton1Down:Connect(function() TweenService:Create(b,TweenInfo.new(0.07),{BackgroundTransparency=0.55}):Play() end)
    b.MouseButton1Up:Connect(function()   TweenService:Create(b,TweenInfo.new(0.07),{BackgroundTransparency=0}):Play() end)
    b.MouseButton1Click:Connect(cb)
    nextY = nextY + 28; MainFrame.Size = UDim2.new(0,195,0,nextY+6)
    return b
end
local function MakeLabel(txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1,-14,0,14); l.Position = UDim2.new(0,7,0,nextY)
    l.BackgroundTransparency = 1; l.Text = txt
    l.Font = Enum.Font.FredokaOne; l.TextSize = 9
    l.TextColor3 = Color3.fromRGB(160,140,200)
    l.TextXAlignment = Enum.TextXAlignment.Left; l.ZIndex = 4; l.Parent = MainFrame
    nextY = nextY + 16; MainFrame.Size = UDim2.new(0,195,0,nextY+6)
end

-- ── ALL BUTTONS ────────────────────────────────────────────────────────────
MakeButton("✨  Spawn All Chroma Guns",   Color3.fromRGB(0,135,210), function()
    if not masterList then masterList=BuildMasterList(); discoverTierField(masterList); discoverTierValues(masterList); discoverTypeField(masterList) end
    SpawnList(GetFiltered("Gun", CHROMA_VAL), "Chroma Guns")
end)
MakeButton("🔮  Spawn All Chroma Knives", Color3.fromRGB(130,0,210), function()
    if not masterList then masterList=BuildMasterList(); discoverTierField(masterList); discoverTierValues(masterList); discoverTypeField(masterList) end
    SpawnList(GetFiltered("Knife", CHROMA_VAL), "Chroma Knives")
end)
MakeButton("🔫  Spawn All Godly Guns",    Color3.fromRGB(200,115,0), function()
    if not masterList then masterList=BuildMasterList(); discoverTierField(masterList); discoverTierValues(masterList); discoverTypeField(masterList) end
    SpawnList(GetFiltered("Gun", GODLY_VAL), "Godly Guns")
end)
MakeButton("🗡️  Spawn All Godly Knives",  Color3.fromRGB(200,45,45), function()
    if not masterList then masterList=BuildMasterList(); discoverTierField(masterList); discoverTierValues(masterList); discoverTypeField(masterList) end
    SpawnList(GetFiltered("Knife", GODLY_VAL), "Godly Knives")
end)
MakeButton("💎  Spawn ALL Guns & Knives", Color3.fromRGB(25,145,75), function()
    SpawnList(GetFiltered(nil, nil), "All Items")
end)
MakeButton("🛑  Stop Spawning",           Color3.fromRGB(70,70,95), function()
    if spawnThread then task.cancel(spawnThread); spawnThread = nil end
    warn("[MOLLY] Stopped.")
end)
MakeButton("🔍  Debug (open executor console)", Color3.fromRGB(45,45,68), function()
    DebugPrint()
end)

MakeLabel("  — Custom Item Spawner —")

local Box = Instance.new("TextBox")
Box.Size = UDim2.new(1,-14,0,22); Box.Position = UDim2.new(0,7,0,nextY)
Box.BackgroundColor3 = Color3.fromRGB(30,20,55); Box.BorderSizePixel = 0
Box.PlaceholderText = "Type item name or ID..."; Box.Text = ""
Box.Font = Enum.Font.FredokaOne; Box.TextSize = 10
Box.TextColor3 = Color3.fromRGB(255,255,255)
Box.PlaceholderColor3 = Color3.fromRGB(110,90,150)
Box.ClearTextOnFocus = false; Box.ZIndex = 4; Box.Parent = MainFrame
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0,6); c.Parent = Box end
do local s = Instance.new("UIStroke"); s.Thickness = 1; s.Color = Color3.fromRGB(90,60,140); s.Parent = Box end
nextY = nextY + 26; MainFrame.Size = UDim2.new(0,195,0,nextY+6)

MakeButton("▶  Spawn Custom Item", Color3.fromRGB(60,90,160), function()
    SpawnCustom(Box.Text)
end)
Box.FocusLost:Connect(function(enter) if enter then SpawnCustom(Box.Text) end end)

-- RAINBOW
local hue = 0
RunService.Heartbeat:Connect(function(dt)
    hue = (hue + dt * 0.38) % 1
    Stroke.Color     = Color3.fromHSV(hue, 1, 1)
    Title.TextColor3 = Color3.fromHSV((hue + 0.5) % 1, 0.75, 1)
end)

warn("[MOLLY SPAWNER v4] Ready! Click 🔍 Debug first to check your DB fields in the console.")
