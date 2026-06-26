local Services = {
    Players = game:GetService('Players'),
    ReplicatedStorage = game:GetService('ReplicatedStorage'),
    RunService = game:GetService('RunService'),
    UserInputService = game:GetService('UserInputService'),
    TweenService = game:GetService('TweenService'),
    HttpService = game:GetService('HttpService'),
    Chat = game:GetService('Chat')
}
local Players = Services.Players
local ReplicatedStorage = Services.ReplicatedStorage
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local TweenService = Services.TweenService
local HttpService = Services.HttpService

pcall(function()
    setthreadidentity(2)
end)

-- COMPREHENSIVE HOOKS FOR FAKE PLAYERS - MUST BE FIRST
local fakePlayerIds = {}
_G.fakePlayerIds = fakePlayerIds

-- Hook SettingsHelper early with better fake player detection
task.spawn(function()
    task.wait(0.1)
    local SettingsHelper = require(ReplicatedStorage:WaitForChild('Fsys')).load('SettingsHelper')
    local original_get_setting_server = SettingsHelper.get_setting_server

    SettingsHelper.get_setting_server = function(player, settingName, ...)
        if player and player.UserId then
            if fakePlayerIds[player.UserId] then return false end
            if not Players:GetPlayerByUserId(player.UserId) then return false end
        end
        local args = { ... }
        local success, result = pcall(function()
            return original_get_setting_server(player, settingName, table.unpack(args))
        end)
        if success then return result else return false end
    end
end)

-- Hook FamilyHelper early
task.spawn(function()
    task.wait(0.1)
    local FamilyHelper = require(ReplicatedStorage:WaitForChild('Fsys')).load('FamilyHelper')
    local original_are_friends_family = FamilyHelper.are_friends_family
    local original_is_my_friend_or_family = FamilyHelper.is_my_friend_or_family
    local original_are_family_because_friends = FamilyHelper.are_family_because_friends
    local original_is_my_family_because_friend = FamilyHelper.is_my_family_because_friend

    FamilyHelper.are_friends_family = function(player1, player2)
        if player1 and player2 and (fakePlayerIds[player1.UserId] or fakePlayerIds[player2.UserId]) then return false end
        return original_are_friends_family(player1, player2)
    end
    FamilyHelper.is_my_friend_or_family = function(player)
        if player and fakePlayerIds[player.UserId] then return false end
        return original_is_my_friend_or_family(player)
    end
    FamilyHelper.are_family_because_friends = function(player1, player2)
        if player1 and player2 and (fakePlayerIds[player1.UserId] or fakePlayerIds[player2.UserId]) then return false end
        return original_are_family_because_friends(player1, player2)
    end
    FamilyHelper.is_my_family_because_friend = function(player)
        if player and fakePlayerIds[player.UserId] then return false end
        return original_is_my_family_because_friend(player)
    end
end)

local Fsys = require(ReplicatedStorage:WaitForChild('Fsys'))
local load = Fsys.load
local Modules = {
    UIManager = load('UIManager'),
    ClientData = load('ClientData'),
    TableUtil = load('TableUtil'),
    RouterClient = load('RouterClient'),
    InventoryDB = load('InventoryDB'),
    animationManager = load('AnimationManager'),
    ColorThemeManager = load('ColorThemeManager')
}
local UIManager = Modules.UIManager
local ClientData = Modules.ClientData
local TableUtil = Modules.TableUtil
local RouterClient = Modules.RouterClient
local InventoryDB = Modules.InventoryDB
local ColorThemeManager = Modules.ColorThemeManager
local animationManager = Modules.animationManager

if UIManager.wait_for_initialization then
    UIManager:wait_for_initialization()
else
    task.wait(2)
end

local Apps = {
    TradeApp = UIManager.apps.TradeApp,
    BackpackApp = UIManager.apps.BackpackApp,
    DialogApp = UIManager.apps.DialogApp,
    HintApp = UIManager.apps.HintApp,
    SettingsApp = UIManager.apps.SettingsApp,
    PlayerProfileApp = UIManager.apps.PlayerProfileApp,
    TradeHistoryApp = UIManager.apps.TradeHistoryApp,
    TradePreviewApp = UIManager.apps.TradePreviewApp
}
local TradeApp = Apps.TradeApp
local BackpackApp = Apps.BackpackApp
local HintApp = Apps.HintApp
local DialogApp = Apps.DialogApp
local TradeHistoryApp = Apps.TradeHistoryApp
local PlayerProfileApp = Apps.PlayerProfileApp

local NegotiationFrame = Players.LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame

local function FriendHighlight(FriendValue)
    NegotiationFrame.FriendHighlight.Visible = FriendValue
    NegotiationFrame.FriendBorder.Visible = FriendValue
    local PartnerFrame = NegotiationFrame.Header.PartnerFrame
    NegotiationFrame.Header.PartnerFrame.NameLabel.FriendLabel.Visible = FriendValue
    local ColorThemeManagerColor = ColorThemeManager.lookup(FriendValue and 'background' or 'saturated')
    NegotiationFrame.Header.PartnerFrame.ProfileIcon.ImageColor3 = ColorThemeManagerColor
    NegotiationFrame.Header.PartnerFrame.NameLabel.TextColor3 = ColorThemeManagerColor
    NegotiationFrame.Header.PartnerFrame.Icon.Visible = FriendValue
    NegotiationFrame.Header.PartnerFrame.Icon.Image = 'rbxassetid://84667805159408'
end

local downloader = load('DownloadClient')
local petModels = {}

local function getPetModel(kind)
    if petModels[kind] then return petModels[kind]:Clone() end
    local success, streamed = pcall(function()
        local promise = downloader.promise_download_copy('Pets', kind)
        if promise then return promise:expect() end
        return nil
    end)
    if success and streamed then
        petModels[kind] = streamed
        return streamed:Clone()
    else
        warn('Failed to download pet model for:', kind)
        return nil
    end
end

if not TradeApp then return end

-- ==================== PET VALUE SYSTEM ====================
local petDisplayNames = {}
for category, items in pairs(InventoryDB) do
    if category == "pets" then
        for id, petinfo in pairs(items) do
            petDisplayNames[id] = petinfo.name
        end
    end
end

-- Fallback pet values when API fails (from amvgg.com)
local fallbackPetValues = {
    ["Bat Dragon"] = {name = "Bat Dragon", ["rvalue - nopotion"] = 2.91, ["rvalue - fly&ride"] = 2.91, ["nvalue - fly&ride"] = 7.625, ["mvalue - fly&ride"] = 20.6},
    ["Shadow Dragon"] = {name = "Shadow Dragon", ["rvalue - nopotion"] = 1.95, ["rvalue - fly&ride"] = 1.95, ["nvalue - fly&ride"] = 4.5, ["mvalue - fly&ride"] = 11.05},
    ["Giraffe"] = {name = "Giraffe", ["rvalue - nopotion"] = 1.305, ["rvalue - fly&ride"] = 1.305, ["nvalue - fly&ride"] = 3.15, ["mvalue - fly&ride"] = 10.7},
    ["Frost Dragon"] = {name = "Frost Dragon", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 2.11, ["mvalue - fly&ride"] = 5.75},
    ["Owl"] = {name = "Owl", ["rvalue - nopotion"] = 0.835, ["rvalue - fly&ride"] = 0.835, ["nvalue - fly&ride"] = 2.3, ["mvalue - fly&ride"] = 8.4},
    ["Parrot"] = {name = "Parrot", ["rvalue - nopotion"] = 0.66, ["rvalue - fly&ride"] = 0.66, ["nvalue - fly&ride"] = 1.435, ["mvalue - fly&ride"] = 4.8},
    ["Crow"] = {name = "Crow", ["rvalue - nopotion"] = 0.555, ["rvalue - fly&ride"] = 0.555, ["nvalue - fly&ride"] = 1.38, ["mvalue - fly&ride"] = 5.5},
    ["Evil Unicorn"] = {name = "Evil Unicorn", ["rvalue - nopotion"] = 0.4425, ["rvalue - fly&ride"] = 0.4425, ["nvalue - fly&ride"] = 1.0, ["mvalue - fly&ride"] = 3.0},
    ["African Wild Dog"] = {name = "African Wild Dog", ["rvalue - nopotion"] = 0.365, ["rvalue - fly&ride"] = 0.365, ["nvalue - fly&ride"] = 1.275, ["mvalue - fly&ride"] = 4.5},
    ["Hedgehog"] = {name = "Hedgehog", ["rvalue - nopotion"] = 0.3, ["rvalue - fly&ride"] = 0.3, ["nvalue - fly&ride"] = 0.9, ["mvalue - fly&ride"] = 3.5},
    ["Balloon Unicorn"] = {name = "Balloon Unicorn", ["rvalue - nopotion"] = 0.355, ["rvalue - fly&ride"] = 0.355, ["nvalue - fly&ride"] = 1.35, ["mvalue - fly&ride"] = 5.3},
    ["Diamond Butterfly"] = {name = "Diamond Butterfly", ["rvalue - nopotion"] = 0.275, ["rvalue - fly&ride"] = 0.275, ["nvalue - fly&ride"] = 0.97, ["mvalue - fly&ride"] = 3.9},
    ["Orchid Butterfly"] = {name = "Orchid Butterfly", ["rvalue - nopotion"] = 0.235, ["rvalue - fly&ride"] = 0.235, ["nvalue - fly&ride"] = 0.97, ["mvalue - fly&ride"] = 3.9},
    ["Dalmatian"] = {name = "Dalmatian", ["rvalue - nopotion"] = 0.245, ["rvalue - fly&ride"] = 0.245, ["nvalue - fly&ride"] = 0.85, ["mvalue - fly&ride"] = 2.8},
    ["Arctic Reindeer"] = {name = "Arctic Reindeer", ["rvalue - nopotion"] = 0.215, ["rvalue - fly&ride"] = 0.215, ["nvalue - fly&ride"] = 0.65, ["mvalue - fly&ride"] = 2.2},
    ["Giant Panda"] = {name = "Giant Panda", ["rvalue - nopotion"] = 0.18, ["rvalue - fly&ride"] = 0.18, ["nvalue - fly&ride"] = 0.6, ["mvalue - fly&ride"] = 2.0},
    ["Cryptid"] = {name = "Cryptid", ["rvalue - nopotion"] = 0.22, ["rvalue - fly&ride"] = 0.22, ["nvalue - fly&ride"] = 0.7, ["mvalue - fly&ride"] = 2.5},
    ["Haetae"] = {name = "Haetae", ["rvalue - nopotion"] = 0.165, ["rvalue - fly&ride"] = 0.165, ["nvalue - fly&ride"] = 0.6, ["mvalue - fly&ride"] = 2.1},
    ["Cow"] = {name = "Cow", ["rvalue - nopotion"] = 0.1475, ["rvalue - fly&ride"] = 0.1475, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.7},
    ["Pelican"] = {name = "Pelican", ["rvalue - nopotion"] = 0.17, ["rvalue - fly&ride"] = 0.17, ["nvalue - fly&ride"] = 0.6, ["mvalue - fly&ride"] = 2.2},
    ["Strawberry Shortcake Bat Dragon"] = {name = "Strawberry Shortcake Bat Dragon", ["rvalue - nopotion"] = 0.129, ["rvalue - fly&ride"] = 0.129, ["nvalue - fly&ride"] = 0.4, ["mvalue - fly&ride"] = 1.3},
    ["Peppermint Penguin"] = {name = "Peppermint Penguin", ["rvalue - nopotion"] = 0.115, ["rvalue - fly&ride"] = 0.115, ["nvalue - fly&ride"] = 0.4, ["mvalue - fly&ride"] = 1.5},
    ["Turtle"] = {name = "Turtle", ["rvalue - nopotion"] = 0.128, ["rvalue - fly&ride"] = 0.128, ["nvalue - fly&ride"] = 0.38, ["mvalue - fly&ride"] = 1.1},
    ["Chocolate Chip Bat Dragon"] = {name = "Chocolate Chip Bat Dragon", ["rvalue - nopotion"] = 0.11, ["rvalue - fly&ride"] = 0.11, ["nvalue - fly&ride"] = 0.35, ["mvalue - fly&ride"] = 1.2},
    ["Monkey King"] = {name = "Monkey King", ["rvalue - nopotion"] = 0.125, ["rvalue - fly&ride"] = 0.125, ["nvalue - fly&ride"] = 0.38, ["mvalue - fly&ride"] = 1.3},
    ["Flamingo"] = {name = "Flamingo", ["rvalue - nopotion"] = 0.1025, ["rvalue - fly&ride"] = 0.1025, ["nvalue - fly&ride"] = 0.36, ["mvalue - fly&ride"] = 1.2},
    ["Mini Pig"] = {name = "Mini Pig", ["rvalue - nopotion"] = 0.135, ["rvalue - fly&ride"] = 0.135, ["nvalue - fly&ride"] = 0.4, ["mvalue - fly&ride"] = 1.4},
    ["Hot Doggo"] = {name = "Hot Doggo", ["rvalue - nopotion"] = 0.11, ["rvalue - fly&ride"] = 0.11, ["nvalue - fly&ride"] = 0.35, ["mvalue - fly&ride"] = 1.25},
    ["Kangaroo"] = {name = "Kangaroo", ["rvalue - nopotion"] = 0.095, ["rvalue - fly&ride"] = 0.095, ["nvalue - fly&ride"] = 0.3, ["mvalue - fly&ride"] = 1.0},
    ["Albino Monkey"] = {name = "Albino Monkey", ["rvalue - nopotion"] = 0.0925, ["rvalue - fly&ride"] = 0.0925, ["nvalue - fly&ride"] = 0.28, ["mvalue - fly&ride"] = 0.9},
    ["Elephant"] = {name = "Elephant", ["rvalue - nopotion"] = 0.088, ["rvalue - fly&ride"] = 0.088, ["nvalue - fly&ride"] = 0.28, ["mvalue - fly&ride"] = 0.85},
    ["Candyfloss Chick"] = {name = "Candyfloss Chick", ["rvalue - nopotion"] = 0.085, ["rvalue - fly&ride"] = 0.085, ["nvalue - fly&ride"] = 0.29, ["mvalue - fly&ride"] = 0.9},
    ["Caterpillar"] = {name = "Caterpillar", ["rvalue - nopotion"] = 0.09, ["rvalue - fly&ride"] = 0.09, ["nvalue - fly&ride"] = 0.29, ["mvalue - fly&ride"] = 0.9},
    ["Lion"] = {name = "Lion", ["rvalue - nopotion"] = 0.085, ["rvalue - fly&ride"] = 0.085, ["nvalue - fly&ride"] = 0.28, ["mvalue - fly&ride"] = 0.85},
    ["Fairy Bat Dragon"] = {name = "Fairy Bat Dragon", ["rvalue - nopotion"] = 0.08, ["rvalue - fly&ride"] = 0.08, ["nvalue - fly&ride"] = 0.25, ["mvalue - fly&ride"] = 0.8},
    ["Winged Tiger"] = {name = "Winged Tiger", ["rvalue - nopotion"] = 0.07, ["rvalue - fly&ride"] = 0.07, ["nvalue - fly&ride"] = 0.23, ["mvalue - fly&ride"] = 0.8},
    ["Goat"] = {name = "Goat", ["rvalue - nopotion"] = 0.065, ["rvalue - fly&ride"] = 0.065, ["nvalue - fly&ride"] = 0.22, ["mvalue - fly&ride"] = 0.75},
    ["Lion Cub"] = {name = "Lion Cub", ["rvalue - nopotion"] = 0.06, ["rvalue - fly&ride"] = 0.06, ["nvalue - fly&ride"] = 0.21, ["mvalue - fly&ride"] = 0.72},
    ["Sheeeeep"] = {name = "Sheeeeep", ["rvalue - nopotion"] = 0.055, ["rvalue - fly&ride"] = 0.055, ["nvalue - fly&ride"] = 0.19, ["mvalue - fly&ride"] = 0.68},
    ["Shark Puppy"] = {name = "Shark Puppy", ["rvalue - nopotion"] = 0.058, ["rvalue - fly&ride"] = 0.058, ["nvalue - fly&ride"] = 0.2, ["mvalue - fly&ride"] = 0.7},
    ["Jellyfish"] = {name = "Jellyfish", ["rvalue - nopotion"] = 0.055, ["rvalue - fly&ride"] = 0.055, ["nvalue - fly&ride"] = 0.19, ["mvalue - fly&ride"] = 0.68},
    ["Meerkat"] = {name = "Meerkat", ["rvalue - nopotion"] = 0.052, ["rvalue - fly&ride"] = 0.052, ["nvalue - fly&ride"] = 0.18, ["mvalue - fly&ride"] = 0.65},
    ["Nessie"] = {name = "Nessie", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.05, ["nvalue - fly&ride"] = 0.17, ["mvalue - fly&ride"] = 0.6},
    ["Pink Cat"] = {name = "Pink Cat", ["rvalue - nopotion"] = 0.047, ["rvalue - fly&ride"] = 0.047, ["nvalue - fly&ride"] = 0.16, ["mvalue - fly&ride"] = 0.55},
    ["Hare"] = {name = "Hare", ["rvalue - nopotion"] = 0.045, ["rvalue - fly&ride"] = 0.045, ["nvalue - fly&ride"] = 0.15, ["mvalue - fly&ride"] = 0.53},
    ["Zombie Buffalo"] = {name = "Zombie Buffalo", ["rvalue - nopotion"] = 0.042, ["rvalue - fly&ride"] = 0.042, ["nvalue - fly&ride"] = 0.145, ["mvalue - fly&ride"] = 0.5},
    ["Many Mackerel"] = {name = "Many Mackerel", ["rvalue - nopotion"] = 0.042, ["rvalue - fly&ride"] = 0.042, ["nvalue - fly&ride"] = 0.145, ["mvalue - fly&ride"] = 0.5},
    ["Honey Badger"] = {name = "Honey Badger", ["rvalue - nopotion"] = 0.035, ["rvalue - fly&ride"] = 0.035, ["nvalue - fly&ride"] = 0.12, ["mvalue - fly&ride"] = 0.42},
    ["Unicorn"] = {name = "Unicorn", ["rvalue - nopotion"] = 0.03, ["rvalue - fly&ride"] = 0.03, ["nvalue - fly&ride"] = 0.1, ["mvalue - fly&ride"] = 0.35},
    ["Happy Clam"] = {name = "Happy Clam", ["rvalue - nopotion"] = 0.032, ["rvalue - fly&ride"] = 0.032, ["nvalue - fly&ride"] = 0.11, ["mvalue - fly&ride"] = 0.38},
    ["Rhino"] = {name = "Rhino", ["rvalue - nopotion"] = 0.015, ["rvalue - fly&ride"] = 0.015, ["nvalue - fly&ride"] = 0.05, ["mvalue - fly&ride"] = 0.18},
    ["Ram"] = {name = "Ram", ["rvalue - nopotion"] = 0.017, ["rvalue - fly&ride"] = 0.017, ["nvalue - fly&ride"] = 0.06, ["mvalue - fly&ride"] = 0.2},
    ["Yeti"] = {name = "Yeti", ["rvalue - nopotion"] = 0.01, ["rvalue - fly&ride"] = 0.01, ["nvalue - fly&ride"] = 0.035, ["mvalue - fly&ride"] = 0.12},
    ["Frostbite Bear"] = {name = "Frostbite Bear", ["rvalue - nopotion"] = 0.075, ["rvalue - fly&ride"] = 0.075, ["nvalue - fly&ride"] = 0.26, ["mvalue - fly&ride"] = 0.9},
    ["Cat"] = {name = "Cat", ["rvalue - nopotion"] = 0.002, ["rvalue - fly&ride"] = 0.002, ["nvalue - fly&ride"] = 0.01, ["mvalue - fly&ride"] = 0.03},
    ["Dog"] = {name = "Dog", ["rvalue - nopotion"] = 0.002, ["rvalue - fly&ride"] = 0.002, ["nvalue - fly&ride"] = 0.01, ["mvalue - fly&ride"] = 0.03},
    ["Lunar Tiger"] = {name = "Lunar Tiger", ["rvalue - nopotion"] = 0.005, ["rvalue - fly&ride"] = 0.005, ["nvalue - fly&ride"] = 0.02, ["mvalue - fly&ride"] = 0.07},

}

local function fetchPetValues()
    local success, response = pcall(function()
        return request({
            Url = "https://elvebredd.com/api/pets/get-latest",
            Method = "GET",
            Headers = {
                ["Accept"] = "*/*",
                ["User-Agent"] = "Mozilla/5.0"
            }
        })
    end)
    if success and response and response.Success then
        local decodeSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(response.Body)
        end)
        if decodeSuccess and responseData and responseData.pets then
            local petsSuccess, petsData = pcall(function()
                return HttpService:JSONDecode(responseData.pets)
            end)
            if petsSuccess and petsData and next(petsData) then
                return petsData
            end
        end
    end
    -- Return fallback values if API fails
    return fallbackPetValues
end

local petsByName = {}
local petValues = fetchPetValues()
for key, pet in pairs(petValues) do
    if type(pet) == "table" and pet.name then
        petsByName[pet.name] = pet
    end
end

local function getPetValue(petKind, petProps)
    local displayName = petDisplayNames[petKind] or petKind
    local pet = petsByName[displayName]
    if not pet then return 0 end
    local baseKey
    if petProps.mega_neon then
        baseKey = "mvalue"
    elseif petProps.neon then
        baseKey = "nvalue"
    else
        baseKey = "rvalue"
    end
    local suffix = ""
    if petProps.rideable and petProps.flyable then
        suffix = " - fly&ride"
    elseif petProps.rideable then
        suffix = " - ride"
    elseif petProps.flyable then
        suffix = " - fly"
    else
        suffix = " - nopotion"
    end
    local key = baseKey .. suffix
    return pet[key] or pet[baseKey] or 0
end

local function processRawProfileData(rawData)
    if not rawData then return nil end
    local processed = {
        pages = {},
        stickers = {},
        properties = rawData.properties or {}
    }
    if rawData.pages then
        for _, page in ipairs(rawData.pages) do
            local pageIndex = page.page_index
            processed.stickers[pageIndex] = page.stickers
            processed.pages[pageIndex] = {}
            if page.widgets then
                for _, widget in ipairs(page.widgets) do
                    processed.pages[pageIndex][widget.slot] = widget.data
                end
            end
        end
    end
    return processed
end

local function extractAllPets(profileData)
    local pets = {}
    if profileData and profileData.pages then
        for pageIndex, page in pairs(profileData.pages) do
            for slotIndex, slotData in pairs(page) do
                if slotData.widget_kind == "collection" and slotData.widget_data and slotData.widget_data.items then
                    for _, pet in ipairs(slotData.widget_data.items) do
                        local props = pet.properties or {}
                        table.insert(pets, {
                            kind = pet.kind,
                            properties = props,
                            displayName = petDisplayNames[pet.kind] or pet.kind,
                            value = getPetValue(pet.kind, props),
                            isMega = props.mega_neon or false,
                            isNeon = props.neon or false,
                            isFly = props.flyable or false,
                            isRide = props.rideable or false,
                        })
                    end
                end
            end
        end
    end
    return pets
end

