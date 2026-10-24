--[[
	Constipated Hub | Steal An Egg
	UI: Orion
	Logic based on open DKHUB remotes + improved prioritization / anti-stuck
	PlaceId reference: 108053424714724
]]

repeat task.wait() until game:IsLoaded()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.__ConstipatedEggGen = (GENV.__ConstipatedEggGen or 0) + 1
local GEN = GENV.__ConstipatedEggGen

local function alive()
	return GENV.__ConstipatedEggGen == GEN
end

-- ===================== LIGHT ANTI-KICK / AFK SHIELD =====================
pcall(function()
	if typeof(hookfunction) == "function" and LocalPlayer then
		local oldKick
		oldKick = hookfunction(LocalPlayer.Kick, function(self, ...)
			if self == LocalPlayer then
				return
			end
			return oldKick(self, ...)
		end)
	end
end)

local BlockedRemoteHints = {
	integrity = true,
	violation = true,
	anticheat = true,
	honeypot = true,
	afk = true,
}

pcall(function()
	if typeof(hookmetamethod) ~= "function" then
		return
	end
	local oldNamecall
	oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
		local method = getnamecallmethod()
		if method == "FireServer" or method == "InvokeServer" then
			local n = tostring(self and self.Name or "")
			local lower = n:lower()
			for hint in pairs(BlockedRemoteHints) do
				if lower:find(hint, 1, true) then
					return
				end
			end
		end
		return oldNamecall(self, ...)
	end)
end)

LocalPlayer.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

-- ===================== ORION =====================
local OrionLib
do
	local urls = {
		"https://raw.githubusercontent.com/jensonhirst/Orion/main/source",
		"https://raw.githubusercontent.com/shlexware/Orion/main/source",
	}
	for _, u in ipairs(urls) do
		local ok, res = pcall(function()
			return loadstring(game:HttpGet(u))()
		end)
		if ok and res then
			OrionLib = res
			break
		end
	end
end
if not OrionLib then
	warn("[Constipated Hub] Orion failed")
	return
end

-- ===================== STATE =====================
local CFG = {
	AutoSteal = false,
	StealMethod = "Tween", -- Instant | Tween
	TweenSpeed = 70,
	StealDelay = 0.28,
	MinRarity = "Common",
	RarestFirst = true,
	PreferEnemyPlots = true,
	AreaEggs = true,
	AutoDeposit = true,

	AutoCollect = false,
	CollectDelay = 1.0,

	AutoHatch = false,
	SelectedEgg = "Starter Egg",
	HatchCount = 1,
	AutoSkipGrowth = true,
	AutoPlaceEgg = true,

	AutoTreadmill = false,
	AutoUpgradeTread = true,
	AutoEquipBestTread = true,

	AutoBaseUpgrade = false,
	AutoSellJunk = false,
	ProtectMutated = true,

	EggESP = true,
	PlayerESP = false,
	GuardESP = true,
	MaxESPDist = 800,

	WalkSpeedOn = false,
	WalkSpeed = 28,
	JumpOn = false,
	JumpPower = 60,
	Noclip = false,
	InfJump = false,
	AntiAFK = true,

	UnstuckKey = true,
}

local RARITY_RANK = {
	Basic = 1,
	Common = 2,
	Uncommon = 3,
	Rare = 4,
	Epic = 5,
	Legendary = 6,
	Mythic = 7,
	Secret = 8,
	Limited = 9,
	Superior = 10,
}

local EGG_TYPES = {
	"Starter Egg",
	"Forest Egg",
	"Desert Egg",
	"Ocean Egg",
	"Volcano Egg",
	"Cyber Egg",
	"Mythic Egg",
	"Void Egg",
	"Limited Egg",
}

-- ===================== NETWORK =====================
local function getNetwork()
	return ReplicatedStorage:FindFirstChild("Network") or ReplicatedStorage
end

local function getRemote(name)
	local net = getNetwork()
	local item = net:FindFirstChild(name)
	if not item then
		item = ReplicatedStorage:FindFirstChild(name, true)
	end
	return item
end

