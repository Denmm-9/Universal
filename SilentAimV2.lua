-- init
if not game:IsLoaded() then 
    game.Loaded:Wait()
end

pcall(function()
    if syn and protectgui then
        protectgui(Library)
    elseif gethui then
        Library.Parent = gethui()
    else
        Library.Parent = game:GetService("CoreGui")
    end
end)

local SilentAimSettings = {
    Enabled = false,
    
    ClassName = "Universal Silent Aim",
    ToggleKey = "RightAlt",
    
    TeamCheck = false,
    VisibleCheck = false, 
    TargetPart = "Head",
    SilentAimMethod = "Raycast",
    
    FOVRadius = 130,
    FOVVisible = false,
    ShowSilentAimTarget = true, 
    
    MouseHitPrediction = false,
    MouseHitPredictionAmount = 0.165,
    HitChance = 100,
    HighlightEnabled = false,
    HeadDotEnabled = false
}

-- variables
getgenv().SilentAimSettings = SilentAimSettings

local MainFileName = "UniversalSilentAim"
local SelectedFile, FileToSave = "", ""


local CurrentTarget = nil
local CurrentTargetPlayer = nil

local Camera = workspace.CurrentCamera
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local GetChildren = game.GetChildren
local GetPlayers = Players.GetPlayers
local WorldToScreen = Camera.WorldToScreenPoint
local WorldToViewportPoint = Camera.WorldToViewportPoint
local GetPartsObscuringTarget = Camera.GetPartsObscuringTarget
local FindFirstChild = game.FindFirstChild
local RenderStepped = RunService.RenderStepped
local GuiInset = GuiService.GetGuiInset
local GetMouseLocation = UserInputService.GetMouseLocation

local resume = coroutine.resume 
local create = coroutine.create

local ValidTargetParts = {"Head", "LeftHand", "RightHand", "LeftFoot", "RightFoot", "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg"}


local PredictionAmount = 0.165

local mouse_box = Drawing.new("Circle") 
mouse_box.Visible = true 
mouse_box.ZIndex = 999 
mouse_box.Color = Color3.fromRGB(255, 0, 0)
mouse_box.Thickness = 2 
mouse_box.Radius = 15 
mouse_box.Filled = false 

local fov_circle = Drawing.new("Circle")
fov_circle.Thickness = 1
fov_circle.NumSides = 100
fov_circle.Radius = 180
fov_circle.Filled = false
fov_circle.Visible = false
fov_circle.ZIndex = 999
fov_circle.Transparency = 1
fov_circle.Color = Color3.fromRGB(54, 57, 241)

local ExpectedArguments = {
    FindPartOnRayWithIgnoreList = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean", "boolean"
        }
    },
    FindPartOnRayWithWhitelist = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Ray", "table", "boolean"
        }
    },
    FindPartOnRay = {
        ArgCountRequired = 2,
        Args = {
            "Instance", "Ray", "Instance", "boolean", "boolean"
        }
    },
    Raycast = {
        ArgCountRequired = 3,
        Args = {
            "Instance", "Vector3", "Vector3", "RaycastParams"
        }
    }
}

function CalculateChance(Percentage)
    -- // Floor the percentage
    Percentage = math.floor(Percentage)

    -- // Get the chance
    local chance = math.floor(Random.new().NextNumber(Random.new(), 0, 1) * 100) / 100

    -- // Return
    return chance <= Percentage / 100
end

--[[file handling]] do 
    if not isfolder(MainFileName) then 
        makefolder(MainFileName);
    end
    
    if not isfolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId))) then 
        makefolder(string.format("%s/%s", MainFileName, tostring(game.PlaceId)))
    end
end

local Files = listfiles(string.format("%s/%s", "UniversalSilentAim", tostring(game.PlaceId)))