local function formatValue(value)
    if value >= 1000000 then
        return string.format("%.2fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    elseif value >= 100 then
        return string.format("%.0f", value)
    else
        return string.format("%.1f", value)
    end
end

local fetchProfile = RouterClient.get("PlayerProfileAPI/FetchProfile")

-- Sanitize an item so only valid inventory fields are written to ClientData.
-- Profile-suggested pets carry widget/page metadata that corrupts the inventory.
local function sanitizeForInventory(item)
    if not item or not item.kind or not item.category then return nil end
    local cat = InventoryDB[item.category]
    if not cat or not cat[item.kind] then return nil end
    local p = item.properties or {}
    return {
        unique         = item.unique or HttpService:GenerateGUID(false),
        category       = item.category,
        id             = item.id or item.kind,
        kind           = item.kind,
        newness_order  = item.newness_order or math.random(1, 900000),
        properties     = {
            flyable         = p.flyable         or false,
            rideable        = p.rideable        or false,
            neon            = p.neon            or false,
            mega_neon       = p.mega_neon       or false,
            age             = p.age             or 0,
            xp              = p.xp              or 0,
            pet_trick_level = p.pet_trick_level or 0,
        },
    }
end

-- Fetch and cache the real pets from the partner's profile.
-- Returns a list of sanitized inventory items, or nil if unavailable.
local function fetchPartnerProfilePets(userId)
    if not userId then return nil end
    local ok, rawData = pcall(function()
        return fetchProfile:InvokeServer(userId)
    end)
    if not ok or not rawData then return nil end
    local profileData = processRawProfileData(rawData)
    local extracted = extractAllPets(profileData)
    if not extracted or #extracted == 0 then return nil end
    -- Convert to inventory-style items, skipping any kind not in InventoryDB.
    -- Profile pets can include newer/event pets that don't exist in the local
    -- InventoryDB snapshot — BackpackItemHider crashes with "attempt to index nil
    -- with 'is_hidden_from_backpack'" when it tries to look up an unknown kind.
    local items = {}
    for _, pet in ipairs(extracted) do
        local dbEntry = pet.kind and InventoryDB.pets and InventoryDB.pets[pet.kind]
        if dbEntry and dbEntry.name then  -- valid, known kind that BackpackApp can handle
            local uid = HttpService:GenerateGUID(false)
            local p = pet.properties or {}
            items[#items + 1] = {
                unique        = uid,
                category      = "pets",
                id            = pet.kind,
                kind          = pet.kind,
                newness_order = math.random(1, 900000),
                properties    = {
                    flyable         = p.flyable         or false,
                    rideable        = p.rideable        or false,
                    neon            = p.neon            or false,
                    mega_neon       = p.mega_neon       or false,
                    age             = p.age             or 0,
                    xp              = p.xp              or 0,
                    pet_trick_level = p.pet_trick_level or 0,
                },
            }
        end
    end
    return #items > 0 and items or nil
end

-- ==================== END PET VALUE SYSTEM ====================

local CONFIG = {
    PARTNER_NAME = 'rvdriie',
    PARTNER_USER_ID = 987654321,
    AUTO_ACCEPT_DELAY = 0.2,
    AUTO_CONFIRM_DELAY = 0.3,
    SPECTATOR_COUNT = 4,
    SPECTATOR_VARIATION_MIN = -1,
    SPECTATOR_VARIATION_MAX = 2,
    AUTO_SPECTATE_ENABLED = false,
    AUTO_SPECTATE_INTERVAL = 1.5,
    AUTO_PARTNER = true,
    NEGOTIATION_LOCK = 5,
    CONFIRMATION_LOCK_PER_ITEM = 3,
    SHOW_TRADE_REQUEST = true,
    TRADE_REQUEST_DELAY = 0,
    ADD_PET_REQUEST_DELAY = 0.5,
    SPAWN_FAKE_PLAYER_WITH_RANDOM_PET = false,
    FAKE_PLAYER_ACCEPT_TRADE_REQUEST = 2,
    CHAT_MESSAGES = {
        'Tysm ! 💗💗', 'Thank you', 'Trusted TY ❤️', 'Can i play also', 'Can i spin this pet', 'Please respin 🥺',
        'Spin again plss 😔', 'Please guys follow', 'Pls both ill cry 😢', 'My dp neon giraffe', 'My dp is bat dragon',
        'Can i get mega pet', 'Change last 2 pets', 'Add or i will decline', 'Add more pets', 'You are under 😂', 'Do mega exotics',
        'win or lose', 'win pls nigga', 'I am followed btw', 'Can you add', 'add more', 'add', 'Did I win?', 'Which one can I spin',
        'Omg Its real Thank you so much', 'I am a big fan pls pet', 'Can i still get gift pls?', 'Can I get a free pet please?',
        'I love youre lives btw!', 'Lose?', 'Win?', 'Thanks!', 'Okay thank you so much for giving back.', 'Yes',
        'Thanks', 'How is youre day so far', 'Yes can i please spin this',
        'Which one should i spin',
        'Which one you wanna spin',
        'hello',
        'Can you offer for my pet',
        'Can you add a lot more',
        'THANKS YOU SO MUCH UR TRUSTED',
        'Yes bro',
        'I got scammed ',
        'YOURE LEGIT',
        'Can i please spin this bro',
        'Can I think abt the offer',
        'Thank u so much',
        'Can I have have a pet since ur doing giveaway',
        'pet pls',
        'Yes i am followed',
        'Im watching youre live bro',
        'can i enter the giveaway',
        'I sent 20 likes',
        'I sent sm likes',
        'Blackie hoe',
        'Ofcc',
        'Im followed',
        'OMG',
        'Chazza im gonna rape you',
        'Caleb im gonna rape you',
        'Are you sure its safe',
        'Okk',
        'Faggot bitch fuck you',
        'Im gonna rape your ass',
        'Nigga',
        'TYSM ILY',
        'Can i have one of the pets in my profile as a gift?',
        'Stupid retarded whale',
        'No problem I love helping my admins',
        'give these away to your fans',
        'Im giving you these special admin pets to showcase for your fans the update coming soon',
        'im your biggest fan',
        'guys everyone spam 1 plss',
        'offers?',
        'TRANNY NIGGER I HATE YOU',
        'I bought from your shop',
        'I bought from Tropical Island and it worked tysmm',

    },
    AUTO_CHAT_DELAY = 2,
    VERIFIED_FRIENDS = {
        'Agusmareborn', 'Kellyvault', 'J3llynoah', 'Rainbowriley321',
        'Bobazmalibu', 'H3llSANG3LX', 'Xcallmeholly', 'Niniko_201999',
    },
    SHOW_VERIFIED_FRIEND = false,
    FRIEND_PARTNER = true,
    REMOVE_PARTNER_PETS_ON_CONFIRM = false,
    SPIN_THE_WHEEL_ON_ADD = false,
}

local ORIGINAL_SPECTATOR_COUNT = CONFIG.SPECTATOR_COUNT

local function getRandomSpectatorCount()
    local variation = math.random(CONFIG.SPECTATOR_VARIATION_MIN, CONFIG.SPECTATOR_VARIATION_MAX)
    local newCount = ORIGINAL_SPECTATOR_COUNT + variation
    return math.max(0, newCount)
end

-- ==================== FAKE INVENTORY GENERATOR ====================
local FakeInventoryGenerator = {}

function FakeInventoryGenerator.generateFakeInventory(partnerName)
    local fakeInventory = {
        pets = {}
    }
    
    print("[FakeInventory] Generating fake inventory for", partnerName)
    
    local highTierPets = {
        "Shadow Dragon", "Bat Dragon", "Frost Dragon", "Giraffe", 
        "Owl", "Parrot", "Crow", "Evil Unicorn", "Arctic Reindeer",
        "Dalmatian", "Turtle", "Kangaroo", "Hedgehog", "Diamond Butterfly"
    }
    
    print("[FakeInventory] Adding", #highTierPets, "high-tier pets...")
    
    for _, petName in ipairs(highTierPets) do
        for petKind, petData in pairs(InventoryDB.pets or {}) do
            if petData.name == petName and not petName:lower():find("egg") then
                table.insert(fakeInventory.pets, {
                    unique = HttpService:GenerateGUID(false),
                    kind = petKind,
                    category = "pets",
                    properties = {
                        flyable = true,
                        rideable = true,
                        age = math.random(80, 100),
                        displayed_rarity = petData.rarity or "legendary",
                        equipped = false,
                    },
                    id = petKind,
                })
                
                table.insert(fakeInventory.pets, {
                    unique = HttpService:GenerateGUID(false),
                    kind = petKind,
                    category = "pets",
                    properties = {
                        neon = true,
                        flyable = true,
                        rideable = true,
                        age = 100,
                        displayed_rarity = petData.rarity or "legendary",
                        equipped = false,
                    },
                    id = petKind,
                })
                
                if petName == "Shadow Dragon" or petName == "Bat Dragon" or 
                   petName == "Frost Dragon" or petName == "Giraffe" then
                    table.insert(fakeInventory.pets, {
                        unique = HttpService:GenerateGUID(false),
                        kind = petKind,
                        category = "pets",
                        properties = {
                            mega_neon = true,
                            flyable = true,
                            rideable = true,
                            age = 100,
                            displayed_rarity = petData.rarity or "legendary",
                            equipped = false,
                        },
                        id = petKind,
                    })
                end
                
                break
            end
        end
    end
    
    local availablePets = {}
    if InventoryDB.pets then
        for petKind, petData in pairs(InventoryDB.pets) do
            table.insert(availablePets, {kind = petKind, data = petData})
        end
    end
    
    print("[FakeInventory] Adding 30-50 random pets from", #availablePets, "available pets...")
    
    local randomPetCount = math.random(30, 50)
    for i = 1, randomPetCount do
        if #availablePets > 0 then
            local randomIndex = math.random(1, #availablePets)
            local selectedPet = availablePets[randomIndex]
            
            local unique = HttpService:GenerateGUID(false)
            local properties = {
                age = math.random(0, 100),
                equipped = false,
            }
            
            if math.random(1, 100) <= 40 then properties.flyable = true end
            if math.random(1, 100) <= 40 then properties.rideable = true end
            if math.random(1, 100) <= 25 then properties.neon = true end
            if math.random(1, 100) <= 8 then 
                properties.mega_neon = true 
                properties.neon = nil 
            end
            
            properties.displayed_rarity = selectedPet.data.rarity or "common"
            
            table.insert(fakeInventory.pets, {
                unique = unique,
                kind = selectedPet.kind,
                category = "pets",
                properties = properties,
                id = selectedPet.kind,
            })
        end
    end
    
    print("[FakeInventory] Generated", #fakeInventory.pets, "total pets")
    
    return fakeInventory
end


local mockState = {
    active = false,
    trade = nil,
    isAddingItem = false,
    partnerActionPending = false,
    originalFunctions = {},
    controlPanelOpen = false,
    tradeCompleting = false,
    scamWarningShown = true,
    originalDialogFunction = nil,
    blockedTradeRequests = {},
    tradeHistory = {},
    addedTradeIds = {},
    pendingTradeRequest = false,
    canShowTradeRequest = true,
    tradeRequestBlocked = false,
    removePartnerPetsOnConfirm = false,
    partnerPetsBeforeConfirm = {},
    isMockTradeDialog = false,
    fakeInventory = nil,
    suggestedItems = {},
    suggestEnabled = true,
    partnerProfilePets = nil,   -- pets extracted from the partner's profile (nil = not fetched yet)
}

local petSpawnState = {
    activeFlags = { F = false, R = false, N = false, M = false },
    validPetNames = {},
    validPetNamesClean = {},
}

local highValuePets = {
    'Shadow Dragon', 'Bat Dragon', 'Frost Dragon', 'Giraffe', 'Owl',
    'Parrot', 'Crow', 'Evil Unicorn'
}

local completePetList = {
    'Shadow Dragon', 'Bat Dragon', 'Frost Dragon', 'Giraffe', 'Owl', 'Parrot', 'Crow',
    'Evil Unicorn', 'Arctic Reindeer', 'Dalmatian', 'Turtle', 'Kangaroo', 'Peppermint Penguin', 
    'Strawberry Shortcake Bat Dragon', 'Chocolate Chip Bat Dragon', 'Cow', 'Mini Pig',
}

local customUsers = {
    'aliceroblox6166', 'DIVAHOLIC', 'iiicristianxx_o', 'Darcie_epic', 'banan_bartek1234',
    's18amg', 'Chicken_nuggitx23817', 'RmSbx_x', 'siqnnaz', 'Nidaanurr7', 'Kkiraly',
    'daisydoo_billy', 'youssefsalah135', 'aurivxs', 'princeplay', 'sofysofy986353',
    'heaseung008800112277', 'Agusmareborn', 'Kellyvault', 'J3llynoah', 'Rainbowriley321',
    'hweartsouls', 'h3llsang3lx', 'Xcallmeholly', 'Niniko_201999', 'Hugso09',
    'ruthjavxn', 'bubblesxwrldd', 'Hugeinvestor', 'Barborich2', 'Underthechemtrailss',
    'Bunzvii', 'Qwrtylostaccount', 'Sparklingorangelol', 'Tr3ndzyy', 'Jellycmt', 'Ex4clusiv3',
    'Killersana66', 'Chasedatfund', 'Pukgames0', 'Lathifcal', 'Tadhghogan009', 'Firefelineyt',
    'Jasperisdic', 'Coalberto', 'Mouasx', 'CodyPlays', 'Obvk1rk', 'Medinololboi',
    '0bvskileyxo', 'dwsiredsouls', 'Track_T0R', 'glowtropics', 'Cqvrleo', 'Alisawants',
    'Themeganplays', 'Avqrsz', 'EvergreenPlane', 'Elisacanlisten', 'Money_Money1000',
    'Al3xsrz', '000teenvogue', 'Stranger_s4mu', 'Pradasvogue', 'Adore1ucax', 'Sincevampire',
    'Iobotomyd', 'Woofnico', 'Sillyoldgoose', 'Obvliams', 'Juandicrack777', 'Lionheart_xo',

}

local function isPetAboveBalloonUnicorn(petName)
    for _, highValuePet in ipairs(highValuePets) do
        if petName == highValuePet then return true end
    end
    return false
end

local function getRandomHighValuePet()
    return highValuePets[math.random(1, #highValuePets)]
end

local function loadPetNames()
    for category_name, category_table in pairs(InventoryDB) do
        if category_name == 'pets' then
            for id, item in pairs(category_table) do
                petSpawnState.validPetNames[#petSpawnState.validPetNames + 1] = item.name
                petSpawnState.validPetNamesClean[#petSpawnState.validPetNamesClean + 1] = item.name:lower():gsub('%s+', '')
            end
            break
        end
    end
end
loadPetNames()

local function checkTradeLicense(player)
    if not player then return false end
    local success, hasLicense = pcall(function()
        if TradeApp and TradeApp._check_if_player_has_trade_license then
            return TradeApp:_check_if_player_has_trade_license(player)
        end
        local result = RouterClient.get('TradeAPI/GetTradeLicenseStatus'):InvokeServer(player.UserId)
        return result and result.has_license == true
    end)
    return success and hasLicense or true
end

local function isVerifiedFriend(username)
    for _, friendName in ipairs(CONFIG.VERIFIED_FRIENDS) do
        if friendName:lower() == username:lower() then return true end
    end
    return false
end

local function storeOriginalFunctions()
    local funcs = {
        '_get_local_trade_state', '_overwrite_local_trade_state', '_change_local_trade_state',
        '_get_my_offer', '_get_partner_offer', '_get_my_player', '_get_partner',
        '_get_current_trade_stage', '_on_accept_pressed', '_on_confirm_pressed',
        '_on_unaccept_pressed', '_decline_trade', '_add_item_to_my_offer',
        '_remove_item_from_my_offer', '_lock_trade_for_appropriate_time', '_get_lock_time',
        'refresh_all', '_evaluate_trade_fairness', '_show_scam_victim_warning', '_show_scam_perpetrator_warning',
    }
    for _, funcName in ipairs(funcs) do
        if TradeApp[funcName] then
            mockState.originalFunctions[funcName] = TradeApp[funcName]
        end
    end
    if TradeHistoryApp then
        if TradeHistoryApp._get_trade_history then
            mockState.originalGetTradeHistory = TradeHistoryApp._get_trade_history
        end
        if TradeHistoryApp.report_scam then
            mockState.originalReportScam = TradeHistoryApp.report_scam
        end
    end
end

storeOriginalFunctions()

local function createMockPartner(player)
    local partnerName = player and player.Name or CONFIG.PARTNER_NAME
    local partnerDisplayName = player and player.DisplayName or CONFIG.PARTNER_NAME
    local partnerUserId = player and player.UserId or CONFIG.PARTNER_USER_ID
    
    local mockPlayer = {
        Name = partnerName,
        DisplayName = partnerDisplayName,
        UserId = partnerUserId,
        ClassName = 'Player',
        Character = nil,
        Team = nil,
        TeamColor = BrickColor.new('White'),
        Neutral = true,
        AccountAge = 365,
        MembershipType = Enum.MembershipType.None,
        CharacterAdded = Instance.new('BindableEvent'),
        CharacterRemoving = Instance.new('BindableEvent'),
    }
    
    return setmetatable(mockPlayer, {
        __index = function(t, k)
            if k == 'Parent' then return Players end
            if k == 'IsA' then 
                return function(self, className) 
                    return className == 'Player' or className == 'Instance'
                end 
            end
            if k == 'GetAttribute' then
                return function(self, attr)
                    return nil
                end
            end
            if k == 'FindFirstChild' then
                return function(self, name)
                    return nil
                end
            end
            if k == 'WaitForChild' then
                return function(self, name, timeout)
                    return nil
                end
            end
            return rawget(t, k)
        end,
        __tostring = function() return partnerName end,
        __eq = function(a, b)
            if type(b) == 'table' then
                return rawget(a, 'UserId') == rawget(b, 'UserId')
            end
            return false
        end,
    })
end

local mockPartner = createMockPartner()

local function createMockTrade(realPlayer)
    local partner = realPlayer and createMockPartner(realPlayer) or mockPartner
    local hasLicense = true
    if realPlayer then hasLicense = checkTradeLicense(realPlayer) end
    return {
        trade_id = 'MOCK_' .. tick(),
        sender = Players.LocalPlayer,
        recipient = partner,
        sender_offer = { items = {}, player_name = Players.LocalPlayer.Name, negotiated = false, confirmed = false },
        recipient_offer = { items = {}, player_name = CONFIG.PARTNER_NAME, negotiated = false, confirmed = false },
        current_stage = 'negotiation',
        offer_version = 1,
        sender_has_trade_license = true,
        recipient_has_trade_license = hasLicense,
        busy_indicators = {},
        subscriber_count = CONFIG.SPECTATOR_COUNT,
    }
end

local function createTradeHistoryRecord(trade)
    return {
        trade_id = trade.trade_id,
        timestamp = os.time(),
        sender_user_id = Players.LocalPlayer.UserId,
        sender_name = Players.LocalPlayer.Name,
        sender_items = TableUtil.deep_copy(trade.sender_offer.items),
        recipient_user_id = trade.recipient.UserId,
        recipient_name = CONFIG.PARTNER_NAME,
        recipient_items = TableUtil.deep_copy(trade.recipient_offer.items),
        reported = false,
        reverted = nil,
    }
end

local function appendToTradeHistory(tradeRecord)
    if mockState.addedTradeIds[tradeRecord.trade_id] then return end
    mockState.addedTradeIds[tradeRecord.trade_id] = true
    table.insert(mockState.tradeHistory, tradeRecord)
end

local function hookTradeHistoryFunctions()
    if not TradeHistoryApp then return end

    TradeHistoryApp._get_trade_history = function(self, useCache)
        local history = mockState.originalGetTradeHistory(self, useCache)
        local combined, seenIds = {}, {}
        if history then
            for _, realTrade in ipairs(history) do
                if not seenIds[realTrade.trade_id] then
                    table.insert(combined, realTrade)
                    seenIds[realTrade.trade_id] = true
                end
            end
        end
        for _, mockTrade in ipairs(mockState.tradeHistory) do
            if not seenIds[mockTrade.trade_id] then
                table.insert(combined, mockTrade)
                seenIds[mockTrade.trade_id] = true
            end
        end
        self.cached_trade_history = combined
        return combined
    end

    TradeHistoryApp.report_scam = function(self, tradeData)
        if tradeData and string.find(tostring(tradeData.trade_id), 'MOCK_') then
            self.UIManager.set_app_visibility(self.ClassName, false)
            local response1 = self.UIManager.apps.DialogApp:dialog({
                dialog_type = 'ReportScamDialog',
                suspect_name = CONFIG.PARTNER_NAME,
                placeholder_text = 'What happened? (Optional)',
                max_length = 500,
                use_utf8_length = true,
                left = 'Cancel',
                right = 'Report',
            })
            self.UIManager.set_app_visibility(self.ClassName, true)
            if response1 == 'Report' then
                for _, record in ipairs(mockState.tradeHistory) do
                    if record.trade_id == tradeData.trade_id then
                        record.reported = true
                        break
                    end
                end
                self.UIManager.apps.DialogApp:dialog({ text = 'Report submitted for review.', button = 'Close', yields = false })
            end
            if self.instance.Frame.Visible then self:_refresh() else self:_clear_scrolling_frame() end
            return
        end
        return mockState.originalReportScam(self, tradeData)
    end
end

hookTradeHistoryFunctions()

local function update_busy_indicators(args1)
    local v144 = mockState.trade.busy_indicators
    local v145 = TradeApp._get_partner().UserId
    v144[tostring(v145)] = args1
    TradeApp.partner_negotiation_offer_pane:display_busy(v144[tostring(v145)])
end

local function addPetToPartnerOffer(petName, flags)
    if not mockState.active or not mockState.trade then return false, 'No active mock trade' end
    if mockState.trade.current_stage == 'confirmation' then return false, 'Cannot modify during confirmation' end
    if #mockState.trade.recipient_offer.items >= 18 then return end

    update_busy_indicators({ ['picking'] = true })
    task.wait(CONFIG.ADD_PET_REQUEST_DELAY)

    for category_name, category_table in pairs(InventoryDB) do
        if category_name == 'pets' then
            for id, item in pairs(category_table) do
                if item.name == petName then
                    local petItem = {
                        category = 'pets',
                        id = id,
                        kind = id,
                        unique = HttpService:GenerateGUID(),
                        newness_order = math.random(1, 900000),
                        properties = { flyable = flags.F, rideable = flags.R, neon = flags.N, mega_neon = flags.M, age = 1 },
                    }
                    table.insert(mockState.trade.recipient_offer.items, petItem)
                    
                    local fake_uuid = petItem.unique
                    if TradeApp.can_suggest_removal_items then
                        TradeApp.can_suggest_removal_items[fake_uuid] = petItem
                    end
                    
                    if TradeApp.can_react_faces_sideTrade then
                        local tradereact = true
                        TradeApp.can_add_reactions_trade[fake_uuid] = tradereact
                    end
                    
                    mockState.trade.sender_offer.negotiated = false
                    mockState.trade.recipient_offer.negotiated = false
                    if mockState.trade.current_stage == 'confirmation' then
                        mockState.trade.current_stage = 'negotiation'
                        mockState.trade.sender_offer.confirmed = false
                        mockState.trade.recipient_offer.confirmed = false
                    end
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    TradeApp:_overwrite_local_trade_state(mockState.trade)
                    if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
                    if TradeApp._render_message_in_trade_chat then
                        TradeApp:_render_message_in_trade_chat(nil, string.format('%s added %s.', CONFIG.PARTNER_NAME, petName), true)
                    end
                    update_busy_indicators({ ['picking'] = false })
                    return true, 'Pet added successfully'
                end
            end
        end
    end
    return false, 'Pet not found'
end

local function removeLatestPetFromPartnerOffer()
    if not mockState.active or not mockState.trade then return false, 'No active mock trade' end
    if mockState.trade.current_stage == 'confirmation' then return false, 'Cannot modify during confirmation' end
    local partnerItems = mockState.trade.recipient_offer.items
    if #partnerItems == 0 then return false, 'No items to remove' end

    local removedItem = table.remove(partnerItems)
    mockState.trade.sender_offer.negotiated = false
    mockState.trade.recipient_offer.negotiated = false
    if mockState.trade.current_stage == 'confirmation' then
        mockState.trade.current_stage = 'negotiation'
        mockState.trade.sender_offer.confirmed = false
        mockState.trade.recipient_offer.confirmed = false
    end
    mockState.trade.offer_version = mockState.trade.offer_version + 1
    TradeApp:_overwrite_local_trade_state(mockState.trade)
    if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
    if TradeApp._render_message_in_trade_chat then
        local itemName = 'item'
        if removedItem.category == 'pets' then
            for _, category_table in pairs(InventoryDB) do
                for id, item in pairs(category_table) do
                    if id == removedItem.kind then itemName = item.name break end
                end
            end
        end
        TradeApp:_render_message_in_trade_chat(nil, string.format('%s removed %s.', CONFIG.PARTNER_NAME, itemName), true)
    end
    return true, 'Pet removed successfully'
end

local function generateRandomPetProperties()
    local petTypes = { 'FR', 'NFR' }
    local chosenType = petTypes[math.random(1, #petTypes)]
    local properties = { F = false, R = false, N = false, M = false }
    if chosenType == 'FR' then
        properties.F, properties.R = true, true
    elseif chosenType == 'NFR' then
        properties.F, properties.R, properties.N = true, true, true
    end
    return properties
end

local function getPropertiesString(properties)
    local props = {}
    if properties.M then table.insert(props, 'Mega') end
    if properties.N then table.insert(props, 'Neon') end
    if properties.F then table.insert(props, 'Fly') end
    if properties.R then table.insert(props, 'Ride') end
    if #props > 0 then return ' (' .. table.concat(props, ' ') .. ')' end
    return ''
end

local function sendTradeChatMessage(message)
    if not mockState.active or not mockState.trade then return false end
    if TradeApp and TradeApp._render_message_in_trade_chat then
        TradeApp:_render_message_in_trade_chat(nil, string.format('%s: %s', CONFIG.PARTNER_NAME, message), true)
        return true
    end
    return false
end

local function removePartnerPetsVisually()
    if not mockState.active or not mockState.trade then return false end
    local partnerItems = mockState.trade.recipient_offer.items
    if #partnerItems == 0 then return false end
    mockState.partnerPetsBeforeConfirm = TableUtil.deep_copy(partnerItems)
    mockState.trade.recipient_offer.items = {}
    mockState.trade.offer_version = mockState.trade.offer_version + 1
    TradeApp:_overwrite_local_trade_state(mockState.trade)
    return true
end

local showBlockedTradeRequests

local function partnerAutoAction()
    if not mockState.active or not mockState.trade or mockState.partnerActionPending then return end
    mockState.partnerActionPending = true

    while TradeApp.lock_countdown and TradeApp.lock_countdown.is_going and TradeApp.lock_countdown:is_going() do
        task.wait(0.1)
    end

    if mockState.trade.current_stage == 'negotiation' then
        task.wait(CONFIG.AUTO_ACCEPT_DELAY)
        if mockState.active and mockState.trade then
            mockState.trade.recipient_offer.negotiated = true
            if mockState.trade.sender_offer.negotiated then
                mockState.trade.current_stage = 'confirmation'
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                TradeApp:_overwrite_local_trade_state(mockState.trade)
                if TradeApp._evaluate_trade_fairness then TradeApp:_evaluate_trade_fairness() end
                if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
            else
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                TradeApp:_overwrite_local_trade_state(mockState.trade)
            end
        end
    elseif mockState.trade.current_stage == 'confirmation' then
        task.wait(CONFIG.AUTO_CONFIRM_DELAY)
        if mockState.active and mockState.trade then
            mockState.trade.recipient_offer.confirmed = true
            mockState.trade.offer_version = mockState.trade.offer_version + 1
            TradeApp:_overwrite_local_trade_state(mockState.trade)
            if mockState.trade.sender_offer.confirmed and not mockState.tradeCompleting then
                mockState.tradeCompleting = true
                if TradeApp._set_confirmation_arrow_rotating then TradeApp:_set_confirmation_arrow_rotating(true) end
                task.wait(3)
                local historyRecord = createTradeHistoryRecord(mockState.trade)
                appendToTradeHistory(historyRecord)

                local realInventory = ClientData.get('inventory')
                if realInventory then
                    for _, item in ipairs(mockState.trade.recipient_offer.items) do
                        local clean = sanitizeForInventory(item)
                        if clean then
                            local cat = clean.category
                            if not realInventory[cat] then realInventory[cat] = {} end
                            realInventory[cat][clean.unique] = clean
                            if typeof(_G.registerTradedPet) == 'function' and cat == 'pets' then
                            _G.registerTradedPet(clean)
                        end 
                    end
                end
            end

                mockState.active = false
                mockState.trade = nil
                mockState.tradeCompleting = false
                mockState.scamWarningShown = true
                mockState.canShowTradeRequest = true
                mockState.tradeRequestBlocked = false
                UIManager.set_app_visibility('TradeApp', false)
                task.wait(0.1)
                showBlockedTradeRequests()
                if HintApp then HintApp:hint({ text = 'The trade was successful!', length = 5, overridable = true }) end
                if TradeHistoryApp and UIManager.is_visible('TradeHistoryApp') then TradeHistoryApp:_refresh() end
            end
        end
    end
    mockState.partnerActionPending = false
end

local function hookTradeFunctions()
    TradeApp._get_local_trade_state = function(self)
        if mockState.active and mockState.trade then return TableUtil.deep_copy(mockState.trade) end
        return mockState.originalFunctions._get_local_trade_state(self)
    end

    TradeApp._overwrite_local_trade_state = function(self, newState)
        if mockState.active then
            if newState then
                mockState.trade = newState
                self.local_trade_state = newState
                if mockState.trade then mockState.trade.subscriber_count = CONFIG.SPECTATOR_COUNT end
                if self._on_local_trade_state_changed then self:_on_local_trade_state_changed(newState, newState) end
                if self.refresh_all then self:refresh_all() FriendHighlight(true) end
                if not self.suggestions then self.suggestions = {} end
                if not self.can_suggest_removal_items then self.can_suggest_removal_items = {} end
            else
                mockState.trade = nil
                mockState.active = false
                mockState.scamWarningShown = false
                mockState.canShowTradeRequest = true
                mockState.tradeRequestBlocked = false
                self.local_trade_state = nil
                mockState.mockFakeInventory = nil
                showBlockedTradeRequests()
            end
        else
            return mockState.originalFunctions._overwrite_local_trade_state(self, newState)
        end
    end

    TradeApp._get_my_offer = function(self)
        local state = self:_get_local_trade_state()
        if mockState.active and state then
            if Players.LocalPlayer == state.sender then return state.sender_offer, 'sender_offer' else return state.recipient_offer, 'recipient_offer' end
        end
        return mockState.originalFunctions._get_my_offer(self)
    end

    TradeApp._get_partner_offer = function(self)
        local state = self:_get_local_trade_state()
        if mockState.active and state then
            if Players.LocalPlayer == state.sender then return state.recipient_offer, 'recipient_offer' else return state.sender_offer, 'sender_offer' end
        end
        return mockState.originalFunctions._get_partner_offer(self)
    end

    TradeApp._get_my_player = function(self)
        if mockState.active and mockState.trade then return Players.LocalPlayer end
        return mockState.originalFunctions._get_my_player(self)
    end

    TradeApp._get_partner = function(self)
        if mockState.active and mockState.trade then return mockState.trade.recipient end
        return mockState.originalFunctions._get_partner(self)
    end

    TradeApp._get_current_trade_stage = function(self)
        if mockState.active and mockState.trade then return mockState.trade.current_stage end
        return mockState.originalFunctions._get_current_trade_stage(self)
    end

    TradeApp._change_local_trade_state = function(self, changes)
        if mockState.active then
            local function recursiveMerge(target, source)
                for k, v in pairs(source) do
                    if type(v) == 'table' and target[k] and type(target[k]) == 'table' then recursiveMerge(target[k], v) else target[k] = v end
                end
                return target
            end
            self:_overwrite_local_trade_state(recursiveMerge(self:_get_local_trade_state(), changes))
        else
            return mockState.originalFunctions._change_local_trade_state(self, changes)
        end
    end

    TradeApp._get_lock_time = function(self)
        if mockState.active and mockState.trade then
            if self:_get_current_trade_stage() == 'negotiation' then return CONFIG.NEGOTIATION_LOCK
            else return math.clamp(CONFIG.CONFIRMATION_LOCK_PER_ITEM * (#mockState.trade.sender_offer.items + #mockState.trade.recipient_offer.items), 5, 15) end
        end
        return mockState.originalFunctions._get_lock_time(self)
    end

    TradeApp._lock_trade_for_appropriate_time = function(self)
        if mockState.active then
            if self.lock_countdown then self.lock_countdown:stop() self.lock_countdown:set_duration(self:_get_lock_time()) self.lock_countdown:start() end
        else
            return mockState.originalFunctions._lock_trade_for_appropriate_time(self)
        end
    end

    TradeApp._add_item_to_my_offer = function(self)
        if mockState.active and mockState.trade then
            if CONFIG.SPIN_THE_WHEEL_ON_ADD and spinnerSystem and spinnerSystem.showWheel then
                spinnerSystem.showWheel()
                return
            end
            if mockState.isAddingItem then return end
            mockState.isAddingItem = true
            
            local pickedItem = nil
            pcall(function()
                pickedItem = BackpackApp:pick_item({ 
                    keep_cached_scroll_positions_on_open = true, 
                    allow_callback = function() return true end 
                })
            end)
            
            if pickedItem then
                local alreadyInTrade = false
                for _, item in ipairs(mockState.trade.sender_offer.items) do 
                    if item.unique == pickedItem.unique then 
                        alreadyInTrade = true 
                        break 
                    end 
                end
                if not alreadyInTrade then
                    table.insert(mockState.trade.sender_offer.items, pickedItem)
                    mockState.trade.sender_offer.negotiated = false
                    mockState.trade.recipient_offer.negotiated = false
                    if mockState.trade.current_stage == 'confirmation' then
                        mockState.trade.current_stage = 'negotiation'
                        mockState.trade.sender_offer.confirmed = false
                        mockState.trade.recipient_offer.confirmed = false
                    end
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    pcall(function() self:_overwrite_local_trade_state(mockState.trade) end)
                    pcall(function() self:_lock_trade_for_appropriate_time() end)
                    pcall(function()
                        if BackpackApp and BackpackApp.set_item_unique_hidden then 
                            BackpackApp:set_item_unique_hidden(pickedItem.unique, 'TradeApp') 
                        end
                    end)
                end
            end
            mockState.isAddingItem = false
        else
            return mockState.originalFunctions._add_item_to_my_offer(self)
        end
    end

    TradeApp._remove_item_from_my_offer = function(self, item)
        if mockState.active and mockState.trade then
            for i, v in ipairs(mockState.trade.sender_offer.items) do
                if v.unique == item.unique then
                    table.remove(mockState.trade.sender_offer.items, i)
                    mockState.trade.sender_offer.negotiated = false
                    mockState.trade.recipient_offer.negotiated = false
                    if mockState.trade.current_stage == 'confirmation' then
                        mockState.trade.current_stage = 'negotiation'
                        mockState.trade.recipient_offer.negotiated = false
                        mockState.trade.sender_offer.confirmed = false
                        mockState.trade.recipient_offer.confirmed = false
                    end
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    self:_overwrite_local_trade_state(mockState.trade)
                    if self._lock_trade_for_appropriate_time then self:_lock_trade_for_appropriate_time() end
                    if BackpackApp.reset_hidden_item_tag then BackpackApp:reset_hidden_item_tag('TradeApp') end
                    break
                end
            end
        else
            return mockState.originalFunctions._remove_item_from_my_offer(self, item)
        end
    end

    TradeApp._on_accept_pressed = function(self)
        if mockState.active and mockState.trade then
            if mockState.trade.sender_offer.negotiated then
                mockState.trade.sender_offer.negotiated = false
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                self:_overwrite_local_trade_state(mockState.trade)
            else
                mockState.trade.sender_offer.negotiated = true
                if mockState.trade.recipient_offer.negotiated then
                    mockState.trade.current_stage = 'confirmation'
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    self:_overwrite_local_trade_state(mockState.trade)
                    if TradeApp._evaluate_trade_fairness then TradeApp:_evaluate_trade_fairness() end
                    if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
                else
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    self:_overwrite_local_trade_state(mockState.trade)
                end
            end
            if CONFIG.AUTO_PARTNER and not mockState.trade.recipient_offer.negotiated and mockState.trade.sender_offer.negotiated then task.spawn(partnerAutoAction) end
        else
            return mockState.originalFunctions._on_accept_pressed(self)
        end
    end

    TradeApp._on_confirm_pressed = function(self)
        if mockState.active and mockState.trade then
            if mockState.removePartnerPetsOnConfirm then removePartnerPetsVisually() end
            mockState.trade.sender_offer.confirmed = true
            mockState.trade.offer_version = mockState.trade.offer_version + 1
            self:_overwrite_local_trade_state(mockState.trade)
            if CONFIG.AUTO_PARTNER and not mockState.trade.recipient_offer.confirmed then task.spawn(partnerAutoAction) end
        else
            return mockState.originalFunctions._on_confirm_pressed(self)
        end
    end

    TradeApp._on_unaccept_pressed = function(self)
        if mockState.active and mockState.trade then
            mockState.trade.sender_offer.negotiated = false
            if mockState.trade.current_stage == 'confirmation' then
                mockState.trade.current_stage = 'negotiation'
                mockState.trade.recipient_offer.negotiated = false
                mockState.trade.sender_offer.confirmed = false
                mockState.trade.recipient_offer.confirmed = false
            end
            mockState.trade.offer_version = mockState.trade.offer_version + 1
            self:_overwrite_local_trade_state(mockState.trade)
        else
            return mockState.originalFunctions._on_unaccept_pressed(self)
        end
    end

    TradeApp._decline_trade = function(self, silent)
        if mockState.active then
            if self.lock_countdown then self.lock_countdown:stop() end
            mockState.active = false
            mockState.trade = nil
            mockState.isAddingItem = false
            mockState.partnerActionPending = false
            mockState.tradeCompleting = false
            mockState.scamWarningShown = false
            mockState.canShowTradeRequest = true
            mockState.tradeRequestBlocked = false
            self:_overwrite_local_trade_state(nil)
            UIManager.set_app_visibility('TradeApp', false)
            if BackpackApp.reset_hidden_item_tag then BackpackApp:reset_hidden_item_tag('TradeApp') end
            showBlockedTradeRequests()
        else
            return mockState.originalFunctions._decline_trade(self, silent)
        end
    end

    TradeApp._evaluate_trade_fairness = function(self)
        if mockState.active and mockState.trade and not mockState.scamWarningShown then
            local myItems = #mockState.trade.sender_offer.items
            local partnerItems = #mockState.trade.recipient_offer.items
            if myItems > 0 and partnerItems == 0 then
                mockState.scamWarningShown = true
                if DialogApp then
                    DialogApp:dialog({ text = 'This trade seems unbalanced. Be careful - you could be getting scammed.', button = 'Next', yields = false })
                    DialogApp:dialog({ text = 'Any items lost to scams WILL NOT be returned. Be sure before you accept!', button = 'I understand', yields = false })
                end
            end
        else
            return mockState.originalFunctions._evaluate_trade_fairness(self)
        end
    end
end

hookTradeFunctions()

local function startMockTradeDirectly()
    if mockState.active then return end
    -- Profile pets are pre-fetched in updatePartnerFromUsername as soon as the
    -- username is typed — no need to fetch again here.
    
    local success, err = pcall(function()
        mockState.active = false
        mockState.trade = nil
        mockState.isAddingItem = false
        mockState.partnerActionPending = false
        mockState.tradeCompleting = false
        mockState.scamWarningShown = true
        mockState.tradeRequestBlocked = true
        mockState.blockedTradeRequests = {}
        mockState.pendingTradeRequest = false
        
        mockState.trade = createMockTrade()
        mockState.active = true
        
        pcall(function() UIManager.set_app_visibility('TradeApp', false) end)
        task.wait(0.05)
        
        pcall(function() TradeApp:_overwrite_local_trade_state(mockState.trade) end)
        task.wait(0.05)
        
        pcall(function() UIManager.set_app_visibility('TradeApp', true) end)
        pcall(function() FriendHighlight(true) end)
        
        pcall(function()
            if TradeApp._show_intro_message then
                TradeApp:_show_intro_message()
            end
        end)
        
        task.wait(0.05)
        pcall(function() 
            if TradeApp.refresh_all then 
                TradeApp:refresh_all() 
                FriendHighlight(true) 
            end 
        end)
    end)
    
    if not success and HintApp then
        HintApp:hint({ text = 'Error starting trade: ' .. tostring(err), length = 5, overridable = true })
    end
end

local function showTradeRequest()
    if mockState.pendingTradeRequest or mockState.active then
        return
    end
    mockState.pendingTradeRequest = true
    mockState.canShowTradeRequest = false
    task.wait(CONFIG.TRADE_REQUEST_DELAY)
    if not mockState.pendingTradeRequest or mockState.active then
        mockState.pendingTradeRequest = false
        mockState.canShowTradeRequest = true
        return
    end
    
    local name = CONFIG.PARTNER_NAME
    local trade_request_table_friend = { 
        ["text"] = name .. " sent you a trade request", 
        ["left"] = "Decline", 
        ["right"] = "Accept", 
        ["header"] = {
            ["text"] = "Verified Friend",
            ["icon"] = "rbxassetid://84667805159408" 
        },
        ["tooltip_options"] = {
            ["force_display_post_trade_values"] = true
        },
        ["yields"] = true
    } 
    local trade_request_table_not_friend = { 
        ["text"] = name .. " sent you a trade request", 
        ["left"] = "Decline", 
        ["right"] = "Accept",
        ["yields"] = true
    } 
    
    mockState.isMockTradeDialog = true
    
    local dialogResult
    local success, err = pcall(function()
        if mockState.originalDialogFunction then
            if CONFIG.FRIEND_PARTNER then
                dialogResult = mockState.originalDialogFunction(DialogApp, trade_request_table_friend)
            else
                dialogResult = mockState.originalDialogFunction(DialogApp, trade_request_table_not_friend)
            end
        else
            if CONFIG.FRIEND_PARTNER then
                dialogResult = DialogApp:dialog(trade_request_table_friend)
            else
                dialogResult = DialogApp:dialog(trade_request_table_not_friend)
            end
        end
    end)
    
    mockState.isMockTradeDialog = false
    mockState.pendingTradeRequest = false
    
    if success and dialogResult and (dialogResult == "Accept" or dialogResult == "right") then
        startMockTradeDirectly()
    else
        mockState.canShowTradeRequest = true
    end
end

local function hookTradeRequestEvent()
    local tradeRequestEvent = RouterClient.get_event('TradeAPI/TradeRequestReceived')
    if tradeRequestEvent then
        local originalConnections = getconnections(tradeRequestEvent.OnClientEvent)
        for _, connection in pairs(originalConnections) do connection:Disable() end
        tradeRequestEvent.OnClientEvent:Connect(function(requestingPlayer)
            if mockState.active or mockState.tradeRequestBlocked then
                table.insert(mockState.blockedTradeRequests, { player = requestingPlayer, timestamp = tick() })
                return
            end
            for _, connection in pairs(originalConnections) do
                if connection.Function then connection.Function(requestingPlayer) end
            end
        end)
    end
end

local function hookDialogApp()
    if not DialogApp or not DialogApp.dialog then return end
    mockState.originalDialogFunction = DialogApp.dialog
    DialogApp.dialog = function(self, dialogData)
        if dialogData and dialogData.text and string.find(dialogData.text, 'has expired!') then return 'Okay' end
        
        if mockState.isMockTradeDialog then
            return mockState.originalDialogFunction(self, dialogData)
        end
        
        if dialogData and dialogData.header and type(dialogData.header) == 'table' and dialogData.header.text == 'Verified Friend' then
            return mockState.originalDialogFunction(self, dialogData)
        end
        
        if dialogData and dialogData.handle == 'trade_request' then
            if mockState.pendingTradeRequest or mockState.active or mockState.tradeRequestBlocked then return 'Decline' end
        end
        
        return mockState.originalDialogFunction(self, dialogData)
    end
end

hookDialogApp()
hookTradeRequestEvent()

showBlockedTradeRequests = function()
    if #mockState.blockedTradeRequests > 0 then
        task.wait(0.5)
        local TradeExcluder = load('TradeExcluder')
        for _, request in ipairs(mockState.blockedTradeRequests) do
            local requestingPlayer = request.player
            if TradeExcluder and TradeExcluder.is_player_excluded(requestingPlayer) then
                RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(requestingPlayer, false)
            else
                if DialogApp and mockState.originalDialogFunction then
                    local response = mockState.originalDialogFunction(DialogApp, {
                        text = string.format('%s sent you a trade request', requestingPlayer.Name),
                        left = 'Decline', right = 'Accept', handle = 'trade_request',
                    })
                    if response == 'Accept' then
                        local shouldAccept = true
                        if TradeApp._confirm_player_if_suspicious then shouldAccept = TradeApp:_confirm_player_if_suspicious(requestingPlayer) end
                        if shouldAccept and not TradeApp:check_and_warn_if_trading_restricted() then TradeApp:show_scam_warning() end
                        RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(requestingPlayer, shouldAccept)
                    else
                        RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(requestingPlayer, false)
                    end
                end
            end
        end
        mockState.blockedTradeRequests = {}
    end
end

task.spawn(function()
    task.wait(1)
    pcall(function()
        if TradeApp and TradeApp.partner_profile_button then
            local profileButton = TradeApp.partner_profile_button
            if profileButton.callbacks and profileButton.callbacks.mouse_button1_click then
                local originalProfileClick = profileButton.callbacks.mouse_button1_click
                profileButton.callbacks.mouse_button1_click = function()
                    if mockState.active and mockState.trade and mockState.trade.recipient then
                        if PlayerProfileApp and PlayerProfileApp.open_player_profile_for_user_id then 
                            PlayerProfileApp:open_player_profile_for_user_id(mockState.trade.recipient.UserId) 
                        end
                    else
                        if originalProfileClick then originalProfileClick() end
                    end
                end
            end
        end
    end)
end)

function updatePartnerFromUsername(username)
    local success, userId = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
    if success and userId then
        CONFIG.PARTNER_USER_ID = userId
        CONFIG.PARTNER_NAME = username
        mockPartner = createMockPartner()
        -- Start fetching profile pets immediately so they're ready by the time
        -- the user clicks Start Trade. The fetch can take 10-20s, so starting
        -- it here (on username entry) instead of at trade-start makes all the difference.
        mockState.partnerProfilePets = nil
        mockState.mockFakeInventory  = nil
        task.spawn(function()
            local fetched = fetchPartnerProfilePets(userId)
            mockState.partnerProfilePets = fetched
            -- If a trade is already active, wipe the old inventory so the next
            -- suggest click rebuilds it with the real profile pets.
            mockState.mockFakeInventory = nil
            if fetched then
                print("[Suggest] Loaded", #fetched, "profile pets for", username)
            else
                print("[Suggest] No profile pets found for", username, "— using random inventory")
            end
        end)
        return true
    else
        CONFIG.PARTNER_NAME = username
        mockPartner = createMockPartner()
        mockState.partnerProfilePets = nil
        mockState.mockFakeInventory  = nil
        return false
    end
end

local function applyMegaNeonEffects(petModel, kind)
    local petRigs = load('new:PetRigs')
    local petModelInstance = petModel:FindFirstChild('PetModel') or petModel
    local petData = InventoryDB.pets[kind]
    if not petData or not petData.neon_parts then return end
    for neonPart, configuration in pairs(petData.neon_parts) do
        local trueNeonPart = petRigs.get(petModelInstance).get_geo_part(petModelInstance, neonPart)
        if trueNeonPart then
            trueNeonPart.Material = Enum.Material.Neon
            local originalColor = configuration.Color
            if originalColor then
                local h, s, v = originalColor:ToHSV()
                trueNeonPart.Color = Color3.fromHSV(h, math.min(s * 1.3, 1), math.min(v * 1.4, 1))
            else
                trueNeonPart.Color = Color3.fromRGB(170, 0, 255)
            end
        end
    end
end

local function applyNeonEffects(petModel, kind)
    local petRigs = load('new:PetRigs')
    local petModelInstance = petModel:FindFirstChild('PetModel') or petModel
    local petData = InventoryDB.pets[kind]
    if not petData or not petData.neon_parts then return end
    for neonPart, configuration in pairs(petData.neon_parts) do
        local trueNeonPart = petRigs.get(petModelInstance).get_geo_part(petModelInstance, neonPart)
        if trueNeonPart then
            trueNeonPart.Material = Enum.Material.Neon
            if configuration.Color then trueNeonPart.Color = configuration.Color end
        end
    end
end

local UIState = {
    currentTab = 'CONTROL',
    tabFrames = {},
    tabButtons = {},
    activeTabPulseTween = nil,
    hasShownAnimation = {},
    playerListButtons = {},
    userListButtons = {},
    petListButtons = {},
    noclipEnabled = true,
    selectedPlayers = {},
    selectionMode = false,
    pulsationTweens = {},
    richestData = {},
    expandedPlayers = {},
    keybinds = {
        selectPartner = Enum.KeyCode.P,
        addRandomItem = Enum.KeyCode.R,
        startTrade = Enum.KeyCode.T,
        blockPlayer = Enum.KeyCode.B
    },
    waitingForKeybind = nil
}
local tabFrames = UIState.tabFrames
local tabButtons = UIState.tabButtons
local richestData = UIState.richestData
local expandedPlayers = UIState.expandedPlayers

local FakePlayers = {}
local FakePetRegistry = {}

-- ==================== FAKE PLAYER FOLLOW SYSTEM ====================
_G.followEnabled   = false
_G.followAnimCache = {}  -- [uniqueId .. animId] = loaded track
_G.followCharId    = 0   -- incrementing unique ID per fake character

task.spawn(function()
    local followConnection = nil
    local WALK_SPEED     = 16
    local STOP_RADIUS    = 8
    local REST_DELAY_MIN = 3.0
    local REST_DELAY_MAX = 5.0
    -- Standard R15 animations — work on every rig CreateHumanoidModelFromUserId produces
    local WALK_ANIM_ID   = 'rbxassetid://507767714'
    local IDLE_ANIM_ID   = 'rbxassetid://507766388'
    local playerRestUntil = {}

    -- setWalking ONLY reads from cache — never loads inside Heartbeat
    local function setWalking(character, isWalking)
        local uid = character:GetAttribute('FollowAnimUID')
        if not uid then return end
        local walkTrack = _G.followAnimCache[uid .. 'W']
        local idleTrack = _G.followAnimCache[uid .. 'I']
        if not walkTrack and not idleTrack then return end
        pcall(function()
            if isWalking then
                if idleTrack and idleTrack.IsPlaying then idleTrack:Stop(0.15) end
                if walkTrack and not walkTrack.IsPlaying then
                    walkTrack.Looped = true
                    walkTrack:Play(0.15)
                end
            else
                if walkTrack and walkTrack.IsPlaying then walkTrack:Stop(0.15) end
                if idleTrack and not idleTrack.IsPlaying then
                    idleTrack.Looped = true
                    idleTrack:Play(0.15)
                end
            end
        end)
    end

    -- Called once per fake player right after spawn
    _G.preloadFollowAnims = function(character)
        task.spawn(function()
            -- Assign a unique numeric ID so cache keys are always distinct
            _G.followCharId = _G.followCharId + 1
            local uid = tostring(_G.followCharId)
            character:SetAttribute('FollowAnimUID', uid)

            local humanoid = character:FindFirstChildOfClass('Humanoid')
            if not humanoid then humanoid = character:WaitForChild('Humanoid', 5) end
            if not humanoid then return end

            -- Kill the built-in Animate script — it fights with our custom tracks
            local animScript = character:FindFirstChild('Animate')
            if animScript then animScript.Enabled = false end

            local animator = humanoid:FindFirstChildOfClass('Animator')
            if not animator then
                animator = Instance.new('Animator')
                animator.Parent = humanoid
            end

            task.wait(1.0)  -- give the character time to fully settle

            -- Stop any tracks the Animate script may have started
            pcall(function()
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    track:Stop(0)
                end
            end)

            -- Load walk
            pcall(function()
                local anim = Instance.new('Animation')
                anim.AnimationId = WALK_ANIM_ID
                local t = animator:LoadAnimation(anim)
                t.Looped = true
                _G.followAnimCache[uid .. 'W'] = t
            end)
            task.wait(0.05)
            -- Load idle
            pcall(function()
                local anim = Instance.new('Animation')
                anim.AnimationId = IDLE_ANIM_ID
                local t = animator:LoadAnimation(anim)
                t.Looped = true
                _G.followAnimCache[uid .. 'I'] = t
            end)
            task.wait(0.05)

            -- Start idle so they are not in T-pose
            setWalking(character, false)
        end)
    end

    local function startFollowLoop()
        if followConnection then return end
        followConnection = RunService.Heartbeat:Connect(function(dt)
            if not _G.followEnabled then
                for _, folder in ipairs(FakePlayers) do
                    if folder and folder.Parent then
                        for _, child in ipairs(folder:GetChildren()) do
                            if child:IsA('Model') then setWalking(child, false) break end
                        end
                    end
                end
                return
            end

            local localChar = Players.LocalPlayer.Character
            if not localChar then return end
            local localRoot = localChar:FindFirstChild('HumanoidRootPart')
            if not localRoot then return end

            local now   = tick()
            local count = #FakePlayers

            for i, folder in ipairs(FakePlayers) do
                if folder and folder.Parent then
                    local character = nil
                    local petModel  = nil

                    for _, child in ipairs(folder:GetChildren()) do
                        if child:IsA('Model') then
                            if child:GetAttribute('IsFakePet') then
                                petModel = child
                            else
                                character = child
                            end
                        end
                    end

                    if character then
                        -- If riding a pet, move the pet — the RigidConstraint drags the character along
                        local moveTarget = petModel or character
                        local rootPart   = moveTarget:FindFirstChild('HumanoidRootPart')
                            or (moveTarget.PrimaryPart)

                        if rootPart then
                            local angle  = (2 * math.pi / math.max(count, 1)) * (i - 1)
                            local offset = Vector3.new(math.cos(angle) * STOP_RADIUS, 0, math.sin(angle) * STOP_RADIUS)
                            local charRoot = character:FindFirstChild('HumanoidRootPart')
                            local refPos = charRoot and charRoot.Position or rootPart.Position
                            local target = Vector3.new(
                                localRoot.Position.X + offset.X,
                                rootPart.Position.Y,
                                localRoot.Position.Z + offset.Z
                            )
                            local dist = (Vector3.new(refPos.X, 0, refPos.Z)
                                       - Vector3.new(target.X, 0, target.Z)).Magnitude

                            if playerRestUntil[folder] and now < playerRestUntil[folder] then
                                -- Resting: zero velocity so game plays idle anim, face player
                                local look = Vector3.new(localRoot.Position.X - rootPart.Position.X, 0, localRoot.Position.Z - rootPart.Position.Z)
                                if look.Magnitude > 0.1 then rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + look) end
                                if petModel then
                                    pcall(function() rootPart.AssemblyLinearVelocity = Vector3.zero end)
                                else
                                    setWalking(character, false)
                                end

                            elseif dist > 1.5 then
                                -- Walking toward target
                                local dir    = Vector3.new(target.X - rootPart.Position.X, 0, target.Z - rootPart.Position.Z).Unit
                                local step   = math.min(WALK_SPEED * dt, dist)
                                local newPos = rootPart.Position + dir * step
                                rootPart.CFrame = CFrame.new(newPos, newPos + dir)
                                -- For pets: set velocity so the game's native anim system sees movement and plays walk
                                if petModel then
                                    pcall(function() rootPart.AssemblyLinearVelocity = dir * WALK_SPEED end)
                                else
                                    setWalking(character, true)
                                end
                                playerRestUntil[folder] = nil

                            else
                                -- Just arrived: assign rest delay of 3-5s
                                if not playerRestUntil[folder] then
                                    playerRestUntil[folder] = now + REST_DELAY_MIN + math.random() * (REST_DELAY_MAX - REST_DELAY_MIN)
                                end
                                local look = Vector3.new(localRoot.Position.X - rootPart.Position.X, 0, localRoot.Position.Z - rootPart.Position.Z)
                                if look.Magnitude > 0.1 then rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + look) end
                                if petModel then
                                    pcall(function() rootPart.AssemblyLinearVelocity = Vector3.zero end)
                                else
                                    setWalking(character, false)
                                end
                            end
                        end
                    end
                end
            end
        end)
    end

    startFollowLoop()
end)
-- ==================== END FAKE PLAYER FOLLOW SYSTEM ====================

local function updateData(key, action)
    local data = ClientData.get(key)
    local clonedData = table.clone(data)
    ClientData.predict(key, action(clonedData))
end

local AnimationManager = { running = false, checkInterval = 0.3, animationTracks = {} }

function AnimationManager:Start()
    if self.running then return end
    self.running = true
    task.spawn(function()
        while self.running do
            task.wait(self.checkInterval)
            for _, petData in ipairs(FakePetRegistry) do
                if petData and petData.model and petData.model.Parent then
                    pcall(function()
                        local character = petData.character
                        if character and character.Parent then
                            local humanoid = character:FindFirstChild('Humanoid')
                            if humanoid then
                                local animator = humanoid:FindFirstChild('Animator')
                                if animator then
                                    local isRiding = false
                                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                        if track.Animation.AnimationId:find('PlayerRidingPet') or track.Animation.AnimationId:find('507766666') then isRiding = true break end
                                    end
                                    if not isRiding and petData.hasRidingPet then
                                        if not petData.ridingAnim or not petData.ridingAnim.IsPlaying then
                                            if petData.ridingAnim then petData.ridingAnim:Stop() end
                                            petData.ridingAnim = animator:LoadAnimation(animationManager.get_track('PlayerRidingPet'))
                                            petData.ridingAnim.Looped = true
                                            petData.ridingAnim:Play()
                                            humanoid.Sit = true
                                        end
                                    end
                                end
                            end
                        end
                        if petData.wrapper.mega_neon then applyMegaNeonEffects(petData.model, petData.wrapper.pet_id)
                        elseif petData.wrapper.neon then applyNeonEffects(petData.model, petData.wrapper.pet_id) end
                    end)
                end
            end
        end
    end)
end

function AnimationManager:Stop()
    self.running = false
    for _, petData in ipairs(FakePetRegistry) do
        if petData.ridingAnim then petData.ridingAnim:Stop() end
    end
end

function AnimationManager:AddPet(petData)
    table.insert(FakePetRegistry, petData)
    if not self.running then self:Start() end
end

local function createFakePetOwner(fakeCharacter, partnerName, partnerId)
    return setmetatable({
        Name = partnerName, DisplayName = partnerName, UserId = partnerId, Character = fakeCharacter,
    }, {
        __index = function(t, k)
            if k == 'Parent' then return Players end
            if k == 'IsA' then return function(self, className) return className == 'Player' end end
            if k == 'GetChildren' then return function() return {} end end
            return rawget(t, k)
        end,
        __tostring = function() return partnerName end
    })
end

function OpenProfile(Id)
    UIManager.apps.PlayerProfileApp:open_player_profile_for_user_id(Id)
end

task.spawn(function()
    task.wait(0.1)
    local InteractionsEngine = load('InteractionsEngine')
    local original_register = InteractionsEngine.register
    InteractionsEngine.register = function(self, interactionData)
        if interactionData and interactionData.part then
            local checkPart = interactionData.part
            while checkPart do
                if checkPart:GetAttribute('IsFakePet') == true and checkPart.Parent then return end
                checkPart = checkPart.Parent
            end
        end
        return original_register(self, interactionData)
    end
end)

local currentFakePetType = 'regular'

function CreateFakePlayerCharacterFromPARTNER_NAME(partner_name, partner_id, pros_fake_pet, pet_flags)
    local maxRetries, retryCount = 3, 0

    local function attemptCreate()
        retryCount = retryCount + 1
        fakePlayerIds[partner_id] = true
        _G.fakePlayerIds[partner_id] = true

        local folder_fake = Instance.new('Folder')
        folder_fake.Name = 'fake_folder_' .. partner_name
        folder_fake.Parent = workspace

        local character = Players:CreateHumanoidModelFromUserId(partner_id)
        local playerCharacter = Players.LocalPlayer.Character
        character:SetPrimaryPartCFrame(playerCharacter.HumanoidRootPart.CFrame * CFrame.new(math.random(-10, 10), 0, math.random(-10, 10)))
        local humanoid = character:WaitForChild('Humanoid')
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.HealthDisplayDistance = 0
        character.Parent = folder_fake
        -- Preload follow animations so they're ready when Follow Player is toggled on
        if _G.preloadFollowAnims then _G.preloadFollowAnims(character) end

        if pros_fake_pet ~= nil then
            local petCreated = false
            local success, err = pcall(function()
                local kind = pros_fake_pet.kind
                local petModel = getPetModel(kind)
                if not petModel then warn('Could not get pet model for kind:', kind) return end
                petModel = petModel:Clone()
                petModel:SetAttribute('IsFakePet', true)
                if pet_flags then
                    if pet_flags.M then applyMegaNeonEffects(petModel, kind)
                    elseif pet_flags.N then applyNeonEffects(petModel, kind) end
                end
                petModel.Parent = folder_fake
                petModel:SetPrimaryPartCFrame(character.HumanoidRootPart.CFrame)
                petModel:ScaleTo(2)
                for _, part in ipairs(petModel:GetDescendants()) do
                    if part:IsA('BasePart') then part:SetAttribute('IsFakePet', true) end
                end
                local ridePosition = petModel:FindFirstChild('RidePosition', true)
                if ridePosition then
                    local sourceAttachment = Instance.new('Attachment')
                    sourceAttachment.Parent = ridePosition
                    sourceAttachment.Position = Vector3.new(0, 1.237, 0)
                    sourceAttachment.Name = 'SourceAttachment'
                    local stateConnection = Instance.new('RigidConstraint')
                    stateConnection.Name = 'StateConnection'
                    stateConnection.Attachment0 = sourceAttachment
                    stateConnection.Attachment1 = character.PrimaryPart.RootAttachment
                    stateConnection.Parent = character
                end
                local ridingAnim = character.Humanoid.Animator:LoadAnimation(animationManager.get_track('PlayerRidingPet'))
                ridingAnim.Looped = true
                ridingAnim:Play()
                character.Humanoid.Sit = true
                for _, descendant in pairs(character:GetDescendants()) do
                    if descendant:IsA('BasePart') and descendant.Massless == false then
                        descendant.Massless = true
                        descendant:SetAttribute('HaveMass', true)
                    end
                end
                local fakePetOwner = createFakePetOwner(character, partner_name, partner_id)
                local petWrapper = {
                    char = petModel, mega_neon = pet_flags and pet_flags.M or false, neon = pet_flags and pet_flags.N or false,
                    player = fakePetOwner, entity_controller = fakePetOwner, controller = fakePetOwner, rp_name = '',
                    pet_trick_level = math.random(1, 5), pet_unique = HttpService:GenerateGUID(false), pet_id = kind,
                    location = { full_destination_id = 'housing', destination_id = 'housing', house_owner = fakePetOwner },
                    pet_progression = { age = math.random(1, 900000), percentage = math.random(0.01, 0.99) },
                    are_colors_sealed = false, is_pet = true,
                }
                local petState = { char = petModel, player = fakePetOwner, store_key = 'pet_state_managers', is_sitting = false, chars_connected_to_me = {}, states = { { id = 'PetBeingRidden' } } }
                updateData('pet_char_wrappers', function(petWrappers)
                    petWrapper.unique = #petWrappers + 1
                    petWrapper.index = #petWrappers + 1
                    petWrappers[#petWrappers + 1] = petWrapper
                    return petWrappers
                end)
                updateData('pet_state_managers', function(petStates)
                    petStates[#petStates + 1] = petState
                    return petStates
                end)
                table.insert(FakePetRegistry, {
                    wrapper = petWrapper, state = petState, model = petModel, character = character,
                    hasRidingPet = true, owner = fakePetOwner, ridingAnim = ridingAnim, folder = folder_fake,
                })
                if not AnimationManager.running then AnimationManager:Start() end
                petCreated = true
                print('✓ Registered fake pet with native game systems:', kind, pet_flags and (pet_flags.M and 'Mega Neon' or pet_flags.N and 'Neon' or 'Regular') or 'Regular')
            end)
            if not success or not petCreated then
                warn('Error creating fake pet (Attempt ' .. retryCount .. '/' .. maxRetries .. '):', err)
                folder_fake:Destroy()
                for i, folder in ipairs(FakePlayers) do if folder == folder_fake then table.remove(FakePlayers, i) break end end
                if retryCount < maxRetries then
                    print('🔄 Retrying fake character creation for ' .. partner_name .. '...')
                    task.wait(0.5)
                    return attemptCreate()
                else
                    warn('❌ Failed to create fake character after ' .. maxRetries .. ' attempts')
                    return false
                end
            end
        else
            local Animation = Instance.new('Animation')
            Animation.AnimationId = 'http://www.roblox.com/asset/?id=507766666'
            local track = character.Humanoid.Animator:LoadAnimation(Animation)
            track.Looped = true
            track:Play()
        end

        pcall(function() UIManager.apps.PlayerNameApp:add_npc_id(character, partner_name) end)

        local Part = character:FindFirstChild('HumanoidRootPart')
        if Part then
            local InteractionsEngine = load('InteractionsEngine')
            local emptyFunc = function() end
            pcall(function()
                InteractionsEngine:register({
                    text = partner_name, part = Part,
                    on_selected = {
                        { text = 'Profile', on_selected = function() pcall(OpenProfile, partner_id) end },
                        { text = 'Trade', on_selected = function()
                            pcall(function()
                                task.spawn(function()
                                    pcall(function()
                                        if HintApp then HintApp:hint({ text = 'Trade request sent to ' .. partner_name, length = 3, overridable = true }) end
                                    end)
                                end)
                                task.wait(CONFIG.FAKE_PLAYER_ACCEPT_TRADE_REQUEST)
                                if partnerBox then partnerBox.Text = partner_name end
                                updatePartnerFromUsername(partner_name)
                                startMockTradeDirectly()
                            end)
                        end },
                        { text = 'Give Item...', on_selected = emptyFunc },
                        { text = 'Mute', on_selected = emptyFunc },
                    },
                })
            end)
        end

        table.insert(FakePlayers, folder_fake)
        folder_fake:SetAttribute('IsFakePlayer', true)
        folder_fake:SetAttribute('PartnerName', partner_name)
        folder_fake:SetAttribute('PartnerId', partner_id)
        return true
    end

    return attemptCreate()
end

function GetKindPet(name)
    for k, v in pairs(InventoryDB.pets) do
        if v['name']:lower() == name:lower() then return k end
    end
end

local function enableNoclip(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA('BasePart') then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            pcall(function() part.CollisionGroup = 'Noclip' end)
        end
    end
    character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA('BasePart') then
            task.wait()
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            pcall(function() descendant.CollisionGroup = 'Noclip' end)
        end
    end)
end

local function enableNoclipForAllFakePlayers()
    for _, folder in ipairs(FakePlayers) do
        if folder and folder.Parent then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA('Model') then enableNoclip(child) end
            end
        end
    end
end

local function enableNoclipForPets()
    for _, petData in ipairs(FakePetRegistry) do
        if petData and petData.model and petData.model.Parent then enableNoclip(petData.model) end
    end
end

function BlockPlayer(Selected)
    pcall(function()
        setthreadidentity(8)
    end)
    game:GetService('StarterGui'):SetCore('PromptBlockPlayer', Selected)

    local startTime = tick()
    local modal = nil
    while not modal do
        RunService.Heartbeat:Wait()
        if tick() - startTime > 10 then
            pcall(function() setthreadidentity(2) end)
            return
        end
        local overlay = game:GetService('CoreGui'):FindFirstChild('FoundationOverlay')
        if overlay then
            modal = overlay:FindFirstChild("BlockingModalScreen", true)
        end
    end

    local function hideModal()
        pcall(function()
            modal.BackgroundTransparency = 1
            for _, desc in ipairs(modal:GetDescendants()) do
                pcall(function()
                    if desc:IsA('ImageLabel') or desc:IsA('ImageButton') then
                        desc.ImageTransparency = 1
                        desc.BackgroundTransparency = 1
                    end
                    if desc:IsA('TextLabel') or desc:IsA('TextButton') then
                        desc.TextTransparency = 1
                        desc.BackgroundTransparency = 1
                    end
                    if desc:IsA('Frame') then
                        desc.BackgroundTransparency = 1
                    end
                    if desc:IsA('UIStroke') then
                        desc.Transparency = 1
                    end
                end)
            end
        end)
    end
    hideModal()

    local posConn
    posConn = RunService.Heartbeat:Connect(function()
        pcall(function()
            if modal and modal.Parent then
                hideModal()
            else
                posConn:Disconnect()
            end
        end)
    end)

    local blockBtn = nil

    pcall(function()
        blockBtn = modal.BlockingModalContainerWrapper.BlockingModal.AlertModal.AlertContents.Footer.Buttons['3']
    end)

    if not blockBtn then
        pcall(function()
            local buttonsContainer = modal:FindFirstChild("Buttons", true)
            if buttonsContainer then
                for _, btn in ipairs(buttonsContainer:GetChildren()) do
                    if btn:IsA('ImageButton') or btn:IsA('TextButton') then
                        local textLabel = btn:FindFirstChild("Text")
                        if textLabel and textLabel:IsA('TextLabel') and textLabel.Text == "Block" then
                            blockBtn = btn
                            break
                        end
                    end
                end
                if not blockBtn then
                    blockBtn = buttonsContainer:FindFirstChild('3')
                end
            end
        end)
    end

    if not blockBtn then
        pcall(function()
            for _, desc in ipairs(modal:GetDescendants()) do
                if (desc:IsA('ImageButton') or desc:IsA('TextButton')) then
                    local textChild = desc:FindFirstChild("Text")
                    if textChild and textChild:IsA('TextLabel') and textChild.Text == "Block" then
                        blockBtn = desc
                        break
                    end
                end
            end
        end)
    end

    if blockBtn then
        local attempts = 0
        while attempts < 20 do
            attempts = attempts + 1
            pcall(function()
                game:GetService('GuiService').SelectedObject = blockBtn
            end)
            task.wait()
            pcall(function()
                if game:GetService('GuiService').SelectedObject == blockBtn then
                    game:GetService('VirtualInputManager'):SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                    game:GetService('VirtualInputManager'):SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                end
            end)
            task.wait(0.1)
            pcall(function()
                local absPos = blockBtn.AbsolutePosition
                local absSize = blockBtn.AbsoluteSize
                local cx = absPos.X + absSize.X / 2
                local cy = absPos.Y + absSize.Y / 2
                local vim = game:GetService('VirtualInputManager')
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait()
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)
            pcall(function()
                if firesignal then firesignal(blockBtn.MouseButton1Click) end
            end)
            pcall(function()
                if fireclick then fireclick(blockBtn) end
            end)
            task.wait(0.2)
            local overlay = game:GetService('CoreGui'):FindFirstChild('FoundationOverlay')
            if not overlay or not overlay:FindFirstChild("BlockingModalScreen", true) then
                break
            end
        end
        pcall(function() game:GetService('GuiService').SelectedObject = nil end)
    end

    pcall(function() if posConn then posConn:Disconnect() end end)

    local timeout = tick() + 10
    while tick() < timeout do
        local overlay = game:GetService('CoreGui'):FindFirstChild('FoundationOverlay')
        if not overlay or not overlay:FindFirstChild("BlockingModalScreen", true) then
            break
        end
        RunService.Heartbeat:Wait()
    end

    pcall(function()
        setthreadidentity(2)
    end)
end

local function sendTradeToPlayer(player)
    if not player then return end
    local targetPlayer = Players:FindFirstChild(player.Name)
    if targetPlayer then
        pcall(function()
            local success = false
            
            if not success then
                local success1 = pcall(function()
                    local sendRequest = RouterClient.get('TradeAPI/SendTradeRequest')
                    if sendRequest then
                        if sendRequest.FireServer then
                            sendRequest:FireServer(targetPlayer)
                            success = true
                        elseif sendRequest.InvokeServer then
                            sendRequest:InvokeServer(targetPlayer)
                            success = true
                        end
                    end
                end)
            end
            
            if not success then
                local success2 = pcall(function()
                    local TradeRemote = ReplicatedStorage:FindFirstChild('Remotes') and ReplicatedStorage.Remotes:FindFirstChild('TradeAPI') and ReplicatedStorage.Remotes.TradeAPI:FindFirstChild('SendTradeRequest')
                    if TradeRemote then
                        TradeRemote:FireServer(targetPlayer)
                        success = true
                    end
                end)
            end
            
            if not success then
                local success3 = pcall(function()
                    local InteractionsEngine = load('InteractionsEngine')
                    if InteractionsEngine then
                        InteractionsEngine:send_trade_request(targetPlayer)
                        success = true
                    end
                end)
            end
            
            if success and HintApp then
                HintApp:hint({ text = 'Trade request sent to ' .. player.Name, length = 3, overridable = true })
            elseif HintApp then
                HintApp:hint({ text = 'Could not send trade request to ' .. player.Name, length = 3, overridable = true })
            end
        end)
    else
        if HintApp then
            HintApp:hint({ text = 'Player ' .. player.Name .. ' not found in server', length = 3, overridable = true })
        end
    end
end

local autoSpectateConnection = nil

local function startAutoSpectate()
    if autoSpectateConnection then return end
    
    autoSpectateConnection = task.spawn(function()
        while CONFIG.AUTO_SPECTATE_ENABLED do
            task.wait(CONFIG.AUTO_SPECTATE_INTERVAL)
            
            if mockState.active and mockState.trade then
                local newCount = getRandomSpectatorCount()
                CONFIG.SPECTATOR_COUNT = newCount
                
                if spectatorBox then
                    spectatorBox.Text = tostring(newCount)
                end
                
                mockState.trade.subscriber_count = newCount
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                TradeApp:_overwrite_local_trade_state(mockState.trade)
            end
        end
        autoSpectateConnection = nil
    end)
end

local function stopAutoSpectate()
    CONFIG.AUTO_SPECTATE_ENABLED = false
end

-- ==================== EXACT HTML-INSPIRED UI ====================
-- This creates a UI that matches the right side of the image exactly

local controlGui = Instance.new('ScreenGui')
controlGui.Name = 'MockTradeControl'
controlGui.ResetOnSpawn = false
controlGui.DisplayOrder = 10
controlGui.Enabled = true
controlGui.Parent = Players.LocalPlayer:WaitForChild('PlayerGui')

-- Main Panel - Thinner design like the right side of the image
local mainPanel = Instance.new('Frame')
mainPanel.Size = UDim2.new(0, 260, 0, 650)
mainPanel.Position = UDim2.new(0, 10, 0, 10)
mainPanel.BackgroundColor3 = Color3.fromRGB(17, 17, 20) -- #111114
mainPanel.BorderSizePixel = 0
mainPanel.ZIndex = 1
mainPanel.Active = true
mainPanel.ClipsDescendants = true
mainPanel.Parent = controlGui

local panelCorner = Instance.new('UICorner')
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = mainPanel

local panelStroke = Instance.new('UIStroke')
panelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
panelStroke.Color = Color3.fromRGB(34, 34, 40) -- #222228
panelStroke.Thickness = 1
panelStroke.Parent = mainPanel

local RGBState = { hue = 0, speed = 0.5, enabled = true }

-- Header - Trade Script with LIVE indicator
local header = Instance.new('Frame')
header.Size = UDim2.new(1, 0, 0, 44)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundTransparency = 1
header.Parent = mainPanel

local headerBorder = Instance.new('Frame')
headerBorder.Size = UDim2.new(1, 0, 0, 1)
headerBorder.Position = UDim2.new(0, 0, 1, -1)
headerBorder.BackgroundColor3 = Color3.fromRGB(28, 28, 34) -- #1c1c22
headerBorder.BorderSizePixel = 0
headerBorder.Parent = header

local headerTitle = Instance.new('TextLabel')
headerTitle.Size = UDim2.new(0.5, -16, 1, 0)
headerTitle.Position = UDim2.new(0, 16, 0, 0)
headerTitle.BackgroundTransparency = 1
headerTitle.Text = 'BY x6dr ON DC'
headerTitle.Font = Enum.Font.SourceSansSemibold
headerTitle.TextSize = 11
headerTitle.TextColor3 = Color3.fromRGB(136, 136, 136) -- #888
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

-- Status indicator with blinking dot
local statusFrame = Instance.new('Frame')
statusFrame.Size = UDim2.new(0, 60, 1, 0)
statusFrame.Position = UDim2.new(1, -70, 0, 0)
statusFrame.BackgroundTransparency = 1
statusFrame.Parent = header

local statusDot = Instance.new('Frame')
statusDot.Size = UDim2.new(0, 6, 0, 6)
statusDot.Position = UDim2.new(0, 0, 0.5, -3)
statusDot.BackgroundColor3 = Color3.fromRGB(34, 197, 94) -- #22c55e
statusDot.BorderSizePixel = 0
statusDot.Parent = statusFrame

local dotCorner = Instance.new('UICorner')
dotCorner.CornerRadius = UDim.new(1, 0)
dotCorner.Parent = statusDot

-- Blink animation
task.spawn(function()
    while statusDot and statusDot.Parent do
        statusDot.BackgroundTransparency = 0
        task.wait(0.5)
        statusDot.BackgroundTransparency = 0.7
        task.wait(2)
    end
end)

local statusText = Instance.new('TextLabel')
statusText.Size = UDim2.new(0, 45, 1, 0)
statusText.Position = UDim2.new(0, 12, 0, 0)
statusText.BackgroundTransparency = 1
statusText.Text = 'V1.0'
statusText.Font = Enum.Font.SourceSansSemibold
statusText.TextSize = 10
statusText.TextColor3 = Color3.fromRGB(68, 68, 68) -- #444
statusText.TextXAlignment = Enum.TextXAlignment.Right
statusText.Parent = statusFrame

-- Drag Lock Button
dragEnabled = true
lockBtn = Instance.new('TextButton')
lockBtn.Size = UDim2.new(0, 24, 0, 24)
lockBtn.Position = UDim2.new(1, -38, 0.5, -12)
lockBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
lockBtn.BorderSizePixel = 0
lockBtn.Text = '🔓'
lockBtn.TextSize = 11
lockBtn.TextColor3 = Color3.fromRGB(136, 136, 136)
lockBtn.Font = Enum.Font.SourceSansBold
lockBtn.AutoButtonColor = false
lockBtn.ZIndex = 10
lockBtn.Parent = header

lockBtnCorner = Instance.new('UICorner')
lockBtnCorner.CornerRadius = UDim.new(0, 6)
lockBtnCorner.Parent = lockBtn

lockBtnStroke = Instance.new('UIStroke')
lockBtnStroke.Color = Color3.fromRGB(50, 50, 60)
lockBtnStroke.Thickness = 1
lockBtnStroke.Parent = lockBtn

lockBtn.MouseButton1Click:Connect(function()
    dragEnabled = not dragEnabled
    if dragEnabled then
        lockBtn.Text = '🔓'
        lockBtn.TextColor3 = Color3.fromRGB(136, 136, 136)
        TweenService:Create(lockBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(28, 28, 34)}):Play()
        TweenService:Create(lockBtnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(50, 50, 60)}):Play()
    else
        lockBtn.Text = '🔒'
        lockBtn.TextColor3 = Color3.fromRGB(251, 146, 60)
        TweenService:Create(lockBtn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(40, 22, 8)}):Play()
        TweenService:Create(lockBtnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(251, 146, 60)}):Play()
    end
end)

-- Tabs
local tabsContainer = Instance.new('Frame')
tabsContainer.Size = UDim2.new(1, 0, 0, 44)
tabsContainer.Position = UDim2.new(0, 0, 0, 44)
tabsContainer.BackgroundTransparency = 1
tabsContainer.Parent = mainPanel

local tabsBorder = Instance.new('Frame')
tabsBorder.Size = UDim2.new(1, 0, 0, 1)
tabsBorder.Position = UDim2.new(0, 0, 1, -1)
tabsBorder.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
tabsBorder.BorderSizePixel = 0
tabsBorder.Parent = tabsContainer

local tabs = {'CONTROL', 'PLAYERS', 'PETS', 'USERS', 'SETS'}
local tabButtons = {}

for i, tabName in ipairs(tabs) do
    local tabButton = Instance.new('TextButton')
    tabButton.Size = UDim2.new(0.2, 0, 1, 0)
    tabButton.Position = UDim2.new((i-1) * 0.2, 0, 0, 0)
    tabButton.BackgroundTransparency = 1
    tabButton.Text = tabName
    tabButton.Font = Enum.Font.SourceSansSemibold
    tabButton.TextSize = 9
    tabButton.TextColor3 = i == 1 and Color3.fromRGB(224, 224, 224) or Color3.fromRGB(51, 51, 51) -- #e0e0e0 or #333
    tabButton.AutoButtonColor = false
    tabButton.Parent = tabsContainer
    
    local bottomLine = Instance.new('Frame')
    bottomLine.Size = UDim2.new(0.8, 0, 0, 2)
    bottomLine.Position = UDim2.new(0.1, 0, 1, -2)
    bottomLine.BackgroundColor3 = i == 1 and Color3.fromRGB(74, 158, 255) or Color3.fromRGB(0, 0, 0) -- #4a9eff
    bottomLine.BackgroundTransparency = i == 1 and 0 or 1
    bottomLine.BorderSizePixel = 0
    bottomLine.Parent = tabButton
    
    tabButtons[tabName] = {button = tabButton, line = bottomLine}
    
    tabButton.MouseButton1Click:Connect(function()
        for name, data in pairs(tabButtons) do
            data.button.TextColor3 = name == tabName and Color3.fromRGB(224, 224, 224) or Color3.fromRGB(51, 51, 51)
            data.line.BackgroundTransparency = name == tabName and 0 or 1
        end
        setActiveTab(tabName)
    end)
end

-- Content area (ScrollingFrame)
local contentFrame = Instance.new('ScrollingFrame')
contentFrame.Size = UDim2.new(1, -28, 0, 562) -- inset 14px each side
contentFrame.Position = UDim2.new(0, 14, 0, 88)
contentFrame.BackgroundTransparency = 1
contentFrame.BorderSizePixel = 0
contentFrame.ScrollBarThickness = 3
contentFrame.ScrollBarImageColor3 = Color3.fromRGB(34, 34, 40)
contentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentFrame.Parent = mainPanel

local contentPadding = Instance.new('UIPadding')
contentPadding.PaddingTop = UDim.new(0, 14)
contentPadding.PaddingBottom = UDim.new(0, 14)
contentPadding.PaddingLeft = UDim.new(0, 0)
contentPadding.PaddingRight = UDim.new(0, 0)
contentPadding.Parent = contentFrame

-- Tab panes
local tabPanes = {}

for _, tabName in ipairs(tabs) do
    local pane = Instance.new('Frame')
    pane.Name = tabName .. 'Pane'
    pane.Size = UDim2.new(1, 0, 0, 0)
    pane.BackgroundTransparency = 1
    pane.Visible = tabName == 'CONTROL'
    pane.AutomaticSize = Enum.AutomaticSize.Y
    pane.Parent = contentFrame
    
    local layout = Instance.new('UIListLayout')
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 8)
    layout.Parent = pane
    
    tabPanes[tabName] = pane
end

-- ==================== SETS TAB ====================
task.spawn(function()
    local setsPane = tabPanes['SETS']

    local C_BG      = Color3.fromRGB(12, 12, 15)
    local C_BORDER  = Color3.fromRGB(28, 28, 34)
    local C_BORDER_ACTIVE = Color3.fromRGB(42, 58, 85)
    local C_TEXT    = Color3.fromRGB(204, 204, 204)
    local C_LABEL   = Color3.fromRGB(68, 68, 68)
    local C_ACCENT  = Color3.fromRGB(74, 158, 255)
    local C_GREEN   = Color3.fromRGB(52, 199, 89)
    local C_PANEL   = Color3.fromRGB(22, 22, 28)

    local function sectionLabel(txt, parent)
        local lbl = Instance.new('TextLabel', parent)
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Text = txt
        lbl.Font = Enum.Font.SourceSansSemibold
        lbl.TextSize = 10
        lbl.TextColor3 = C_LABEL
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        return lbl
    end

    local function setsBtn(txt, bg, tc, bc, parent, onClick)
        local btn = Instance.new('TextButton', parent)
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.BackgroundColor3 = bg
        btn.BackgroundTransparency = 0
        btn.Text = txt
        btn.Font = Enum.Font.SourceSansSemibold
        btn.TextSize = 11
        btn.TextColor3 = tc
        btn.AutoButtonColor = false
        Instance.new('UICorner', btn).CornerRadius = UDim.new(1, 0)
        local stroke = Instance.new('UIStroke', btn)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Color = bc or bg:Lerp(Color3.new(1,1,1), 0.3)
        stroke.Thickness = 1
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn,    TweenInfo.new(0.15), {BackgroundColor3 = bg:Lerp(Color3.new(1,1,1), 0.08)}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = C_BORDER_ACTIVE}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn,    TweenInfo.new(0.15), {BackgroundColor3 = bg}):Play()
            TweenService:Create(stroke, TweenInfo.new(0.15), {Color = bc or bg:Lerp(Color3.new(1,1,1), 0.3)}):Play()
        end)
        if onClick then btn.MouseButton1Click:Connect(onClick) end
        return btn, stroke
    end

-- ── THEME SECTION ────────────────────────────────────────────────
    local themeSection = Instance.new('Frame', setsPane)
    themeSection.Size = UDim2.new(1, 0, 0, 0)
    themeSection.BackgroundColor3 = C_PANEL
    themeSection.BackgroundTransparency = 0
    themeSection.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new('UICorner', themeSection).CornerRadius = UDim.new(0, 8)
    local tsStroke = Instance.new('UIStroke', themeSection)
    tsStroke.Color = C_BORDER
    tsStroke.Thickness = 1

    local tsPad = Instance.new('UIPadding', themeSection)
    tsPad.PaddingTop    = UDim.new(0, 12)
    tsPad.PaddingBottom = UDim.new(0, 14)
    tsPad.PaddingLeft   = UDim.new(0, 12)
    tsPad.PaddingRight  = UDim.new(0, 12)

    local tsLayout = Instance.new('UIListLayout', themeSection)
    tsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    tsLayout.Padding   = UDim.new(0, 10)

    local tsTitle = Instance.new('TextLabel', themeSection)
    tsTitle.Size = UDim2.new(1, 0, 0, 18)
    tsTitle.BackgroundTransparency = 1
    tsTitle.Text = 'UI THEME'
    tsTitle.Font = Enum.Font.SourceSansSemibold
    tsTitle.TextSize = 11
    tsTitle.TextColor3 = C_TEXT
    tsTitle.TextXAlignment = Enum.TextXAlignment.Left
    tsTitle.LayoutOrder = 0

    local themes = {
        {
            label = '⬛  Default',
            panelBg      = Color3.fromRGB(17, 17, 20),
            border       = Color3.fromRGB(34, 34, 40),
            headerBorder = Color3.fromRGB(28, 28, 34),
            inputBg      = Color3.fromRGB(12, 12, 15),
            inputBorder  = Color3.fromRGB(28, 28, 34),
            accent       = Color3.fromRGB(74, 158, 255),
            btnBg        = Color3.fromRGB(28, 28, 34),
            btnBorder    = Color3.fromRGB(50, 50, 60),
            textMain     = Color3.fromRGB(204, 204, 204),
            textSub      = Color3.fromRGB(68, 68, 68),
            tabActive    = Color3.fromRGB(224, 224, 224),
            tabInactive  = Color3.fromRGB(51, 51, 51),
            rgb          = true,
        },
        {
            label = '🔵  Ocean',
            panelBg      = Color3.fromRGB(8, 16, 32),
            border       = Color3.fromRGB(18, 42, 80),
            headerBorder = Color3.fromRGB(14, 34, 64),
            inputBg      = Color3.fromRGB(5, 12, 24),
            inputBorder  = Color3.fromRGB(20, 50, 90),
            accent       = Color3.fromRGB(56, 189, 248),
            btnBg        = Color3.fromRGB(12, 28, 54),
            btnBorder    = Color3.fromRGB(24, 60, 110),
            textMain     = Color3.fromRGB(186, 220, 255),
            textSub      = Color3.fromRGB(50, 90, 140),
            tabActive    = Color3.fromRGB(186, 230, 255),
            tabInactive  = Color3.fromRGB(40, 70, 110),
            rgb          = false,
            rgbColor     = Color3.fromRGB(18, 42, 80),
        },
        {
            label = '🔴  Crimson',
            panelBg      = Color3.fromRGB(22, 8, 8),
            border       = Color3.fromRGB(72, 18, 18),
            headerBorder = Color3.fromRGB(50, 14, 14),
            inputBg      = Color3.fromRGB(14, 4, 4),
            inputBorder  = Color3.fromRGB(60, 16, 16),
            accent       = Color3.fromRGB(248, 80, 80),
            btnBg        = Color3.fromRGB(44, 12, 12),
            btnBorder    = Color3.fromRGB(80, 22, 22),
            textMain     = Color3.fromRGB(255, 200, 200),
            textSub      = Color3.fromRGB(120, 50, 50),
            tabActive    = Color3.fromRGB(255, 210, 210),
            tabInactive  = Color3.fromRGB(90, 36, 36),
            rgb          = false,
            rgbColor     = Color3.fromRGB(72, 18, 18),
        },
    }

    local function applyTheme(theme)
        -- Panel background & border
        mainPanel.BackgroundColor3 = theme.panelBg
        panelStroke.Color = theme.border
        RGBState.enabled = theme.rgb
        if not theme.rgb then
            panelStroke.Color = theme.rgbColor or theme.border
        end

        -- Header border
        if headerBorder then
            headerBorder.BackgroundColor3 = theme.headerBorder
        end

        -- Tab underline color for active tab
        for name, data in pairs(tabButtons) do
            local isActive = name == UIState.currentTab
            data.button.TextColor3 = isActive and theme.tabActive or theme.tabInactive
            if data.line then
                data.line.BackgroundColor3 = theme.accent
            end
        end

        -- Scrollbar tint
        contentFrame.ScrollBarImageColor3 = theme.border

        -- Walk all descendants and recolor known element types
        local function recolorDescendants(root)
            for _, child in ipairs(root:GetDescendants()) do
                local name = child.Name or ''

                -- Input boxes / text boxes
                if child:IsA('TextBox') then
                    child.BackgroundColor3 = theme.inputBg
                    child.TextColor3       = theme.textMain
                    child.PlaceholderColor3 = theme.textSub
                    local stroke = child:FindFirstChildOfClass('UIStroke')
                    if stroke then stroke.Color = theme.inputBorder end

                -- Toggle rows / section cards
                elseif child:IsA('Frame') and child.Name ~= 'UICorner' then
                    -- Only recolor frames that look like cards/rows (have a stroke child)
                    local stroke = child:FindFirstChildOfClass('UIStroke')
                    if stroke then
                        local bg = child.BackgroundColor3
                        -- Detect dark panel-ish backgrounds (not neon/accent frames)
                        local r, g, b = bg.R, bg.G, bg.B
                        local avg = (r + g + b) / 3
                        if avg < 0.2 then
                            child.BackgroundColor3 = theme.inputBg
                            stroke.Color = theme.inputBorder
                        end
                    end

                -- Labels
                elseif child:IsA('TextLabel') then
                    local tc = child.TextColor3
                    local r, g, b = tc.R, tc.G, tc.B
                    local avg = (r + g + b) / 3
                    -- Accent-colored labels stay accent
                    if math.abs(r - 0.29) < 0.1 and math.abs(g - 0.62) < 0.1 then
                        child.TextColor3 = theme.accent
                    -- Main text
                    elseif avg > 0.6 then
                        child.TextColor3 = theme.textMain
                    -- Sub / dim text
                    elseif avg > 0.1 and avg <= 0.6 then
                        child.TextColor3 = theme.textSub
                    end
                end
            end
        end

        recolorDescendants(mainPanel)
    end

    -- Button row
    local themeBtnRow = Instance.new('Frame', themeSection)
    themeBtnRow.Size = UDim2.new(1, 0, 0, 36)
    themeBtnRow.BackgroundTransparency = 1
    themeBtnRow.LayoutOrder = 1

    local themeBtnLayout = Instance.new('UIListLayout', themeBtnRow)
    themeBtnLayout.FillDirection = Enum.FillDirection.Horizontal
    themeBtnLayout.Padding = UDim.new(0, 6)
    themeBtnLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local themeButtonRefs = {}

    for ti, theme in ipairs(themes) do
        local isOcean   = theme.label:find('Ocean')
        local isCrimson = theme.label:find('Crimson')

        local btnBg     = isOcean   and Color3.fromRGB(8, 24, 50)
                       or isCrimson and Color3.fromRGB(40, 10, 10)
                       or Color3.fromRGB(22, 22, 28)

        local btnBorder = isOcean   and Color3.fromRGB(20, 60, 110)
                       or isCrimson and Color3.fromRGB(80, 22, 22)
                       or Color3.fromRGB(44, 44, 54)

        local btnText   = isOcean   and Color3.fromRGB(100, 180, 255)
                       or isCrimson and Color3.fromRGB(255, 100, 100)
                       or Color3.fromRGB(180, 180, 180)

        local btn = Instance.new('TextButton', themeBtnRow)
        btn.Size = UDim2.new(0.33, -5, 1, 0)
        btn.BackgroundColor3 = btnBg
        btn.Text = theme.label
        btn.Font = Enum.Font.SourceSansSemibold
        btn.TextSize = 10
        btn.TextColor3 = btnText
        btn.AutoButtonColor = false
        btn.LayoutOrder = ti
        Instance.new('UICorner', btn).CornerRadius = UDim.new(1, 0)

        local bs = Instance.new('UIStroke', btn)
        bs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        bs.Color = btnBorder
        bs.Thickness = 1

        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = btnBg:Lerp(Color3.new(1,1,1), 0.08)}):Play()
            TweenService:Create(bs,  TweenInfo.new(0.12), {Color = btnBorder:Lerp(Color3.new(1,1,1), 0.25)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = btnBg}):Play()
            TweenService:Create(bs,  TweenInfo.new(0.12), {Color = btnBorder}):Play()
        end)

        local capturedTheme = theme
        btn.MouseButton1Click:Connect(function()
            applyTheme(capturedTheme)
            -- Highlight active theme button
            for _, ref in ipairs(themeButtonRefs) do
                TweenService:Create(ref.btn, TweenInfo.new(0.15), {BackgroundColor3 = ref.baseBg}):Play()
                TweenService:Create(ref.stroke, TweenInfo.new(0.15), {Thickness = 1}):Play()
            end
            TweenService:Create(btn,    TweenInfo.new(0.15), {BackgroundColor3 = btnBg:Lerp(Color3.new(1,1,1), 0.15)}):Play()
            TweenService:Create(bs, TweenInfo.new(0.15), {Thickness = 2}):Play()
        end)

        table.insert(themeButtonRefs, { btn = btn, stroke = bs, baseBg = btnBg })
    end

    -- ── GUI SIZE SECTION ────────────────────────────────────────────────
    local sizeSection = Instance.new('Frame', setsPane)
    sizeSection.Size = UDim2.new(1, 0, 0, 0)
    sizeSection.BackgroundColor3 = C_PANEL
    sizeSection.BackgroundTransparency = 0
    sizeSection.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new('UICorner', sizeSection).CornerRadius = UDim.new(0, 8)
    local szStroke = Instance.new('UIStroke', sizeSection)
    szStroke.Color = C_BORDER
    szStroke.Thickness = 1

    local szPad = Instance.new('UIPadding', sizeSection)
    szPad.PaddingTop    = UDim.new(0, 12)
    szPad.PaddingBottom = UDim.new(0, 14)
    szPad.PaddingLeft   = UDim.new(0, 12)
    szPad.PaddingRight  = UDim.new(0, 12)

    local szLayout = Instance.new('UIListLayout', sizeSection)
    szLayout.SortOrder = Enum.SortOrder.LayoutOrder
    szLayout.Padding   = UDim.new(0, 10)

    local szTitle = Instance.new('TextLabel', sizeSection)
    szTitle.Size = UDim2.new(1, 0, 0, 18)
    szTitle.BackgroundTransparency = 1
    szTitle.Text = 'GUI SIZE'
    szTitle.Font = Enum.Font.SourceSansSemibold
    szTitle.TextSize = 11
    szTitle.TextColor3 = C_TEXT
    szTitle.TextXAlignment = Enum.TextXAlignment.Left
    szTitle.LayoutOrder = 0

    local scaleDisplay = Instance.new('TextLabel', sizeSection)
    scaleDisplay.Size = UDim2.new(1, 0, 0, 24)
    scaleDisplay.BackgroundColor3 = C_BG
    scaleDisplay.BackgroundTransparency = 0
    scaleDisplay.Text = 'Scale: 100%'
    scaleDisplay.Font = Enum.Font.SourceSansSemibold
    scaleDisplay.TextSize = 13
    scaleDisplay.TextColor3 = C_ACCENT
    scaleDisplay.LayoutOrder = 1
    Instance.new('UICorner', scaleDisplay).CornerRadius = UDim.new(0, 6)
    local sdStroke = Instance.new('UIStroke', scaleDisplay)
    sdStroke.Color = C_BORDER
    sdStroke.Thickness = 1

    local btnRow = Instance.new('Frame', sizeSection)
    btnRow.Size = UDim2.new(1, 0, 0, 36)
    btnRow.BackgroundTransparency = 1
    btnRow.LayoutOrder = 2
    local btnRowLayout = Instance.new('UIListLayout', btnRow)
    btnRowLayout.FillDirection = Enum.FillDirection.Horizontal
    btnRowLayout.Padding = UDim.new(0, 8)
    btnRowLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local uiScale = mainPanel:FindFirstChild('UIScale') or Instance.new('UIScale')
    uiScale.Name = 'UIScale'
    uiScale.Scale = 1.0
    uiScale.Parent = mainPanel

    local currentScale = 1.0

    local function setScale(s)
        currentScale = math.clamp(s, 0.5, 1.5)
        uiScale.Scale = currentScale
        scaleDisplay.Text = string.format('Scale: %d%%', math.round(currentScale * 100))
        if currentScale < 1.0 then
            scaleDisplay.TextColor3 = Color3.fromRGB(255, 180, 60)
        elseif currentScale > 1.0 then
            scaleDisplay.TextColor3 = C_GREEN
        else
            scaleDisplay.TextColor3 = C_ACCENT
        end
    end

    local smallBtn = Instance.new('TextButton', btnRow)
    smallBtn.Size = UDim2.new(0.5, -4, 1, 0)
    smallBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    smallBtn.Text = '− Smaller'
    smallBtn.Font = Enum.Font.SourceSansSemibold
    smallBtn.TextSize = 11
    smallBtn.TextColor3 = C_TEXT
    smallBtn.AutoButtonColor = false
    smallBtn.LayoutOrder = 1
    Instance.new('UICorner', smallBtn).CornerRadius = UDim.new(1, 0)
    local sbStroke = Instance.new('UIStroke', smallBtn)
    sbStroke.Color = C_BORDER
    sbStroke.Thickness = 1
    smallBtn.MouseEnter:Connect(function()
        TweenService:Create(smallBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 50)}):Play()
        TweenService:Create(sbStroke, TweenInfo.new(0.12), {Color = C_BORDER_ACTIVE}):Play()
    end)
    smallBtn.MouseLeave:Connect(function()
        TweenService:Create(smallBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(28, 28, 34)}):Play()
        TweenService:Create(sbStroke, TweenInfo.new(0.12), {Color = C_BORDER}):Play()
    end)
    smallBtn.MouseButton1Click:Connect(function() setScale(currentScale - 0.05) end)

    local bigBtn = Instance.new('TextButton', btnRow)
    bigBtn.Size = UDim2.new(0.5, -4, 1, 0)
    bigBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
    bigBtn.Text = '+ Bigger'
    bigBtn.Font = Enum.Font.SourceSansSemibold
    bigBtn.TextSize = 11
    bigBtn.TextColor3 = C_TEXT
    bigBtn.AutoButtonColor = false
    bigBtn.LayoutOrder = 2
    Instance.new('UICorner', bigBtn).CornerRadius = UDim.new(1, 0)
    local bbStroke = Instance.new('UIStroke', bigBtn)
    bbStroke.Color = C_BORDER
    bbStroke.Thickness = 1
    bigBtn.MouseEnter:Connect(function()
        TweenService:Create(bigBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(40, 40, 50)}):Play()
        TweenService:Create(bbStroke, TweenInfo.new(0.12), {Color = C_BORDER_ACTIVE}):Play()
    end)
    bigBtn.MouseLeave:Connect(function()
        TweenService:Create(bigBtn, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(28, 28, 34)}):Play()
        TweenService:Create(bbStroke, TweenInfo.new(0.12), {Color = C_BORDER}):Play()
    end)
    bigBtn.MouseButton1Click:Connect(function() setScale(currentScale + 0.05) end)

    local presetRow = Instance.new('Frame', sizeSection)
    presetRow.Size = UDim2.new(1, 0, 0, 30)
    presetRow.BackgroundTransparency = 1
    presetRow.LayoutOrder = 3
    local presetLayout = Instance.new('UIListLayout', presetRow)
    presetLayout.FillDirection = Enum.FillDirection.Horizontal
    presetLayout.Padding = UDim.new(0, 6)
    presetLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local presets = {
        {label = '70%',  scale = 0.70},
        {label = '85%',  scale = 0.85},
        {label = '100%', scale = 1.00},
        {label = '115%', scale = 1.15},
        {label = '130%', scale = 1.30},
    }
    for pi, p in ipairs(presets) do
        local pb = Instance.new('TextButton', presetRow)
        pb.Size = UDim2.new(0.19, -3, 1, 0)
        pb.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
        pb.Text = p.label
        pb.Font = Enum.Font.SourceSansSemibold
        pb.TextSize = 10
        pb.TextColor3 = Color3.fromRGB(180, 180, 180)
        pb.AutoButtonColor = false
        pb.LayoutOrder = pi
        Instance.new('UICorner', pb).CornerRadius = UDim.new(1, 0)
        local pbs = Instance.new('UIStroke', pb)
        pbs.Color = C_BORDER
        pbs.Thickness = 1
        local pScale = p.scale
        pb.MouseEnter:Connect(function()
            TweenService:Create(pb,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(36, 36, 46)}):Play()
            TweenService:Create(pbs, TweenInfo.new(0.12), {Color = C_BORDER_ACTIVE}):Play()
        end)
        pb.MouseLeave:Connect(function()
            TweenService:Create(pb,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(22, 22, 28)}):Play()
            TweenService:Create(pbs, TweenInfo.new(0.12), {Color = C_BORDER}):Play()
        end)
        pb.MouseButton1Click:Connect(function() setScale(pScale) end)
    end

    local resetBtn, _ = setsBtn('↺  Reset to Default (100%)',
        Color3.fromRGB(22, 22, 28), C_TEXT, C_BORDER, sizeSection,
        function() setScale(1.0) end)
    resetBtn.LayoutOrder = 4

    -- ── VALUE CHECKER SECTION ───────────────────────────────────────────
    local valueSection = Instance.new('Frame', setsPane)
    valueSection.Size = UDim2.new(1, 0, 0, 0)
    valueSection.BackgroundColor3 = C_PANEL
    valueSection.BackgroundTransparency = 0
    valueSection.AutomaticSize = Enum.AutomaticSize.Y
    Instance.new('UICorner', valueSection).CornerRadius = UDim.new(0, 8)
    local vsStroke = Instance.new('UIStroke', valueSection)
    vsStroke.Color = C_BORDER
    vsStroke.Thickness = 1

    local vsPad = Instance.new('UIPadding', valueSection)
    vsPad.PaddingTop    = UDim.new(0, 12)
    vsPad.PaddingBottom = UDim.new(0, 14)
    vsPad.PaddingLeft   = UDim.new(0, 12)
    vsPad.PaddingRight  = UDim.new(0, 12)

    local vsLayout = Instance.new('UIListLayout', valueSection)
    vsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    vsLayout.Padding   = UDim.new(0, 8)

    local vsTitle = Instance.new('TextLabel', valueSection)
    vsTitle.Size = UDim2.new(1, 0, 0, 18)
    vsTitle.BackgroundTransparency = 1
    vsTitle.Text = 'TRADE VALUE CHECKER'
    vsTitle.Font = Enum.Font.SourceSansSemibold
    vsTitle.TextSize = 11
    vsTitle.TextColor3 = C_TEXT
    vsTitle.TextXAlignment = Enum.TextXAlignment.Left
    vsTitle.LayoutOrder = 0

    local vsSource = Instance.new('TextLabel', valueSection)
    vsSource.Size = UDim2.new(1, 0, 0, 14)
    vsSource.BackgroundTransparency = 1
    vsSource.Text = 'Values from amvgg.com'
    vsSource.Font = Enum.Font.SourceSans
    vsSource.TextSize = 10
    vsSource.TextColor3 = Color3.fromRGB(51, 51, 51)
    vsSource.TextXAlignment = Enum.TextXAlignment.Left
    vsSource.LayoutOrder = 1

    -- Your offer row
    local yourRow = Instance.new('Frame', valueSection)
    yourRow.Size = UDim2.new(1, 0, 0, 36)
    yourRow.BackgroundColor3 = C_BG
    yourRow.BackgroundTransparency = 0
    yourRow.LayoutOrder = 2
    Instance.new('UICorner', yourRow).CornerRadius = UDim.new(0, 6)
    local yrStroke = Instance.new('UIStroke', yourRow)
    yrStroke.Color = C_BORDER
    yrStroke.Thickness = 1

    local yourLabel = Instance.new('TextLabel', yourRow)
    yourLabel.Size = UDim2.new(0.5, -8, 1, 0)
    yourLabel.Position = UDim2.new(0, 10, 0, 0)
    yourLabel.BackgroundTransparency = 1
    yourLabel.Text = 'YOUR OFFER'
    yourLabel.Font = Enum.Font.SourceSansSemibold
    yourLabel.TextSize = 10
    yourLabel.TextColor3 = C_LABEL
    yourLabel.TextXAlignment = Enum.TextXAlignment.Left

    local yourValue = Instance.new('TextLabel', yourRow)
    yourValue.Size = UDim2.new(0.5, -10, 1, 0)
    yourValue.Position = UDim2.new(0.5, 0, 0, 0)
    yourValue.BackgroundTransparency = 1
    yourValue.Text = '0.00'
    yourValue.Font = Enum.Font.SourceSansSemibold
    yourValue.TextSize = 13
    yourValue.TextColor3 = C_ACCENT
    yourValue.TextXAlignment = Enum.TextXAlignment.Right

    -- Partner offer row
    local partnerRow = Instance.new('Frame', valueSection)
    partnerRow.Size = UDim2.new(1, 0, 0, 36)
    partnerRow.BackgroundColor3 = C_BG
    partnerRow.BackgroundTransparency = 0
    partnerRow.LayoutOrder = 3
    Instance.new('UICorner', partnerRow).CornerRadius = UDim.new(0, 6)
    local prStroke = Instance.new('UIStroke', partnerRow)
    prStroke.Color = C_BORDER
    prStroke.Thickness = 1

    local partnerLabel = Instance.new('TextLabel', partnerRow)
    partnerLabel.Size = UDim2.new(0.5, -8, 1, 0)
    partnerLabel.Position = UDim2.new(0, 10, 0, 0)
    partnerLabel.BackgroundTransparency = 1
    partnerLabel.Text = 'PARTNER OFFER'
    partnerLabel.Font = Enum.Font.SourceSansSemibold
    partnerLabel.TextSize = 10
    partnerLabel.TextColor3 = C_LABEL
    partnerLabel.TextXAlignment = Enum.TextXAlignment.Left

    local partnerValue = Instance.new('TextLabel', partnerRow)
    partnerValue.Size = UDim2.new(0.5, -10, 1, 0)
    partnerValue.Position = UDim2.new(0.5, 0, 0, 0)
    partnerValue.BackgroundTransparency = 1
    partnerValue.Text = '0.00'
    partnerValue.Font = Enum.Font.SourceSansSemibold
    partnerValue.TextSize = 13
    partnerValue.TextColor3 = C_ACCENT
    partnerValue.TextXAlignment = Enum.TextXAlignment.Right

    -- Divider
    local vsDivider = Instance.new('Frame', valueSection)
    vsDivider.Size = UDim2.new(1, 0, 0, 1)
    vsDivider.BackgroundColor3 = C_BORDER
    vsDivider.BorderSizePixel = 0
    vsDivider.LayoutOrder = 4

    -- Verdict row
    local verdictRow = Instance.new('Frame', valueSection)
    verdictRow.Size = UDim2.new(1, 0, 0, 36)
    verdictRow.BackgroundColor3 = C_BG
    verdictRow.BackgroundTransparency = 0
    verdictRow.LayoutOrder = 5
    Instance.new('UICorner', verdictRow).CornerRadius = UDim.new(0, 6)
    local vrdStroke = Instance.new('UIStroke', verdictRow)
    vrdStroke.Color = C_BORDER
    vrdStroke.Thickness = 1

    local verdictLabel = Instance.new('TextLabel', verdictRow)
    verdictLabel.Size = UDim2.new(0.45, -8, 1, 0)
    verdictLabel.Position = UDim2.new(0, 10, 0, 0)
    verdictLabel.BackgroundTransparency = 1
    verdictLabel.Text = 'VERDICT'
    verdictLabel.Font = Enum.Font.SourceSansSemibold
    verdictLabel.TextSize = 10
    verdictLabel.TextColor3 = C_LABEL
    verdictLabel.TextXAlignment = Enum.TextXAlignment.Left

    local verdictText = Instance.new('TextLabel', verdictRow)
    verdictText.Size = UDim2.new(0.55, -10, 1, 0)
    verdictText.Position = UDim2.new(0.45, 0, 0, 0)
    verdictText.BackgroundTransparency = 1
    verdictText.Text = 'No active trade'
    verdictText.Font = Enum.Font.SourceSansSemibold
    verdictText.TextSize = 11
    verdictText.TextColor3 = C_LABEL
    verdictText.TextXAlignment = Enum.TextXAlignment.Right

    -- Breakdown label
    local breakdownLabel = Instance.new('TextLabel', valueSection)
    breakdownLabel.Size = UDim2.new(1, 0, 0, 14)
    breakdownLabel.BackgroundTransparency = 1
    breakdownLabel.Text = 'ITEM BREAKDOWN'
    breakdownLabel.Font = Enum.Font.SourceSansSemibold
    breakdownLabel.TextSize = 10
    breakdownLabel.TextColor3 = C_LABEL
    breakdownLabel.TextXAlignment = Enum.TextXAlignment.Left
    breakdownLabel.LayoutOrder = 6

    -- Breakdown scroll frame
    local breakdownFrame = Instance.new('ScrollingFrame', valueSection)
    breakdownFrame.Size = UDim2.new(1, 0, 0, 180)
    breakdownFrame.BackgroundColor3 = C_BG
    breakdownFrame.BackgroundTransparency = 0
    breakdownFrame.BorderSizePixel = 0
    breakdownFrame.ScrollBarThickness = 3
    breakdownFrame.ScrollBarImageColor3 = C_BORDER
    breakdownFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
    breakdownFrame.LayoutOrder = 7
    Instance.new('UICorner', breakdownFrame).CornerRadius = UDim.new(0, 6)
    local bfStroke = Instance.new('UIStroke', breakdownFrame)
    bfStroke.Color = C_BORDER
    bfStroke.Thickness = 1

    local bfLayout = Instance.new('UIListLayout', breakdownFrame)
    bfLayout.SortOrder = Enum.SortOrder.LayoutOrder
    bfLayout.Padding = UDim.new(0, 2)

    local bfPad = Instance.new('UIPadding', breakdownFrame)
    bfPad.PaddingTop    = UDim.new(0, 4)
    bfPad.PaddingBottom = UDim.new(0, 4)
    bfPad.PaddingLeft   = UDim.new(0, 6)
    bfPad.PaddingRight  = UDim.new(0, 6)

    -- Refresh button
    local refreshBtn, _ = setsBtn('↺  Refresh Values',
        Color3.fromRGB(22, 22, 28), C_TEXT, C_BORDER, valueSection, function() end)
    refreshBtn.LayoutOrder = 8

    -- ── Helpers ──────────────────────────────────────────────────────────
    local function getPropsTag(props)
        local t = {}
        if props.mega_neon then table.insert(t, 'MN') end
        if props.neon      then table.insert(t, 'N')  end
        if props.flyable   then table.insert(t, 'F')  end
        if props.rideable  then table.insert(t, 'R')  end
        return #t > 0 and ('[' .. table.concat(t, '') .. ']') or '[Reg]'
    end

    local function addBreakdownRow(text, valueStr, isHeader)
        local row = Instance.new('Frame', breakdownFrame)
        row.Size = UDim2.new(1, 0, 0, isHeader and 20 or 18)
        row.BackgroundTransparency = 1

        local nameL = Instance.new('TextLabel', row)
        nameL.Size = UDim2.new(0.72, 0, 1, 0)
        nameL.BackgroundTransparency = 1
        nameL.Text = text
        nameL.Font = isHeader and Enum.Font.SourceSansSemibold or Enum.Font.SourceSans
        nameL.TextSize = isHeader and 11 or 10
        nameL.TextColor3 = isHeader and C_TEXT or Color3.fromRGB(150, 150, 150)
        nameL.TextXAlignment = Enum.TextXAlignment.Left
        nameL.TextTruncate = Enum.TextTruncate.AtEnd

        local valL = Instance.new('TextLabel', row)
        valL.Size = UDim2.new(0.28, 0, 1, 0)
        valL.Position = UDim2.new(0.72, 0, 0, 0)
        valL.BackgroundTransparency = 1
        valL.Text = valueStr
        valL.Font = isHeader and Enum.Font.SourceSansSemibold or Enum.Font.SourceSans
        valL.TextSize = isHeader and 11 or 10
        valL.TextColor3 = isHeader and C_ACCENT or Color3.fromRGB(120, 120, 120)
        valL.TextXAlignment = Enum.TextXAlignment.Right
    end

    -- ── Core refresh logic ───────────────────────────────────────────────
    local function refreshValues()
    for _, child in ipairs(breakdownFrame:GetChildren()) do
        if child:IsA('Frame') then child:Destroy() end
    end

    -- Get trade state from mock OR real trade
    local tradeState = nil
    local isMyTrade = false

    if mockState.active and mockState.trade then
        tradeState = mockState.trade
        isMyTrade = true
    else
        pcall(function()
            local state = mockState.originalFunctions._get_local_trade_state(TradeApp)
            if state then
                tradeState = state
                isMyTrade = true
            end
        end)
    end

    if not tradeState then
        yourValue.Text    = '0.00'
        partnerValue.Text = '0.00'
        verdictText.Text  = 'No active trade'
        verdictText.TextColor3 = C_LABEL
        vrdStroke.Color = C_BORDER
        yourValue.TextColor3    = C_ACCENT
        partnerValue.TextColor3 = C_ACCENT
        addBreakdownRow('Start a trade to see values.', '', false)
        return
    end

    -- Figure out which offer is mine and which is partner's
    local myOffer, partnerOffer
    if tradeState.sender and tradeState.sender == Players.LocalPlayer then
        myOffer      = tradeState.sender_offer
        partnerOffer = tradeState.recipient_offer
    else
        myOffer      = tradeState.recipient_offer
        partnerOffer = tradeState.sender_offer
    end

    local myItems      = myOffer and myOffer.items or {}
    local partnerItems = partnerOffer and partnerOffer.items or {}

    local function calcOfferValue(items)
        local total = 0
        for _, item in ipairs(items) do
            if item and item.kind and item.category == 'pets' then
                local v = getPetValue(item.kind, item.properties or {})
                total = total + v
            end
        end
        return total
    end

    local myTotal      = calcOfferValue(myItems)
    local partnerTotal = calcOfferValue(partnerItems)

    yourValue.Text    = formatValue(myTotal)
    partnerValue.Text = formatValue(partnerTotal)

    if myTotal > partnerTotal * 1.05 then
        yourValue.TextColor3    = C_GREEN
        partnerValue.TextColor3 = Color3.fromRGB(248, 113, 113)
    elseif partnerTotal > myTotal * 1.05 then
        yourValue.TextColor3    = Color3.fromRGB(248, 113, 113)
        partnerValue.TextColor3 = C_GREEN
    else
        yourValue.TextColor3    = C_ACCENT
        partnerValue.TextColor3 = C_ACCENT
    end

    local diff = partnerTotal - myTotal
    local pct  = myTotal > 0 and math.abs(diff) / myTotal * 100 or 0

    if myTotal == 0 and partnerTotal == 0 then
        verdictText.Text = 'Both empty'
        verdictText.TextColor3 = C_LABEL
        vrdStroke.Color = C_BORDER
    elseif math.abs(diff) < 0.001 then
        verdictText.Text = 'Even trade'
        verdictText.TextColor3 = C_ACCENT
        vrdStroke.Color = C_ACCENT
    elseif diff > 0 then
        verdictText.Text = string.format('You profit %.0f%%', pct)
        verdictText.TextColor3 = C_GREEN
        vrdStroke.Color = C_GREEN
    else
        verdictText.Text = string.format('You lose %.0f%%', pct)
        verdictText.TextColor3 = Color3.fromRGB(248, 113, 113)
        vrdStroke.Color = Color3.fromRGB(248, 113, 113)
    end

    addBreakdownRow('── YOUR OFFER ──', '', true)
    if #myItems == 0 then
        addBreakdownRow('  (empty)', '', false)
    else
        for _, item in ipairs(myItems) do
            if item and item.kind and item.category == 'pets' then
                local props = item.properties or {}
                local dname = petDisplayNames[item.kind] or item.kind
                local v = getPetValue(item.kind, props)
                addBreakdownRow('  ' .. dname .. ' ' .. getPropsTag(props), formatValue(v), false)
            end
        end
    end

    addBreakdownRow('── PARTNER OFFER ──', '', true)
    if #partnerItems == 0 then
        addBreakdownRow('  (empty)', '', false)
    else
        for _, item in ipairs(partnerItems) do
            if item and item.kind and item.category == 'pets' then
                local props = item.properties or {}
                local dname = petDisplayNames[item.kind] or item.kind
                local v = getPetValue(item.kind, props)
                addBreakdownRow('  ' .. dname .. ' ' .. getPropsTag(props), formatValue(v), false)
            end
        end
    end
