-- LuaScript1
-- Author: Benji
-- DateCreated: 10/25/2017 6:27:12 PM
--------------------------------------------------------------
include("InstanceManager");
include("SupportFunctions");
include("CitySupport");

local human_id = nil

local function IsValidPlayer(player)
	if player == nil then return false end
	if player:IsAlive() ~= true then return false end
	if player:GetID() < 0 then return false end
	return true
end

local function GetLand(player)
	local size = 0
	if IsValidPlayer(player) then
		local cities = player:GetCities()
		for i, c in cities:Members() do
			if c then
				for s,z in 	pairs(Map.GetCityPlots():GetPurchasedPlots(c)) do
					size = size + 1
				end
			end
		end
	end
	return size * 10000
end

--[[Get real military might for player]]
local function GetMight(player)
	if IsValidPlayer(player) == false then return 0 end
	local might = player:GetStats():GetMilitaryStrength()
	might = math.sqrt(might) * 2000
	return might
end

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

local function GetGoods(player)
	local goods = 0
	if IsValidPlayer(player) == false then return 0 end
	for x, c in player:GetCities():Members() do
		goods = goods + c:GetBuildQueue():GetProductionYield()
	end
	return goods
end

local function GetGoodsDemographics()
	local demographics = {}
	for k, p in pairs(Players) do
		if IsValidPlayer(p) then
			if p:GetID() >= 0 and p:IsAlive() then
				demographics[p:GetID()] = GetGoods(p)
			end

		end
	end
	return demographics
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

--[[Get Military might for all alive players in game]]
local function GetMilitaryMight()
	local m_might = {}
	for k, p in pairs(Players) do
		if p then
			if p ~= nil then
				if p:GetID() >= 0 and p:IsAlive() then
					m_might[p:GetID()] = GetMight(p)
				end
			end
		end
	end
	return m_might
end

local function GetLandAll()
	local land = {}
	for x, p in pairs(Players) do
		if IsValidPlayer(p) then
			if p:GetID() >= 0 then
				land[p:GetID()] = GetLand(p)
			end
		end
	end
	return land
end

local function GetCropYield(player)
	-- get crop yield of player
end

local function GetGNP(player)
	local GNP = 0
	if IsValidPlayer(player) then
		GNP = player:GetTreasury():GetGoldYield()
	end
	return GNP
end

local function GetGNPAll()
	local gnp = {}
	for x, p in pairs(Players) do
		if IsValidPlayer(p) then
			if p:GetID() >= 0 then
				gnp[p:GetID()] = GetGNP(p)
			end
		end
	end
	return gnp
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
--[[
local function SetFields(field)
	-- place holder to reduce redundant code use flags
	local demographics = nil
	if(field == "population") then 
	print("getting demographics")
	local demographics = GetDemographics()
	local rank = 1
	local average = 0
	local worst = 0
	local best = 0
	local count = 0

	-- get and set population value
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

	-- Set all population fields
	print("setting population value")
	Controls.pop_value:SetText(tostring(demographics[human_id]))

	print("setting rank: ", rank)
	Controls.pop_rank:SetText(tostring(rank))

	print("setting worst: ", worst)
	Controls.pop_worst:SetText(tostring(worst))

	print("setting best: ", best)
	Controls.pop_best:SetText(tostring(best))

	average = math.ceil(average / count)
	print("setting average: ", average)
	Controls.pop_average:SetText(tostring(average))
end]]