-- functions
local function GetFiles() 
	local out = {}
	for i = 1, #Files do
		local file = Files[i]
		if file:sub(-4) == '.lua' then

			local pos = file:find('.lua', 1, true)
			local start = pos

			local char = file:sub(pos, pos)
			while char ~= '/' and char ~= '\\' and char ~= '' do
				pos = pos - 1
				char = file:sub(pos, pos)
			end

			if char == '/' or char == '\\' then
				table.insert(out, file:sub(pos + 1, start - 1))
			end
		end
	end
	
	return out
end

local function UpdateFile(FileName)
    assert(FileName or FileName == "string", "oopsies");
    writefile(string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName), HttpService:JSONEncode(SilentAimSettings))
end

local function LoadFile(FileName)
    assert(FileName or FileName == "string", "oopsies");
    
    local File = string.format("%s/%s/%s.lua", MainFileName, tostring(game.PlaceId), FileName)
    local ConfigData = HttpService:JSONDecode(readfile(File))
    for Index, Value in next, ConfigData do
        SilentAimSettings[Index] = Value
    end
end

local function getPositionOnScreen(Vector)
    local Vec3, OnScreen = WorldToScreen(Camera, Vector)
    return Vector2.new(Vec3.X, Vec3.Y), OnScreen
end

local function ValidateArguments(Args, RayMethod)
    local Matches = 0
    if #Args < RayMethod.ArgCountRequired then
        return false
    end
    for Pos, Argument in next, Args do
        if typeof(Argument) == RayMethod.Args[Pos] then
            Matches = Matches + 1
        end
    end
    return Matches >= RayMethod.ArgCountRequired
end

local function getDirection(Origin, Position)
    return (Position - Origin).Unit * 1000
end

local function getMousePosition()
    return GetMouseLocation(UserInputService)
end

local function IsPlayerVisible(Player)
    local PlayerCharacter = Player.Character
    local LocalPlayerCharacter = LocalPlayer.Character
    
    if not (PlayerCharacter or LocalPlayerCharacter) then return end 
    
    local PlayerRoot = FindFirstChild(PlayerCharacter, Options.TargetPart.Value) or FindFirstChild(PlayerCharacter, "HumanoidRootPart")
    
    if not PlayerRoot then return end 
    
    local CastPoints, IgnoreList = {PlayerRoot.Position, LocalPlayerCharacter, PlayerCharacter}, {LocalPlayerCharacter, PlayerCharacter}
    local ObscuringObjects = #GetPartsObscuringTarget(Camera, CastPoints, IgnoreList)
    
    return ((ObscuringObjects == 0 and true) or (ObscuringObjects > 0 and false))
end

local function GetClosestPointOnPartToMouse(part, mousePos)
    local size = part.Size / 2
    local cf = part.CFrame

    -- Menor factor para no irse tanto a las esquinas
    local cornerOffsetFactor = 0.4

    -- Lista de offsets: esquinas, centro y puntos intermedios
    local offsets = {
        Vector3.new( 0, 0, 0), -- centro
        Vector3.new( size.X * cornerOffsetFactor, 0, 0),
        Vector3.new(-size.X * cornerOffsetFactor, 0, 0),
        Vector3.new(0, size.Y * cornerOffsetFactor, 0),
        Vector3.new(0, -size.Y * cornerOffsetFactor, 0),
        Vector3.new(0, 0, size.Z * cornerOffsetFactor),
        Vector3.new(0, 0, -size.Z * cornerOffsetFactor),
        Vector3.new( size.X * cornerOffsetFactor,  size.Y * cornerOffsetFactor,  size.Z * cornerOffsetFactor),
        Vector3.new(-size.X * cornerOffsetFactor, -size.Y * cornerOffsetFactor, -size.Z * cornerOffsetFactor),
        -- Puedes agregar más puntos intermedios aquí si quieres más precisión
    }

    local closestPoint = nil
    local closestDist = math.huge

    for _, offset in ipairs(offsets) do
        local worldPoint = (cf * CFrame.new(offset)).p

        local screenPoint, onScreen = getPositionOnScreen(worldPoint)
        if onScreen then
            local dist = (mousePos - screenPoint).Magnitude
            if dist < closestDist then
                closestDist = dist
                closestPoint = worldPoint
            end
        end
    end

    return closestPoint or part.Position
