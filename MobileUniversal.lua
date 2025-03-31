-- SIMPLE AND BASIC SOURCE --
local repo = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local Options = Library.Options

Library.ForceCheckbox = false
Library.ShowToggleFrameInKeybinds = true 

-- Create the main UI
local Window = Library:CreateWindow({
    Title = "Mounx",
    Footer = "..",
    NotifySide = "Right",
    ShowCustomCursor = true,
})

local MainTab = Window:AddTab("Main", "user")
local SettingsTab = Window:AddTab("Config", "settings")

local HitboxGroup = MainTab:AddLeftGroupbox("Hitbox ")
local AimbotGroup = MainTab:AddRightGroupbox("Aimbot")
local MiscGroup = MainTab:AddLeftGroupbox("Visuals")
local ChecksGroup = MainTab:AddRightGroupbox("Checks")

-- SERVICES
local Players = game:GetService("Players")  
local Camera = workspace.CurrentCamera 
local RunService = game:GetService("RunService") 
local LocalPlayer = Players.LocalPlayer 
local CurrentCamera = game:GetService("Workspace").CurrentCamera

-- VARIABLES
local hitboxActive = false
local hitboxTransparency = 0.5 
local activeHeadSize = Vector3.new(4, 4, 4) 
local originalHeadSizes = {}
local WallhackEnabled = false
local AimbotEnabled = false
local TargetPart = "Head"
local CurrentTarget = nil
local FOVSize = 100
local FOVVisible = false
local FOVColor = Color3.new(1, 1, 1) 
local DrawingFOV = Drawing.new("Circle")
local Chams = {}
local ChamsActive = false
local chamsColor = Color3.fromRGB(255, 105, 180)
local chamsTransparency = 0.7
local ESPBoxes = {}
local ESPEnabled = false
local TeamCheckEnabled = false

-- VALIDACIONES 
local function isValidTarget(player, character)
    if not player or not character then
        return false
    end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end
    
    if TeamCheckEnabled then
        if player.Team and LocalPlayer.Team then
            return player.Team ~= LocalPlayer.Team
        else
            return false
        end
    end
    
    return true
end

local function isVisible(position, character)
    if not WallhackEnabled then
        return true
    end
    
    local excludeParts = {workspace.CurrentCamera, character}
    for _, player in pairs(Players:GetPlayers()) do
        if player.Character then
            table.insert(excludeParts, player.Character)
            local head = player.Character:FindFirstChild("Head")
            if head then
                table.insert(excludeParts, head)
            end
        end
    end
    
    return #workspace.CurrentCamera:GetPartsObscuringTarget({position}, excludeParts) == 0
end

local function updateAimbot()
    if AimbotEnabled then
        local closestPlayer = nil
        local shortestDistance = math.huge
        local screenCenter = Vector2.new(CurrentCamera.ViewportSize.X / 2, CurrentCamera.ViewportSize.Y / 2)

        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild(TargetPart) then
                local targetPart = player.Character:FindFirstChild(TargetPart)

                if isValidTarget(player, player.Character) then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local distanceFromCenter = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        local distance = (Camera.CFrame.Position - targetPart.Position).Magnitude

                        if distanceFromCenter <= FOVSize then
                            if WallhackEnabled and not isVisible(targetPart.Position, player.Character) then
                                continue
                            end
                            
                            if distance < shortestDistance then
                                closestPlayer = targetPart
                                shortestDistance = distance
                            end
                        end
                    end
                end
            end
        end
        
        if closestPlayer then
            CurrentTarget = closestPlayer
            local aimPosition = closestPlayer.Position
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, aimPosition)
        else
            CurrentTarget = nil
        end
    else
        CurrentTarget = nil
    end
end

RunService.RenderStepped:Connect(updateAimbot)

-- BOX
local function createBox(player)
    local Box = {
        Frame = Drawing.new("Square"),         
        Background = Drawing.new("Square"),
        Shadow = Drawing.new("Square")        
    }

    Box.Background.Transparency = 0.2 
    Box.Background.Color = Color3.fromRGB(0, 0, 0) 
    Box.Background.Filled = true 
    Box.Background.Thickness = 0 

    Box.Frame.Thickness = 0.8
    Box.Frame.Color = Color3.fromRGB(255, 255, 255) 
    Box.Frame.Filled = false 

    Box.Shadow.Transparency = 1
    Box.Shadow.Color = Color3.fromRGB(0, 0, 0) 
    Box.Shadow.Filled = true
    Box.Shadow.Thickness = 0

    ESPBoxes[player] = Box
end