end

    refreshBtn.MouseButton1Click:Connect(refreshValues)

    -- Auto-refresh every 2s while SETS tab is open
    task.spawn(function()
        while true do
            task.wait(2)
            if UIState.currentTab == 'SETS' then
                pcall(refreshValues)
            end
        end
    end)

    refreshValues()
end)
-- ==================== END SETS TAB ====================

function setActiveTab(tabName)
    for name, pane in pairs(tabPanes) do
        pane.Visible = name == tabName
    end
    UIState.currentTab = tabName
end

-- Helper Functions
local function createFieldLabel(text, parent)
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(1, 0, 0, 16)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.SourceSansSemibold
    label.TextSize = 10
    label.TextColor3 = Color3.fromRGB(68, 68, 68) -- #444
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function createInputBox(placeholder, defaultValue, parent)
    local box = Instance.new('TextBox')
    box.Size = UDim2.new(1, 0, 0, 32)
    box.BackgroundColor3 = Color3.fromRGB(12, 12, 15) -- #0c0c0f
    box.BackgroundTransparency = 0
    box.Text = tostring(defaultValue or '')
    box.PlaceholderText = placeholder or ''
    box.Font = Enum.Font.SourceSans
    box.TextSize = 12
    box.TextColor3 = Color3.fromRGB(204, 204, 204) -- #ccc
    box.PlaceholderColor3 = Color3.fromRGB(51, 51, 51) -- #333
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = parent
    
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = box
    
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(28, 28, 34) -- #1c1c22
    stroke.Thickness = 1
    stroke.Parent = box
    
    box.Focused:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(42, 58, 85)}):Play() -- #2a3a55
    end)
    
    box.FocusLost:Connect(function()
        TweenService:Create(stroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 34)}):Play()
    end)
    
    return box