local function fireRemote(name, ...)
	local r = getRemote(name)
	if r and r:IsA("RemoteEvent") then
		return pcall(function(...)
			r:FireServer(...)
		end, ...)
	end
	return false
end

local function invokeRemote(name, ...)
	local rf = getRemote(name)
	if rf and (rf:IsA("RemoteFunction") or rf:IsA("RemoteEvent")) then
		local res
		local ok = pcall(function(...)
			if rf:IsA("RemoteFunction") then
				res = rf:InvokeServer(...)
			else
				rf:FireServer(...)
			end
		end, ...)
		if ok then
			return res
		end
	end
	return nil
end

-- ===================== CHARACTER =====================
local function getChar()
	return LocalPlayer.Character
end

local function getRoot()
	local c = getChar()
	return c and (c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso"))
end

local function getHum()
	local c = getChar()
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function teleportTo(cf, useTween, speed)
	local root = getRoot()
	if not root then
		return
	end
	if useTween then
		local dist = (root.Position - cf.Position).Magnitude
		local dur = math.clamp(dist / (speed or CFG.TweenSpeed), 0.12, 3.5)
		local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear), { CFrame = cf })
		tw:Play()
		tw.Completed:Wait()
	else
		root.CFrame = cf
	end
end

local function triggerPrompt(prompt)
	if not prompt or not prompt:IsA("ProximityPrompt") or not prompt.Enabled then
		return false
	end
	return pcall(function()
		if fireproximityprompt then
			fireproximityprompt(prompt)
		else
			prompt:InputHoldBegin()
			task.wait(prompt.HoldDuration or 0.1)
			prompt:InputHoldEnd()
		end
	end)
end

-- ===================== PLOTS / EGGS =====================
local function getPlotsFolder()
	return Workspace:FindFirstChild("Plots")
		or Workspace:FindFirstChild("Bases")
		or Workspace:FindFirstChild("Islands")
		or Workspace:FindFirstChild("PlayerPlots")
end

local function getPlayerPlot(player)
	local folder = getPlotsFolder()
	if not folder then
		return nil
	end
	for _, plot in ipairs(folder:GetChildren()) do
		local owner = plot:FindFirstChild("Owner")
		if owner and tostring(owner.Value) == player.Name then
			return plot
		end
		if plot.Name == player.Name or plot.Name == "Plot_" .. player.Name or plot.Name == "Base_" .. player.Name then
			return plot
		end
	end
	return nil
end

local function getLocalPlot()
	return getPlayerPlot(LocalPlayer)
end

local function getDepositCF()
	local plot = getLocalPlot()
	if not plot then
		return nil
	end
	local names = { "Deposit", "Nest", "DropZone", "EggSpawn", "BaseSpawn", "Collector" }
	for _, n in ipairs(names) do
		local d = plot:FindFirstChild(n, true)
		if d then
			if d:IsA("BasePart") then
				return d.CFrame + Vector3.new(0, 3, 0)
			elseif d:IsA("Model") then
				local pp = d.PrimaryPart or d:FindFirstChildWhichIsA("BasePart")
				if pp then
					return pp.CFrame + Vector3.new(0, 3, 0)
				end
			end
		end
	end
	local pp = plot.PrimaryPart or plot:FindFirstChildWhichIsA("BasePart", true)
	if pp then
		return pp.CFrame + Vector3.new(0, 4, 0)
	end
	return nil
end

local function rarityScore(obj)
	local r = obj:GetAttribute("Rarity") or obj:GetAttribute("AssetRarity") or obj:GetAttribute("Tier") or "Common"
	if typeof(r) ~= "string" then
		r = tostring(r)
	end
	return RARITY_RANK[r] or RARITY_RANK[r:gsub("^%l", string.upper)] or 2, r
end

local function isEggLike(obj)
	if not obj then
		return false
	end
	if obj:GetAttribute("IsEgg") or obj:GetAttribute("IsAreaEgg") then
		return true
	end
	local n = obj.Name:lower()
	if n:find("egg") then
		return true
	end
	if obj:IsA("Model") and obj:FindFirstChild("Egg", true) then
		return true
	end
	return false
end