end


local function getClosestPlayer()
    if not Options.TargetPart.Value then return end

    local ClosestPart = nil
    local ClosestPoint = nil
    local DistanceToMouse = nil

    local mousePos = getMousePosition() 
    local maxRadius = Options.Radius.Value or 2000

    for _, Player in next, GetPlayers(Players) do
        if Player == LocalPlayer then continue end
        if Toggles.TeamCheck.Value and Player.Team == LocalPlayer.Team then continue end

        local Character = Player.Character
        if not Character then continue end
        
        if Toggles.VisibleCheck.Value and not IsPlayerVisible(Player) then continue end

        local HumanoidRootPart = FindFirstChild(Character, "HumanoidRootPart")
        local Humanoid = FindFirstChild(Character, "Humanoid")
        if not HumanoidRootPart or not Humanoid or (Humanoid and Humanoid.Health <= 0) then continue end

        local partsToCheck = {}

        if Options.TargetPart.Value == "ClosestToMouse" then
            for _, partName in ipairs(ValidTargetParts) do
                local part = FindFirstChild(Character, partName)
                if part then
                    table.insert(partsToCheck, part)
                end
            end
        else
            local part = (Options.TargetPart.Value == "Random" and Character[ValidTargetParts[math.random(1, #ValidTargetParts)]]) or Character[Options.TargetPart.Value]
            if part then
                table.insert(partsToCheck, part)
            end
        end

        for _, part in ipairs(partsToCheck) do
            local targetPoint

            if Options.TargetPart.Value == "ClosestToMouse" then
                targetPoint = GetClosestPointOnPartToMouse(part, mousePos)
            else
                targetPoint = part.Position
            end

            local ScreenPosition, OnScreen = getPositionOnScreen(targetPoint)
            if not OnScreen then continue end

            local Distance = (mousePos - ScreenPosition).Magnitude
            if Distance <= maxRadius and (DistanceToMouse == nil or Distance < DistanceToMouse) then
                ClosestPart = part
                ClosestPoint = targetPoint
                DistanceToMouse = Distance
            end
        end
    end

    return ClosestPart, ClosestPoint
end

local VirtualInputManager = game:GetService("VirtualInputManager")
local LastClick = 0
local ClickDelay = 0.10

RunService.RenderStepped:Connect(function()
    if not (Toggles.AutoShoot and Toggles.AutoShoot.Value) or not (Toggles.aim_Enabled and Toggles.aim_Enabled.Value) then return end

    local targetPart = getClosestPlayer()
    if targetPart then
        local targetPlayer = Players:GetPlayerFromCharacter(targetPart.Parent)
        
        if IsPlayerVisible(targetPlayer) then
            if tick() - LastClick >= ClickDelay then
                local mousePos = UserInputService:GetMouseLocation()
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, true, game, 0)
                VirtualInputManager:SendMouseButtonEvent(mousePos.X, mousePos.Y, 0, false, game, 0)
                LastClick = tick()
            end
        end
    end
end)


local Highlight = Instance.new("Highlight")
Highlight.FillColor = Color3.fromRGB(255, 0, 255) 
Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
Highlight.FillTransparency = 0.7
Highlight.OutlineTransparency = 0
Highlight.Parent = game.CoreGui 
Highlight.Enabled = false 

local cachedHeadDots = {}

local function applyHeadDot(character)
    if not character or not SilentAimSettings.HeadDotEnabled then return end

    local head = character:FindFirstChild("Head")
    local humanoid = character:FindFirstChild("Humanoid")

    if not head or not humanoid or humanoid.Health <= 0 then 

        if cachedHeadDots[character] then
            cachedHeadDots[character]:Destroy()
            cachedHeadDots[character] = nil
        end
        return 
    end

    if character == LocalPlayer.Character or head:FindFirstChild("HeadDot") then return end

    if not cachedHeadDots[character] then
        local headDot = Instance.new("BillboardGui")
        headDot.Name = "HeadDot"
        headDot.Size = UDim2.new(0, 6, 0, 6)
        headDot.StudsOffset = Vector3.new(0, 0.7, 0)
        headDot.AlwaysOnTop = true
        headDot.Adornee = head

        local dot = Instance.new("Frame")
        dot.Size = UDim2.new(1, 0, 1, 0)
        
        if Player and Player.Team then
            dot.BackgroundColor3 = Player.Team.TeamColor.Color
        else
            dot.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
        end
        
        dot.BackgroundTransparency = 0.4
        dot.BorderSizePixel = 0

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0)
        corner.Parent = dot

        dot.Parent = headDot
        headDot.Parent = head
        cachedHeadDots[character] = headDot

        humanoid.Died:Connect(function()
            if cachedHeadDots[character] then
                cachedHeadDots[character]:Destroy()
                cachedHeadDots[character] = nil
            end
        end)

        humanoid.HealthChanged:Connect(function(health)
            if health <= 0 and cachedHeadDots[character] then
                cachedHeadDots[character]:Destroy()
                cachedHeadDots[character] = nil
            end
        end)
    end
end

local function clearAllHeadDots()
    for _, dot in pairs(cachedHeadDots) do
        if dot then
            dot:Destroy()
        end
    end
    cachedHeadDots = {} 
end

local function updateAllHeadDots()
    if not SilentAimSettings.HeadDotEnabled then
        clearAllHeadDots()
        return
    end

    for _, character in ipairs(Workspace:GetChildren()) do
        if character:IsA("Model") and character:FindFirstChild("Humanoid") then
            applyHeadDot(character)
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        task.wait(1) 
        applyHeadDot(character)
    end)
end)