end

local function createButton(text, bgColor, textColor, borderColor, parent, onClick)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, 0, 0, 36)
    btn.Position = UDim2.new(0, 0, 0, 0)
    btn.BackgroundColor3 = bgColor
    btn.BackgroundTransparency = 0
    btn.Text = text
    btn.Font = Enum.Font.SourceSansSemibold
    btn.TextSize = 11
    btn.TextColor3 = textColor
    btn.AutoButtonColor = false
    btn.Parent = parent
    
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(1, 0) -- 50px radius (pill shape)
    corner.Parent = btn
    
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = borderColor or bgColor:Lerp(Color3.new(1,1,1), 0.3)
    stroke.Thickness = 1
    stroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        btn.BackgroundTransparency = 0.18
    end)
    
    btn.MouseLeave:Connect(function()
       -- Reset if mouse leaves while button is pressed
       btn.Size = UDim2.new(1, 0, 0, 36)
       btn.Position = UDim2.new(0, 0, 0, 0)
    end)
    
    btn.MouseButton1Down:Connect(function()
        btn.Size = UDim2.new(1, 0, 0, 34)
        btn.Position = UDim2.new(0, 0, 0, 1)
    end)
    
    btn.MouseButton1Up:Connect(function()
        btn.Size = UDim2.new(1, 0, 0, 36)
        btn.Position = UDim2.new(0, 0, 0, 0)
    end)
    
    if onClick then
        btn.MouseButton1Click:Connect(onClick)
    end
    
    return btn