local function updateBox(player)
    if not player or player == LocalPlayer or not player.Character then
        return
    end

    local Box = ESPBoxes[player]
    if not Box then return end

    local character = player.Character
    if character:FindFirstChild("HumanoidRootPart") then
        local rootPart = character.HumanoidRootPart
        local localRootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        
        if not localRootPart then return end

        if not isValidTarget(player, character) then
            Box.Background.Visible = false
            Box.Frame.Visible = false
            return
        end

        local Vector, OnScreen = Camera:WorldToViewportPoint(rootPart.Position)
        local distance = (rootPart.Position - Camera.CFrame.Position).Magnitude 

        if OnScreen then
            local baseSizeX, baseSizeY = 40, 60
            local scaleFactor = math.clamp(1 / (distance / 30), 0.1, 2.8) 

            local sizeX, sizeY = baseSizeX * scaleFactor, baseSizeY * scaleFactor
            local posX, posY = Vector.X - sizeX / 2, Vector.Y - sizeY / 2.3

            posX = posX + 41  

            Box.Background.Size = Vector2.new(sizeX, sizeY)
            Box.Background.Position = Vector2.new(posX, posY)
            Box.Background.Visible = true

            Box.Frame.Size = Vector2.new(sizeX, sizeY)
            Box.Frame.Position = Vector2.new(posX, posY)
            Box.Frame.Visible = true
        else
            Box.Background.Visible = false
            Box.Frame.Visible = false
        end
    else
        Box.Background.Visible = false
        Box.Frame.Visible = false
    end
end

local function removeBox(player)
    local Box = ESPBoxes[player]
    if Box then
        for _, element in pairs(Box) do
            element:Remove()
        end
        ESPBoxes[player] = nil
    end
end

-- CHAMS
local function createChams(player)
    local character = player and player.Character or nil
    if not character or not character:FindFirstChild("HumanoidRootPart") then
        return
    end

    if not isValidTarget(player, character) then
        return 
    end

    if not Chams[player or character] then
        local highlight = Instance.new("Highlight")
        highlight.Adornee = character 
        highlight.Parent = game.CoreGui 
        highlight.FillColor = chamsColor 
        highlight.FillTransparency = chamsTransparency 
        highlight.OutlineColor = Color3.fromRGB(0, 0, 0) 
        highlight.OutlineTransparency = 0 

        Chams[player or character] = highlight
    else
        Chams[player or character].Adornee = character
        Chams[player or character].Enabled = true 
    end
end

local function updateChams(player)
    local highlight = Chams[player]
    local character = player.Character

    if character and character:FindFirstChild("HumanoidRootPart") and isValidTarget(player, character) then
        if not highlight then
            createChams(player)
        else
            highlight.Adornee = character 
        end
    else
        if highlight then
            highlight:Destroy()
            Chams[player] = nil
        end
    end
end

local function removeChams(player)
    local highlight = Chams[player or (player and player.Character)]
    if highlight then
        highlight:Destroy()
        Chams[player or (player and player.Character)] = nil
    end
end

-- FOV
RunService.RenderStepped:Connect(function()
    if FOVVisible then

        DrawingFOV.Visible = true
        DrawingFOV.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
        DrawingFOV.Radius = FOVSize
        DrawingFOV.Color = FOVColor
        DrawingFOV.Filled = false  
        DrawingFOV.Thickness = 0.9  
    else
        DrawingFOV.Visible = false
    end
end)

local function updateHitboxesForAllCharacters()
    for _, player in pairs(game.Players:GetPlayers()) do

        if player ~= game.Players.LocalPlayer and player.Character then
            local character = player.Character
            local head = character:FindFirstChild("Head")

            if head then
         
                if hitboxActive and isValidTarget(player, character) then
            
                    if not originalHeadSizes[head] then
                        originalHeadSizes[head] = head.Size 
                    end
                    head.Size = activeHeadSize
                    head.Transparency = hitboxTransparency
                elseif originalHeadSizes[head] then

                    head.Size = originalHeadSizes[head]
                    head.Transparency = 0  
                    originalHeadSizes[head] = nil
                end
            end
        end
    end
end
game:GetService("RunService").Heartbeat:Connect(updateHitboxesForAllCharacters)

AimbotGroup:AddToggle("Aimbot", {
    Text = "Aimbot",
    Default = false,
    Callback = function(state)
        AimbotEnabled = state
        if not state then
            CurrentTarget = nil
        end
    end
})

AimbotGroup:AddToggle("FOV", {
    Text = "FOV Circle",
    Default = false,
    Callback = function(state)
        FOVVisible = state
    end
})