--[[Add custom function to fire when PlayerTurnStarted event fires]]
function UpdatePanel()
	print("getting demographics")
	local demographics = GetDemographics()
	print("creating string")
	local rank = 1
	local average = 0
	local worst = 0
	local best = 0
	local count = 0

	-- get and set population value
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

	-- Set all population fields
	print("setting population value")
	Controls.pop_value:SetText(tostring(demographics[human_id]))

	print("setting rank: ", rank)
	Controls.pop_rank:SetText(tostring(rank))

	print("setting worst: ", worst)
	Controls.pop_worst:SetText(tostring(worst))

	print("setting best: ", best)
	Controls.pop_best:SetText(tostring(best))

	average = math.ceil(average / count)
	print("setting average: ", average)
	Controls.pop_average:SetText(tostring(average))

	demographics = GetMilitaryMight()
	tmp = demographics[human_id]
	average = 0
	count = 0
	best = tmp
	worst = tmp
	rank = 1
	for i, j in pairs(demographics) do
		if i >= 0 then
			if j > tmp then rank = rank + 1 end
			if j < worst then worst = j end
			if j > best then best = j end
			average = average + j
			count = count + 1
		end
	end

	print("setting military values")
	Controls.mil_value:SetText(tostring(math.ceil(demographics[human_id])))

	print("setting rank: ", rank)
	Controls.mil_rank:SetText(tostring(rank))

	worst = math.ceil(worst)
	print("setting worst: ", worst)
	Controls.mil_worst:SetText(tostring(worst))
	
	best = math.ceil(best)
	print("setting best: ", best)
	Controls.mil_best:SetText(tostring(best))

	average = math.ceil(average / count)
	print("setting average: ", average)
	Controls.mil_average:SetText(tostring(average))

	demographics = GetLandAll()
	tmp = demographics[human_id]
	best = tmp
	worst = tmp
	rank = 1
	average = 0
	count = 0
	for i, j in pairs(demographics) do
		if i >= 0 then
			print(j)
			if j > tmp then rank = rank + 1 end
			if j < worst then worst = j end
			if j > best then best = j end
			average = average + j
			count = count + 1
		end
	end

	print("setting land values")
	Controls.land_value:SetText(tostring(math.ceil(tmp)))

	print("setting rank: ", rank)
	Controls.land_rank:SetText(tostring(rank))

	worst = math.ceil(worst)
	print("setting worst: ", worst)
	Controls.land_worst:SetText(tostring(worst))
	
	best = math.ceil(best)
	print("setting best: ", best)
	Controls.land_best:SetText(tostring(best))

	if count ~= 0 then
		average = math.ceil(average / count)
		print("setting average: ", average)
		Controls.land_average:SetText(tostring(average))
	end

	demographics = GetGoodsDemographics()
	tmp = demographics[human_id]
	best = tmp
	worst = tmp
	rank = 1
	average = 0
	count = 0
	for i, j in pairs(demographics) do
		if i >= 0 then
			print(j)
			if j > tmp then rank = rank + 1 end
			if j < worst then worst = j end
			if j > best then best = j end
			average = average + j
			count = count + 1
		end
	end

	print("setting goods values")
	Controls.goods_value:SetText(tostring(math.ceil(tmp)))

	print("setting rank: ", rank)
	Controls.goods_rank:SetText(tostring(rank))

	worst = math.ceil(worst)
	print("setting worst: ", worst)
	Controls.goods_worst:SetText(tostring(worst))
	
	best = math.ceil(best)
	print("setting best: ", best)
	Controls.goods_best:SetText(tostring(best))

	if count ~= 0 then
		average = math.ceil(average / count)
		print("setting average: ", average)
		Controls.goods_average:SetText(tostring(average))
	end

	demographics = GetGNPAll()
	tmp = demographics[human_id]
	best = tmp
	worst = tmp
	rank = 1
	average = 0
	count = 0
	for i, j in pairs(demographics) do
		if i >= 0 then
			print(j)
			if j > tmp then rank = rank + 1 end
			if j < worst then worst = j end
			if j > best then best = j end
			average = average + j
			count = count + 1
		end
	end

	print("setting dnp values")
	Controls.gnp_value:SetText(tostring(math.ceil(tmp)))

	print("setting rank: ", rank)
	Controls.gnp_rank:SetText(tostring(rank))

	worst = math.ceil(worst)
	print("setting worst: ", worst)
	Controls.gnp_worst:SetText(tostring(worst))
	
	best = math.ceil(best)
	print("setting best: ", best)
	Controls.gnp_best:SetText(tostring(best))

	if count ~= 0 then
		average = math.ceil(average / count)
		print("setting average: ", average)
		Controls.gnp:SetText(tostring(average))
	end

end

--GameEvents.PlayerTurnStarted.Add(PlayerTurnStarted)

function OnOK()
	--Controls.D_BOX:SetHide(true) --Change to destroy?
	UpdatePanel()
end

-- change in case of multiplayers or hotseat
function Init()
	for i, j in pairs(Players) do
		if j then
			if j:IsHuman() then human_id = j:GetID() break end
		end
	end
	--UpdatePanel()
	Controls.OK:RegisterCallback(Mouse.eLClick, OnOK)
end

Events.LoadComplete.Add(Init)

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