end

local function createDivider(parent)
    local div = Instance.new('Frame')
    div.Size = UDim2.new(1, 0, 0, 1)
    div.BackgroundColor3 = Color3.fromRGB(28, 28, 34) -- #1c1c22
    div.BorderSizePixel = 0
    div.Parent = parent
    return div
end

local function createSectionLabel(text, parent)
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(1, 0, 0, 20)
    label.BackgroundTransparency = 1
    label.Text = text
    label.Font = Enum.Font.SourceSansSemibold
    label.TextSize = 9
    label.TextColor3 = Color3.fromRGB(51, 51, 51) -- #333
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Bottom
    label.Parent = parent
    return label
end

local function createGrid2(parent)
    local grid = Instance.new('Frame')
    grid.Size = UDim2.new(1, 0, 0, 0)
    grid.BackgroundTransparency = 1
    grid.AutomaticSize = Enum.AutomaticSize.Y
    grid.Parent = parent
    
    local gridLayout = Instance.new('UIGridLayout')
    gridLayout.FillDirection = Enum.FillDirection.Horizontal
    gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
    gridLayout.CellSize = UDim2.new(0.48, 0, 0, 48) -- Taller to accommodate labels
    gridLayout.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
    gridLayout.Parent = grid
    
    return grid, gridLayout
end

-- ==================== CONTROL TAB ====================
local controlPane = tabPanes['CONTROL']

-- Partner Username
createFieldLabel('PARTNER USERNAME', controlPane)
local partnerBox = createInputBox('username...', CONFIG.PARTNER_NAME, controlPane)
partnerBox.FocusLost:Connect(function() updatePartnerFromUsername(partnerBox.Text) end)

-- Grid for delays - FIXED: Labels are now properly positioned above inputs
local delayGrid, delayLayout = createGrid2(controlPane)

-- Accept Delay
local acceptField = Instance.new('Frame')
acceptField.Size = UDim2.new(0.48, 0, 0, 48)
acceptField.BackgroundTransparency = 1
acceptField.Parent = delayGrid

local acceptLabel = Instance.new('TextLabel')
acceptLabel.Size = UDim2.new(1, 0, 0, 16)
acceptLabel.BackgroundTransparency = 1
acceptLabel.Text = 'ACCEPT DELAY'
acceptLabel.Font = Enum.Font.SourceSansSemibold
acceptLabel.TextSize = 10
acceptLabel.TextColor3 = Color3.fromRGB(68, 68, 68)
acceptLabel.TextXAlignment = Enum.TextXAlignment.Left
acceptLabel.Parent = acceptField

local acceptBox = Instance.new('TextBox')
acceptBox.Size = UDim2.new(1, 0, 0, 30)
acceptBox.Position = UDim2.new(0, 0, 0, 18)
acceptBox.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
acceptBox.BackgroundTransparency = 0
acceptBox.Text = tostring(CONFIG.AUTO_ACCEPT_DELAY)
acceptBox.Font = Enum.Font.SourceSans
acceptBox.TextSize = 12
acceptBox.TextColor3 = Color3.fromRGB(204, 204, 204)
acceptBox.ClearTextOnFocus = false
acceptBox.TextXAlignment = Enum.TextXAlignment.Center
acceptBox.Parent = acceptField

local acceptCorner = Instance.new('UICorner')
acceptCorner.CornerRadius = UDim.new(0, 6)
acceptCorner.Parent = acceptBox

local acceptStroke = Instance.new('UIStroke')
acceptStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
acceptStroke.Color = Color3.fromRGB(28, 28, 34)
acceptStroke.Thickness = 1
acceptStroke.Parent = acceptBox

acceptBox.Focused:Connect(function()
    TweenService:Create(acceptStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(42, 58, 85)}):Play()
end)

acceptBox.FocusLost:Connect(function()
    TweenService:Create(acceptStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 34)}):Play()
    local value = tonumber(acceptBox.Text)
    if value and value >= 0 then CONFIG.AUTO_ACCEPT_DELAY = value else acceptBox.Text = tostring(CONFIG.AUTO_ACCEPT_DELAY) end
end)

-- Confirm Delay
local confirmField = Instance.new('Frame')
confirmField.Size = UDim2.new(0.48, 0, 0, 48)
confirmField.BackgroundTransparency = 1
confirmField.Parent = delayGrid

local confirmLabel = Instance.new('TextLabel')
confirmLabel.Size = UDim2.new(1, 0, 0, 16)
confirmLabel.BackgroundTransparency = 1
confirmLabel.Text = 'CONFIRM DELAY'
confirmLabel.Font = Enum.Font.SourceSansSemibold
confirmLabel.TextSize = 10
confirmLabel.TextColor3 = Color3.fromRGB(68, 68, 68)
confirmLabel.TextXAlignment = Enum.TextXAlignment.Left
confirmLabel.Parent = confirmField

local confirmBox = Instance.new('TextBox')
confirmBox.Size = UDim2.new(1, 0, 0, 30)
confirmBox.Position = UDim2.new(0, 0, 0, 18)
confirmBox.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
confirmBox.BackgroundTransparency = 0
confirmBox.Text = tostring(CONFIG.AUTO_CONFIRM_DELAY)
confirmBox.Font = Enum.Font.SourceSans
confirmBox.TextSize = 12
confirmBox.TextColor3 = Color3.fromRGB(204, 204, 204)
confirmBox.ClearTextOnFocus = false
confirmBox.TextXAlignment = Enum.TextXAlignment.Center
confirmBox.Parent = confirmField

local confirmCorner = Instance.new('UICorner')
confirmCorner.CornerRadius = UDim.new(0, 6)
confirmCorner.Parent = confirmBox

local confirmStroke = Instance.new('UIStroke')
confirmStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
confirmStroke.Color = Color3.fromRGB(28, 28, 34)
confirmStroke.Thickness = 1
confirmStroke.Parent = confirmBox

confirmBox.Focused:Connect(function()
    TweenService:Create(confirmStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(42, 58, 85)}):Play()
end)

confirmBox.FocusLost:Connect(function()
    TweenService:Create(confirmStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 34)}):Play()
    local value = tonumber(confirmBox.Text)
    if value and value >= 0 then CONFIG.AUTO_CONFIRM_DELAY = value else confirmBox.Text = tostring(CONFIG.AUTO_CONFIRM_DELAY) end
end)

-- Request Delay
local requestField = Instance.new('Frame')
requestField.Size = UDim2.new(0.48, 0, 0, 48)
requestField.BackgroundTransparency = 1
requestField.Parent = delayGrid

local requestLabel = Instance.new('TextLabel')
requestLabel.Size = UDim2.new(1, 0, 0, 16)
requestLabel.BackgroundTransparency = 1
requestLabel.Text = 'REQUEST DELAY'
requestLabel.Font = Enum.Font.SourceSansSemibold
requestLabel.TextSize = 10
requestLabel.TextColor3 = Color3.fromRGB(68, 68, 68)
requestLabel.TextXAlignment = Enum.TextXAlignment.Left
requestLabel.Parent = requestField

local requestBox = Instance.new('TextBox')
requestBox.Size = UDim2.new(1, 0, 0, 30)
requestBox.Position = UDim2.new(0, 0, 0, 18)
requestBox.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
requestBox.BackgroundTransparency = 0
requestBox.Text = tostring(CONFIG.TRADE_REQUEST_DELAY)
requestBox.Font = Enum.Font.SourceSans
requestBox.TextSize = 12
requestBox.TextColor3 = Color3.fromRGB(204, 204, 204)
requestBox.ClearTextOnFocus = false
requestBox.TextXAlignment = Enum.TextXAlignment.Center
requestBox.Parent = requestField

local requestCorner = Instance.new('UICorner')
requestCorner.CornerRadius = UDim.new(0, 6)
requestCorner.Parent = requestBox

local requestStroke = Instance.new('UIStroke')
requestStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
requestStroke.Color = Color3.fromRGB(28, 28, 34)
requestStroke.Thickness = 1
requestStroke.Parent = requestBox

requestBox.Focused:Connect(function()
    TweenService:Create(requestStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(42, 58, 85)}):Play()
end)

requestBox.FocusLost:Connect(function()
    TweenService:Create(requestStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 34)}):Play()
    local value = tonumber(requestBox.Text)
    if value and value >= 0 then CONFIG.TRADE_REQUEST_DELAY = value else requestBox.Text = tostring(CONFIG.TRADE_REQUEST_DELAY) end
end)

-- Spectators
local spectatorField = Instance.new('Frame')
spectatorField.Size = UDim2.new(0.48, 0, 0, 48)
spectatorField.BackgroundTransparency = 1
spectatorField.Parent = delayGrid

local spectatorLabel = Instance.new('TextLabel')
spectatorLabel.Size = UDim2.new(1, 0, 0, 16)
spectatorLabel.BackgroundTransparency = 1
spectatorLabel.Text = 'SPECTATORS'
spectatorLabel.Font = Enum.Font.SourceSansSemibold
spectatorLabel.TextSize = 10
spectatorLabel.TextColor3 = Color3.fromRGB(68, 68, 68)
spectatorLabel.TextXAlignment = Enum.TextXAlignment.Left
spectatorLabel.Parent = spectatorField

local spectatorBox = Instance.new('TextBox')
spectatorBox.Size = UDim2.new(1, 0, 0, 30)
spectatorBox.Position = UDim2.new(0, 0, 0, 18)
spectatorBox.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
spectatorBox.BackgroundTransparency = 0
spectatorBox.Text = tostring(CONFIG.SPECTATOR_COUNT)
spectatorBox.Font = Enum.Font.SourceSans
spectatorBox.TextSize = 12
spectatorBox.TextColor3 = Color3.fromRGB(204, 204, 204)
spectatorBox.ClearTextOnFocus = false
spectatorBox.TextXAlignment = Enum.TextXAlignment.Center
spectatorBox.Parent = spectatorField

local spectatorCorner = Instance.new('UICorner')
spectatorCorner.CornerRadius = UDim.new(0, 6)
spectatorCorner.Parent = spectatorBox

local spectatorStroke = Instance.new('UIStroke')
spectatorStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
spectatorStroke.Color = Color3.fromRGB(28, 28, 34)
spectatorStroke.Thickness = 1
spectatorStroke.Parent = spectatorBox

spectatorBox.Focused:Connect(function()
    TweenService:Create(spectatorStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(42, 58, 85)}):Play()
end)

spectatorBox.FocusLost:Connect(function()
    TweenService:Create(spectatorStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 34)}):Play()
    local value = tonumber(spectatorBox.Text)
    if value and value >= 0 then
        CONFIG.SPECTATOR_COUNT = value
        ORIGINAL_SPECTATOR_COUNT = value
        if mockState.trade then
            mockState.trade.subscriber_count = value
            if TradeApp.refresh_all then TradeApp:refresh_all() FriendHighlight(true) end
        end
    else
        spectatorBox.Text = tostring(CONFIG.SPECTATOR_COUNT)
    end
end)

createDivider(controlPane)
createSectionLabel('ACTIONS', controlPane)

-- Action buttons - Matching the HTML colors exactly
createButton('▶ START TRADE', 
    Color3.fromRGB(26, 51, 32), -- #1a3320
    Color3.fromRGB(74, 222, 128), -- #4ade80
    Color3.fromRGB(30, 74, 40), -- #1e4a28
    controlPane, 
    function()
        if mockState.active or mockState.pendingTradeRequest then return end
        if CONFIG.SHOW_TRADE_REQUEST then
            task.spawn(showTradeRequest)
        else
            task.spawn(startMockTradeDirectly)
        end
    end)

createButton('✓ MAKE PARTNER ACCEPT', 
    Color3.fromRGB(19, 29, 48), -- #131d30
    Color3.fromRGB(96, 165, 250), -- #60a5fa
    Color3.fromRGB(26, 42, 68), -- #1a2a44
    controlPane, 
    function()
        if mockState.active and mockState.trade then
            if mockState.trade.current_stage == 'negotiation' then
                if not mockState.trade.recipient_offer.negotiated then
                    mockState.trade.recipient_offer.negotiated = true
                    if mockState.trade.sender_offer.negotiated then
                        mockState.trade.current_stage = 'confirmation'
                        mockState.trade.offer_version = mockState.trade.offer_version + 1
                        TradeApp:_overwrite_local_trade_state(mockState.trade)
                        if TradeApp._evaluate_trade_fairness then TradeApp:_evaluate_trade_fairness() end
                        if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
                    else
                        mockState.trade.offer_version = mockState.trade.offer_version + 1
                        TradeApp:_overwrite_local_trade_state(mockState.trade)
                    end
                end
            elseif mockState.trade.current_stage == 'confirmation' then
                if not mockState.trade.recipient_offer.confirmed then
                    mockState.trade.recipient_offer.confirmed = true
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    TradeApp:_overwrite_local_trade_state(mockState.trade)
                    if mockState.trade.sender_offer.confirmed and not mockState.tradeCompleting then
                        mockState.tradeCompleting = true
                        if TradeApp._set_confirmation_arrow_rotating then TradeApp:_set_confirmation_arrow_rotating(true) end
                        task.wait(3)
                        local historyRecord = createTradeHistoryRecord(mockState.trade)
                        appendToTradeHistory(historyRecord)
                        mockState.active = false
                        mockState.trade = nil
                        mockState.tradeCompleting = false
                        mockState.scamWarningShown = true
                        mockState.canShowTradeRequest = true
                        mockState.tradeRequestBlocked = false
                        UIManager.set_app_visibility('TradeApp', false)
                        task.wait(0.1)
                        showBlockedTradeRequests()
                        if HintApp then HintApp:hint({ text = 'The trade was successful!', length = 5, overridable = true }) end
                        if TradeHistoryApp and UIManager.is_visible('TradeHistoryApp') then TradeHistoryApp:_refresh() end
                    end
                end
            end
        end
    end)

createButton('✗ MAKE PARTNER UNACCEPT', 
    Color3.fromRGB(17, 17, 22), -- #111116
    Color3.fromRGB(85, 85, 85), -- #555
    Color3.fromRGB(28, 28, 34), -- #1c1c22
    controlPane, 
    function()
        if mockState.active and mockState.trade then
            if mockState.trade.current_stage == 'negotiation' then
                if mockState.trade.recipient_offer.negotiated then
                    mockState.trade.recipient_offer.negotiated = false
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    TradeApp:_overwrite_local_trade_state(mockState.trade)
                end
            elseif mockState.trade.current_stage == 'confirmation' then
                if mockState.trade.recipient_offer.confirmed then
                    mockState.trade.recipient_offer.confirmed = false
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    TradeApp:_overwrite_local_trade_state(mockState.trade)
                end
            end
        end
    end)

createButton('+ ADD RANDOM ITEM', 
    Color3.fromRGB(26, 16, 48), -- #1a1030
    Color3.fromRGB(167, 139, 250), -- #a78bfa
    Color3.fromRGB(37, 21, 64), -- #251540
    controlPane, 
    function()
        if mockState.active and mockState.trade then
            addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
        end
    end)

createButton('⊘ CLEAR TRADE', 
    Color3.fromRGB(42, 18, 18), -- #2a1212
    Color3.fromRGB(248, 113, 113), -- #f87171
    Color3.fromRGB(58, 24, 24), -- #3a1818
    controlPane, 
    function()
        if mockState.active and mockState.trade then
            mockState.trade.sender_offer.items = {}
            mockState.trade.recipient_offer.items = {}
            mockState.trade.sender_offer.negotiated = false
            mockState.trade.recipient_offer.negotiated = false
            mockState.trade.current_stage = 'negotiation'
            mockState.trade.offer_version = mockState.trade.offer_version + 1
            TradeApp:_overwrite_local_trade_state(mockState.trade)
        end
    end)

createButton('🚫 BLOCK PLAYER', 
    Color3.fromRGB(42, 18, 18), -- #2a1212
    Color3.fromRGB(248, 113, 113), -- #f87171
    Color3.fromRGB(58, 24, 24), -- #3a1818
    controlPane, 
    function()
        local player = Players:FindFirstChild(partnerBox.Text)
        if player then BlockPlayer(player) end
    end)

createButton('🎰 SPIN THE WHEEL',
    Color3.fromRGB(18, 30, 70),
    Color3.fromRGB(80, 160, 255),
    Color3.fromRGB(30, 60, 140),
    controlPane,
    function()
        if spinnerSystem and spinnerSystem.showWheel then
            spinnerSystem.showWheel()
        end
    end)

-- Spin on Add toggle button
do
    local spinOnAddBtn = Instance.new('TextButton')
    spinOnAddBtn.Size = UDim2.new(1, 0, 0, 32)
    spinOnAddBtn.BackgroundColor3 = Color3.fromRGB(42, 18, 18)
    spinOnAddBtn.BackgroundTransparency = 0.2
    spinOnAddBtn.Text = '🎰 Spin on +: OFF'
    spinOnAddBtn.Font = Enum.Font.SourceSansSemibold
    spinOnAddBtn.TextSize = 12
    spinOnAddBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spinOnAddBtn.Parent = controlPane
    Instance.new('UICorner', spinOnAddBtn).CornerRadius = UDim.new(0, 6)
    local spinOnAddStroke = Instance.new('UIStroke')
    spinOnAddStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    spinOnAddStroke.Color = Color3.fromRGB(248, 113, 113)
    spinOnAddStroke.Thickness = 1.0
    spinOnAddStroke.Transparency = 0.3
    spinOnAddStroke.Parent = spinOnAddBtn
    spinOnAddBtn.MouseButton1Click:Connect(function()
        CONFIG.SPIN_THE_WHEEL_ON_ADD = not CONFIG.SPIN_THE_WHEEL_ON_ADD
        if CONFIG.SPIN_THE_WHEEL_ON_ADD then
            spinOnAddBtn.Text = '🎰 Spin on +: ON'
            spinOnAddBtn.BackgroundColor3 = Color3.fromRGB(18, 50, 18)
            spinOnAddStroke.Color = Color3.fromRGB(100, 255, 100)
        else
            spinOnAddBtn.Text = '🎰 Spin on +: OFF'
            spinOnAddBtn.BackgroundColor3 = Color3.fromRGB(42, 18, 18)
            spinOnAddStroke.Color = Color3.fromRGB(248, 113, 113)
        end
    end)
end

createDivider(controlPane)
createSectionLabel('TOGGLES', controlPane)

-- Toggle Row Helper
local function createToggleRow(labelText, defaultOn, parent, onChange)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundColor3 = Color3.fromRGB(12, 12, 15) -- #0c0c0f
           row.BackgroundTransparency = 0
           row.Active = true
           row.Parent = parent
    
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = row
    
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(28, 28, 34) -- #1c1c22
    stroke.Thickness = 1
    stroke.Parent = row
    
    local labelContainer = Instance.new('Frame')
    labelContainer.Size = UDim2.new(0.7, 0, 1, 0)
    labelContainer.Position = UDim2.new(0, 12, 0, 0)
    labelContainer.BackgroundTransparency = 1
    labelContainer.Parent = row
    
    local mainLabel = Instance.new('TextLabel')
    mainLabel.Size = UDim2.new(1, 0, 0.6, 0)
    mainLabel.Position = UDim2.new(0, 0, 0.1, 0)
    mainLabel.BackgroundTransparency = 1
    mainLabel.Text = labelText
    mainLabel.Font = Enum.Font.SourceSansSemibold
    mainLabel.TextSize = 11
    mainLabel.TextColor3 = Color3.fromRGB(102, 102, 102) -- #666
    mainLabel.TextXAlignment = Enum.TextXAlignment.Left
    mainLabel.TextYAlignment = Enum.TextYAlignment.Bottom
    mainLabel.Parent = labelContainer
    
    local subLabel = Instance.new('TextLabel')
    subLabel.Size = UDim2.new(1, 0, 0.4, 0)
    subLabel.Position = UDim2.new(0, 0, 0.6, 0)
    subLabel.BackgroundTransparency = 1
    subLabel.Text = defaultOn and 'ON' or 'OFF'
    subLabel.Font = Enum.Font.SourceSans
    subLabel.TextSize = 10
    subLabel.TextColor3 = Color3.fromRGB(51, 51, 51) -- #333
    subLabel.TextXAlignment = Enum.TextXAlignment.Left
    subLabel.TextYAlignment = Enum.TextYAlignment.Top
    subLabel.Parent = labelContainer
    
    local switchFrame = Instance.new('Frame')
    switchFrame.Size = UDim2.new(0, 30, 0, 16)
    switchFrame.Position = UDim2.new(1, -42, 0.5, -8)
    switchFrame.BackgroundColor3 = defaultOn and Color3.fromRGB(26, 58, 40) or Color3.fromRGB(26, 26, 32) -- #1a3a28 or #1a1a20
    switchFrame.Parent = row
    
    local switchCorner = Instance.new('UICorner')
    switchCorner.CornerRadius = UDim.new(0, 8)
    switchCorner.Parent = switchFrame
    
    local switchKnob = Instance.new('Frame')
    switchKnob.Size = UDim2.new(0, 12, 0, 12)
    switchKnob.Position = defaultOn and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    switchKnob.BackgroundColor3 = defaultOn and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(51, 51, 51) -- #22c55e or #333
    switchKnob.Parent = switchFrame
    
    local knobCorner = Instance.new('UICorner')
    knobCorner.CornerRadius = UDim.new(0, 6)
    knobCorner.Parent = switchKnob
    
    local isOn = defaultOn

           local clickBtn = Instance.new('TextButton')
           clickBtn.Size = UDim2.new(1, 0, 1, 0)
           clickBtn.BackgroundTransparency = 1
           clickBtn.Text = ''
           clickBtn.ZIndex = 10
           clickBtn.AutoButtonColor = false
           clickBtn.Parent = row

           clickBtn.MouseButton1Click:Connect(function()
           isOn = not isOn
           switchFrame.BackgroundColor3 = isOn and Color3.fromRGB(26, 58, 40) or Color3.fromRGB(26, 26, 32)
           switchKnob.BackgroundColor3 = isOn and Color3.fromRGB(34, 197, 94) or Color3.fromRGB(51, 51, 51)
           TweenService:Create(switchKnob, TweenInfo.new(0.15), {
           Position = isOn and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
           }):Play()
           subLabel.Text = isOn and 'ON' or 'OFF'
           if onChange then onChange(isOn) end
    end)

    return row
end

-- Auto Spectate Toggle
createToggleRow('Auto Spectate', false, controlPane, function(isOn)
    CONFIG.AUTO_SPECTATE_ENABLED = isOn
    if isOn then
        ORIGINAL_SPECTATOR_COUNT = CONFIG.SPECTATOR_COUNT
        startAutoSpectate()
    else
        stopAutoSpectate()
    end
end)

-- Noclip Toggle
createToggleRow('Noclip', true, controlPane, function(isOn)
    UIState.noclipEnabled = isOn
    if isOn then
        enableNoclipForAllFakePlayers()
        enableNoclipForPets()
    end
end)

-- Remove Partner Pets Toggle
createToggleRow('Remove Partner Pets', false, controlPane, function(isOn)
    mockState.removePartnerPetsOnConfirm = isOn
    CONFIG.REMOVE_PARTNER_PETS_ON_CONFIRM = isOn
end)

-- Random Pet Spawn Toggle
createToggleRow('Random Pet Spawn', false, controlPane, function(isOn)
    CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET = isOn
end)

createToggleRow('Auto Partner Emoji', false, controlPane, function(isOn)
    _G.EmojiSystem.running = isOn
    if isOn then
        task.spawn(function()
            while _G.EmojiSystem.running do
                task.wait(math.random(8, 20) / 10)
                if _G.EmojiSystem.running and mockState.active and mockState.trade then
                    _G.EmojiSystem.display(math.random(1, #_G.EmojiSystem.reactions))
                end
            end
        end)
    end
end)

-- Follow Player Toggle
createToggleRow('Follow Player', false, controlPane, function(isOn)
    _G.followEnabled = isOn
    if HintApp then
        HintApp:hint({
            length = 3, overridable = true, yields = false
        })
    end
end)

-- Suggest System Toggle
createToggleRow('Suggest System', true, controlPane, function(isOn)
    mockState.suggestEnabled = isOn
    if not isOn then
        -- Clean up any cached fake inventory so it doesn't leak into real trades
        mockState.mockFakeInventory = nil
        if TradeApp then
            TradeApp.backpack_access = nil
            TradeApp._requesting_backpack_access = false
        end
    end
    if HintApp then
        HintApp:hint({
            text = isOn and 'Suggest system enabled.' or 'Suggest system disabled.',
            length = 3, overridable = true, yields = false
        })
    end
end)

createDivider(controlPane)
createSectionLabel('FAKE PLAYER', controlPane)

-- Pet Type Segmented Control
createFieldLabel('PET TYPE', controlPane)

local segContainer = Instance.new('Frame')
segContainer.Size = UDim2.new(1, 0, 0, 32)
segContainer.BackgroundTransparency = 1
segContainer.Parent = controlPane

local segButtons = {}
local segOptions = {'Reg', 'Neon', 'Mega'}

for i, opt in ipairs(segOptions) do
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1/3, 0, 1, 0)
    btn.Position = UDim2.new((i-1)/3, 0, 0, 0)
    btn.BackgroundColor3 = i == 1 and Color3.fromRGB(19, 29, 48) or Color3.fromRGB(12, 12, 15)
    btn.Text = opt
    btn.Font = Enum.Font.SourceSansSemibold
    btn.TextSize = 10
    btn.TextColor3 = i == 1 and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(51, 51, 51)
    btn.AutoButtonColor = false
    btn.Parent = segContainer
    
    if i == 1 then
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
    elseif i == 3 then
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 6)
        corner.Parent = btn
    else
        local corner = Instance.new('UICorner')
        corner.CornerRadius = UDim.new(0, 0)
        corner.Parent = btn
    end
    
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(28, 28, 34)
    stroke.Thickness = 1
    stroke.Parent = btn
    
    segButtons[opt] = btn
    
    btn.MouseButton1Click:Connect(function()
        for name, b in pairs(segButtons) do
            b.BackgroundColor3 = name == opt and Color3.fromRGB(19, 29, 48) or Color3.fromRGB(12, 12, 15)
            b.TextColor3 = name == opt and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(51, 51, 51)
        end
        if opt == 'Reg' then currentFakePetType = 'regular'
        elseif opt == 'Neon' then currentFakePetType = 'neon'
        elseif opt == 'Mega' then currentFakePetType = 'mega' end
    end)
end

-- Spawn Fake Player button
createButton('👤 SPAWN FAKE PLAYER', 
    Color3.fromRGB(26, 16, 48), -- #1a1030
    Color3.fromRGB(167, 139, 250), -- #a78bfa
    Color3.fromRGB(37, 21, 64), -- #251540
    controlPane, 
    function()
        local petData, petFlags = nil, nil
        if CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET then
            local highValuePet = getRandomHighValuePet()
            petFlags = { M = currentFakePetType == 'mega', N = currentFakePetType == 'neon', F = true, R = true }
            petData = { kind = GetKindPet(highValuePet) }
        end
        CreateFakePlayerCharacterFromPARTNER_NAME(CONFIG.PARTNER_NAME, Players:GetUserIdFromNameAsync(CONFIG.PARTNER_NAME), petData, petFlags)
    end)

-- Delete All Fake Players button
createButton('🗑 DELETE ALL FAKE PLAYERS', 
    Color3.fromRGB(42, 18, 18), -- #2a1212
    Color3.fromRGB(248, 113, 113), -- #f87171
    Color3.fromRGB(58, 24, 24), -- #3a1818
    controlPane, 
    function()
        pcall(function()
            AnimationManager:Stop()
            for _, petData in ipairs(FakePetRegistry) do
                if petData and petData.model then
                    pcall(function()
                        updateData('pet_char_wrappers', function(petWrappers)
                            for i = #petWrappers, 1, -1 do
                                if petWrappers[i].pet_unique == petData.wrapper.pet_unique then table.remove(petWrappers, i) end
                            end
                            return petWrappers
                        end)
                    end)
                    pcall(function()
                        updateData('pet_state_managers', function(petStates)
                            for i = #petStates, 1, -1 do
                                if petStates[i].char == petData.model then table.remove(petStates, i) end
                            end
                            return petStates
                        end)
                    end)
                end
            end
            for _, folder in pairs(FakePlayers) do if folder and folder.Parent then folder:Destroy() end end
            FakePlayers = {}
            FakePetRegistry = {}
            fakePlayerIds = {}
            _G.fakePlayerIds = {}
            print('✅ All fake players and pets deleted successfully')
        end)
    end)


-- ==================== PLAYERS TAB ====================
local playersPane = tabPanes['PLAYERS']

-- Player search box
local playerSearchBox = Instance.new('TextBox')
playerSearchBox.Size = UDim2.new(1, 0, 0, 26)
playerSearchBox.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
playerSearchBox.BackgroundTransparency = 0
playerSearchBox.Text = ''
playerSearchBox.PlaceholderText = 'Search players...'
playerSearchBox.Font = Enum.Font.SourceSans
playerSearchBox.TextSize = 12
playerSearchBox.TextColor3 = Color3.fromRGB(204, 204, 204)
playerSearchBox.PlaceholderColor3 = Color3.fromRGB(51, 51, 51)
playerSearchBox.ClearTextOnFocus = false
playerSearchBox.TextXAlignment = Enum.TextXAlignment.Left
playerSearchBox.Parent = playersPane

local searchCorner = Instance.new('UICorner')
searchCorner.CornerRadius = UDim.new(0, 6)
searchCorner.Parent = playerSearchBox

local searchStroke = Instance.new('UIStroke')
searchStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
searchStroke.Color = Color3.fromRGB(28, 28, 34)
searchStroke.Thickness = 1
searchStroke.Parent = playerSearchBox

-- Selection controls
local selectionControls = Instance.new('Frame')
selectionControls.Size = UDim2.new(1, 0, 0, 26)
selectionControls.Position = UDim2.new(0, 0, 0, 30)
selectionControls.BackgroundTransparency = 1
selectionControls.Parent = playersPane

local selectPlayersButton = Instance.new('TextButton')
selectPlayersButton.Size = UDim2.new(0.48, 0, 1, 0)
selectPlayersButton.BackgroundColor3 = Color3.fromRGB(19, 29, 48)
selectPlayersButton.BackgroundTransparency = 0
selectPlayersButton.Text = 'Select Players'
selectPlayersButton.Font = Enum.Font.SourceSansSemibold
selectPlayersButton.TextSize = 10
selectPlayersButton.TextColor3 = Color3.fromRGB(96, 165, 250)
selectPlayersButton.AutoButtonColor = false
selectPlayersButton.Parent = selectionControls

