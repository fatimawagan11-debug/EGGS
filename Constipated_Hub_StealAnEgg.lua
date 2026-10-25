--[[
	Constipated Hub | Steal An Egg
	UI: Orion + loading screen
	Feature set inspired by Clout Hub / DKHUB / SAE open patterns
	Auto Steal (Tween/TP) · Filters · ESP · Anti-Guard · Treadmill · Hatch · Staff Leave
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local PathfindingService = game:GetService("PathfindingService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.__ConstipatedSAEGen = (GENV.__ConstipatedSAEGen or 0) + 1
local GEN = GENV.__ConstipatedSAEGen
local function alive() return GENV.__ConstipatedSAEGen == GEN end

LocalPlayer.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

-- ===================== LOADING SCREEN =====================
local function showLoadingScreen(duration)
	duration = duration or 2.2
	local parent = (typeof(gethui) == "function" and gethui()) or CoreGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "ConstipatedLoad"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 999
	gui.Parent = parent

	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(8, 8, 12)
	bg.BorderSizePixel = 0
	bg.Parent = gui

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.Position = UDim2.new(0, 0, 0.42, 0)
	accent.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
	accent.BorderSizePixel = 0
	accent.Parent = bg

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Position = UDim2.new(0, 0, 0.38, -50)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 32
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.Text = "CONSTIPATED HUB"
	title.Parent = bg

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.Position = UDim2.new(0, 0, 0.38, -8)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 14
	sub.TextColor3 = Color3.fromRGB(160, 170, 190)
	sub.Text = "Steal An Egg  ·  Loading modules..."
	sub.Parent = bg

	local barBG = Instance.new("Frame")
	barBG.Size = UDim2.new(0.35, 0, 0, 4)
	barBG.Position = UDim2.new(0.325, 0, 0.52, 0)
	barBG.BackgroundColor3 = Color3.fromRGB(30, 32, 40)
	barBG.BorderSizePixel = 0
	barBG.Parent = bg
	Instance.new("UICorner", barBG).CornerRadius = UDim.new(1, 0)

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(255, 200, 80)
	bar.BorderSizePixel = 0
	bar.Parent = barBG
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	TweenService:Create(bar, TweenInfo.new(duration * 0.85, Enum.EasingStyle.Quad), {
		Size = UDim2.new(1, 0, 1, 0)
	}):Play()
	task.wait(duration)
	TweenService:Create(bg, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	TweenService:Create(title, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	TweenService:Create(sub, TweenInfo.new(0.35), { TextTransparency = 1 }):Play()
	TweenService:Create(accent, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	task.wait(0.4)
	gui:Destroy()
end

showLoadingScreen(2.2)

-- ===================== ORION =====================
local OrionLib
do
	for _, u in ipairs({
		"https://raw.githubusercontent.com/jensonhirst/Orion/main/source",
		"https://raw.githubusercontent.com/shlexware/Orion/main/source",
	}) do
		local ok, res = pcall(function() return loadstring(game:HttpGet(u))() end)
		if ok and res then OrionLib = res break end
	end
end
if not OrionLib then warn("[Constipated] Orion failed") return end

-- ===================== CONFIG =====================
local RARITY_RANK = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5,
	Mythic = 6, Secret = 7, Divine = 8, Eternal = 9, Exclusive = 10,
}

local CFG = {
	-- Steal
	AutoSteal = false,
	StealMode = "Tween", -- Tween | Teleport
	TweenSpeed = 90,
	StealDelay = 0.9,
	Humanize = true,
	ReturnToBase = true,
	Priority = "Rarest", -- Rarest | Nearest | Biggest
	MinRarity = "Common",
	OnlyMutated = false,
	TargetEggName = "", -- optional name filter
	FastCycle = false,

	-- Anti guard / safety
	AntiGuard = true,
	GuardFleeDist = 28,
	NoclipCarry = true,
	AntiTrap = true,
	GetUnstuck = false,
	StaffAutoLeave = true,
	Watchlist = {}, -- names

	-- Base farm
	AutoPlace = false,
	AutoHatch = false,
	AutoTreadmill = false,
	AutoUpgradeTreadmill = false,
	AutoEquipBest = false,
	AutoSellJunk = false,
	ProtectMutated = true,
	AutoClaim = false,

	-- ESP
	EggESP = true,
	PlayerESP = false,
	GuardESP = true,
	TrapESP = false,
	ESPMaxDist = 1200,

	-- Movement
	WalkSpeedOn = false,
	WalkSpeed = 24,
	InfJump = false,
	Noclip = false,
	Fly = false,
	FlySpeed = 60,

	Fullbright = false,
	ServerHopOnEmpty = false,
}

local statusText = "Idle"
local lastBaseCF = nil
local stealing = false

-- ===================== HELPERS =====================
local function getChar()
	return LocalPlayer.Character
end

local function getHRP(ch)
	ch = ch or getChar()
	return ch and (ch:FindFirstChild("HumanoidRootPart") or ch:FindFirstChild("Torso") or ch:FindFirstChild("UpperTorso"))
end

local function getHum(ch)
	ch = ch or getChar()
	return ch and ch:FindFirstChildOfClass("Humanoid")
end

local function notify(title, content)
	pcall(function()
		OrionLib:MakeNotification({ Name = title, Content = content, Time = 3 })
	end)
end

local function setStatus(s)
	statusText = s
end

local function humanDelay(base)
	if CFG.Humanize then
		return base + math.random() * 0.25
	end
	return base
end

local function tweenTo(cf, speed)
	local root = getHRP()
	if not root then return false end
	speed = speed or CFG.TweenSpeed
	local dist = (root.Position - cf.Position).Magnitude
	local t = math.clamp(dist / math.max(speed, 1), 0.05, 8)
	local tw = TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Linear), { CFrame = cf })
	tw:Play()
	tw.Completed:Wait()
	return true
end

local function tpTo(cf)
	local root = getHRP()
	if not root then return false end
	root.CFrame = cf
	return true
end

local function moveTo(cf)
	if CFG.StealMode == "Teleport" then
		return tpTo(cf)
	end
	return tweenTo(cf, CFG.TweenSpeed)
end

-- Find own plot / base
local function findBaseCF()
	if lastBaseCF then return lastBaseCF end
	local plots = workspace:FindFirstChild("Plots") or workspace:FindFirstChild("Bases") or workspace:FindFirstChild("Tycoons")
	if plots then
		for _, p in ipairs(plots:GetChildren()) do
			local owner = p:GetAttribute("Owner") or p:GetAttribute("OwnerName") or p:GetAttribute("Player")
			if owner == LocalPlayer.Name or owner == LocalPlayer.UserId then
				local part = p:FindFirstChildWhichIsA("BasePart", true)
				if part then
					lastBaseCF = part.CFrame + Vector3.new(0, 4, 0)
					return lastBaseCF
				end
			end
		end
	end
	-- fallback spawn
	local spawn = workspace:FindFirstChild("SpawnLocation") or workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		lastBaseCF = spawn.CFrame + Vector3.new(0, 4, 0)
		return lastBaseCF
	end
	local root = getHRP()
	if root then
		lastBaseCF = root.CFrame
		return lastBaseCF
	end
	return nil
end

-- ===================== EGG DISCOVERY =====================
local function rarityValue(r)
	if not r then return 0 end
	local s = tostring(r)
	for name, rank in pairs(RARITY_RANK) do
		if s:lower():find(name:lower()) then return rank end
	end
	local n = tonumber(s)
	return n or 0
end

local function isEggModel(obj)
	if not obj or not obj:IsA("Model") and not obj:IsA("BasePart") then
		-- still allow models
	end
	if not obj then return false end
	local name = obj.Name:lower()
	if name:find("egg") then return true end
	if obj:GetAttribute("Rarity") or obj:GetAttribute("EggRarity") or obj:GetAttribute("EggId") then return true end
	if obj:FindFirstChild("Rarity") or obj:FindFirstChild("EggId") then return true end
	if obj:FindFirstChildWhichIsA("ProximityPrompt", true) and name:find("nest") then return true end
	return false
end

local function getEggPart(obj)
	if obj:IsA("BasePart") then return obj end
	return obj:FindFirstChild("HumanoidRootPart")
		or obj:FindFirstChild("Handle")
		or obj:FindFirstChildWhichIsA("BasePart", true)
end

local function getEggInfo(obj)
	local part = getEggPart(obj)
	if not part then return nil end
	local rarity = obj:GetAttribute("Rarity") or obj:GetAttribute("EggRarity")
		or (obj:FindFirstChild("Rarity") and obj.Rarity.Value)
		or "Common"
	local mutation = obj:GetAttribute("Mutation") or obj:GetAttribute("Variant") or ""
	local size = obj:GetAttribute("Size") or obj:GetAttribute("Scale") or 1
	if typeof(size) ~= "number" then size = 1 end
	local income = obj:GetAttribute("Income") or obj:GetAttribute("CashPerSec") or 0
	return {
		obj = obj,
		part = part,
		rarity = tostring(rarity),
		rank = rarityValue(rarity),
		mutation = tostring(mutation),
		size = size,
		income = tonumber(income) or 0,
		name = obj.Name,
	}
end

local function passesFilters(info)
	if not info then return false end
	if CFG.MinRarity and rarityValue(CFG.MinRarity) > 0 then
		if info.rank < rarityValue(CFG.MinRarity) then return false end
	end
	if CFG.OnlyMutated then
		local m = info.mutation:lower()
		if m == "" or m == "none" or m == "normal" then return false end
	end
	if CFG.TargetEggName ~= "" then
		if not info.name:lower():find(CFG.TargetEggName:lower())
			and not info.rarity:lower():find(CFG.TargetEggName:lower()) then
			return false
		end
	end
	return true
end

local function collectEggs()
	local list = {}
	local folders = {
		workspace:FindFirstChild("Eggs"),
		workspace:FindFirstChild("Nests"),
		workspace:FindFirstChild("WorldEggs"),
		workspace:FindFirstChild("Map"),
		workspace,
	}
	local seen = {}
	for _, folder in ipairs(folders) do
		if folder then
			for _, obj in ipairs(folder:GetDescendants()) do
				if (obj:IsA("Model") or obj:IsA("BasePart")) and isEggModel(obj) and not seen[obj] then
					seen[obj] = true
					local info = getEggInfo(obj)
					if info and passesFilters(info) then
						table.insert(list, info)
					end
				end
			end
		end
		if folder == workspace then break end
	end
	return list
end

local function pickBestEgg()
	local eggs = collectEggs()
	if #eggs == 0 then return nil end
	local root = getHRP()
	local myPos = root and root.Position or Vector3.zero

	table.sort(eggs, function(a, b)
		if CFG.Priority == "Nearest" then
			return (a.part.Position - myPos).Magnitude < (b.part.Position - myPos).Magnitude
		elseif CFG.Priority == "Biggest" then
			if a.size ~= b.size then return a.size > b.size end
			return a.rank > b.rank
		else -- Rarest
			if a.rank ~= b.rank then return a.rank > b.rank end
			if a.income ~= b.income then return a.income > b.income end
			return (a.part.Position - myPos).Magnitude < (b.part.Position - myPos).Magnitude
		end
	end)
	return eggs[1]
end

-- ===================== STEAL ACTIONS =====================
local function fireStealRemotes(target)
	local names = {
		"RequestStealTarget", "StealTargetEvent", "StealEgg", "RequestSteal",
		"PickEgg", "CollectEgg", "GrabEgg", "Steal",
	}
	local function tryContainer(c)
		if not c then return end
		for _, r in ipairs(c:GetDescendants()) do
			if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
				local n = r.Name:lower()
				for _, want in ipairs(names) do
					if n:find(want:lower()) then
						pcall(function()
							if r:IsA("RemoteEvent") then
								r:FireServer(target)
								r:FireServer(target.Name)
							else
								r:InvokeServer(target)
							end
						end)
					end
				end
			end
		end
	end
	tryContainer(ReplicatedStorage)
	tryContainer(ReplicatedStorage:FindFirstChild("Remotes"))
	tryContainer(ReplicatedStorage:FindFirstChild("Events"))
	tryContainer(ReplicatedStorage:FindFirstChild("ActiveAssets"))
	tryContainer(ReplicatedStorage:FindFirstChild("Eggs"))
end

local function triggerPrompt(obj)
	local prompt = obj:FindFirstChildOfClass("ProximityPrompt")
		or obj:FindFirstChildWhichIsA("ProximityPrompt", true)
	if prompt then
		pcall(function()
			if fireproximityprompt then
				fireproximityprompt(prompt)
			else
				prompt:InputHoldBegin()
				task.wait(prompt.HoldDuration or 0.1)
				prompt:InputHoldEnd()
			end
		end)
		return true
	end
	return false
end

local function stealEgg(info)
	if not info or not info.part then return false end
	setStatus("Stealing " .. info.rarity)
	local dest = info.part.CFrame + Vector3.new(0, 3.5, 0)
	moveTo(dest)
	task.wait(humanDelay(0.12))
	triggerPrompt(info.obj)
	fireStealRemotes(info.obj)
	fireStealRemotes(info.part)
	task.wait(humanDelay(CFG.StealDelay * (CFG.FastCycle and 0.5 or 1)))
	return true
end

local function returnHome()
	if not CFG.ReturnToBase then return end
	local base = findBaseCF()
	if base then
		setStatus("Returning to base")
		moveTo(base)
		task.wait(humanDelay(0.3))
	end
end

-- ===================== ANTI GUARD =====================
local function isGuard(model)
	if not model then return false end
	local n = model.Name:lower()
	if n:find("guard") or n:find("security") or n:find("npc") or n:find("police") then
		return true
	end
	if model:GetAttribute("IsGuard") or model:GetAttribute("Guard") then return true end
	return false
end

local function nearbyGuard(maxDist)
	maxDist = maxDist or CFG.GuardFleeDist
	local root = getHRP()
	if not root then return nil end
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and isGuard(obj) then
			local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
			if p and (p.Position - root.Position).Magnitude <= maxDist then
				return obj, p
			end
		end
	end
	return nil
end

local function fleeFromGuards()
	if not CFG.AntiGuard then return end
	local g, gp = nearbyGuard(CFG.GuardFleeDist)
	if not g or not gp then return end
	local root = getHRP()
	if not root then return end
	setStatus("Fleeing guard")
	local away = (root.Position - gp.Position)
	if away.Magnitude < 1 then away = Vector3.new(1, 0, 0) end
	local dest = root.Position + away.Unit * 40 + Vector3.new(0, 6, 0)
	if CFG.NoclipCarry then
		for _, p in ipairs(getChar():GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
	moveTo(CFrame.new(dest))
end

-- Staff leave
local STAFF_HINTS = { "admin", "mod", "staff", "dev", "owner", "manager" }
Players.PlayerAdded:Connect(function(plr)
	if not CFG.StaffAutoLeave then return end
	local name = (plr.Name .. " " .. (plr.DisplayName or "")):lower()
	for _, h in ipairs(STAFF_HINTS) do
		if name:find(h) then
			notify("Staff detected", plr.Name .. " joined — leaving")
			pcall(function()
				TeleportService:Teleport(game.PlaceId, LocalPlayer)
			end)
			return
		end
	end
	for _, w in ipairs(CFG.Watchlist) do
		if plr.Name:lower() == w:lower() then
			notify("Watchlist", plr.Name)
			pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
			return
		end
	end
end)

-- ===================== AUTO STEAL LOOP =====================
task.spawn(function()
	while alive() do
		if CFG.AutoSteal and not stealing then
			stealing = true
			pcall(function()
				fleeFromGuards()
				local egg = pickBestEgg()
				if egg then
					stealEgg(egg)
					returnHome()
					setStatus("Idle")
				else
					setStatus("No eggs match filters")
					if CFG.ServerHopOnEmpty then
						pcall(function()
							TeleportService:Teleport(game.PlaceId, LocalPlayer)
						end)
					end
					task.wait(1.5)
				end
			end)
			stealing = false
		end
		task.wait(CFG.FastCycle and 0.15 or 0.35)
	end
end)

-- ===================== TREADMILL / HATCH / PLACE =====================
local function fireNamed(container, names, ...)
	if not container then return end
	local args = { ... }
	for _, r in ipairs(container:GetDescendants()) do
		if r:IsA("RemoteEvent") or r:IsA("RemoteFunction") then
			local n = r.Name:lower()
			for _, want in ipairs(names) do
				if n:find(want:lower()) then
					pcall(function()
						if r:IsA("RemoteEvent") then
							r:FireServer(unpack(args))
						else
							r:InvokeServer(unpack(args))
						end
					end)
				end
			end
		end
	end
end

task.spawn(function()
	while alive() do
		if CFG.AutoTreadmill then
			setStatus("Treadmill")
			fireNamed(ReplicatedStorage, { "SpeedGain", "Treadmill", "RequestTrain" })
			-- stand on treadmill if found
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj.Name:lower():find("treadmill") and obj:IsA("BasePart") then
					local root = getHRP()
					if root and (root.Position - obj.Position).Magnitude > 8 then
						moveTo(obj.CFrame + Vector3.new(0, 3, 0))
					end
					break
				end
			end
		end
		if CFG.AutoUpgradeTreadmill then
			fireNamed(ReplicatedStorage, { "RequestUpgrade", "UpgradeTreadmill", "TreadmillUpgrade" })
		end
		if CFG.AutoHatch then
			fireNamed(ReplicatedStorage, { "RequestHatchEgg", "HatchEgg", "RequestCompleteHatchEgg", "Hatch" })
		end
		if CFG.AutoPlace then
			fireNamed(ReplicatedStorage, { "RequestPlaceEgg", "PlaceEgg", "Place" })
		end
		if CFG.AutoEquipBest then
			fireNamed(ReplicatedStorage, { "EquipBest", "RequestEquipBest" })
		end
		if CFG.AutoSellJunk then
			fireNamed(ReplicatedStorage, { "SellAllAssets", "SellJunk", "SellPets" })
		end
		if CFG.AutoClaim then
			fireNamed(ReplicatedStorage, { "RequestClaimAll", "ClaimReward", "Claim" })
		end
		task.wait(2)
	end
end)

-- ===================== ESP =====================
local espFolder
local function ensureESP()
	if espFolder and espFolder.Parent then return espFolder end
	local parent = (typeof(gethui) == "function" and gethui()) or CoreGui
	local old = parent:FindFirstChild("ConstipatedSAE_ESP")
	if old then old:Destroy() end
	espFolder = Instance.new("Folder")
	espFolder.Name = "ConstipatedSAE_ESP"
	espFolder.Parent = parent
	return espFolder
end

local function clearESP()
	if espFolder then espFolder:ClearAllChildren() end
end

local function hl(adornee, color)
	local h = Instance.new("Highlight")
	h.Adornee = adornee
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.55
	h.OutlineTransparency = 0.1
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = ensureESP()
end

local function bb(adornee, text, color)
	local b = Instance.new("BillboardGui")
	b.Adornee = adornee
	b.Size = UDim2.fromOffset(160, 40)
	b.StudsOffset = Vector3.new(0, 3, 0)
	b.AlwaysOnTop = true
	b.Parent = ensureESP()
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBold
	t.TextSize = 12
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.4
	t.Text = text
	t.Parent = b
end

local RARITY_COLOR = {
	Common = Color3.fromRGB(200, 200, 200),
	Uncommon = Color3.fromRGB(80, 200, 80),
	Rare = Color3.fromRGB(80, 140, 255),
	Epic = Color3.fromRGB(180, 80, 255),
	Legendary = Color3.fromRGB(255, 180, 40),
	Mythic = Color3.fromRGB(255, 60, 100),
	Secret = Color3.fromRGB(255, 40, 40),
	Divine = Color3.fromRGB(255, 255, 120),
	Eternal = Color3.fromRGB(120, 255, 255),
}

local function refreshESP()
	clearESP()
	local root = getHRP()
	if not root then return end

	if CFG.EggESP then
		for _, info in ipairs(collectEggs()) do
			local dist = (info.part.Position - root.Position).Magnitude
			if dist <= CFG.ESPMaxDist then
				local col = RARITY_COLOR[info.rarity] or Color3.fromRGB(255, 200, 80)
				for k, v in pairs(RARITY_COLOR) do
					if info.rarity:lower():find(k:lower()) then col = v break end
				end
				hl(info.obj, col)
				bb(info.part, string.format("%s\n%.0fm", info.rarity, dist), col)
			end
		end
	end

	if CFG.PlayerESP then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				local hrp = getHRP(plr.Character)
				if hrp then
					local dist = (hrp.Position - root.Position).Magnitude
					if dist <= CFG.ESPMaxDist then
						hl(plr.Character, Color3.fromRGB(100, 180, 255))
						bb(hrp, plr.Name .. string.format("\n%.0fm", dist), Color3.fromRGB(100, 180, 255))
					end
				end
			end
		end
	end

	if CFG.GuardESP then
		for _, obj in ipairs(workspace:GetDescendants()) do
			if obj:IsA("Model") and isGuard(obj) then
				local p = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
				if p then
					hl(obj, Color3.fromRGB(255, 50, 50))
					bb(p, "GUARD", Color3.fromRGB(255, 80, 80))
				end
			end
		end
	end

	if CFG.TrapESP then
		for _, obj in ipairs(workspace:GetDescendants()) do
			local n = obj.Name:lower()
			if (n:find("trap") or n:find("spike") or n:find("hazard")) and obj:IsA("BasePart") then
				hl(obj, Color3.fromRGB(255, 140, 0))
			end
		end
	end
end

task.spawn(function()
	while alive() do
		pcall(refreshESP)
		task.wait(0.7)
	end
	clearESP()
end)

-- ===================== MOVEMENT =====================
RunService.Stepped:Connect(function()
	if not alive() then return end
	if CFG.Noclip or (CFG.NoclipCarry and stealing) then
		local c = getChar()
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then p.CanCollide = false end
			end
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if not alive() then return end
	local hum = getHum()
	if hum and CFG.WalkSpeedOn then
		hum.WalkSpeed = CFG.WalkSpeed
	end
	if CFG.Fly then
		local root = getHRP()
		if root then
			local dir = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
			root.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * CFG.FlySpeed or Vector3.zero
		end
	end
end)

UserInputService.JumpRequest:Connect(function()
	if CFG.InfJump and alive() then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

-- ===================== UI =====================
local Window = OrionLib:MakeWindow({
	Name = "Constipated Hub | Steal An Egg",
	HidePremium = true,
	SaveConfig = false,
	IntroEnabled = false,
})

local TabFarm = Window:MakeTab({ Name = "Auto Farm", Icon = "rbxassetid://4483362458", PremiumOnly = false })
local TabFilters = Window:MakeTab({ Name = "Filters", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabSafety = Window:MakeTab({ Name = "Safety", Icon = "rbxassetid://4483342657", PremiumOnly = false })
local TabBase = Window:MakeTab({ Name = "Base", Icon = "rbxassetid://4483362748", PremiumOnly = false })
local TabESP = Window:MakeTab({ Name = "ESP", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabPlayer = Window:MakeTab({ Name = "Player", Icon = "rbxassetid://4483342657", PremiumOnly = false })
local TabMisc = Window:MakeTab({ Name = "Misc", Icon = "rbxassetid://4483362458", PremiumOnly = false })

TabFarm:AddToggle({
	Name = "Auto Steal",
	Default = false,
	Callback = function(v) CFG.AutoSteal = v setStatus(v and "Auto Steal ON" or "Idle") end,
})
TabFarm:AddDropdown({
	Name = "Steal Mode",
	Default = "Tween",
	Options = { "Tween", "Teleport" },
	Callback = function(v) CFG.StealMode = v end,
})
TabFarm:AddSlider({
	Name = "Tween Speed",
	Min = 30, Max = 200, Default = 90, Increment = 5,
	Callback = function(v) CFG.TweenSpeed = v end,
})
TabFarm:AddSlider({
	Name = "Steal Delay",
	Min = 0.2, Max = 3, Default = 0.9, Increment = 0.1,
	Callback = function(v) CFG.StealDelay = v end,
})
TabFarm:AddToggle({ Name = "Humanized Delays", Default = true, Callback = function(v) CFG.Humanize = v end })
TabFarm:AddToggle({ Name = "Return To Base", Default = true, Callback = function(v) CFG.ReturnToBase = v end })
TabFarm:AddToggle({ Name = "Fast Cycle", Default = false, Callback = function(v) CFG.FastCycle = v end })
TabFarm:AddDropdown({
	Name = "Priority",
	Default = "Rarest",
	Options = { "Rarest", "Nearest", "Biggest" },
	Callback = function(v) CFG.Priority = v end,
})
TabFarm:AddParagraph("Status", "See Misc tab / console — loops run while Auto Steal is on")

TabFilters:AddDropdown({
	Name = "Min Rarity",
	Default = "Common",
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret", "Divine", "Eternal" },
	Callback = function(v) CFG.MinRarity = v end,
})
TabFilters:AddToggle({ Name = "Only Mutated", Default = false, Callback = function(v) CFG.OnlyMutated = v end })
TabFilters:AddTextbox({
	Name = "Target Name Filter",
	Default = "",
	TextDisappear = false,
	Callback = function(v) CFG.TargetEggName = v or "" end,
})
TabFilters:AddParagraph("Tip", "Leave name empty for all eggs above min rarity")

TabSafety:AddToggle({ Name = "Anti Guard (flee)", Default = true, Callback = function(v) CFG.AntiGuard = v end })
TabSafety:AddSlider({
	Name = "Guard Flee Distance",
	Min = 10, Max = 60, Default = 28, Increment = 1,
	Callback = function(v) CFG.GuardFleeDist = v end,
})
TabSafety:AddToggle({ Name = "Noclip While Carry", Default = true, Callback = function(v) CFG.NoclipCarry = v end })
TabSafety:AddToggle({ Name = "Staff Auto Leave", Default = true, Callback = function(v) CFG.StaffAutoLeave = v end })
TabSafety:AddButton({
	Name = "Get Unstuck (TP Base)",
	Callback = function()
		local base = findBaseCF()
		if base then tpTo(base) notify("Unstuck", "Teleported to base") end
	end,
})
TabSafety:AddButton({
	Name = "Server Hop",
	Callback = function()
		pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
	end,
})
TabSafety:AddToggle({
	Name = "Hop When No Matching Eggs",
	Default = false,
	Callback = function(v) CFG.ServerHopOnEmpty = v end,
})

TabBase:AddToggle({ Name = "Auto Place Eggs", Default = false, Callback = function(v) CFG.AutoPlace = v end })
TabBase:AddToggle({ Name = "Auto Hatch", Default = false, Callback = function(v) CFG.AutoHatch = v end })
TabBase:AddToggle({ Name = "Auto Treadmill", Default = false, Callback = function(v) CFG.AutoTreadmill = v end })
TabBase:AddToggle({ Name = "Auto Upgrade Treadmill", Default = false, Callback = function(v) CFG.AutoUpgradeTreadmill = v end })
TabBase:AddToggle({ Name = "Auto Equip Best", Default = false, Callback = function(v) CFG.AutoEquipBest = v end })
TabBase:AddToggle({ Name = "Auto Sell Junk", Default = false, Callback = function(v) CFG.AutoSellJunk = v end })
TabBase:AddToggle({ Name = "Protect Mutated (sell filter)", Default = true, Callback = function(v) CFG.ProtectMutated = v end })
TabBase:AddToggle({ Name = "Auto Claim Rewards", Default = false, Callback = function(v) CFG.AutoClaim = v end })

TabESP:AddToggle({ Name = "Egg ESP", Default = true, Callback = function(v) CFG.EggESP = v end })
TabESP:AddToggle({ Name = "Player ESP", Default = false, Callback = function(v) CFG.PlayerESP = v end })
TabESP:AddToggle({ Name = "Guard ESP", Default = true, Callback = function(v) CFG.GuardESP = v end })
TabESP:AddToggle({ Name = "Trap ESP", Default = false, Callback = function(v) CFG.TrapESP = v end })
TabESP:AddSlider({
	Name = "ESP Max Distance",
	Min = 200, Max = 3000, Default = 1200, Increment = 50,
	Callback = function(v) CFG.ESPMaxDist = v end,
})

TabPlayer:AddToggle({ Name = "WalkSpeed", Default = false, Callback = function(v) CFG.WalkSpeedOn = v end })
TabPlayer:AddSlider({ Name = "WalkSpeed Value", Min = 16, Max = 50, Default = 24, Increment = 1, Callback = function(v) CFG.WalkSpeed = v end })
TabPlayer:AddToggle({ Name = "Infinite Jump", Default = false, Callback = function(v) CFG.InfJump = v end })
TabPlayer:AddToggle({ Name = "Noclip", Default = false, Callback = function(v) CFG.Noclip = v end })
TabPlayer:AddToggle({ Name = "Fly", Default = false, Callback = function(v) CFG.Fly = v end })
TabPlayer:AddSlider({ Name = "Fly Speed", Min = 20, Max = 150, Default = 60, Increment = 5, Callback = function(v) CFG.FlySpeed = v end })

TabMisc:AddToggle({
	Name = "Fullbright",
	Default = false,
	Callback = function(v)
		CFG.Fullbright = v
		if v then
			Lighting.Brightness = 2
			Lighting.ClockTime = 14
			Lighting.FogEnd = 1e6
			Lighting.GlobalShadows = false
		else
			Lighting.Brightness = 1
			Lighting.GlobalShadows = true
		end
	end,
})
TabMisc:AddButton({
	Name = "Unload Hub",
	Callback = function()
		GENV.__ConstipatedSAEGen = GEN + 1
		clearESP()
		pcall(function() OrionLib:Destroy() end)
	end,
})
TabMisc:AddParagraph("About", "Clout-style farm · Orion UI · Tween/TP steal · rarity filters · anti-guard · staff leave")

OrionLib:MakeNotification({
	Name = "Constipated Hub",
	Content = "Steal An Egg loaded — enable Auto Steal when ready",
	Time = 4,
})

print("[Constipated Hub] Steal An Egg ready")