AimbotGroup:AddSlider("FOVSize", {
    Text = "FOV Size",
    Default = 100,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value)
        FOVSize = value
    end
})

HitboxGroup:AddToggle("Hitbox", {
    Text = "Hitbox",
    Default = false,
    Callback = function(state)
        hitboxActive = state
    end
})

HitboxGroup:AddSlider("HitboxSize", {
    Text = "Hitbox Size",
    Default = 4,
    Min = 1,
    Max = 10,
    Rounding = 0,
    Callback = function(value)
        activeHeadSize = Vector3.new(value, value, value)
    end
})

HitboxGroup:AddSlider("HitboxTransparency", {
    Text = "Hitbox Transparency",
    Default = 0.5,
    Min = 0,
    Max = 1,
    Rounding = 1,
    Callback = function(value)
        hitboxTransparency = value
    end
})

MiscGroup:AddToggle("Boxes", {
    Text = "Boxes",
    Default = false,
    Callback = function(state)
        ESPEnabled = state
        if not state then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    removeBox(player)
                end
            end
        else
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    createBox(player)
                end
            end
        end
    end
})

MiscGroup:AddToggle("Chams", {
    Text = "Chams",
    Default = false,
    Callback = function(state)
        ChamsActive = state
        if not state then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer then
                    removeChams(player)
                end
            end
        end
    end
})

ChecksGroup:AddToggle("Wallhack", {
    Text = "Wallhack",
    Default = false,
    Callback = function(state)
        WallhackEnabled = state
    end
})

ChecksGroup:AddToggle("TeamCheck", {
    Text = "TeamCheck",
    Default = false,
    Callback = function(state)
        TeamCheckEnabled = state
    end
})

Players.PlayerAdded:Connect(function(player)
    if ESPEnabled then createBox(player) end
    if ChamsActive then createChams(player) end
end)

Players.PlayerRemoving:Connect(function(player)
    removeBox(player)
    removeChams(player)
end)

RunService.RenderStepped:Connect(function()
    if ESPEnabled then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                updateBox(player)
            end
        end
    end

    if ChamsActive then
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                updateChams(player)
            end
        end
    end
end)

local MenuGroup = SettingsTab:AddLeftGroupbox("Menu")

MenuGroup:AddToggle("KeybindMenuOpen", {
	Default = Library.KeybindFrame.Visible,
	Text = "Open Keybind Menu",
	Callback = function(value)
		Library.KeybindFrame.Visible = value
	end,
})
MenuGroup:AddToggle("ShowCustomCursor", {
	Text = "Custom Cursor",
	Default = true,
	Callback = function(Value)
		Library.ShowCustomCursor = Value
	end,
})
MenuGroup:AddDropdown("NotificationSide", {
	Values = { "Left", "Right" },
	Default = "Right",
	Text = "Notification Side",
	Callback = function(Value)
		Library:SetNotifySide(Value)
	end,
})
MenuGroup:AddDropdown("DPIDropdown", {
	Values = { "50%", "75%", "100%", "125%", "150%", "175%", "200%" },
	Default = "100%",
	Text = "DPI Scale",
	Callback = function(Value)
		Value = Value:gsub("%%", "")
		local DPI = tonumber(Value)
		Library:SetDPIScale(DPI)
	end,
})

MenuGroup:AddDivider()
MenuGroup:AddLabel("Menu bind")
	:AddKeyPicker("MenuKeybind", { Default = "Delete", NoUI = true, Text = "Menu keybind" })

    local function UnloadScript()

        hitboxActive = false
        AimbotEnabled = false
        FOVVisible = false
        ESPEnabled = false
        ChamsActive = false
        
        for _, player in pairs(Players:GetPlayers()) do
            removeChams(player)
        end
        Chams = {}
    
        for _, Box in pairs(ESPBoxes) do
            if Box then
                for _, line in pairs(Box) do
                    if line.Remove then
                        line:Remove()
                    end
                end
            end
        end
        ESPBoxes = {}
    
        DrawingFOV.Visible = false

        Library:Notify("Script Unloaded Successfully", 3)
        task.wait(0.5)
        Library:Unload()
    end
    
    MenuGroup:AddButton("Unload", function()
        UnloadScript()
    end)
    
Library.ToggleKeybind = Options.MenuKeybind 

Options.MenuKeybind:OnChanged(function()
    Library:Notify('Menu toggle key changed to [' .. Options.MenuKeybind.Value .. ']')
end)

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)

SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)

SaveManager:LoadAutoloadConfig()
Library:Notify("Script Loaded Successfully", 5)