local selectCorner = Instance.new('UICorner')
selectCorner.CornerRadius = UDim.new(0, 6)
selectCorner.Parent = selectPlayersButton

local selectStroke = Instance.new('UIStroke')
selectStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
selectStroke.Color = Color3.fromRGB(26, 42, 68)
selectStroke.Thickness = 1
selectStroke.Parent = selectPlayersButton

local blockSelectedButton = Instance.new('TextButton')
blockSelectedButton.Size = UDim2.new(0.48, 0, 1, 0)
blockSelectedButton.Position = UDim2.new(0.52, 0, 0, 0)
blockSelectedButton.BackgroundColor3 = Color3.fromRGB(42, 18, 18)
blockSelectedButton.BackgroundTransparency = 0
blockSelectedButton.Text = 'Block Selected'
blockSelectedButton.Font = Enum.Font.SourceSansSemibold
blockSelectedButton.TextSize = 10
blockSelectedButton.TextColor3 = Color3.fromRGB(248, 113, 113)
blockSelectedButton.AutoButtonColor = false
blockSelectedButton.Parent = selectionControls

local blockCorner = Instance.new('UICorner')
blockCorner.CornerRadius = UDim.new(0, 6)
blockCorner.Parent = blockSelectedButton

local blockStroke = Instance.new('UIStroke')
blockStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
blockStroke.Color = Color3.fromRGB(58, 24, 24)
blockStroke.Thickness = 1
blockStroke.Parent = blockSelectedButton

-- Player list scrolling frame
local playerListFrame = Instance.new('ScrollingFrame')
playerListFrame.Size = UDim2.new(1, 0, 0, 500) -- Taller to fill space
playerListFrame.Position = UDim2.new(0, 0, 0, 60)
playerListFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
playerListFrame.BackgroundTransparency = 0
playerListFrame.BorderSizePixel = 0
playerListFrame.ScrollBarThickness = 3
playerListFrame.ScrollBarImageColor3 = Color3.fromRGB(34, 34, 40)
playerListFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
playerListFrame.Parent = playersPane

local playerListCorner = Instance.new('UICorner')
playerListCorner.CornerRadius = UDim.new(0, 6)
playerListCorner.Parent = playerListFrame

local playerListStroke = Instance.new('UIStroke')
playerListStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
playerListStroke.Color = Color3.fromRGB(28, 28, 34)
playerListStroke.Thickness = 1
playerListStroke.Parent = playerListFrame

local playerListLayout = Instance.new('UIListLayout')
playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
playerListLayout.Padding = UDim.new(0, 3)
playerListLayout.Parent = playerListFrame

local playerListPadding = Instance.new('UIPadding')
playerListPadding.PaddingTop = UDim.new(0, 4)
playerListPadding.PaddingBottom = UDim.new(0, 4)
playerListPadding.PaddingLeft = UDim.new(0, 4)
playerListPadding.PaddingRight = UDim.new(0, 4)
playerListPadding.Parent = playerListFrame

-- UI State for players tab
UIState.selectedPlayers = UIState.selectedPlayers or {}
UIState.selectionMode = false
UIState.playerListButtons = {}

-- Function to create player button
local function createPlayerButton(player, index, isSelected)
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, -8, 0, 32)
    button.BackgroundColor3 = isSelected and Color3.fromRGB(19, 29, 48) or Color3.fromRGB(12, 12, 15)
    button.BackgroundTransparency = 0
    button.Text = ''
    button.LayoutOrder = index
    button.AutoButtonColor = false
    button.Parent = playerListFrame
    
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button
    
    local btnStroke = Instance.new('UIStroke')
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Color = isSelected and Color3.fromRGB(26, 42, 68) or Color3.fromRGB(28, 28, 34)
    btnStroke.Thickness = 1
    btnStroke.Parent = button

    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(1, -30, 1, 0)
    nameLabel.Position = UDim2.new(0, 4, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.Font = Enum.Font.SourceSansSemibold
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = isSelected and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(204, 204, 204)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = button

    -- Checkbox for selection mode
    local checkBox = Instance.new('Frame')
    checkBox.Size = UDim2.new(0, 20, 0, 20)
    checkBox.Position = UDim2.new(1, -25, 0.5, -10)
    checkBox.BackgroundColor3 = isSelected and Color3.fromRGB(26, 51, 32) or Color3.fromRGB(12, 12, 15)
    checkBox.BackgroundTransparency = 0
    checkBox.Visible = UIState.selectionMode
    checkBox.Parent = button
    
    local checkCorner = Instance.new('UICorner')
    checkCorner.CornerRadius = UDim.new(0, 4)
    checkCorner.Parent = checkBox
    
    local checkBoxStroke = Instance.new('UIStroke')
    checkBoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    checkBoxStroke.Color = isSelected and Color3.fromRGB(30, 74, 40) or Color3.fromRGB(28, 28, 34)
    checkBoxStroke.Thickness = 1
    checkBoxStroke.Parent = checkBox

    local checkMark = Instance.new('TextLabel')
    checkMark.Size = UDim2.new(1, 0, 1, 0)
    checkMark.BackgroundTransparency = 1
    checkMark.Text = '✓'
    checkMark.Font = Enum.Font.SourceSansSemibold
    checkMark.TextSize = 14
    checkMark.TextColor3 = Color3.fromRGB(74, 222, 128)
    checkMark.Visible = isSelected
    checkMark.Parent = checkBox

    -- Click handler
    button.MouseButton1Click:Connect(function()
        if UIState.selectionMode then
            -- Toggle selection
            local isNowSelected = not UIState.selectedPlayers[player.Name]
            UIState.selectedPlayers[player.Name] = isNowSelected
            
            -- Update visuals
            checkBox.BackgroundColor3 = isNowSelected and Color3.fromRGB(26, 51, 32) or Color3.fromRGB(12, 12, 15)
            checkBoxStroke.Color = isNowSelected and Color3.fromRGB(30, 74, 40) or Color3.fromRGB(28, 28, 34)
            checkMark.Visible = isNowSelected
            button.BackgroundColor3 = isNowSelected and Color3.fromRGB(19, 29, 48) or Color3.fromRGB(12, 12, 15)
            btnStroke.Color = isNowSelected and Color3.fromRGB(26, 42, 68) or Color3.fromRGB(28, 28, 34)
            nameLabel.TextColor3 = isNowSelected and Color3.fromRGB(96, 165, 250) or Color3.fromRGB(204, 204, 204)
        else
            -- Set as partner
            setActiveTab('CONTROL')
            if partnerBox then
                partnerBox.Text = player.Name
                updatePartnerFromUsername(player.Name)
            end
        end
    end)

    return button
end

-- Function to create "Select from trade" button
local function createSelectFromTradeButton()
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, -8, 0, 32)
    button.BackgroundColor3 = Color3.fromRGB(26, 16, 48)
    button.BackgroundTransparency = 0
    button.Text = ''
    button.Name = 'SelectFromTradeButton'
    button.LayoutOrder = -999
    button.AutoButtonColor = false
    button.Parent = playerListFrame
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button
    local btnStroke = Instance.new('UIStroke')
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Color = Color3.fromRGB(37, 21, 64)
    btnStroke.Thickness = 1
    btnStroke.Parent = button
    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(1, -8, 1, 0)
    nameLabel.Position = UDim2.new(0, 4, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = 'Select Partner From Trade'
    nameLabel.Font = Enum.Font.SourceSansSemibold
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = Color3.fromRGB(167, 139, 250)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = button
    button.MouseButton1Click:Connect(function()
        setActiveTab('CONTROL')
        pcall(function()
            local tradePart = Players.LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame.Header.PartnerFrame.NameLabel.Text
            for _, player in ipairs(Players:GetPlayers()) do
                if player.Name:lower() == tradePart:lower() then
                    partnerBox.Text = player.Name
                    updatePartnerFromUsername(player.Name)
                    break
                end
            end
        end)
    end)
    return button
end

-- Refresh player list
local function refreshPlayerList()
    -- Clear existing buttons (except SelectFromTradeButton)
    for _, child in ipairs(playerListFrame:GetChildren()) do
        if child:IsA('TextButton') and child.Name ~= 'SelectFromTradeButton' then
            child:Destroy()
        end
    end
    UIState.playerListButtons = {}

    -- Filter players by search
    local searchText = playerSearchBox.Text:lower()
    local filteredPlayers = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then -- Exclude self
            if searchText == '' or player.Name:lower():find(searchText, 1, true) then
                table.insert(filteredPlayers, player)
            end
        end
    end
    
    -- Sort alphabetically
    table.sort(filteredPlayers, function(a, b) 
        return a.Name:lower() < b.Name:lower() 
    end)

    -- Create buttons
    for i, player in ipairs(filteredPlayers) do
        local isSelected = UIState.selectedPlayers[player.Name] == true
        local button = createPlayerButton(player, i, isSelected)
        table.insert(UIState.playerListButtons, button)
    end
    
    -- Update canvas size
    playerListFrame.CanvasSize = UDim2.new(0, 0, 0, (#filteredPlayers * 36) + 40)
end

-- Connect search
playerSearchBox:GetPropertyChangedSignal("Text"):Connect(refreshPlayerList)

-- Selection mode toggle
selectPlayersButton.MouseButton1Click:Connect(function()
    UIState.selectionMode = not UIState.selectionMode
    
    if UIState.selectionMode then
        selectPlayersButton.Text = 'Cancel Selection'
        selectPlayersButton.BackgroundColor3 = Color3.fromRGB(42, 18, 18)
        selectPlayersButton.TextColor3 = Color3.fromRGB(248, 113, 113)
        selectStroke.Color = Color3.fromRGB(58, 24, 24)
    else
        selectPlayersButton.Text = 'Select Players'
        selectPlayersButton.BackgroundColor3 = Color3.fromRGB(19, 29, 48)
        selectPlayersButton.TextColor3 = Color3.fromRGB(96, 165, 250)
        selectStroke.Color = Color3.fromRGB(26, 42, 68)
        UIState.selectedPlayers = {}
    end
    
    -- Update checkbox visibility
    for _, child in ipairs(playerListFrame:GetChildren()) do
        if child:IsA('TextButton') and child.Name ~= 'SelectFromTradeButton' then
            local checkBox = child:FindFirstChildOfClass('Frame')
            if checkBox then 
                checkBox.Visible = UIState.selectionMode
            end
        end
    end
end)

-- Block selected players
blockSelectedButton.MouseButton1Click:Connect(function()
    if not UIState.selectionMode then return end
    
    local count = 0
    for playerName, isSelected in pairs(UIState.selectedPlayers) do
        if isSelected then
            local player = Players:FindFirstChild(playerName)
            if player then
                pcall(function() 
                    -- Simple block prompt
                    game:GetService('StarterGui'):SetCore('PromptBlockPlayer', player)
                    count = count + 1 
                end)
                task.wait(0.15)
            end
        end
    end
    
    -- Exit selection mode
    UIState.selectionMode = false
    selectPlayersButton.Text = 'Select Players'
    selectPlayersButton.BackgroundColor3 = Color3.fromRGB(19, 29, 48)
    selectPlayersButton.TextColor3 = Color3.fromRGB(96, 165, 250)
    selectStroke.Color = Color3.fromRGB(26, 42, 68)
    UIState.selectedPlayers = {}
    
    refreshPlayerList()
    
    if HintApp then 
        HintApp:hint({ text = 'Blocked ' .. count .. ' player(s)', length = 3, overridable = true }) 
    end
end)

-- Initial population
refreshPlayerList()
createSelectFromTradeButton()

refreshPlayerList()
createSelectFromTradeButton()

-- Auto-refresh when players join/leave
Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(refreshPlayerList)

-- ==================== TOP RICHEST PLAYERS ====================
do
    local richestHeading = Instance.new('TextLabel')
    richestHeading.Size = UDim2.new(1, 0, 0, 18)
    richestHeading.BackgroundTransparency = 1
    richestHeading.Text = '💰 Top 35 Richest Players (Auto-Refresh)'
    richestHeading.Font = Enum.Font.GothamBold
    richestHeading.TextSize = 9
    richestHeading.TextColor3 = Color3.fromRGB(255, 215, 0)
    richestHeading.TextXAlignment = Enum.TextXAlignment.Left
    richestHeading.Parent = playersPane

    local autoRefreshButton = Instance.new('TextButton')
    autoRefreshButton.Size = UDim2.new(0.3, 0, 0, 18)
    autoRefreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    autoRefreshButton.BackgroundTransparency = 0.2
    autoRefreshButton.Text = 'Auto: ON'
    autoRefreshButton.Font = Enum.Font.GothamBold
    autoRefreshButton.TextSize = 8
    autoRefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    autoRefreshButton.Parent = playersPane
    Instance.new('UICorner', autoRefreshButton).CornerRadius = UDim.new(0, 4)

    local refreshRichestButton = Instance.new('TextButton')
    refreshRichestButton.Size = UDim2.new(0.3, 0, 0, 18)
    refreshRichestButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
    refreshRichestButton.BackgroundTransparency = 0.2
    refreshRichestButton.Text = '🔄 Manual'
    refreshRichestButton.Font = Enum.Font.GothamBold
    refreshRichestButton.TextSize = 8
    refreshRichestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    refreshRichestButton.Parent = playersPane
    Instance.new('UICorner', refreshRichestButton).CornerRadius = UDim.new(0, 4)

    local richestListFrame = Instance.new('ScrollingFrame')
    richestListFrame.Size = UDim2.new(1, 0, 0, 320)
    richestListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    richestListFrame.BackgroundTransparency = 0.5
    richestListFrame.BorderSizePixel = 0
    richestListFrame.ScrollBarThickness = 4
    richestListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    richestListFrame.ScrollBarImageTransparency = 0.5
    richestListFrame.Parent = playersPane
    Instance.new('UICorner', richestListFrame).CornerRadius = UDim.new(0, 4)
    local richestListLayout = Instance.new('UIListLayout')
    richestListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    richestListLayout.Padding = UDim.new(0, 3)
    richestListLayout.Parent = richestListFrame
    local richestListPadding = Instance.new('UIPadding')
    richestListPadding.PaddingTop = UDim.new(0, 4)
    richestListPadding.PaddingBottom = UDim.new(0, 4)
    richestListPadding.PaddingLeft = UDim.new(0, 4)
    richestListPadding.PaddingRight = UDim.new(0, 4)
    richestListPadding.Parent = richestListFrame

    local RefreshState = {
        autoRefreshEnabled = true,
        playerCache = {},
        isRefreshing = false,
        lastRefreshTime = 0,
        lastFullRefreshTime = 0,
        REFRESH_COOLDOWN = 2,
        FULL_REFRESH_INTERVAL = 30,
        playerContainers = {}
    }

    local function getExistingPlayerNames()
        local names = {}
        for _, child in ipairs(richestListFrame:GetChildren()) do
            if child:IsA('Frame') and child.Name:sub(1, 14) == 'RichestPlayer_' then
                names[child.Name:sub(15)] = true
            end
        end
        return names
    end

    local function removeRichestPlayer(playerName)
        for _, child in ipairs(richestListFrame:GetChildren()) do
            if child:IsA('Frame') and child.Name == 'RichestPlayer_' .. playerName then
                child:Destroy()
            end
        end
        RefreshState.playerContainers[playerName] = nil
        RefreshState.playerCache[playerName] = nil
        UIState.expandedPlayers[playerName] = nil
    end

    local function updateRichestCanvasSize()
        task.wait(0.05)
        local totalHeight = 8
        for _, child in ipairs(richestListFrame:GetChildren()) do
            if child:IsA('Frame') then
                totalHeight = totalHeight + child.AbsoluteSize.Y + 3
            end
        end
        richestListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end

    local rankColors = {
        [1] = Color3.fromRGB(255, 215, 0),
        [2] = Color3.fromRGB(200, 200, 210),
        [3] = Color3.fromRGB(205, 140, 80),
    }

    local function createRichestPlayerButton(playerData, index)
        local container = Instance.new('Frame')
        container.Size = UDim2.new(1, -8, 0, 32)
        container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
        container.BackgroundTransparency = 0.1
        container.LayoutOrder = index
        container.Name = 'RichestPlayer_' .. playerData.playerName
        container.ClipsDescendants = true
        container.Parent = richestListFrame
        Instance.new('UICorner', container).CornerRadius = UDim.new(0, 8)
        local containerGradient = Instance.new('UIGradient')
        containerGradient.Color = ColorSequence.new({
            ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 45, 65)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 32, 48))
        })
        containerGradient.Rotation = 90
        containerGradient.Parent = container
        local containerStroke = Instance.new('UIStroke')
        containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        containerStroke.Color = Color3.fromRGB(255, 200, 50)
        containerStroke.Thickness = 1.5
        containerStroke.Transparency = 0.2
        containerStroke.Parent = container
        local rankBadge = Instance.new('TextLabel')
        rankBadge.Size = UDim2.new(0, 22, 0, 22)
        rankBadge.Position = UDim2.new(0, 5, 0, 5)
        rankBadge.BackgroundColor3 = rankColors[index] or Color3.fromRGB(70, 70, 90)
        rankBadge.BackgroundTransparency = 0.2
        rankBadge.Text = tostring(index)
        rankBadge.Font = Enum.Font.GothamBlack
        rankBadge.TextSize = 11
        rankBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
        rankBadge.Parent = container
        Instance.new('UICorner', rankBadge).CornerRadius = UDim.new(0, 11)
        local tradeButton = Instance.new('TextButton')
        tradeButton.Size = UDim2.new(0, 32, 0, 22)
        tradeButton.Position = UDim2.new(1, -74, 0, 5)
        tradeButton.BackgroundColor3 = Color3.fromRGB(50, 130, 100)
        tradeButton.BackgroundTransparency = 0.1
        tradeButton.Text = '🤝'
        tradeButton.Font = Enum.Font.GothamBold
        tradeButton.TextSize = 12
        tradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        tradeButton.Parent = container
        Instance.new('UICorner', tradeButton).CornerRadius = UDim.new(0, 6)
        tradeButton.MouseEnter:Connect(function()
            TweenService:Create(tradeButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 160, 120) }):Play()
        end)
        tradeButton.MouseLeave:Connect(function()
            TweenService:Create(tradeButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 130, 100) }):Play()
        end)
        tradeButton.MouseButton1Click:Connect(function()
            local targetPlayer = Players:FindFirstChild(playerData.playerName)
            if targetPlayer then
                sendTradeToPlayer(targetPlayer)
            else
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Name == playerData.playerName then
                        sendTradeToPlayer(player)
                        return
                    end
                end
                if HintApp then HintApp:hint({ text = playerData.playerName .. ' is not in this server', length = 3, overridable = true }) end
            end
        end)
        local profileButton = Instance.new('TextButton')
        profileButton.Size = UDim2.new(0, 32, 0, 22)
        profileButton.Position = UDim2.new(1, -38, 0, 5)
        profileButton.BackgroundColor3 = Color3.fromRGB(100, 70, 150)
        profileButton.BackgroundTransparency = 0.1
        profileButton.Text = '👤'
        profileButton.Font = Enum.Font.GothamBold
        profileButton.TextSize = 12
        profileButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        profileButton.Parent = container
        Instance.new('UICorner', profileButton).CornerRadius = UDim.new(0, 6)
        profileButton.MouseEnter:Connect(function()
            TweenService:Create(profileButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(130, 90, 180) }):Play()
        end)
        profileButton.MouseLeave:Connect(function()
            TweenService:Create(profileButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(100, 70, 150) }):Play()
        end)
        profileButton.MouseButton1Click:Connect(function()
            local targetPlayer = Players:FindFirstChild(playerData.playerName)
            if targetPlayer then
                pcall(function() OpenProfile(targetPlayer.UserId) end)
            else
                for _, player in ipairs(Players:GetPlayers()) do
                    if player.Name == playerData.playerName then
                        pcall(function() OpenProfile(player.UserId) end)
                        return
                    end
                end
                if HintApp then HintApp:hint({ text = playerData.playerName .. ' is not in this server', length = 3, overridable = true }) end
            end
        end)
        local mainButton = Instance.new('TextButton')
        mainButton.Size = UDim2.new(1, -110, 0, 32)
        mainButton.Position = UDim2.new(0, 30, 0, 0)
        mainButton.BackgroundTransparency = 1
        mainButton.Text = ''
        mainButton.Parent = container
        local nameLabel = Instance.new('TextLabel')
        nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
        nameLabel.Position = UDim2.new(0, 0, 0, 0)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = playerData.playerName
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextSize = 10
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
        nameLabel.Parent = mainButton
        local valueLabel = Instance.new('TextLabel')
        valueLabel.Size = UDim2.new(0.45, 0, 1, 0)
        valueLabel.Position = UDim2.new(0.55, 0, 0, 0)
        valueLabel.BackgroundTransparency = 1
        valueLabel.Text = formatValue(playerData.totalValue)
        valueLabel.Font = Enum.Font.GothamBold
        valueLabel.TextSize = 10
        valueLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
        valueLabel.TextXAlignment = Enum.TextXAlignment.Right
        valueLabel.Parent = mainButton
        local petsSection = Instance.new('Frame')
        petsSection.Size = UDim2.new(1, -8, 0, 0)
        petsSection.Position = UDim2.new(0, 4, 0, 34)
        petsSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
        petsSection.BackgroundTransparency = 0.3
        petsSection.Visible = false
        petsSection.Name = 'PetsSection'
        petsSection.Parent = container
        Instance.new('UICorner', petsSection).CornerRadius = UDim.new(0, 6)
        local petsLayout = Instance.new('UIListLayout')
        petsLayout.SortOrder = Enum.SortOrder.LayoutOrder
        petsLayout.Padding = UDim.new(0, 2)
        petsLayout.Parent = petsSection
        local petsPadding = Instance.new('UIPadding')
        petsPadding.PaddingTop = UDim.new(0, 4)
        petsPadding.PaddingBottom = UDim.new(0, 4)
        petsPadding.PaddingLeft = UDim.new(0, 6)
        petsPadding.PaddingRight = UDim.new(0, 6)
        petsPadding.Parent = petsSection
        local isExpanded = false
        local expandId = 0
        mainButton.MouseButton1Click:Connect(function()
            if isExpanded then
                isExpanded = false
                expandId = expandId + 1
                petsSection.Visible = false
                petsSection.Size = UDim2.new(1, -8, 0, 0)
                container.Size = UDim2.new(1, -8, 0, 32)
            else
                isExpanded = true
                expandId = expandId + 1
                local currentExpandId = expandId
                for _, child in ipairs(petsSection:GetChildren()) do
                    if child:IsA('TextLabel') then child:Destroy() end
                end
                local petsHeight = 0
                if playerData.pets and #playerData.pets > 0 then
                    local sortedPets = {}
                    for _, pet in ipairs(playerData.pets) do table.insert(sortedPets, pet) end
                    table.sort(sortedPets, function(a, b) return a.value > b.value end)
                    local displayCount = math.min(#sortedPets, 8)
                    for i = 1, displayCount do
                        local pet = sortedPets[i]
                        local prefix = ""
                        if pet.isMega then prefix = "M "
                        elseif pet.isNeon then prefix = "N " end
                        if pet.isFly then prefix = prefix .. "F" end
                        if pet.isRide then prefix = prefix .. "R" end
                        if prefix ~= "" then prefix = "[" .. prefix:gsub("%s+$", "") .. "] " end
                        local petLabel = Instance.new('TextLabel')
                        petLabel.Size = UDim2.new(1, 0, 0, 14)
                        petLabel.BackgroundTransparency = 1
                        petLabel.Text = prefix .. pet.displayName .. ' - ' .. formatValue(pet.value)
                        petLabel.Font = Enum.Font.SourceSans
                        petLabel.TextSize = 9
                        petLabel.TextColor3 = pet.isMega and Color3.fromRGB(170, 100, 255) or (pet.isNeon and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(200, 200, 200))
                        petLabel.TextXAlignment = Enum.TextXAlignment.Left
                        petLabel.LayoutOrder = i
                        petLabel.Parent = petsSection
                    end
                    if #sortedPets > 8 then
                        local moreLabel = Instance.new('TextLabel')
                        moreLabel.Size = UDim2.new(1, 0, 0, 12)
                        moreLabel.BackgroundTransparency = 1
                        moreLabel.Text = '... and ' .. (#sortedPets - 8) .. ' more pets'
                        moreLabel.Font = Enum.Font.SourceSansItalic
                        moreLabel.TextSize = 8
                        moreLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                        moreLabel.TextXAlignment = Enum.TextXAlignment.Left
                        moreLabel.LayoutOrder = 999
                        moreLabel.Parent = petsSection
                    end
                    petsHeight = (displayCount * 16) + 10
                    if #sortedPets > 8 then petsHeight = petsHeight + 14 end
                else
                    local noPetsLabel = Instance.new('TextLabel')
                    noPetsLabel.Size = UDim2.new(1, 0, 0, 14)
                    noPetsLabel.BackgroundTransparency = 1
                    noPetsLabel.Text = 'No pets listed in profile'
                    noPetsLabel.Font = Enum.Font.SourceSansItalic
                    noPetsLabel.TextSize = 9
                    noPetsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                    noPetsLabel.TextXAlignment = Enum.TextXAlignment.Left
                    noPetsLabel.Parent = petsSection
                    petsHeight = 22
                end
                petsSection.Size = UDim2.new(1, -8, 0, petsHeight)
                petsSection.Visible = true
                container.Size = UDim2.new(1, -8, 0, 36 + petsHeight)
                task.spawn(function()
                    task.wait(10)
                    if isExpanded and expandId == currentExpandId then
                        isExpanded = false
                        petsSection.Visible = false
                        petsSection.Size = UDim2.new(1, -8, 0, 0)
                        container.Size = UDim2.new(1, -8, 0, 32)
                        updateRichestCanvasSize()
                    end
                end)
            end
            updateRichestCanvasSize()
        end)
        return container
    end

    local function refreshRichestPlayers(forceRefresh)
        if RefreshState.isRefreshing then return end
        local currentTime = tick()
        if not forceRefresh and (currentTime - RefreshState.lastRefreshTime) < RefreshState.REFRESH_COOLDOWN then return end
        local isFullRefresh = forceRefresh or (currentTime - RefreshState.lastFullRefreshTime) >= RefreshState.FULL_REFRESH_INTERVAL
        RefreshState.isRefreshing = true
        RefreshState.lastRefreshTime = currentTime
        if isFullRefresh then RefreshState.lastFullRefreshTime = currentTime end
        local localPlayer = Players.LocalPlayer
        local currentPlayers = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then currentPlayers[player.Name] = player end
        end
        local existingNames = getExistingPlayerNames()
        for playerName in pairs(existingNames) do
            if not currentPlayers[playerName] then
                removeRichestPlayer(playerName)
                for i, data in ipairs(UIState.richestData) do
                    if data.playerName == playerName then table.remove(UIState.richestData, i) break end
                end
            end
        end
        if forceRefresh then
            for _, child in ipairs(richestListFrame:GetChildren()) do
                if child:IsA('Frame') then child:Destroy() end
            end
            UIState.expandedPlayers = {}
            UIState.richestData = {}
            RefreshState.playerContainers = {}
            existingNames = {}
            local loadingLabel = Instance.new('TextLabel')
            loadingLabel.Size = UDim2.new(1, -8, 0, 30)
            loadingLabel.BackgroundTransparency = 1
            loadingLabel.Text = '⏳ Scanning players...'
            loadingLabel.Font = Enum.Font.GothamBold
            loadingLabel.TextSize = 11
            loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
            loadingLabel.LayoutOrder = 0
            loadingLabel.Name = 'LoadingLabel'
            loadingLabel.Parent = richestListFrame
        end
        task.spawn(function()
            local playersToFetch = {}
            if isFullRefresh then
                for _, player in pairs(currentPlayers) do table.insert(playersToFetch, player) end
                if not forceRefresh then UIState.richestData = {} end
            else
                for playerName, player in pairs(currentPlayers) do
                    if not existingNames[playerName] then table.insert(playersToFetch, player) end
                end
            end
            for _, player in ipairs(playersToFetch) do
                local success, profileData = pcall(function() return fetchProfile:InvokeServer(player.UserId) end)
                local totalValue = 0
                local allPets = {}
                if success and profileData then
                    local processedData = processRawProfileData(profileData)
                    allPets = extractAllPets(processedData)
                    for _, pet in ipairs(allPets) do totalValue = totalValue + pet.value end
                end
                local playerData = { playerName = player.Name, totalValue = totalValue, pets = allPets, player = player }
                RefreshState.playerCache[player.Name] = { totalValue = totalValue, pets = allPets, player = player, lastUpdated = tick() }
                if isFullRefresh and not forceRefresh then
                    table.insert(UIState.richestData, playerData)
                else
                    local found = false
                    for i, data in ipairs(UIState.richestData) do
                        if data.playerName == player.Name then UIState.richestData[i] = playerData found = true break end
                    end
                    if not found then table.insert(UIState.richestData, playerData) end
                end
            end
            local loadingLabel = richestListFrame:FindFirstChild('LoadingLabel')
            if loadingLabel then loadingLabel:Destroy() end
            table.sort(UIState.richestData, function(a, b) return a.totalValue > b.totalValue end)
            local displayCount = math.min(#UIState.richestData, 35)
            for i = 1, displayCount do
                local data = UIState.richestData[i]
                local existingContainer = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
                if not existingContainer then
                    createRichestPlayerButton(data, i)
                    RefreshState.playerContainers[data.playerName] = true
                else
                    existingContainer.LayoutOrder = i
                    local rankBadge = existingContainer:FindFirstChildOfClass('TextLabel')
                    if rankBadge and rankBadge.Size == UDim2.new(0, 22, 0, 22) then
                        rankBadge.Text = tostring(i)
                        rankBadge.BackgroundColor3 = rankColors[i] or Color3.fromRGB(80, 80, 100)
                    end
                end
            end
            for i = displayCount + 1, #UIState.richestData do
                local data = UIState.richestData[i]
                local container = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
                if container then container:Destroy() end
            end
            updateRichestCanvasSize()
            if forceRefresh and HintApp then
                HintApp:hint({ text = 'Updated ' .. #UIState.richestData .. ' players!', length = 2, overridable = true })
            end
            RefreshState.isRefreshing = false
        end)
    end

    refreshRichestButton.MouseButton1Click:Connect(function() refreshRichestPlayers(true) end)
    autoRefreshButton.MouseButton1Click:Connect(function()
        RefreshState.autoRefreshEnabled = not RefreshState.autoRefreshEnabled
        if RefreshState.autoRefreshEnabled then
            autoRefreshButton.Text = 'Auto: ON'
            autoRefreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
            refreshRichestPlayers(true)
        else
            autoRefreshButton.Text = 'Auto: OFF'
            autoRefreshButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        end
    end)

    task.spawn(function()
        while true do
            task.wait(10)
            if RefreshState.autoRefreshEnabled then refreshRichestPlayers(false) end
        end
    end)

    Players.PlayerAdded:Connect(function(player)
        if not RefreshState.autoRefreshEnabled then return end
        task.wait(1)
        if player == Players.LocalPlayer then return end
        task.spawn(function()
            local success, profileData = pcall(function() return fetchProfile:InvokeServer(player.UserId) end)
            local totalValue = 0
            local allPets = {}
            if success and profileData then
                local processedData = processRawProfileData(profileData)
                allPets = extractAllPets(processedData)
                for _, pet in ipairs(allPets) do totalValue = totalValue + pet.value end
            end
            local playerData = { playerName = player.Name, totalValue = totalValue, pets = allPets, player = player }
            RefreshState.playerCache[player.Name] = { totalValue = totalValue, pets = allPets, player = player, lastUpdated = tick() }
            table.insert(UIState.richestData, playerData)
            table.sort(UIState.richestData, function(a, b) return a.totalValue > b.totalValue end)
            local newIndex = 1
            for i, data in ipairs(UIState.richestData) do
                if data.playerName == player.Name then newIndex = i break end
            end
            if newIndex <= 35 then
                createRichestPlayerButton(playerData, newIndex)
                RefreshState.playerContainers[player.Name] = true
                for i, data in ipairs(UIState.richestData) do
                    if i <= 35 then
                        local container = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
                        if container then
                            container.LayoutOrder = i
                            local rankBadge = container:FindFirstChildOfClass('TextLabel')
                            if rankBadge and rankBadge.Size == UDim2.new(0, 22, 0, 22) then
                                rankBadge.Text = tostring(i)
                                rankBadge.BackgroundColor3 = rankColors[i] or Color3.fromRGB(80, 80, 100)
                            end
                        end
                    end
                end
                updateRichestCanvasSize()
            end
        end)
    end)

    Players.PlayerRemoving:Connect(function(player)
        if not RefreshState.autoRefreshEnabled then return end
        removeRichestPlayer(player.Name)
        for i, data in ipairs(UIState.richestData) do
            if data.playerName == player.Name then table.remove(UIState.richestData, i) break end
        end
        for i, data in ipairs(UIState.richestData) do
            if i <= 35 then
                local container = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
                if container then
                    container.LayoutOrder = i
                    local rankBadge = container:FindFirstChildOfClass('TextLabel')
                    if rankBadge and rankBadge.Size == UDim2.new(0, 22, 0, 22) then
                        rankBadge.Text = tostring(i)
                        rankBadge.BackgroundColor3 = rankColors[i] or Color3.fromRGB(80, 80, 100)
                    end
                end
            end
        end
        updateRichestCanvasSize()
    end)

    refreshRichestPlayers(true)
end
-- ==================== END TOP RICHEST PLAYERS ====================

-- ==================== PETS TAB ====================
local petsPane = tabPanes['PETS']

createFieldLabel('PET NAME TO ADD', petsPane)
local petNameBox = createInputBox('Enter pet name...', '', petsPane)

-- Pet Type toggles (M, N, F, R)
createFieldLabel('PET TYPE', petsPane)

local petTypeContainer = Instance.new('Frame')
petTypeContainer.Size = UDim2.new(1, 0, 0, 32)
petTypeContainer.BackgroundTransparency = 1
petTypeContainer.Parent = petsPane

local petTypeButtons = {}
local petTypeLabels = {'M', 'N', 'F', 'R'}
local petTypeColors = {
    M = Color3.fromRGB(170, 0, 255),
    N = Color3.fromRGB(0, 255, 100),
    F = Color3.fromRGB(0, 200, 255),
    R = Color3.fromRGB(255, 50, 150),
}

for i, label in ipairs(petTypeLabels) do
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0.23, 0, 1, 0)
    btn.Position = UDim2.new((i-1) * 0.25 + 0.01, 0, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    btn.Text = label
    btn.Font = Enum.Font.SourceSansSemibold
    btn.TextSize = 13
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.AutoButtonColor = false
    btn.Parent = petTypeContainer
    
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = btn
    
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = petTypeColors[label]
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = btn
    
    petTypeButtons[label] = {button = btn, stroke = stroke}
    
    btn.MouseButton1Click:Connect(function()
        if label == 'M' and petSpawnState.activeFlags['N'] then return end
        if label == 'N' and petSpawnState.activeFlags['M'] then return end
        
        petSpawnState.activeFlags[label] = not petSpawnState.activeFlags[label]
        
        if petSpawnState.activeFlags[label] then
            btn.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            TweenService:Create(stroke, TweenInfo.new(0.3), {Color = Color3.fromRGB(0, 255, 0), Thickness = 1.2, Transparency = 0.2}):Play()
        else
            btn.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
            TweenService:Create(stroke, TweenInfo.new(0.3), {Color = petTypeColors[label], Thickness = 1, Transparency = 0.5}):Play()
        end
    end)
end

createFieldLabel('ADD PET DELAY (S)', petsPane)
local addPetDelayBox = createInputBox('', CONFIG.ADD_PET_REQUEST_DELAY, petsPane)
addPetDelayBox.FocusLost:Connect(function()
    local value = tonumber(addPetDelayBox.Text)
    if value and value >= 0 then CONFIG.ADD_PET_REQUEST_DELAY = value else addPetDelayBox.Text = tostring(CONFIG.ADD_PET_REQUEST_DELAY) end
end)

createButton('ADD PET TO TRADE', 
    Color3.fromRGB(19, 29, 48), -- #131d30
    Color3.fromRGB(96, 165, 250), -- #60a5fa
    Color3.fromRGB(26, 42, 68), -- #1a2a44
    petsPane, 
    function()
        local petName = petNameBox.Text
        if petName and petName ~= '' then addPetToPartnerOffer(petName, petSpawnState.activeFlags) end
    end)

createButton('REMOVE LATEST PET', 
    Color3.fromRGB(42, 18, 18), -- #2a1212
    Color3.fromRGB(248, 113, 113), -- #f87171
    Color3.fromRGB(58, 24, 24), -- #3a1818
    petsPane, 
    removeLatestPetFromPartnerOffer)

createButton('ADD RANDOM HIGH-VALUE PET', 
    Color3.fromRGB(26, 16, 48), -- #1a1030
    Color3.fromRGB(167, 139, 250), -- #a78bfa
    Color3.fromRGB(37, 21, 64), -- #251540
    petsPane, 
    function()
        addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
    end)

createSectionLabel('HIGH-VALUE PETS (BALLOON UNICORN+)', petsPane)

-- High-value pet list
local petList = Instance.new('ScrollingFrame')
petList.Size = UDim2.new(1, 0, 0, 240)
petList.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
petList.BorderSizePixel = 0
petList.ScrollBarThickness = 3
petList.ScrollBarImageColor3 = Color3.fromRGB(34, 34, 40)
petList.AutomaticCanvasSize = Enum.AutomaticSize.Y
petList.Parent = petsPane

local petListCorner = Instance.new('UICorner')
petListCorner.CornerRadius = UDim.new(0, 6)
petListCorner.Parent = petList

local petListStroke = Instance.new('UIStroke')
petListStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
petListStroke.Color = Color3.fromRGB(28, 28, 34)
petListStroke.Thickness = 1
petListStroke.Parent = petList

local petListLayout = Instance.new('UIListLayout')
petListLayout.SortOrder = Enum.SortOrder.LayoutOrder
petListLayout.Padding = UDim.new(0, 3)
petListLayout.Parent = petList

local petListPadding = Instance.new('UIPadding')
petListPadding.PaddingTop = UDim.new(0, 4)
petListPadding.PaddingBottom = UDim.new(0, 4)
petListPadding.PaddingLeft = UDim.new(0, 4)
petListPadding.PaddingRight = UDim.new(0, 4)
petListPadding.Parent = petList

-- Add pet buttons
for _, petName in ipairs(completePetList) do
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, -8, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(15, 15, 19)
    btn.BackgroundTransparency = 0
    btn.Text = petName
    btn.Font = Enum.Font.SourceSansSemibold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(170, 170, 170)
    btn.AutoButtonColor = false
    btn.Parent = petList
    
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(0, 7)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new('UIStroke')
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Color = Color3.fromRGB(42, 34, 24)
    btnStroke.Thickness = 1
    btnStroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(24, 20, 16)}):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(58, 48, 32)}):Play()
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundColor3 = Color3.fromRGB(15, 15, 19)}):Play()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(42, 34, 24)}):Play()
    end)
    
    btn.MouseButton1Click:Connect(function()
        petNameBox.Text = petName
    end)