local function partOf(obj)
	if obj:IsA("BasePart") then
		return obj
	end
	if obj:IsA("Model") then
		return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function scanStealTargets()
	local results = {}
	local minRank = RARITY_RANK[CFG.MinRarity] or 2

	-- Enemy plot eggs
	if CFG.PreferEnemyPlots then
		local folder = getPlotsFolder()
		local myPlot = getLocalPlot()
		if folder then
			for _, plot in ipairs(folder:GetChildren()) do
				if plot ~= myPlot then
					for _, obj in ipairs(plot:GetDescendants()) do
						if isEggLike(obj) then
							local score, rarity = rarityScore(obj)
							if score >= minRank then
								local p = partOf(obj)
								if p then
									table.insert(results, {
										Obj = obj,
										Part = p,
										Score = score,
										Rarity = rarity,
										Source = "plot",
										Owner = plot.Name,
									})
								end
							end
						end
					end
				end
			end
		end
	end

	-- World / area eggs
	if CFG.AreaEggs then
		local folders = {
			Workspace:FindFirstChild("AreaEggs"),
			Workspace:FindFirstChild("SpawnedEggs"),
			Workspace:FindFirstChild("Eggs"),
			Workspace:FindFirstChild("ActiveAssets"),
		}
		for _, folder in ipairs(folders) do
			if folder then
				for _, obj in ipairs(folder:GetDescendants()) do
					if isEggLike(obj) then
						local score, rarity = rarityScore(obj)
						if score >= minRank then
							local p = partOf(obj)
							if p then
								table.insert(results, {
									Obj = obj,
									Part = p,
									Score = score,
									Rarity = rarity,
									Source = "area",
								})
							end
						end
					end
				end
			end
		end
		-- loose scan (limited)
		for _, obj in ipairs(Workspace:GetChildren()) do
			if isEggLike(obj) then
				local score, rarity = rarityScore(obj)
				if score >= minRank then
					local p = partOf(obj)
					if p then
						table.insert(results, {
							Obj = obj,
							Part = p,
							Score = score,
							Rarity = rarity,
							Source = "world",
						})
					end
				end
			end
		end
	end

	if CFG.RarestFirst then
		table.sort(results, function(a, b)
			if a.Score == b.Score then
				local root = getRoot()
				if root then
					return (a.Part.Position - root.Position).Magnitude < (b.Part.Position - root.Position).Magnitude
				end
			end
			return a.Score > b.Score
		end)
	else
		local root = getRoot()
		if root then
			table.sort(results, function(a, b)
				return (a.Part.Position - root.Position).Magnitude < (b.Part.Position - root.Position).Magnitude
			end)
		end
	end

	return results
end

-- ===================== STEAL / FARM STEPS =====================
local lastStealPos = nil
local stuckCount = 0

local function doUnstuck()
	local root = getRoot()
	local hum = getHum()
	if not root then
		return
	end
	pcall(function()
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = root.CFrame + Vector3.new(0, 8, 0)
	end)
	-- try lobby / plot return
	invokeRemote("Plots: RequestLobbyTeleport")
	task.wait(0.2)
	local dep = getDepositCF()
	if dep then
		teleportTo(dep, false)
	end
end

local function stepAutoSteal()
	local targets = scanStealTargets()
	if #targets == 0 then
		task.wait(0.8)
		return
	end

	local t = targets[1]
	local root = getRoot()
	if not root or not t.Part then
		task.wait(0.4)
		return
	end

	-- stuck detection
	if lastStealPos and (root.Position - lastStealPos).Magnitude < 1.5 then
		stuckCount += 1
		if stuckCount >= 4 then
			doUnstuck()
			stuckCount = 0
			task.wait(0.5)
		end
	else
		stuckCount = 0
	end
	lastStealPos = root.Position

	local useTween = CFG.StealMethod == "Tween"
	local dest = t.Part.CFrame + Vector3.new(0, 3, 0)
	teleportTo(dest, useTween, CFG.TweenSpeed)

	-- steal remotes (DKHUB set)
	fireRemote("ActiveAssets: RequestStealTarget")
	fireRemote("ActiveAssets: StealTargetEvent")
	invokeRemote("Eggs: RequestAreaEggCarry")
	fireRemote("ActiveAssets: RequestDnaStealAnimationComplete")

	-- prompts on target
	for _, d in ipairs(t.Obj:GetDescendants()) do
		if d:IsA("ProximityPrompt") then
			triggerPrompt(d)
		end
	end
	if t.Obj:IsA("ProximityPrompt") then
		triggerPrompt(t.Obj)
	end

	task.wait(0.12)

	if CFG.AutoDeposit then
		local dep = getDepositCF()
		if dep then
			teleportTo(dep, useTween, CFG.TweenSpeed)
			task.wait(0.12)
			invokeRemote("Eggs: RequestAreaEggDrop")
			fireRemote("Guards: ForestDeposit")
		end
	end

	task.wait(CFG.StealDelay)