local function UpdateHighlight()
    if not SilentAimSettings.HighlightEnabled then
        if Highlight then
            Highlight.Enabled = false
            Highlight.Adornee = nil
        end
        return
    end

    if not Highlight or not Highlight.Parent then
        Highlight = Instance.new("Highlight")
        Highlight.Parent = game.CoreGui  
    end

    local target = getClosestPlayer()  
    if not target or not target.Parent then
        Highlight.Enabled = false
        Highlight.Adornee = nil
        return
    end

    local Character = target.Parent
    local TargetPart = Character:FindFirstChild("Head") or Character:FindFirstChild("HumanoidRootPart") 

    if not TargetPart then
        Highlight.Enabled = false
        Highlight.Adornee = nil
        return
    end

    Highlight.Parent = game.CoreGui 
    Highlight.Adornee = Character
    Highlight.Enabled = true
end

RunService.RenderStepped:Connect(updateAllHeadDots)
RunService.RenderStepped:Connect(UpdateHighlight)

-- ui creating & handling
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua"))()
Library:SetWatermark("Non Uni")

local Window = Library:CreateWindow({Title = 'Universal Silent Aim', Center = true, AutoShow = true, TabPadding = 8, MenuFadeTime = 0.2})

local GeneralTab = Window:AddTab("General")
local MainBOX = GeneralTab:AddLeftTabbox("Main") do
    local Main = MainBOX:AddTab("Main")

    Main:AddToggle("aim_Enabled", {Text = "Enabled"}):AddKeyPicker("aim_Enabled_KeyPicker", {Default = "RightAlt", SyncToggleState = true, Mode = "Toggle", Text = "Enabled", NoUI = false});
    Options.aim_Enabled_KeyPicker:OnClick(function()
        SilentAimSettings.Enabled = not SilentAimSettings.Enabled
        Toggles.aim_Enabled.Value = SilentAimSettings.Enabled
        Toggles.aim_Enabled:SetValue(SilentAimSettings.Enabled)
        mouse_box.Visible = SilentAimSettings.Enabled
    end)

    Main:AddToggle("AutoShoot", {Text = "TriggerbotVisible", Default = SilentAimSettings.AutoShoot or false}):OnChanged(function()
        SilentAimSettings.AutoShoot = Toggles.AutoShoot.Value
    end)

    Main:AddToggle("TeamCheck", {Text = "Team Check", Default = SilentAimSettings.TeamCheck}):OnChanged(function()
        SilentAimSettings.TeamCheck = Toggles.TeamCheck.Value
    end)

    Main:AddToggle("VisibleCheck", {Text = "Visible Check", Default = SilentAimSettings.VisibleCheck}):OnChanged(function()
        SilentAimSettings.VisibleCheck = Toggles.VisibleCheck.Value
    end)

    Main:AddDropdown("TargetPart", {AllowNull = true, Text = "Target Part", Default = SilentAimSettings.TargetPart, Values = {"Head", "HumanoidRootPart", "Random", "ClosestToMouse"}}):OnChanged(function()
        SilentAimSettings.TargetPart = Options.TargetPart.Value
    end)

    Main:AddDropdown("Method", {AllowNull = true, Text = "Silent Aim Method", Default = SilentAimSettings.SilentAimMethod, Values = {
        "Raycast","FindPartOnRay",
        "FindPartOnRayWithWhitelist",
        "FindPartOnRayWithIgnoreList",
        "Mouse.Hit/Target"
    }}):OnChanged(function() 
        SilentAimSettings.SilentAimMethod = Options.Method.Value 
    end)

    Main:AddSlider('HitChance', {
        Text = 'Hit chance',
        Default = 100,
        Min = 0,
        Max = 100,
        Rounding = 1,
        Compact = false,
    })
    Options.HitChance:OnChanged(function()
        SilentAimSettings.HitChance = Options.HitChance.Value
    end)