end

-- ==================== USERS TAB ====================
local usersPane = tabPanes['USERS']

createFieldLabel('SEARCH USERS', usersPane)
local userSearchBox = createInputBox('Search users...', '', usersPane)

-- User list
local userList = Instance.new('ScrollingFrame')
userList.Size = UDim2.new(1, 0, 0, 150)
userList.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
userList.BorderSizePixel = 0
userList.ScrollBarThickness = 3
userList.ScrollBarImageColor3 = Color3.fromRGB(34, 34, 40)
userList.AutomaticCanvasSize = Enum.AutomaticSize.Y
userList.Parent = usersPane

local userListCorner = Instance.new('UICorner')
userListCorner.CornerRadius = UDim.new(0, 6)
userListCorner.Parent = userList

local userListStroke = Instance.new('UIStroke')
userListStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
userListStroke.Color = Color3.fromRGB(28, 28, 34)
userListStroke.Thickness = 1
userListStroke.Parent = userList

local userListLayout = Instance.new('UIListLayout')
userListLayout.SortOrder = Enum.SortOrder.LayoutOrder
userListLayout.Padding = UDim.new(0, 3)
userListLayout.Parent = userList

local userListPadding = Instance.new('UIPadding')
userListPadding.PaddingTop = UDim.new(0, 4)
userListPadding.PaddingBottom = UDim.new(0, 4)
userListPadding.PaddingLeft = UDim.new(0, 4)
userListPadding.PaddingRight = UDim.new(0, 4)
userListPadding.Parent = userList

-- Function to create user item
local function createUserItem(username)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, -8, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    btn.BackgroundTransparency = 0
    btn.Text = '  ' .. username
    btn.Font = Enum.Font.SourceSansSemibold
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(204, 204, 204)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = userList
    
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new('UIStroke')
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Color = Color3.fromRGB(28, 28, 34)
    btnStroke.Thickness = 1
    btnStroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(200, 168, 75)}):Play()
        btn.TextColor3 = Color3.fromRGB(232, 200, 106)
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 34)}):Play()
        btn.TextColor3 = Color3.fromRGB(204, 204, 204)
    end)
    
    btn.MouseButton1Click:Connect(function()
        setActiveTab('CONTROL')
        partnerBox.Text = username
        updatePartnerFromUsername(username)
    end)
    
    return btn
end

-- Add sample users
for _, username in ipairs(customUsers) do
    createUserItem(username)
end

-- User search functionality
userSearchBox:GetPropertyChangedSignal('Text'):Connect(function()
    for _, child in ipairs(userList:GetChildren()) do
        if child:IsA('TextButton') then
            child:Destroy()
        end
    end
    
    local searchText = userSearchBox.Text:lower()
    for _, username in ipairs(customUsers) do
        if searchText == '' or username:lower():find(searchText) then
            createUserItem(username)
        end
    end
end)

createSectionLabel('CHAT MESSAGES', usersPane)

-- Custom message input
createFieldLabel('ENTER CUSTOM MESSAGE', usersPane)
local customMsgBox = createInputBox('Enter custom message...', '', usersPane)

createButton('SEND CHAT MESSAGE', 
    Color3.fromRGB(26, 51, 32), -- #1a3320
    Color3.fromRGB(74, 222, 128), -- #4ade80
    Color3.fromRGB(30, 74, 40), -- #1e4a28
    usersPane, 
    function()
        local message = customMsgBox.Text
        if message and message ~= '' then
            sendTradeChatMessage(message)
            customMsgBox.Text = ''
        end
    end)

createSectionLabel('QUICK MESSAGES', usersPane)

-- Quick messages list
local quickMsgList = Instance.new('ScrollingFrame')
quickMsgList.Size = UDim2.new(1, 0, 0, 200)
quickMsgList.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
quickMsgList.BorderSizePixel = 0
quickMsgList.ScrollBarThickness = 3
quickMsgList.ScrollBarImageColor3 = Color3.fromRGB(34, 34, 40)
quickMsgList.AutomaticCanvasSize = Enum.AutomaticSize.Y
quickMsgList.Parent = usersPane

local quickMsgCorner = Instance.new('UICorner')
quickMsgCorner.CornerRadius = UDim.new(0, 6)
quickMsgCorner.Parent = quickMsgList

local quickMsgStroke = Instance.new('UIStroke')
quickMsgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
quickMsgStroke.Color = Color3.fromRGB(28, 28, 34)
quickMsgStroke.Thickness = 1
quickMsgStroke.Parent = quickMsgList

local quickMsgLayout = Instance.new('UIListLayout')
quickMsgLayout.SortOrder = Enum.SortOrder.LayoutOrder
quickMsgLayout.Padding = UDim.new(0, 3)
quickMsgLayout.Parent = quickMsgList

local quickMsgPadding = Instance.new('UIPadding')
quickMsgPadding.PaddingTop = UDim.new(0, 4)
quickMsgPadding.PaddingBottom = UDim.new(0, 4)
quickMsgPadding.PaddingLeft = UDim.new(0, 4)
quickMsgPadding.PaddingRight = UDim.new(0, 4)
quickMsgPadding.Parent = quickMsgList

-- Add quick messages
for _, msg in ipairs(CONFIG.CHAT_MESSAGES) do
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, -8, 0, 36)
    btn.BackgroundColor3 = Color3.fromRGB(12, 12, 15)
    btn.BackgroundTransparency = 0
    btn.Text = '  ' .. msg
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(204, 204, 204)
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.AutoButtonColor = false
    btn.Parent = quickMsgList
    
    local btnCorner = Instance.new('UICorner')
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn
    
    local btnStroke = Instance.new('UIStroke')
    btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    btnStroke.Color = Color3.fromRGB(28, 28, 34)
    btnStroke.Thickness = 1
    btnStroke.Parent = btn
    
    btn.MouseEnter:Connect(function()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(200, 168, 75)}):Play()
        btn.TextColor3 = Color3.fromRGB(232, 200, 106)
    end)
    
    btn.MouseLeave:Connect(function()
        TweenService:Create(btnStroke, TweenInfo.new(0.15), {Color = Color3.fromRGB(28, 28, 34)}):Play()
        btn.TextColor3 = Color3.fromRGB(204, 204, 204)
    end)
    
    btn.MouseButton1Click:Connect(function()
        sendTradeChatMessage(msg)
    end)
end

-- ==================== DRAGGING SYSTEM ====================
do
local dragging = false
local dragInput, dragStart, startPos

mainPanel.InputBegan:Connect(function(input)
    if not dragEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainPanel.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

mainPanel.InputChanged:Connect(function(input)
    if not dragEnabled then return end
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragEnabled then return end
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        mainPanel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)
end -- drag scope

-- ==================== KEYBOARD SHORTCUT ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        mainPanel.Visible = not mainPanel.Visible
    end
end)

-- ==================== NOCLIP MAINTENANCE ====================
task.spawn(function()
    while true do
        task.wait(1)
        if UIState.noclipEnabled then
            enableNoclipForAllFakePlayers()
            enableNoclipForPets()
        end
    end
end)

-- ==================== AUTO PARTNER EMOJI ====================
_G.EmojiSystem = {
    running = false,
    reactions = load('SharedConstants').trade_spectate_reactions
}

_G.EmojiSystem.display = function(index)
    if not _G.EmojiSystem.reactions[index] then return end
    if not mockState.active or not mockState.trade then return end
    pcall(function()
        local tradeFrame = Players.LocalPlayer.PlayerGui.TradeApp.Frame
        local e = Instance.new('ImageLabel')
        e.Image = _G.EmojiSystem.reactions[index]
        e.BackgroundTransparency = 1
        e.ImageTransparency = 1
        e.Size = UDim2.fromOffset(40, 40)
        e.Position = UDim2.new(1.06 + math.random(-2, 2) / 100, 0, 0.95, 0)
        e.AnchorPoint = Vector2.new(0.5, 1)
        e.ZIndex = 100
        e.Parent = tradeFrame
        TweenService:Create(e, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            ImageTransparency = 0, Size = UDim2.fromOffset(45, 45)
        }):Play()
        local st, dur, spd = tick(), math.random(18, 28) / 10, 0.18
        local c
        c = RunService.Heartbeat:Connect(function(dt)
            local el = tick() - st
            if el >= dur or not e.Parent then
                c:Disconnect()
                if e.Parent then e:Destroy() end
                return
            end
            local newY = e.Position.Y.Scale - spd * dt
            local drift = math.sin(el * 4) * dt * 0.0
            e.Position = UDim2.new(
                math.clamp(e.Position.X.Scale + drift, 0.97, 1.07), 0, newY, 0
            )
            if el >= dur * 0.5 then
                e.ImageTransparency = (el - dur * 0.5) / (dur * 0.5)
            end
        end)
    end)
end

-- ==================== RGB CYCLING EFFECT ====================
task.spawn(function()
    while true do
        task.wait(0.03)
        if RGBState.enabled and panelStroke then
            RGBState.hue = (RGBState.hue + RGBState.speed) % 360
            local color = Color3.fromHSV(RGBState.hue / 360, 0.7, 1)
            panelStroke.Color = color
        end
    end
end)