end

local function stepAutoCollect()
	fireRemote("ActiveAssets: MoneyCollected")
	invokeRemote("OfflineAssets: Redeem")

	local plot = getLocalPlot()
	local root = getRoot()
	if plot and root then
		for _, d in ipairs(plot:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				local at = (d.ActionText or ""):lower()
				if at:find("collect") or at:find("claim") then
					triggerPrompt(d)
				end
			elseif d:IsA("BasePart") then
				local n = d.Name:lower()
				if n:find("money") or n:find("coin") or n:find("pile") then
					pcall(function()
						if firetouchinterest then
							firetouchinterest(root, d, 0)
							task.wait(0.02)
							firetouchinterest(root, d, 1)
						end
					end)
				end
			end
		end
	end
	task.wait(CFG.CollectDelay)
end

local function stepAutoHatch()
	if CFG.AutoSkipGrowth then
		invokeRemote("Eggs: RequestSkipGrowth")
	end
	invokeRemote("Eggs: RequestHatchEgg", CFG.SelectedEgg, CFG.HatchCount)
	invokeRemote("Eggs: RequestCompleteHatchEgg", CFG.SelectedEgg)
	if CFG.AutoPlaceEgg then
		invokeRemote("Eggs: RequestPlaceEgg")
	end
	task.wait(0.6)
end

local function stepAutoTreadmill()
	fireRemote("Treadmills: SpeedGain")
	if CFG.AutoUpgradeTread then
		invokeRemote("Treadmills: RequestUpgrade")
	end
	if CFG.AutoEquipBestTread then
		invokeRemote("Treadmills: RequestEquipStatic")
	end
	-- touch treadmill parts near player
	local root = getRoot()
	if root then
		for _, obj in ipairs(Workspace:GetDescendants()) do
			if obj:IsA("BasePart") and obj.Name:lower():find("tread") then
				if (obj.Position - root.Position).Magnitude < 40 then
					pcall(function()
						if firetouchinterest then
							firetouchinterest(root, obj, 0)
							task.wait(0.02)
							firetouchinterest(root, obj, 1)
						end
					end)
				end
			end
		end
	end
	task.wait(0.35)
end

local function stepBaseUpgrade()
	invokeRemote("Plots: RequestBaseUpgrade")
	task.wait(1.2)
end

local function sellAllAssets()
	fireRemote("AssetInventory: SellAllAssets")
	invokeRemote("Index: RequestClaimAll")
end

-- ===================== ESP =====================
local espFolder
local function ensureESPFolder()
	if espFolder and espFolder.Parent then
		return espFolder
	end
	local parent = (typeof(gethui) == "function" and gethui()) or game:GetService("CoreGui")
	local old = parent:FindFirstChild("ConstipatedEggESP")
	if old then
		old:Destroy()
	end
	espFolder = Instance.new("Folder")
	espFolder.Name = "ConstipatedEggESP"
	espFolder.Parent = parent
	return espFolder
end

local function clearESP()
	if espFolder then
		espFolder:ClearAllChildren()
	end
end

local function makeHighlight(adornee, color, name)
	local folder = ensureESPFolder()
	local h = Instance.new("Highlight")
	h.Name = name or "hl"
	h.Adornee = adornee
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.55
	h.OutlineTransparency = 0.2
	h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	h.Parent = folder
	return h
end

local function makeBillboard(adornee, text, color)
	local folder = ensureESPFolder()
	local bb = Instance.new("BillboardGui")
	bb.Name = "bb"
	bb.Adornee = adornee
	bb.Size = UDim2.fromOffset(120, 28)
	bb.StudsOffset = Vector3.new(0, 3, 0)
	bb.AlwaysOnTop = true
	bb.Parent = folder
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.GothamBold
	tl.TextSize = 13
	tl.TextColor3 = color
	tl.TextStrokeTransparency = 0.4
	tl.Text = text
	tl.Parent = bb
	return bb
end

local function refreshESP()
	clearESP()
	local root = getRoot()
	if not root then
		return
	end

	if CFG.EggESP then
		for _, t in ipairs(scanStealTargets()) do
			if t.Part and (t.Part.Position - root.Position).Magnitude <= CFG.MaxESPDist then
				local col = Color3.fromRGB(80, 255, 120)
				if t.Score >= 7 then
					col = Color3.fromRGB(255, 80, 220)
				elseif t.Score >= 5 then
					col = Color3.fromRGB(255, 200, 60)
				elseif t.Score >= 4 then
					col = Color3.fromRGB(80, 160, 255)
				end
				local model = t.Obj:IsA("Model") and t.Obj or t.Obj.Parent
				if model and model:IsA("Model") then
					makeHighlight(model, col, "egg")
				else
					makeHighlight(t.Part, col, "egg")
				end
				makeBillboard(t.Part, string.format("%s [%s]", t.Rarity or "?", t.Source or ""), col)
			end
		end
	end

	if CFG.PlayerESP then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer and plr.Character then
				local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
				if hrp and (hrp.Position - root.Position).Magnitude <= CFG.MaxESPDist then
					makeHighlight(plr.Character, Color3.fromRGB(80, 180, 255), "plr")
					makeBillboard(hrp, plr.Name, Color3.fromRGB(80, 180, 255))
				end
			end
		end
	end

	if CFG.GuardESP then
		for _, obj in ipairs(Workspace:GetDescendants()) do
			local n = obj.Name:lower()
			if (n:find("guard") or n:find("staff") or n:find("security")) and (obj:IsA("Model") or obj:IsA("BasePart")) then
				local p = partOf(obj)
				if p and (p.Position - root.Position).Magnitude <= CFG.MaxESPDist then
					makeHighlight(obj:IsA("Model") and obj or p, Color3.fromRGB(255, 70, 70), "guard")
					makeBillboard(p, "GUARD", Color3.fromRGB(255, 70, 70))
				end
			end
		end
	end
end

-- ===================== MOVEMENT LOOPS =====================
RunService.Stepped:Connect(function()
	if not alive() then
		return
	end
	if CFG.Noclip then
		local c = getChar()
		if c then
			for _, p in ipairs(c:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
				end
			end
		end
	end
end)

RunService.Heartbeat:Connect(function()
	if not alive() then
		return
	end
	local hum = getHum()
	if not hum then
		return
	end
	if CFG.WalkSpeedOn then
		hum.WalkSpeed = CFG.WalkSpeed
	end
	if CFG.JumpOn then
		hum.UseJumpPower = true
		hum.JumpPower = CFG.JumpPower
	end
end)

UserInputService.JumpRequest:Connect(function()
	if CFG.InfJump and alive() then
		local hum = getHum()
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

-- ===================== UI =====================
local Window = OrionLib:MakeWindow({
	Name = "Constipated Hub | Steal An Egg",
	HidePremium = true,
	SaveConfig = false,
	IntroEnabled = false,
})

local TabMain = Window:MakeTab({ Name = "Main", Icon = "rbxassetid://4483362748", PremiumOnly = false })
local TabEgg = Window:MakeTab({ Name = "Eggs", Icon = "rbxassetid://4483362458", PremiumOnly = false })
local TabVis = Window:MakeTab({ Name = "Visuals", Icon = "rbxassetid://4483345998", PremiumOnly = false })
local TabPlayer = Window:MakeTab({ Name = "Player", Icon = "rbxassetid://4483342657", PremiumOnly = false })
local TabMisc = Window:MakeTab({ Name = "Misc", Icon = "rbxassetid://4483345998", PremiumOnly = false })

-- Main
TabMain:AddToggle({
	Name = "Auto Steal (Rarest First)",
	Default = false,
	Callback = function(v)
		CFG.AutoSteal = v
	end,
})

TabMain:AddDropdown({
	Name = "Steal Method",
	Default = "Tween",
	Options = { "Tween", "Instant" },
	Callback = function(v)
		CFG.StealMethod = v
	end,
})

TabMain:AddSlider({
	Name = "Tween Speed",
	Min = 30,
	Max = 140,
	Default = 70,
	Increment = 5,
	Callback = function(v)
		CFG.TweenSpeed = v
	end,
})

TabMain:AddSlider({
	Name = "Steal Delay",
	Min = 0.1,
	Max = 2,
	Default = 0.28,
	Increment = 0.05,
	Callback = function(v)
		CFG.StealDelay = v
	end,
})

TabMain:AddDropdown({
	Name = "Min Rarity",
	Default = "Common",
	Options = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Limited" },
	Callback = function(v)
		CFG.MinRarity = v
	end,
})

TabMain:AddToggle({
	Name = "Rarest Target First",
	Default = true,
	Callback = function(v)
		CFG.RarestFirst = v
	end,
})

TabMain:AddToggle({
	Name = "Scan Enemy Plots",
	Default = true,
	Callback = function(v)
		CFG.PreferEnemyPlots = v
	end,
})

TabMain:AddToggle({
	Name = "Scan Area / World Eggs",
	Default = true,
	Callback = function(v)
		CFG.AreaEggs = v
	end,
})

TabMain:AddToggle({
	Name = "Auto Deposit After Steal",
	Default = true,
	Callback = function(v)
		CFG.AutoDeposit = v
	end,
})

TabMain:AddToggle({
	Name = "Auto Collect Income",
	Default = false,
	Callback = function(v)
		CFG.AutoCollect = v
	end,
})

TabMain:AddToggle({
	Name = "Auto Treadmill",
	Default = false,
	Callback = function(v)
		CFG.AutoTreadmill = v
	end,
})

TabMain:AddToggle({
	Name = "Auto Upgrade Treadmill",
	Default = true,
	Callback = function(v)
		CFG.AutoUpgradeTread = v
	end,
})

TabMain:AddToggle({
	Name = "Auto Base Upgrade",
	Default = false,
	Callback = function(v)
		CFG.AutoBaseUpgrade = v
	end,
})

TabMain:AddButton({
	Name = "Unstuck / Return Plot",
	Callback = function()
		doUnstuck()
		OrionLib:MakeNotification({ Name = "Constipated Hub", Content = "Unstuck fired", Time = 2 })
	end,
})

TabMain:AddButton({
	Name = "Sell All Assets Now",
	Callback = function()
		sellAllAssets()
		OrionLib:MakeNotification({ Name = "Constipated Hub", Content = "Sell fired", Time = 2 })
	end,
})

-- Eggs
TabEgg:AddToggle({
	Name = "Auto Hatch",
	Default = false,
	Callback = function(v)
		CFG.AutoHatch = v
	end,
})

TabEgg:AddDropdown({
	Name = "Egg Type",
	Default = "Starter Egg",
	Options = EGG_TYPES,
	Callback = function(v)
		CFG.SelectedEgg = v
	end,
})

TabEgg:AddSlider({
	Name = "Hatch Count",
	Min = 1,
	Max = 10,
	Default = 1,
	Increment = 1,
	Callback = function(v)
		CFG.HatchCount = v
	end,
})

TabEgg:AddToggle({
	Name = "Skip Growth",
	Default = true,
	Callback = function(v)
		CFG.AutoSkipGrowth = v
	end,
})

TabEgg:AddToggle({
	Name = "Auto Place Egg",
	Default = true,
	Callback = function(v)
		CFG.AutoPlaceEgg = v
	end,
})

TabEgg:AddButton({
	Name = "Hatch Once Now",
	Callback = function()
		stepAutoHatch()
	end,
})

-- Visuals
TabVis:AddToggle({
	Name = "Egg ESP",
	Default = true,
	Callback = function(v)
		CFG.EggESP = v
		if not v then
			clearESP()
		end
	end,
})

TabVis:AddToggle({
	Name = "Player ESP",
	Default = false,
	Callback = function(v)
		CFG.PlayerESP = v
	end,
})

TabVis:AddToggle({
	Name = "Guard ESP",
	Default = true,
	Callback = function(v)
		CFG.GuardESP = v
	end,
})

TabVis:AddSlider({
	Name = "Max ESP Distance",
	Min = 100,
	Max = 2000,
	Default = 800,
	Increment = 50,
	Callback = function(v)
		CFG.MaxESPDist = v
	end,
})

TabVis:AddButton({
	Name = "Refresh ESP",
	Callback = function()
		refreshESP()
	end,
})

-- Player
TabPlayer:AddToggle({
	Name = "WalkSpeed",
	Default = false,
	Callback = function(v)
		CFG.WalkSpeedOn = v
	end,
})

TabPlayer:AddSlider({
	Name = "WalkSpeed Value",
	Min = 16,
	Max = 120,
	Default = 28,
	Increment = 1,
	Callback = function(v)
		CFG.WalkSpeed = v
	end,
})

TabPlayer:AddToggle({
	Name = "JumpPower",
	Default = false,
	Callback = function(v)
		CFG.JumpOn = v
	end,
})

TabPlayer:AddSlider({
	Name = "JumpPower Value",
	Min = 50,
	Max = 200,
	Default = 60,
	Increment = 5,
	Callback = function(v)
		CFG.JumpPower = v
	end,
})

TabPlayer:AddToggle({
	Name = "Noclip",
	Default = false,
	Callback = function(v)
		CFG.Noclip = v
	end,
})

TabPlayer:AddToggle({
	Name = "Infinite Jump",
	Default = false,
	Callback = function(v)
		CFG.InfJump = v
	end,
})

-- Misc
TabMisc:AddToggle({
	Name = "Anti AFK",
	Default = true,
	Callback = function(v)
		CFG.AntiAFK = v
	end,
})

TabMisc:AddButton({
	Name = "Claim Index / Limited Rewards",
	Callback = function()
		invokeRemote("Index: RequestClaimAll")
		invokeRemote("Index: RequestClaimLimitedEggReward")
	end,
})

TabMisc:AddButton({
	Name = "Unload Hub",
	Callback = function()
		GENV.__ConstipatedEggGen = GEN + 1
		clearESP()
		pcall(function()
			OrionLib:Destroy()
		end)
	end,
})

TabMisc:AddParagraph(
	"Info",
	"Constipated Hub | Steal An Egg\nRemotes from open DKHUB\nRarest-first steal · stuck recovery · guard ESP"
)

-- ===================== TASK LOOPS =====================
task.spawn(function()
	while alive() do
		if CFG.AutoSteal then
			pcall(stepAutoSteal)
		else
			task.wait(0.25)
		end
	end
end)

task.spawn(function()
	while alive() do
		if CFG.AutoCollect then
			pcall(stepAutoCollect)
		else
			task.wait(0.5)
		end
	end
end)

task.spawn(function()
	while alive() do
		if CFG.AutoHatch then
			pcall(stepAutoHatch)
		else
			task.wait(0.5)
		end
	end
end)

task.spawn(function()
	while alive() do
		if CFG.AutoTreadmill then
			pcall(stepAutoTreadmill)
		else
			task.wait(0.5)
		end
	end
end)

task.spawn(function()
	while alive() do
		if CFG.AutoBaseUpgrade then
			pcall(stepBaseUpgrade)
		else
			task.wait(1)
		end
	end
end)

task.spawn(function()
	while alive() do
		if CFG.EggESP or CFG.PlayerESP or CFG.GuardESP then
			pcall(refreshESP)
		end
		task.wait(1.25)
	end
	clearESP()
end)

OrionLib:MakeNotification({
	Name = "Constipated Hub",
	Content = "Steal An Egg loaded",
	Time = 4,
})

print("[Constipated Hub] Steal An Egg ready")
