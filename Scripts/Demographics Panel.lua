-- LuaScript1
-- Author: Benji
-- DateCreated: 10/25/2017 6:27:12 PM
--------------------------------------------------------------
include("InstanceManager");
include("SupportFunctions");
include("CitySupport");

local human_id = nil

-- ADD IS EVER ALIVE TO PLAYER BEFORE FUNCITON CALL
--[[Get total population of player's empire.
	return total population]]
local function GetPop(player)
	if(player == nil) then return 0 end
	local cities = player:GetCities()
	if(cities == nil) then return 0 end
	local population = 0
	for i, c in cities:Members() do
		if c then
			population = population + 1000*c:GetPopulation()^2.8
		end
	end
	return population
end

local function GetName(player)
	return "placeholder"
end

--[[Get the total population of all cities for each player.
	Store in table according to player ID]]
local function GetDemographics()
	local demographics = {}
	for k, p in pairs(Players) do
		if p then
			if(p ~= nil) then
				local pop = GetPop(p)
				pop = math.ceil(pop)
				if p:GetID() >= 0 and p:IsAlive() then
					demographics[p:GetID()] = pop
				end

			end
		end
	end
	return demographics
end

local function GetCropYield(player)
	-- get crop yield of player
end

local function GetLand(player)
	-- get total land of player
end

local function GetGNP(player)
	-- get gnp of player
end

local count = 0;
local players = 30;

--[[Create demographics through GetDemographics function
	Iterate through table and print player id and total population]]
function UpdatePopulation()
	local demographics = nil
	if count >= players then
				-- Temporary way to trigger refresh
				demographics = GetDemographics()
				for n, p in pairs(demographics) do
					if(p) then print(n, ": ", p) end
				end
				count = 0
	else count = count + 1 end
end

--[[Add custom function to fire when PlayerTurnStarted event fires]]
function UpdatePanel()
	print("getting demographics")
	local demographics = GetDemographics()
	print("creating string")
	local pop_text :string = ""
	local gnp_text	:string = ""
	local land_text :string = ""
	local crop_yield :string = ""
	local rank = 1
	local average = 0
	local worst = 0
	local best = 0
	local count = 0
	-- get and set population value
	pop_text = pop_text .. demographics[human_id]-- get democraphic of player. Currently incorrect. Need to get ID of active player
	Controls.pop_value:SetText(pop_text)
	local tmp = demographics[human_id]
	best = tmp
	worst = tmp
	for i, j in pairs(demographics) do
		if i >= 0 then
			if j > tmp then rank = rank + 1 end
			if j < worst then worst = j end
			if j > best then best = j end
			average = average + j
			count = count + 1
		end
	end

	pop_text = ""
	pop_text = pop_text .. rank
	print("setting rank: ", rank)
	Controls.pop_rank:SetText(pop_text)

	pop_text = ""
	pop_text = pop_text .. worst
	print("setting worst: ", worst)
	Controls.pop_worst:SetText(pop_text)

	pop_text = ""
	pop_text = pop_text .. best
	print("setting best: ", best)
	Controls.pop_best:SetText(pop_text)

	pop_text = ""
	pop_text = pop_text .. math.ceil(average / count)
	print("setting average: ", pop_text)
	Controls.pop_average:SetText(pop_text)
end

--GameEvents.PlayerTurnStarted.Add(PlayerTurnStarted)

function OnOK()
	--Controls.D_BOX:SetHide(true) --Change to destroy?
	UpdatePanel()
end

-- change in case of multiplayers or hotseat
function RigOkButton()
	for i, j in pairs(Players) do
		if j then
			if j:IsHuman() then human_id = j:GetID() break end
		end
	end
	Controls.OK:RegisterCallback(Mouse.eLClick, OnOK)
end

Events.LoadComplete.Add(RigOkButton)

--[[Add custom fire to show test window when GameplaySetActivePlayer
	event fires]]
local bIsRegistered = false
function SetActivePlayer(iPlayer, iPrevPlayer)
  if (not bIsRegistered) then
    local control = ContextPtr
	if control ~= nil then 
		control:SetHide(false)
	else print("NO CONTROL STILL") end
  end
end

GameEvents.GameplaySetActivePlayer.Add(SetActivePlayer)

function print_this(T)
	for i,j in pairs(T) do
		print("i: ", i)
	end
end