end

local MiscellaneousBOX = GeneralTab:AddLeftTabbox("Miscellaneous")
local FieldOfViewBOX = GeneralTab:AddLeftTabbox("Field Of View") do
    local Main = FieldOfViewBOX:AddTab("Visuals")

    Main:AddToggle("Visible", {Text = "Show FOV Circle"}):AddColorPicker("Color", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function()
        fov_circle.Visible = Toggles.Visible.Value
        SilentAimSettings.FOVVisible = Toggles.Visible.Value
    end)

    Main:AddSlider("Radius", {Text = "FOV Circle Radius", Min = 0, Max = 360, Default = 200, Rounding = 0}):OnChanged(function()
        fov_circle.Radius = Options.Radius.Value
        SilentAimSettings.FOVRadius = Options.Radius.Value
    end)

    Main:AddToggle("MousePosition", {Text = "Show Silent Aim Target"}):AddColorPicker("MouseVisualizeColor", {Default = Color3.fromRGB(54, 57, 241)}):OnChanged(function()
        mouse_box.Visible = Toggles.MousePosition.Value 
        SilentAimSettings.ShowSilentAimTarget = Toggles.MousePosition.Value 
    end)

    Main:AddToggle("HighlightEnabled", {Text = "Highlight Target", Default = false}):OnChanged(function()
        SilentAimSettings.HighlightEnabled = Toggles.HighlightEnabled.Value
    end)

    Main:AddToggle("HeadDotEnabled", {Text = "Head Dot", Default = false}):OnChanged(function()
        SilentAimSettings.HeadDotEnabled = Toggles.HeadDotEnabled.Value
        if not SilentAimSettings.HeadDotEnabled and cachedHeadDots then  
            for _, dot in pairs(cachedHeadDots) do
                if dot then dot:Destroy() end
            end
            cachedHeadDots = {} 
        end
    end)

    local PredictionTab = MiscellaneousBOX:AddTab("Prediction")
    PredictionTab:AddToggle("Prediction", {Text = "Mouse.Hit/Target Prediction"}):OnChanged(function()
        SilentAimSettings.MouseHitPrediction = Toggles.Prediction.Value
    end)
    PredictionTab:AddSlider("Amount", {Text = "Prediction Amount", Min = 0.165, Max = 1, Default = 0.165, Rounding = 3}):OnChanged(function()
        PredictionAmount = Options.Amount.Value
        SilentAimSettings.MouseHitPredictionAmount = Options.Amount.Value
    end)
end