-- ==================== SUGGEST SYSTEM ====================
local function buildFakePartnerInventory()
    local highTierNames = {
        "Shadow Dragon","Bat Dragon","Frost Dragon","Giraffe",
        "Owl","Parrot","Crow","Evil Unicorn","Arctic Reindeer",
        "Dalmatian","Turtle","Kangaroo","Hedgehog","Diamond Butterfly",
        "Flamingo","Peppermint Penguin","Chocolate Chip Bat Dragon",
        "Strawberry Shortcake Bat Dragon","Monkey King","Elephant",
    }
    local function makePet(petKind, flyable, rideable, neon, mega_neon)
        local uid = HttpService:GenerateGUID(false)
        return uid, {
            unique=uid, category="pets", id=petKind, kind=petKind,
            newness_order=math.random(1,900000),
            properties={
                pet_trick_level=0, rideable=rideable, flyable=flyable,
                neon=neon, mega_neon=mega_neon, age=100, xp=0,
            },
        }
    end
    local pets = {}

    -- ── Build a lookup table of all non-egg pet kinds for random filler ──
    local allKinds = {}
    for k, v in pairs(InventoryDB.pets or {}) do
        if not (v and v.name or ""):lower():find("egg") then
            table.insert(allKinds, k)
        end
    end

    local usingProfilePets = mockState.partnerProfilePets and #mockState.partnerProfilePets > 0

    if usingProfilePets then
        -- ── Insert the partner's real profile-pinned pets first ──
        -- Many profile pets may be filtered out by the InventoryDB check in
        -- fetchPartnerProfilePets, so we count how many were actually inserted
        -- rather than using #partnerProfilePets (the raw pre-filter count).
        for _, item in ipairs(mockState.partnerProfilePets) do
            pets[item.unique] = item
        end
        -- Count how many pets actually landed in the table after filtering
        local insertedCount = 0
        for _ in pairs(pets) do insertedCount = insertedCount + 1 end
        -- Pad with random filler so the backpack always looks full (30-40 pets total)
        local target = math.random(30, 40)
        for _ = 1, target - insertedCount do
            if #allKinds > 0 then
                local kind = allKinds[math.random(1, #allKinds)]
                local uid, item = makePet(kind, math.random()<0.5, math.random()<0.5, math.random()<0.2, math.random()<0.06)
                pets[uid] = item
            end
        end
    else
        -- ── Fallback: original random high-tier + filler generation ──
        for _, petName in ipairs(highTierNames) do
            for petKind, petData in pairs(InventoryDB.pets or {}) do
                if petData.name == petName and not petName:lower():find("egg") then
                    local uid, item = makePet(petKind, true, true, false, false)
                    pets[uid] = item
                    uid, item = makePet(petKind, true, true, true, false)
                    pets[uid] = item
                    if petName=="Shadow Dragon" or petName=="Bat Dragon"
                    or petName=="Frost Dragon" or petName=="Giraffe" then
                        uid, item = makePet(petKind, true, true, false, true)
                        pets[uid] = item
                    end
                    break
                end
            end
        end
        for _ = 1, math.random(30, 40) do
            if #allKinds > 0 then
                local kind = allKinds[math.random(1, #allKinds)]
                local uid, item = makePet(kind, math.random()<0.5, math.random()<0.5, math.random()<0.2, math.random()<0.06)
                pets[uid] = item
            end
        end
    end
    local EXCLUDED = { pets=true, eggs=true }
    local result = { pets=pets }
    for catName, catTable in pairs(InventoryDB) do
        if not EXCLUDED[catName] then
            local catItems = {}
            local added = 0
            for itemKind in pairs(catTable) do
                for _ = 1, math.random(1,3) do
                    local uid = HttpService:GenerateGUID(false)
                    catItems[uid] = {
                        unique=uid, category=catName, id=itemKind, kind=itemKind,
                        newness_order=math.random(1,900000),
                        properties={ age=math.random(0,100) },
                    }
                    added = added + 1
                    if added >= 20 then break end
                end
                if added >= 20 then break end
            end
            if next(catItems) then result[catName] = catItems end
        end
    end
    return result
end

-- Hook _overwrite_local_trade_state for suggest state
-- Wrapped in task.spawn so this closure gets its own register space
-- (top-level do...end shares the chunk's 200-register limit).
task.spawn(function()
    local _prevOverwrite = TradeApp._overwrite_local_trade_state
    TradeApp._overwrite_local_trade_state = function(self, newState)
        _prevOverwrite(self, newState)
        if mockState.active and newState then
            if self.backpack_access == nil then
                self.suggestions = self.suggestions or {}
                self.can_suggest_removal_items = self.can_suggest_removal_items or {}
                mockState.mockFakeInventory = buildFakePartnerInventory()
            end
        elseif not newState then
            mockState.mockFakeInventory = nil
            mockState.partnerProfilePets = nil
            self.backpack_access = nil
            self._requesting_backpack_access = false
        end
    end
end)

task.spawn(function()
    task.wait(0.1)
    local _orig_suggestible = TradeApp._get_suggestible_items
    TradeApp._get_suggestible_items = function(self)
        if not mockState.suggestEnabled then
            return _orig_suggestible(self)
        end
        if mockState.active and mockState.trade then
            if not mockState.mockFakeInventory then
                mockState.mockFakeInventory = buildFakePartnerInventory()
            end
            return mockState.mockFakeInventory
        end
        return _orig_suggestible(self)
    end

    local _orig_try_suggest_item = TradeApp.try_suggest_item
    TradeApp.try_suggest_item = function(self)
        if not mockState.suggestEnabled then
            if _orig_try_suggest_item then return _orig_try_suggest_item(self) end
            return
        end
        if not mockState.active or not mockState.trade then return end
        if self.backpack_access == false then
            HintApp:hint({ text="Backpack access denied.", length=3, overridable=true, yields=false })
            return
        elseif self.backpack_access == nil then
            HintApp:hint({ text="Backpack access requested..", length=3, overridable=true, yields=false })
            if self._requesting_backpack_access then return end
            local partner = self:_get_partner()
            self._requesting_backpack_access = true
            task.wait(0.9)
            self._requesting_backpack_access = false
            if partner ~= self:_get_partner() then return end
            self.backpack_access = true
            if DialogApp:dialog({
                text=partner.Name.." has granted you access to view their backpack! Make a suggestion now?",
                left="Cancel", right="Suggest",
            }) == "Suggest" then self:suggest_item() end
        else
            self:suggest_item()
        end
    end

    local _orig_suggest_item = TradeApp.suggest_item
    TradeApp.suggest_item = function(self, prePickedItem)
        if not mockState.suggestEnabled then
            if _orig_suggest_item then return _orig_suggest_item(self, prePickedItem) end
            return false
        end
        if not mockState.active or not mockState.trade then return end
        local BackpackAppRef = self.UIManager.apps.BackpackApp
        if BackpackAppRef:is_picking_item() then return false end
        if not self.suggestions then self.suggestions = {} end
        if not self.can_suggest_removal_items then self.can_suggest_removal_items = {} end
        if not mockState.mockFakeInventory then mockState.mockFakeInventory = buildFakePartnerInventory() end
        local fakeInv = mockState.mockFakeInventory
        local myPlayer = self:_get_my_player()
        local pickedItem = prePickedItem
        if not pickedItem then
            local realInv = ClientData.get('inventory')
            local saved = {}
            for catName, catItems in pairs(fakeInv) do
                saved[catName] = {}
                if realInv[catName] then
                    for uid, item in pairs(realInv[catName]) do saved[catName][uid]=item realInv[catName][uid]=nil end
                else realInv[catName] = {} end
                for uid, item in pairs(catItems) do realInv[catName][uid]=item end
            end
            for _, catName in ipairs({"eggs"}) do
                if realInv[catName] and not fakeInv[catName] then
                    saved["__hidden_"..catName] = {}
                    for uid, item in pairs(realInv[catName]) do saved["__hidden_"..catName][uid]=item realInv[catName][uid]=nil end
                end
            end
            local ok, result = pcall(function()
                return BackpackAppRef:pick_item({
                    friendship_hidden=true,
                    title_override=self:_get_partner().Name:upper().."'S BACKPACK",
                    force_no_filters=true,
                    allow_callback=function(item)
                        local s = self.suggestions[item.unique]
                        return (not s or s.item_owner==myPlayer) and true or false
                    end,
                })
            end)
            for catName, catItems in pairs(saved) do
                local realCat = catName:match("^__hidden_(.+)$") or catName
                if realInv[realCat] then for uid in pairs(realInv[realCat]) do realInv[realCat][uid]=nil end end
                for uid, item in pairs(catItems) do
                    if not realInv[realCat] then realInv[realCat]={} end
                    realInv[realCat][uid]=item
                end
            end
            if not ok or not result then return false end
            pickedItem = result
        end
        if not pickedItem then return false end
        if self.suggestions[pickedItem.unique] then
            HintApp:hint({ text="Item already suggested!", length=3, overridable=true, yields=false }) return false
        end
        for _, v in self:_get_partner_offer().items do
            if v.unique==pickedItem.unique then
                HintApp:hint({ text="Item already in offer!", length=4, overridable=true, yields=false }) return false
            end
        end
        local fullItem = nil
        for _, catItems in pairs(fakeInv) do
            if catItems[pickedItem.unique] then fullItem=catItems[pickedItem.unique] break end
        end
        fullItem = fullItem or pickedItem
        -- BUG FIX 2: profile-clicked items have their own UUID from the profile save
        -- data, not a UUID that was generated into mockFakeInventory. _render_suggestion
        -- searches _get_suggestible_items() (our fakeInv) by unique and returns early
        -- without any chat card if it can't find the item. Fix: register the item in
        -- fakeInv under its real unique so the lookup succeeds and the card is shown.
        if fullItem and fullItem.unique and fullItem.category then
            if not fakeInv[fullItem.category] then fakeInv[fullItem.category] = {} end
            fakeInv[fullItem.category][fullItem.unique] = fullItem
        end
        local partner = self:_get_partner()
        self:_render_suggestion(fullItem.unique, partner)
        update_busy_indicators({ ['picking']=true })
        task.delay(1.5, function()
            if not mockState.active or not mockState.trade then update_busy_indicators({ ['picking']=false }) return end
            update_busy_indicators({ ['picking']=false })
            table.insert(mockState.trade.recipient_offer.items, fullItem)
            self.can_suggest_removal_items[fullItem.unique] = fullItem
            mockState.suggestedItems[fullItem.unique] = true
            mockState.trade.sender_offer.negotiated = false
            mockState.trade.recipient_offer.negotiated = false
            if mockState.trade.current_stage=="confirmation" then
                mockState.trade.current_stage="negotiation"
                mockState.trade.sender_offer.confirmed=false
                mockState.trade.recipient_offer.confirmed=false
            end
            mockState.trade.offer_version = (mockState.trade.offer_version or 0) + 1
            TradeApp:_overwrite_local_trade_state(mockState.trade)
            if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
            pcall(function() self:_render_suggestion_finalized(fullItem.unique, true, partner) end)
        end)
        return true
    end
end)
-- ==================== END SUGGEST SYSTEM ====================

-- ==================== PROFILE SUGGEST INTEGRATION v3 ====================
task.spawn(function()

    -- ── 1. Patch TradeApp._get_partner ─────────────────────────────────
    -- The native widget checks  TradeApp:_get_partner() == widget.player_profile.player
    -- For mock trades this always needs to return our fake Partner Player object.
    task.spawn(function()
        task.wait(1.5)

        local TradeApp = UIManager and UIManager.apps and UIManager.apps.TradeApp
        if not TradeApp then
            warn("[ProfileSuggest v3] TradeApp not found")
            return
        end

        local _origGetPartner = TradeApp._get_partner
        TradeApp._get_partner = function(self, ...)
            -- While a mock trade is active, always return the mock recipient.
            -- This makes  _get_partner() == widget.player_profile.player  evaluate
            -- true as soon as we set app.player (step 2 below).
            if mockState.active
               and mockState.trade
               and mockState.trade.recipient then
                return mockState.trade.recipient
            end
            return _origGetPartner(self, ...)
        end

        print("[ProfileSuggest v3] _get_partner patched")

        -- ── 2. Patch PlayerProfileApp ───────────────────────────────────
        local PlayerProfileApp = UIManager.apps.PlayerProfileApp
        if not PlayerProfileApp then
            warn("[ProfileSuggest v3] PlayerProfileApp not found")
            return
        end

        local function isMockPartner(userId)
            return mockState.active
                and mockState.trade
                and mockState.trade.recipient
                and tostring(userId) == tostring(mockState.trade.recipient.UserId)
        end

        -- Patches both app.player AND player_profile.player, then flips the header.
        -- IMPORTANT: player_profile.player must be set before widgets render because
        -- CollectionProfileWidget.render() captures it as a copied upvalue in click
        -- handler closures — if it's nil at render time, no click handlers are wired up.
        local function applyMockContext(app)
            pcall(function()
                app.player = mockState.trade.recipient
                -- Also patch inside player_profile so widget upvalue captures correct ref
                if app.player_profile then
                    app.player_profile.player = mockState.trade.recipient
                end
                -- BUG FIX 1: load_start sets app.player = nil (fake partner has no real
                -- Player object at that point), then enable_profile_editing(false) hides
                -- TradeButton because player==nil. set_header_info only changes icon/text,
                -- never Visible. We must call enable_profile_editing again now that
                -- app.player is correctly set so TradeButton.Visible gets set to true.
                if not app.is_editing_profile then
                    app:enable_profile_editing(false)
                end
                -- Flip the Trade header button icon/text to "Suggest"
                app:set_header_info({
                    in_trade         = true,
                    in_trade_with_me = true,
                })
            end)
        end

        -- Re-renders all slots on the current page so click handlers re-capture
        -- the now-patched player_profile.player reference.
        local function rerenderSlots(app)
            pcall(function()
                if not app.player_profile or not app.slots then return end
                local page = app.page or 1
                for i = 1, #app.slots do
                    pcall(function()
                        app.player_profile:render_slot(page, i)
                    end)
                end
            end)
        end

        -- ── HOOK: open_player_profile_for_user_id ──
        local _origOpen = PlayerProfileApp.open_player_profile_for_user_id
        PlayerProfileApp.open_player_profile_for_user_id = function(self, userId, ...)
            local result = _origOpen(self, userId, ...)
            if isMockPartner(userId) then
                task.spawn(function()
                    -- Wait for the loading spinner to clear
                    local deadline = tick() + 10
                    while self.loading and tick() < deadline do
                        task.wait(0.05)
                    end
                    task.wait(0.1)
                    if isMockPartner(userId) then
                        applyMockContext(self)
                        -- Re-render so widgets rebuild click handlers with correct player
                        rerenderSlots(self)
                    end
                end)
            end
            return result
        end

        -- ── HOOK: load_start / on_load_call ──
        -- on_load_call fires once, exactly when profile data is ready.
        local _origLoadStart = PlayerProfileApp.load_start
        PlayerProfileApp.load_start = function(self, ...)
            local result = _origLoadStart(self, ...)
            pcall(function()
                self:on_load_call(function()
                    local uid = self.player_profile and self.player_profile.user_id
                    if uid and isMockPartner(uid) then
                        task.defer(function()
                            applyMockContext(self)
                            -- Re-render so click handler upvalues capture the mock player
                            rerenderSlots(self)
                        end)
                    end
                end)
            end)
            return result
        end

        -- ── HOOK: open_page ──
        -- Patch player_profile.player BEFORE _origOpenPage runs so that when
        -- CollectionProfileWidget.render() is called, v_u_78 (the player upvalue)
        -- is already set to the mock partner and click handlers are wired up correctly.
        local _origOpenPage = PlayerProfileApp.open_page
        PlayerProfileApp.open_page = function(self, pageNum, ...)
            local uid = self.player_profile and self.player_profile.user_id
            if uid and isMockPartner(uid) then
                -- Patch BEFORE render so widgets capture correct player in upvalues
                pcall(function()
                    self.player_profile.player = mockState.trade.recipient
                    self.player = mockState.trade.recipient
                end)
            end
            local result = _origOpenPage(self, pageNum, ...)
            -- Refresh header after render
            if uid and isMockPartner(uid) then
                pcall(function()
                    self:set_header_info({
                        in_trade         = true,
                        in_trade_with_me = true,
                    })
                end)
            end
            return result
        end

        print("[ProfileSuggest v3] PlayerProfileApp hooks installed")
        print("[ProfileSuggest v3] Ready — open mock partner's profile to see Suggest button + pet-click suggest")
    end)

    -- ── 3. Guard: hook suggest_item to intercept server call ───────────
    -- The native suggest_item fires TradeAPI/SuggestItem:InvokeServer(unique).
    -- Your existing fake-trade script should already hook this; if not,
    -- uncomment the block below to stub it out.

    --[[
    task.spawn(function()
        task.wait(2)
        local TradeApp = UIManager and UIManager.apps and UIManager.apps.TradeApp
        if not TradeApp then return end

        local _origSuggest = TradeApp.suggest_item
        TradeApp.suggest_item = function(self, prePickedItem)
            if mockState.active then
                -- Skip InvokeServer; render the suggestion locally instead.
                local item = prePickedItem
                if not item then
                    -- Fall back to BackpackApp picker using mock inventory
                    local mockInv = mockState.mockFakeInventory or {}
                    item = self.UIManager.apps.BackpackApp:pick_item({
                        friendship_hidden = true,
                        title_override    = (self:_get_partner().Name:upper() .. "'S BACKPACK"),
                        inventory_override = mockInv,
                        force_no_filters  = true,
                    })
                end
                if item then
                    self:_render_suggestion(item.unique, self:_get_partner())
                    return true
                end
                return false
            end
            return _origSuggest(self, prePickedItem)
        end
        print("[ProfileSuggest v3] suggest_item stubbed for mock trades")
    end)
    --]]

end)
-- ==================== END PROFILE SUGGEST INTEGRATION v3 ====================

-- ==================== FAKE PLAYER PROFILE TRADE BUTTON ====================
task.spawn(function()
    task.wait(3)

    local ProfileApp = UIManager and UIManager.apps and UIManager.apps.PlayerProfileApp
    if not ProfileApp then
        warn("[FakePlayerProfile] PlayerProfileApp not found")
        return
    end

    local _prev_open = ProfileApp.open_player_profile_for_user_id
    ProfileApp.open_player_profile_for_user_id = function(self, userId, ...)
        local result = _prev_open(self, userId, ...)

        if fakePlayerIds[userId] and not mockState.active then
            task.spawn(function()
                -- Wait for spinner to clear
                local deadline = tick() + 10
                while self.loading and tick() < deadline do
                    task.wait(0.05)
                end
                task.wait(0.15)

                if not fakePlayerIds[userId] or mockState.active then return end

                pcall(function()
                    -- Resolve name from folder
                    local partnerName = tostring(userId)
                    for _, folder in ipairs(FakePlayers) do
                        if folder:GetAttribute('PartnerId') == userId then
                            partnerName = folder:GetAttribute('PartnerName') or partnerName
                            break
                        end
                    end

                    -- Build fake player object so enable_profile_editing makes TradeButton visible
                    local fakePObj = setmetatable({
                        Name        = partnerName,
                        DisplayName = partnerName,
                        UserId      = userId,
                        ClassName   = 'Player',
                    }, {
                        __index = function(t, k)
                            if k == 'Parent'         then return Players end
                            if k == 'IsA'            then return function(_, cls) return cls == 'Player' or cls == 'Instance' end end
                            if k == 'GetAttribute'   then return function() return nil end end
                            if k == 'FindFirstChild' then return function() return nil end end
                            if k == 'WaitForChild'   then return function() return nil end end
                            return rawget(t, k)
                        end,
                        __tostring = function() return partnerName end,
                        __eq = function(a, b)
                            return type(b) == 'table' and rawget(a, 'UserId') == rawget(b, 'UserId')
                        end,
                    })

                    -- Inject so TradeButton becomes visible
                    self.player = fakePObj
                    if self.player_profile then
                        self.player_profile.player = fakePObj
                    end
                    self:enable_profile_editing(false)
                    self:set_header_info({ in_trade = false, in_trade_with_me = false })

                    -- Remove any existing overlay from a previous load
                    local tradeBtn = self.header and self.header.TradeButton
                    if not tradeBtn then return end
                    local existing = tradeBtn:FindFirstChild('FakeTradeOverlay')
                    if existing then existing:Destroy() end

                    -- Place a transparent button ON TOP of TradeButton.
                    -- Fires BEFORE the DepthButton's MouseButton1Click
                    -- so the native handler (which tries FireServer) never runs.
                    local overlay = Instance.new('TextButton')
                    overlay.Name = 'FakeTradeOverlay'
                    overlay.Size = UDim2.new(1, 0, 1, 0)
                    overlay.Position = UDim2.new(0, 0, 0, 0)
                    overlay.BackgroundTransparency = 1
                    overlay.Text = ''
                    overlay.ZIndex = tradeBtn.ZIndex + 50
                    overlay.AutoButtonColor = false
                    overlay.Parent = tradeBtn

                    overlay.MouseButton1Click:Connect(function()
                        overlay:Destroy()
                        UIManager.set_app_visibility('PlayerProfileApp', false)
                        if partnerBox then partnerBox.Text = partnerName end
                        updatePartnerFromUsername(partnerName)
                        if HintApp then
                            HintApp:hint({ text = 'Trade request sent to ' .. partnerName, length = 3, overridable = true })
                        end
                        task.wait(CONFIG.FAKE_PLAYER_ACCEPT_TRADE_REQUEST)
                        startMockTradeDirectly()
                    end)
                end)
            end)
        end

        return result
    end

    print("[FakePlayerProfile] Trade button overlay ready")
end)
-- ==================== END FAKE PLAYER PROFILE TRADE BUTTON ====================

-- ==================== SUGGEST REMOVAL AUTO-ACCEPT ====================
-- Keeps the X button live on every item in the partner's offer.
-- When you click X the game fires SuggestRemoveItem to the server
-- (blocked in mock) and immediately nils the can_suggest_removal_items
-- entry, then renders "You want [partner] to remove [item] from their offer".
-- We intercept that chat message, look the item up by name in the partner's
-- current offer, and auto-remove it 1.3 s later just like a real acceptance.
task.spawn(function()
    task.wait(2.5)

    local pendingRemovals = {}

    -- 1. Sync can_suggest_removal_items with partner's offer
    -- This is the sole thing that makes the X icon interactive on each slot.
    local function syncRemovable()
        if not (mockState.active and mockState.trade) then return end
        TradeApp.can_suggest_removal_items = TradeApp.can_suggest_removal_items or {}
        for _, item in ipairs((mockState.trade.recipient_offer or {}).items or {}) do
            if item and item.unique then
                TradeApp.can_suggest_removal_items[item.unique] = item
            end
        end
    end

    -- Chain onto whatever hook is already installed (suggest system etc.)
    local _prevOverwrite = TradeApp._overwrite_local_trade_state
    TradeApp._overwrite_local_trade_state = function(self, newState)
        _prevOverwrite(self, newState)
        syncRemovable()
    end

    -- 2. Detect X click via the chat message it renders locally
    -- Exact format from TradeApp source:
    --   "You want [partnerName] to remove [itemName] from their offer"
    -- NOTE: the game already nils can_suggest_removal_items[unique] BEFORE
    -- this message fires, so we find the item by matching its name in the offer.
    local _origChat = TradeApp._render_message_in_trade_chat
    TradeApp._render_message_in_trade_chat = function(self, sender, msg, ...)
        _origChat(self, sender, msg, ...)
        if not (mockState.active and mockState.trade and msg) then return end

        local itemName = msg:match("You want .+ to remove (.+) from their offer")
        if not itemName then return end

        -- Find item by display name in the partner's current offer
        local foundItem = nil
        for _, item in ipairs((mockState.trade.recipient_offer or {}).items or {}) do
            if item and item.category and item.kind then
                local ok, name = pcall(function()
                    return InventoryDB[item.category][item.kind].name
                end)
                if ok and name and name:lower() == itemName:lower() then
                    foundItem = item
                    break
                end
            end
        end
        if not foundItem or pendingRemovals[foundItem.unique] then return end

        pendingRemovals[foundItem.unique] = true
        local targetUnique = foundItem.unique
        local displayName  = itemName

        -- 3. Partner auto-accepts the removal after 1.3 s
        task.delay(1.3, function()
            pendingRemovals[targetUnique] = nil
            if not (mockState.active and mockState.trade) then return end

            local offerItems = mockState.trade.recipient_offer.items
            local removed = false
            for i = #offerItems, 1, -1 do
                if offerItems[i] and offerItems[i].unique == targetUnique then
                    table.remove(offerItems, i)
                    removed = true
                    break
                end
            end
            if not removed then return end

            if TradeApp.can_suggest_removal_items then
                TradeApp.can_suggest_removal_items[targetUnique] = nil
            end

            mockState.trade.sender_offer.negotiated    = false
            mockState.trade.recipient_offer.negotiated = false
            if mockState.trade.current_stage == "confirmation" then
                mockState.trade.current_stage             = "negotiation"
                mockState.trade.sender_offer.confirmed    = false
                mockState.trade.recipient_offer.confirmed = false
            end
            mockState.trade.offer_version = (mockState.trade.offer_version or 0) + 1

            TradeApp:_overwrite_local_trade_state(mockState.trade)
            if TradeApp._lock_trade_for_appropriate_time then
                TradeApp:_lock_trade_for_appropriate_time()
            end

            pcall(function()
                self:_render_message_in_trade_chat(
                    nil,
                    string.format("%s removed %s.", CONFIG.PARTNER_NAME, displayName),
                    true
                )
            end)
        end)
    end

    syncRemovable()
    print("[SuggestRemoval] Ready — X buttons live on all partner offer items")
end)
-- ==================== END SUGGEST REMOVAL AUTO-ACCEPT ====================

-- ==================== SPIN THE WHEEL SYSTEM ====================
spinnerSystem = {}
function initSpinnerSystem()
    pcall(function() spinnerSystem.SoundPlayer = load('SoundPlayer') end)
    spinnerSystem.Templates = ReplicatedStorage.Resources.UI_Resources.Templates
    spinnerSystem.ItemImageTemplate = spinnerSystem.Templates.ItemImageTemplate
    spinnerSystem.PlayerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
    spinnerSystem.DailyLoginGui = spinnerSystem.PlayerGui:WaitForChild("DailyLoginApp")
    spinnerSystem.MainFrame = spinnerSystem.DailyLoginGui:WaitForChild("Frame")
    spinnerSystem.app = UIManager.apps.DailyLoginApp
    spinnerSystem.THEME = {
        cardDefaultBG = Color3.fromRGB(230, 240, 255),
        cardDefaultStroke = Color3.fromRGB(200, 80, 80),
        cardHighlightBG = Color3.fromRGB(200, 255, 210),
        cardHighlightStroke = Color3.fromRGB(74, 198, 85),
        cardWinFlashBG = Color3.fromRGB(255, 248, 215),
        cardWinFlashStroke = Color3.fromRGB(255, 200, 50),
        rewardBoxDefault = Color3.fromRGB(200, 60, 60),
        rewardBoxHighlight = Color3.fromRGB(50, 190, 80),
        rewardTextDefault = Color3.fromRGB(255, 255, 255),
        pointer = Color3.fromRGB(100, 180, 255),
        pointerStroke = Color3.fromRGB(60, 130, 220),
        innerStroke = Color3.fromRGB(180, 210, 255),
        cardShadow = Color3.fromRGB(40, 80, 140),
        petNameText = Color3.fromRGB(30, 50, 100),
        toggleBG = Color3.fromRGB(60, 140, 255),
        toggleShadow = Color3.fromRGB(30, 100, 200),
        toggleStroke = Color3.fromRGB(30, 100, 200),
    }
    spinnerSystem.TIERS = {
        HIGH = {
            'Shadow Dragon', 'Bat Dragon', 'Frost Dragon', 'Giraffe', 'Owl', 'Parrot', 'Crow',
            'Evil Unicorn', 'Arctic Reindeer', 'Hedgehog', 'Dalmatian',
        },
        MID = {
            'Turtle', 'Kangaroo', 'Lion', 'Elephant', 'Rhino', 'Chocolate Chip Bat Dragon',
            'Cow', 'Blazing Lion', 'African Wild Dog', 'Flamingo', 'Diamond Butterfly',
            'Mini Pig', 'Caterpillar', 'Albino Monkey', 'Candyfloss Chick', 'Pelican',
            'Blue Dog', 'Pink Cat', 'Haetae', 'Peppermint Penguin', 'Winged Tiger',
            'Sugar Glider', 'Shark Puppy', 'Goat', 'Sheeeeep', 'Lion Cub', 'Nessie',
            'Frostbite Bear', 'Balloon Unicorn', 'Honey Badger', 'Hot Doggo', 'Crocodile',
            'Hare', 'Ram', 'Yeti', 'Meerkat', 'Jellyfish', 'Happy Clam', 'Orchid Butterfly',
            'Many Mackerel', 'Strawberry Shortcake Bat Dragon', 'Zombie Buffalo', 'Fairy Bat Dragon',
        },
    }
    spinnerSystem.PROPERTY_COMBOS = {
        { flyable = true, rideable = true, neon = false, mega_neon = false, label = "FR" },
        { flyable = true, rideable = true, neon = true,  mega_neon = false, label = "NFR" },
        { flyable = true, rideable = true, neon = false, mega_neon = true,  label = "MFR" },
    }
    spinnerSystem.currentTier = nil
    spinnerSystem.resolvePetsForTier = function(tierName)
        local names = spinnerSystem.TIERS[tierName]
        if not names then return {} end
        local resolved = {}
        for _, petName in ipairs(names) do
            local found = false
            for kind, data in pairs(InventoryDB.pets or {}) do
                if data.name == petName then
                    local combo = spinnerSystem.PROPERTY_COMBOS[math.random(1, #spinnerSystem.PROPERTY_COMBOS)]
                    table.insert(resolved, {
                        name = petName,
                        kind = kind,
                        image = data.image or "",
                        item_data = {
                            category = "pets", kind = kind, unique = "spinner_" .. kind .. "_" .. math.random(1, 99999),
                            properties = { flyable = combo.flyable, rideable = combo.rideable, neon = combo.neon, mega_neon = combo.mega_neon },
                        },
                        propLabel = combo.label,
                    })
                    found = true
                    break
                end
            end
            if not found then
                table.insert(resolved, {
                    name = petName, kind = petName:gsub(" ", ""), image = "",
                    item_data = {
                        category = "pets", kind = petName:gsub(" ", ""), unique = "spinner_" .. petName:gsub(" ", ""),
                        properties = { flyable = true, rideable = true, neon = false, mega_neon = true },
                    },
                    propLabel = "MFR",
                })
            end
        end
        return resolved
    end
    spinnerSystem.PETS = {}
    spinnerSystem.STRIP_REPEATS = 20
    spinnerSystem.STRIP_PETS = {}
    spinnerSystem.CARD_GAP = 6
    spinnerSystem.CONFETTI_COLORS = {
        Color3.fromRGB(100, 180, 255), Color3.fromRGB(60, 220, 130),
        Color3.fromRGB(255, 130, 80),  Color3.fromRGB(255, 220, 80),
        Color3.fromRGB(180, 100, 255), Color3.fromRGB(80, 230, 255),
        Color3.fromRGB(255, 100, 150), Color3.fromRGB(255, 255, 255),
    }
    spinnerSystem.spinning = false
    spinnerSystem.spinCount = 0
    spinnerSystem.persistentHL = -1
    spinnerSystem.petCards = {}
    spinnerSystem.cardScales = {}
    spinnerSystem.rewardBoxes = {}
    spinnerSystem.dragState = { dragStart = nil, startPos = nil, dragMoved = false }

    spinnerSystem.toggleGui = Instance.new("ScreenGui")
    spinnerSystem.toggleGui.Name = "PetSpinnerToggle"
    spinnerSystem.toggleGui.ResetOnSpawn = false
    spinnerSystem.toggleGui.DisplayOrder = 100
    spinnerSystem.toggleGui.Parent = spinnerSystem.PlayerGui

    spinnerSystem.toggleBtn = Instance.new("TextButton")
    spinnerSystem.toggleBtn.Name = "ToggleBtn"
    spinnerSystem.toggleBtn.Size = UDim2.new(0, 52, 0, 52)
    spinnerSystem.toggleBtn.Position = UDim2.new(0, 14, 0.5, 0)
    spinnerSystem.toggleBtn.AnchorPoint = Vector2.new(0, 0.5)
    spinnerSystem.toggleBtn.BackgroundColor3 = spinnerSystem.THEME.toggleBG
    spinnerSystem.toggleBtn.BorderSizePixel = 0
    spinnerSystem.toggleBtn.Text = ""
    spinnerSystem.toggleBtn.AutoButtonColor = true
    spinnerSystem.toggleBtn.Parent = spinnerSystem.toggleGui
    Instance.new("UICorner", spinnerSystem.toggleBtn).CornerRadius = UDim.new(0, 12)

    spinnerSystem.toggleShadow = Instance.new("Frame")
    spinnerSystem.toggleShadow.Size = UDim2.new(1, 2, 1, 2)
    spinnerSystem.toggleShadow.Position = UDim2.new(0.5, 0, 0.5, 3)
    spinnerSystem.toggleShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    spinnerSystem.toggleShadow.BackgroundColor3 = spinnerSystem.THEME.toggleShadow
    spinnerSystem.toggleShadow.BorderSizePixel = 0
    spinnerSystem.toggleShadow.ZIndex = 0
    spinnerSystem.toggleShadow.Parent = spinnerSystem.toggleBtn
    Instance.new("UICorner", spinnerSystem.toggleShadow).CornerRadius = UDim.new(0, 12)

    spinnerSystem.tIcon = spinnerSystem.ItemImageTemplate:Clone()
    spinnerSystem.tIcon.Image = "rbxassetid://4115248712"
    spinnerSystem.tIcon.Size = UDim2.new(0, 34, 0, 34)
    spinnerSystem.tIcon.Position = UDim2.new(0.5, 0, 0.5, -1)
    spinnerSystem.tIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    spinnerSystem.tIcon.BackgroundTransparency = 1
    spinnerSystem.tIcon.ScaleType = Enum.ScaleType.Fit
    spinnerSystem.tIcon.ZIndex = 2
    spinnerSystem.tIcon.Parent = spinnerSystem.toggleBtn

    spinnerSystem.tStroke = Instance.new("UIStroke")
    spinnerSystem.tStroke.Color = spinnerSystem.THEME.toggleStroke
    spinnerSystem.tStroke.Thickness = 2
    spinnerSystem.tStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    spinnerSystem.tStroke.Parent = spinnerSystem.toggleBtn

    spinnerSystem.toggleBtn.MouseButton1Click:Connect(function()
        if spinnerSystem.DailyLoginGui.Enabled then
            spinnerSystem.DailyLoginGui.Enabled = false
            spinnerSystem.MainFrame.Visible = false
        else
            spinnerSystem.showTierPopup()
        end
    end)

    spinnerSystem.toggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            spinnerSystem.dragState.dragMoved = false
            spinnerSystem.dragState.dragStart = input.Position
            spinnerSystem.dragState.startPos = spinnerSystem.toggleBtn.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if spinnerSystem.dragState.dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - spinnerSystem.dragState.dragStart
            if delta.Magnitude > 6 then spinnerSystem.dragState.dragMoved = true end
            if spinnerSystem.dragState.dragMoved then
                spinnerSystem.toggleBtn.Position = UDim2.new(
                    spinnerSystem.dragState.startPos.X.Scale, spinnerSystem.dragState.startPos.X.Offset + delta.X,
                    spinnerSystem.dragState.startPos.Y.Scale, spinnerSystem.dragState.startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            spinnerSystem.dragState.dragStart = nil
        end
    end)

    spinnerSystem.DailyLoginGui.Enabled = false
    spinnerSystem.MainFrame.Visible = false

    spinnerSystem.app.claim_ad_button_instance.Visible = false
    spinnerSystem.app.milestones_button_instance.Visible = false
    spinnerSystem.app.early_claim_explainer_button_instance.Visible = false
    spinnerSystem.daysContainer = spinnerSystem.app.days_list_container
    spinnerSystem.daysContainer:FindFirstChild("LeftArrowButtonContainer").Visible = false
    spinnerSystem.daysContainer:FindFirstChild("RightArrowButtonContainer").Visible = false
    for _, bucket in ipairs(spinnerSystem.app.day_buckets) do bucket:Destroy() end
    spinnerSystem.app.day_buckets = {}
    if spinnerSystem.app.page_layout then spinnerSystem.app.page_layout:Destroy() end

    do
        local taglineArea = spinnerSystem.app.body:FindFirstChild("TaglineArea")
        if taglineArea then
            taglineArea.Visible = true
            local tagline = taglineArea:FindFirstChild("Tagline")
            if tagline then
                tagline.Text = "Spin to win your dream pet!"
                tagline.Font = Enum.Font.GothamBold
            end
            for _, child in ipairs(taglineArea:GetChildren()) do
                if child.Name ~= "Tagline" and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    child.Visible = false
                end
            end
        end
    end

    spinnerSystem.spinBtn = spinnerSystem.app.claim_depth_button
    spinnerSystem.claimBtnInst = spinnerSystem.app.claim_button_instance

    do
        local buttonsContainer = spinnerSystem.app.body:FindFirstChild("Buttons")
        if buttonsContainer then buttonsContainer.Size = buttonsContainer.Size + UDim2.new(0.5, 0, 0, 0) end
    end
    spinnerSystem.claimBtnInst.Size = spinnerSystem.claimBtnInst.Size + UDim2.new(0.7, 0, 0, 0)
    do
        local face = spinnerSystem.claimBtnInst:FindFirstChild("Face")
        if face then face.Size = UDim2.new(1, 0, face.Size.Y.Scale, face.Size.Y.Offset) end
        local shadow = spinnerSystem.claimBtnInst:FindFirstChild("Shadow")
        if shadow then shadow.Size = UDim2.new(1, 0, shadow.Size.Y.Scale, shadow.Size.Y.Offset) end
    end
    spinnerSystem.spinBtn:set_state("normal")
    spinnerSystem.spinBtn:set_text("SPIN")

    spinnerSystem.daysList = spinnerSystem.app.days_list
    spinnerSystem.daysList.ClipsDescendants = true

    task.wait()
    spinnerSystem.vpH = spinnerSystem.daysList.AbsoluteSize.Y
    spinnerSystem.vpW = spinnerSystem.daysList.AbsoluteSize.X
    spinnerSystem.CARD_SIZE = math.max(math.floor(spinnerSystem.vpH * 0.68), 50)
    spinnerSystem.CELL_WIDTH = spinnerSystem.CARD_SIZE + spinnerSystem.CARD_GAP
    spinnerSystem.originalBtnSize = spinnerSystem.claimBtnInst.Size

    spinnerSystem.addPetToMySide = function(petName, flags)
        if not mockState.active or not mockState.trade then return end
        if #mockState.trade.sender_offer.items >= 18 then return end
        for category_name, category_table in pairs(InventoryDB) do
            if category_name == 'pets' then
                for id, item in pairs(category_table) do
                    if item.name == petName then
                        local petItem = {
                            category = 'pets',
                            kind = id,
                            unique = HttpService:GenerateGUID(),
                            properties = { flyable = flags.F, rideable = flags.R, neon = flags.N, mega_neon = flags.M, age = 1 },
                        }
                        table.insert(mockState.trade.sender_offer.items, petItem)
                        mockState.trade.sender_offer.negotiated = false
                        mockState.trade.recipient_offer.negotiated = false
                        if mockState.trade.current_stage == 'confirmation' then
                            mockState.trade.current_stage = 'negotiation'
                            mockState.trade.sender_offer.confirmed = false
                            mockState.trade.recipient_offer.confirmed = false
                        end
                        mockState.trade.offer_version = mockState.trade.offer_version + 1
                        TradeApp:_overwrite_local_trade_state(mockState.trade)
                        if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
                        return
                    end
                end
            end
        end
    end

    spinnerSystem.showWinPopup = function(pet)
        spinnerSystem.lastWonPet = pet
        task.spawn(function()
            local props = pet.item_data and pet.item_data.properties or {}
            local petKind = pet.kind
            DialogApp:dialog({
                dialog_type = "ItemPreviewDialog",
                item = {
                    unique = HttpService:GenerateGUID(false),
                    category = "pets",
                    id = petKind,
                    kind = petKind,
                    properties = {
                        neon = props.neon or false,
                        mega_neon = props.mega_neon or false,
                        rideable = props.rideable or false,
                        flyable = props.flyable or false,
                    }
                },
                text = ("You won a %s!"):format(pet.name),
                button = "Add to Trade",
            })
            if spinnerSystem.lastWonPet and mockState.active and mockState.trade then
                local flags = props
                spinnerSystem.addPetToMySide(pet.name, {
                    F = flags.flyable or false,
                    R = flags.rideable or false,
                    N = flags.neon or false,
                    M = flags.mega_neon or false,
                })
            end
        end)
    end

    spinnerSystem.hideWinPopup = function() end

    spinnerSystem.animateStroke = function(stroke, color, thickness)
        TweenService:Create(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Color = color, Thickness = thickness }):Play()
    end

    spinnerSystem.resetCard = function(card)
        local s = card:FindFirstChild("Stroke")
        if s then spinnerSystem.animateStroke(s, spinnerSystem.THEME.cardDefaultStroke, 2) end
        TweenService:Create(card, TweenInfo.new(0.12), { BackgroundColor3 = spinnerSystem.THEME.cardDefaultBG }):Play()
        local idx = card:GetAttribute("CardIndex")
        if idx and spinnerSystem.rewardBoxes[idx] then
            TweenService:Create(spinnerSystem.rewardBoxes[idx], TweenInfo.new(0.12), { BackgroundColor3 = spinnerSystem.THEME.rewardBoxDefault }):Play()
        end
    end

    spinnerSystem.highlightCard = function(card)
        local s = card:FindFirstChild("Stroke")
        if s then spinnerSystem.animateStroke(s, spinnerSystem.THEME.cardHighlightStroke, 3) end
        TweenService:Create(card, TweenInfo.new(0.08), { BackgroundColor3 = spinnerSystem.THEME.cardHighlightBG }):Play()
        local idx = card:GetAttribute("CardIndex")
        if idx and spinnerSystem.rewardBoxes[idx] then
            TweenService:Create(spinnerSystem.rewardBoxes[idx], TweenInfo.new(0.08), { BackgroundColor3 = spinnerSystem.THEME.rewardBoxHighlight }):Play()
        end
    end

    spinnerSystem.Strip = Instance.new("Frame")
    spinnerSystem.Strip.Name = "Strip"
    spinnerSystem.Strip.Size = UDim2.new(0, 100, 1, 0)
    spinnerSystem.Strip.Position = UDim2.new(0, 0, 0.5, 0)
    spinnerSystem.Strip.AnchorPoint = Vector2.new(0, 0.5)
    spinnerSystem.Strip.BackgroundTransparency = 1
    spinnerSystem.Strip.Parent = spinnerSystem.daysList

    spinnerSystem.Pointer = Instance.new("Frame")
    spinnerSystem.Pointer.Size = UDim2.new(0, 3, 0.7, 0)
    spinnerSystem.Pointer.Position = UDim2.new(0.5, 0, 0.5, 0)
    spinnerSystem.Pointer.AnchorPoint = Vector2.new(0.5, 0.5)
    spinnerSystem.Pointer.BackgroundColor3 = spinnerSystem.THEME.pointer
    spinnerSystem.Pointer.BorderSizePixel = 0
    spinnerSystem.Pointer.ZIndex = 10
    spinnerSystem.Pointer.Parent = spinnerSystem.daysList
    do
        local ps = Instance.new("UIStroke")
        ps.Color = spinnerSystem.THEME.pointerStroke
        ps.Thickness = 1
        ps.Transparency = 0.4
        ps.Parent = spinnerSystem.Pointer
    end

    spinnerSystem.MFR_PIP_SIZE = math.clamp(math.floor(spinnerSystem.CARD_SIZE * 0.17), 8, 16)

    spinnerSystem.buildStrip = function(tierName)
        if spinnerSystem.currentTier == tierName and #spinnerSystem.petCards > 0 then return end
        spinnerSystem.currentTier = tierName
        for _, child in ipairs(spinnerSystem.Strip:GetChildren()) do child:Destroy() end
        spinnerSystem.petCards = {}
        spinnerSystem.cardScales = {}
        spinnerSystem.rewardBoxes = {}
        spinnerSystem.persistentHL = -1
        spinnerSystem.PETS = spinnerSystem.resolvePetsForTier(tierName)
        spinnerSystem.STRIP_REPEATS = math.clamp(math.floor(300 / math.max(#spinnerSystem.PETS, 1)), 4, 30)
        spinnerSystem.SPIN_SETS = math.clamp(math.floor(spinnerSystem.STRIP_REPEATS / 4), 2, 8)
        spinnerSystem.STRIP_PETS = {}
        for _ = 1, spinnerSystem.STRIP_REPEATS do
            for _, pet in ipairs(spinnerSystem.PETS) do table.insert(spinnerSystem.STRIP_PETS, pet) end
        end
        spinnerSystem.Strip.Size = UDim2.new(0, #spinnerSystem.STRIP_PETS * spinnerSystem.CELL_WIDTH, 1, 0)
        spinnerSystem.Strip.Position = UDim2.new(0, 0, 0.5, 0)
        for i, pet in ipairs(spinnerSystem.STRIP_PETS) do
            local shadowFrame = Instance.new("Frame")
            shadowFrame.Name = "Shadow_" .. i
            shadowFrame.Size = UDim2.new(0, spinnerSystem.CARD_SIZE + 4, 0, spinnerSystem.CARD_SIZE + 4)
            shadowFrame.Position = UDim2.new(0, (i - 1) * spinnerSystem.CELL_WIDTH + spinnerSystem.CARD_SIZE / 2, 0.5, 2)
            shadowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            shadowFrame.BackgroundColor3 = spinnerSystem.THEME.cardShadow
            shadowFrame.BackgroundTransparency = 0.82
            shadowFrame.BorderSizePixel = 0
            shadowFrame.ZIndex = 0
            shadowFrame.Parent = spinnerSystem.Strip
            Instance.new("UICorner", shadowFrame).CornerRadius = UDim.new(0, 12)
            local card = Instance.new("Frame")
            card.Name = "Card_" .. i
            card.Size = UDim2.new(0, spinnerSystem.CARD_SIZE, 0, spinnerSystem.CARD_SIZE)
            card.Position = UDim2.new(0, (i - 1) * spinnerSystem.CELL_WIDTH, 0.5, 0)
            card.AnchorPoint = Vector2.new(0, 0.5)
            card.BackgroundColor3 = spinnerSystem.THEME.cardDefaultBG
            card.BorderSizePixel = 0
            card.ZIndex = 1
            card:SetAttribute("CardIndex", i)
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
            local uiScale = Instance.new("UIScale")
            uiScale.Scale = 1
            uiScale.Parent = card
            spinnerSystem.cardScales[i] = uiScale
            local stroke = Instance.new("UIStroke")
            stroke.Name = "Stroke"
            stroke.Color = spinnerSystem.THEME.cardDefaultStroke
            stroke.Thickness = 2
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            stroke.Parent = card
            local innerBorder = Instance.new("Frame")
            innerBorder.Name = "InnerBorder"
            innerBorder.Size = UDim2.new(1, -4, 1, -4)
            innerBorder.Position = UDim2.new(0.5, 0, 0.5, 0)
            innerBorder.AnchorPoint = Vector2.new(0.5, 0.5)
            innerBorder.BackgroundTransparency = 1
            innerBorder.Parent = card
            Instance.new("UICorner", innerBorder).CornerRadius = UDim.new(0, 8)
            local innerStroke = Instance.new("UIStroke")
            innerStroke.Name = "InnerStroke"
            innerStroke.Color = spinnerSystem.THEME.innerStroke
            innerStroke.Thickness = 1
            innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            innerStroke.Parent = innerBorder
            local content = Instance.new("Frame")
            content.Name = "Content"
            content.Size = UDim2.new(1, -8, 1, -8)
            content.Position = UDim2.new(0.5, 0, 0.5, 0)
            content.AnchorPoint = Vector2.new(0.5, 0.5)
            content.BackgroundTransparency = 1
            content.Parent = card
            local rewardBox = Instance.new("Frame")
            rewardBox.Name = "RewardBox"
            rewardBox.Size = UDim2.new(0.55, 0, 0.11, 0)
            rewardBox.Position = UDim2.new(0.5, 0, 0, 0)
            rewardBox.AnchorPoint = Vector2.new(0.5, 0)
            rewardBox.BackgroundColor3 = spinnerSystem.THEME.rewardBoxDefault
            rewardBox.BorderSizePixel = 0
            rewardBox.ZIndex = 5
            rewardBox.Parent = content
            Instance.new("UICorner", rewardBox).CornerRadius = UDim.new(0, 6)
            local rwStroke = Instance.new("UIStroke")
            rwStroke.Color = Color3.fromRGB(160, 40, 40)
            rwStroke.Thickness = 1.5
            rwStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            rwStroke.Parent = rewardBox
            local rwText = Instance.new("TextLabel")
            rwText.Size = UDim2.new(1, 0, 1, 0)
            rwText.BackgroundTransparency = 1
            rwText.Font = Enum.Font.GothamBold
            rwText.TextScaled = true
            rwText.TextColor3 = spinnerSystem.THEME.rewardTextDefault
            rwText.Text = "REWARD"
            rwText.ZIndex = 6
            rwText.Parent = rewardBox
            spinnerSystem.rewardBoxes[i] = rewardBox
            local img = spinnerSystem.ItemImageTemplate:Clone()
            img.Image = pet.image or ""
            img.Size = UDim2.new(1, 0, 0.52, 0)
            img.Position = UDim2.new(0.5, 0, 0.12, 0)
            img.AnchorPoint = Vector2.new(0.5, 0)
            img.ScaleType = Enum.ScaleType.Fit
            img.BackgroundTransparency = 1
            img.ZIndex = 1
            img.Parent = content
            local tagHolder = Instance.new("Frame")
            tagHolder.Name = "TagHolder"
            tagHolder.Size = UDim2.new(1, 0, 0.18, 0)
            tagHolder.Position = UDim2.new(0.5, 0, 0.65, 0)
            tagHolder.AnchorPoint = Vector2.new(0.5, 0)
            tagHolder.BackgroundTransparency = 1
            tagHolder.ZIndex = 1
            tagHolder.Parent = content
            pcall(function()
                UIManager.wrap(tagHolder, "ItemDataTagDisplay"):start({
                    item_data = pet.item_data, wearing = false, fixed_property_size = spinnerSystem.MFR_PIP_SIZE,
                })
            end)
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "PetName"
            nameLabel.Text = pet.name
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextScaled = true
            nameLabel.TextColor3 = spinnerSystem.THEME.petNameText
            nameLabel.Size = UDim2.new(1, 0, 0.16, 0)
            nameLabel.Position = UDim2.new(0.5, 0, 1, 0)
            nameLabel.AnchorPoint = Vector2.new(0.5, 1)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.ZIndex = 1
            nameLabel.Parent = content
            card.Parent = spinnerSystem.Strip
            spinnerSystem.petCards[i] = card
        end
    end

    spinnerSystem.updateCardScales = function()
        local center = spinnerSystem.daysList.AbsolutePosition.X + spinnerSystem.vpW / 2
        for idx, card in ipairs(spinnerSystem.petCards) do
            local cardCenter = card.AbsolutePosition.X + spinnerSystem.CARD_SIZE / 2
            local dist = math.abs(cardCenter - center)
            local t = math.clamp(dist / (spinnerSystem.vpW / 2), 0, 1)
            local sc = spinnerSystem.cardScales[idx]
            if sc then sc.Scale = 1.12 - t * 0.24 end
        end
    end

    RunService.Heartbeat:Connect(function()
        spinnerSystem.updateCardScales()
        local vc = spinnerSystem.vpW / 2
        local center = spinnerSystem.daysList.AbsolutePosition.X + vc
        for idx, card in ipairs(spinnerSystem.petCards) do
            local cc = card.AbsolutePosition.X + spinnerSystem.CARD_SIZE / 2
            if math.abs(cc - center) < spinnerSystem.CARD_SIZE / 2 then
                if idx ~= spinnerSystem.persistentHL then
                    if spinnerSystem.persistentHL > 0 and spinnerSystem.petCards[spinnerSystem.persistentHL] then
                        spinnerSystem.resetCard(spinnerSystem.petCards[spinnerSystem.persistentHL])
                    end
                    spinnerSystem.highlightCard(card)
                    spinnerSystem.persistentHL = idx
                end
                break
            end
        end
    end)

    spinnerSystem.doSpin = function()
        if spinnerSystem.spinning then return end
        spinnerSystem.spinning = true
        spinnerSystem.spinCount = spinnerSystem.spinCount + 1
        spinnerSystem.spinBtn:set_state("inactive")
        spinnerSystem.spinBtn:set_text("SPINNING...")
        spinnerSystem.hideWinPopup()
        TweenService:Create(spinnerSystem.claimBtnInst, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = spinnerSystem.originalBtnSize - UDim2.new(0.03, 0, 0, 2)
        }):Play()
        for _, card in ipairs(spinnerSystem.petCards) do spinnerSystem.resetCard(card) end
        spinnerSystem.persistentHL = -1
        local winIndex = math.random(1, #spinnerSystem.PETS)
        local vc = spinnerSystem.vpW / 2
        local curX = spinnerSystem.Strip.Position.X.Offset
        local halfStrip = (#spinnerSystem.STRIP_PETS / 2) * spinnerSystem.CELL_WIDTH
        if -curX > halfStrip then
            local jumpBack = math.floor(spinnerSystem.STRIP_REPEATS / 2) * #spinnerSystem.PETS * spinnerSystem.CELL_WIDTH
            spinnerSystem.Strip.Position = UDim2.new(0, curX + jumpBack, 0.5, 0)
            curX = spinnerSystem.Strip.Position.X.Offset
        end
        local currentCenter = math.clamp(math.floor((-curX + vc) / spinnerSystem.CELL_WIDTH) + 1, 1, #spinnerSystem.STRIP_PETS)
        local targetIdx = math.clamp(currentCenter + ((spinnerSystem.SPIN_SETS or 3) * #spinnerSystem.PETS) + (winIndex - 1), 1, #spinnerSystem.STRIP_PETS)
        local targetX = -((targetIdx - 1) * spinnerSystem.CELL_WIDTH) + vc - (spinnerSystem.CARD_SIZE / 2)
        local spinTween = TweenService:Create(spinnerSystem.Strip, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
            Position = UDim2.new(0, targetX, 0.5, 0)
        })
        spinTween:Play()
        spinTween.Completed:Connect(function()
            local winCard = spinnerSystem.petCards[targetIdx]
            local winPet = spinnerSystem.STRIP_PETS[targetIdx]
            if winCard then
                local s = winCard:FindFirstChild("Stroke")
                for _ = 1, 3 do
                    if s then spinnerSystem.animateStroke(s, spinnerSystem.THEME.cardWinFlashStroke, 3.5) end
                    TweenService:Create(winCard, TweenInfo.new(0.08), { BackgroundColor3 = spinnerSystem.THEME.cardWinFlashBG }):Play()
                    task.wait(0.12)
                    spinnerSystem.highlightCard(winCard)
                    task.wait(0.12)
                end
            end
            pcall(function() if spinnerSystem.SoundPlayer then spinnerSystem.SoundPlayer.FX:play("GoldSparklePrize") end end)
            task.wait(0.3)
            spinnerSystem.DailyLoginGui.Enabled = false
            spinnerSystem.MainFrame.Visible = false
            if winPet then spinnerSystem.showWinPopup(winPet) end
            spinnerSystem.spinBtn:set_state("normal")
            spinnerSystem.spinBtn:set_text("SPIN")
            spinnerSystem.spinning = false
        end)
    end

    spinnerSystem.spinBtn:set_mouse_button1_click(spinnerSystem.doSpin)

    spinnerSystem.selectTier = function(tierName)
        spinnerSystem.buildStrip(tierName)
        spinnerSystem.DailyLoginGui.Enabled = true
        spinnerSystem.MainFrame.Visible = true
        spinnerSystem.spinBtn:set_state("normal")
        spinnerSystem.spinBtn:set_text("SPIN")
    end

    spinnerSystem.showTierPopup = function()
        task.spawn(function()
            local response = DialogApp:dialog({
                text = "Which tier would you like to spin?",
                left = "High Tier",
                right = "Mid Tier",
            })
            if response == "High Tier" then
                spinnerSystem.selectTier("HIGH")
            elseif response == "Mid Tier" then
                spinnerSystem.selectTier("MID")
            end
        end)
    end

    spinnerSystem.showWheel = function()
        spinnerSystem.showTierPopup()
    end

    print("[SpinnerSystem] Ready — use 🎰 SPIN THE WHEEL in the control panel or enable 'Spin on +'")
end
initSpinnerSystem()
-- ==================== END SPIN THE WHEEL SYSTEM ====================

print("m0_3a on discord made this script, for any other inquires please message me on discord.")
