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
	local total_yield = 0
	if IsValidPlayer(player) == false then return 0 end
	for x, c in player:GetCities():Members() do
		total_yield = total_yield + c:GetYield()
	end
	return total_yield
end

local function GetCropYieldAll()
	local demographics = {}
	for k, p in pairs(Players) do
		if p then
			if(p ~= nil) then
				if p:GetID() >= 0 and p:IsAlive() then
					demographics[p:GetID()] = GetCropYield(p)
				end
			end
		end
	end
	return demographics
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

local function UpdateField(field)
	-- place holder to reduce redundant code use flags
	local demographics = nil
	if(field == "population") then 
		demographics = GetDemographics()
	elseif(field == "gnp") then 
		demographics = GetGNPAll()
	elseif(field == "military") then 
		demographics = GetMilitaryMight()
	elseif(field == "goods") then 
		demographics = GetGoodsDemographics()
	elseif(field == "land") then 
		demographics = GetLandAll()
	elseif(field == "crop_yield") then 
		demographics = GetCropYieldAll()
	else 
		return 0
	end

	print("getting demographics")
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

	average = math.ceil(average / count)
	worst = math.ceil(worst)
	best = math.ceil(best)
	local value = math.ceil(demographics[human_id])
	-- Set all population fields
	print("updating ", field, " fields")
	if(field == "population") then 
		Controls.pop_value:SetText(tostring(value))
		Controls.pop_rank:SetText(tostring(rank))
		Controls.pop_worst:SetText(tostring(worst))
		Controls.pop_best:SetText(tostring(best))
		Controls.pop_average:SetText(tostring(average))
	elseif(field == "gnp") then 
		Controls.gnp_value:SetText(tostring(value))
		Controls.gnp_rank:SetText(tostring(rank))
		Controls.gnp_worst:SetText(tostring(worst))
		Controls.gnp_best:SetText(tostring(best))
		Controls.gnp_average:SetText(tostring(average))
	elseif(field == "military") then 
		Controls.mil_value:SetText(tostring(value))
		Controls.mil_rank:SetText(tostring(rank))
		Controls.mil_worst:SetText(tostring(worst))
		Controls.mil_best:SetText(tostring(best))
		Controls.mil_average:SetText(tostring(average))
	elseif(field == "goods") then 
		Controls.goods_value:SetText(tostring(value))
		Controls.goods_rank:SetText(tostring(rank))
		Controls.goods_worst:SetText(tostring(worst))
		Controls.goods_best:SetText(tostring(best))
		Controls.goods_average:SetText(tostring(average))
	elseif(field == "land") then 
		Controls.land_value:SetText(tostring(value))
		Controls.land_rank:SetText(tostring(rank))
		Controls.land_worst:SetText(tostring(worst))
		Controls.land_best:SetText(tostring(best))
		Controls.land_average:SetText(tostring(average))
	elseif(field == "crop_yield") then
		Controls.crop_value:SetText(tostring(demographics[human_id]))
		Controls.crop_rank:SetText(tostring(rank))
		Controls.crop_worst:SetText(tostring(worst))
		Controls.crop_best:SetText(tostring(best))
		Controls.crop_average:SetText(tostring(average))
	else 
		return 0
	end
	--else if(field == "crop_yield") return 0
	
end

--[[Update panel by rewriting to all fields]]
function UpdatePanel()
	UpdateField("population")
	UpdateField("gnp")
	UpdateField("military")
	UpdateField("goods")
	UpdateField("land")
	UpdateField("crop_yield")
end

function OnOK()
	UpdatePanel()
end

function ClosePanel()
	Controls.D_BOX:SetHide(true)
end

-- change in case of multiplayers or hotseat
function Init()
	for i, j in pairs(Players) do
		if j then
			if j:IsHuman() then human_id = j:GetID() break end
		end
	end
	UpdatePanel()
	Controls.OK:RegisterCallback(Mouse.eLClick, OnOK)
	Controls.Close:RegisterCallback(Mouse.eLClick, ClosePanel)
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