local SettingsTab = Window:AddTab("Settings")
local ThemeManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/ThemeManager.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/addons/SaveManager.lua"))()
ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
ThemeManager:SetFolder("UniversalSilentAim")
SaveManager:SetFolder("UniversalSilentAim/configs")
SaveManager:IgnoreThemeSettings()
SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)

local UnloadTab = SettingsTab:AddLeftTabbox("Unload") do
    local Tab = UnloadTab:AddTab("Unload Script")
    Tab:AddButton("Unload", function()
        Library:Unload() 
        for i,v in pairs(getconnections or {})() do
            if v.Disconnect then pcall(function() v:Disconnect() end) end
        end
        print("Silent Aim unloaded.")
    end)
end
Library:Notify("Silent Aim UI Loaded", 3)

resume(create(function()
    RenderStepped:Connect(function()
        if Toggles.MousePosition.Value and Toggles.aim_Enabled.Value then
            if getClosestPlayer() then 
                local Root = getClosestPlayer().Parent.PrimaryPart or getClosestPlayer()
                local RootToViewportPoint, IsOnScreen = WorldToViewportPoint(Camera, Root.Position);
                mouse_box.Visible = IsOnScreen
                mouse_box.Position = Vector2.new(RootToViewportPoint.X, RootToViewportPoint.Y)
            else 
                mouse_box.Visible = false 
                mouse_box.Position = Vector2.new()
            end
        end
        if Toggles.Visible.Value then 
            fov_circle.Visible = Toggles.Visible.Value
            fov_circle.Color = Options.Color.Value
            fov_circle.Position = getMousePosition()
        end
    end)
end))

-- hooks
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local Method = getnamecallmethod()
    local Arguments = {...}
    local self = Arguments[1]
    local chance = CalculateChance(SilentAimSettings.HitChance)
    if Toggles.aim_Enabled.Value and self == workspace and not checkcaller() and chance == true then
        if Method == "FindPartOnRayWithIgnoreList" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithIgnoreList) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "FindPartOnRayWithWhitelist" and Options.Method.Value == Method then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRayWithWhitelist) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif (Method == "FindPartOnRay" or Method == "findPartOnRay") and Options.Method.Value:lower() == Method:lower() then
            if ValidateArguments(Arguments, ExpectedArguments.FindPartOnRay) then
                local A_Ray = Arguments[2]

                local HitPart = getClosestPlayer()
                if HitPart then
                    local Origin = A_Ray.Origin
                    local Direction = getDirection(Origin, HitPart.Position)
                    Arguments[2] = Ray.new(Origin, Direction)

                    return oldNamecall(unpack(Arguments))
                end
            end
        elseif Method == "Raycast" and Options.Method.Value == Method then
    if ValidateArguments(Arguments, ExpectedArguments.Raycast) then
        local A_Origin = Arguments[2]

        local HitPart, HitPoint = getClosestPlayer()
        if HitPart and HitPoint then
            Arguments[3] = getDirection(A_Origin, HitPoint) 

            return oldNamecall(unpack(Arguments))
        end
    end
end

    end
    return oldNamecall(...)
end))

local oldIndex = nil 
oldIndex = hookmetamethod(game, "__index", newcclosure(function(self, Index)
    if self == Mouse and not checkcaller() and Toggles.aim_Enabled.Value and Options.Method.Value == "Mouse.Hit/Target" and getClosestPlayer() then
        local HitPart = getClosestPlayer()
         
        if Index == "Target" or Index == "target" then 
            return HitPart
        elseif Index == "Hit" or Index == "hit" then 
            return ((Toggles.Prediction.Value and (HitPart.CFrame + (HitPart.Velocity * PredictionAmount))) or (not Toggles.Prediction.Value and HitPart.CFrame))
        elseif Index == "X" or Index == "x" then 
            return self.X 
        elseif Index == "Y" or Index == "y" then 
            return self.Y 
        elseif Index == "UnitRay" then 
            return Ray.new(self.Origin, (self.Hit - self.Origin).Unit)
        end
    end

    return oldIndex(self, Index)
end))
