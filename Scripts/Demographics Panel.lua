-- LuaScript1
-- Author: Benji
-- DateCreated: 10/25/2017 6:27:12 PM
--------------------------------------------------------------
include("InstanceManager");
include("SupportFunctions");
include("CitySupport");

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
				if p:GetID() >= 0 then
					demographics[p:GetID()] = pop
				end

			end
		end
	end
	return demographics
end

local count = 0;
local players = 30;

--[[Create demographics through GetDemographics function
	Iterate through table and print player id and total population]]
function ConditionalPrintPop()
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
function PlayerTurnStarted()
	local context = ContextPtr
	local control = Controls
	if context ~= nil then
		ContextPtr:LookUpControl("message"):SetText("MESSAGE HERE")
	end
	GameEvents.PlayerTurnStarted.Add(ConditionalPrintPop)
end

GameEvents.PlayerTurnStarted.Add(PlayerTurnStarted)

function OnOK()
	Controls.D_BOX:SetHide(true) --Change to destroy?
end

function RigOkButton()
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