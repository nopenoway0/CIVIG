-- LuaScript1
-- Author: Benji
-- DateCreated: 10/25/2017 6:27:12 PM
--------------------------------------------------------------
include("SupportFunctions")
include("InstanceManager")

-- data is stored in the following fashion:
-- 

local human_id = nil
local start_year :number = nil
local context_store = nil
local population_graphs = {}
local mil_graphs = {}
local gnp_graphs = {}
local goods_graphs = {}
local crops_graphs = {}
local land_graphs = {}
local graph_maxes = {}
local graph_legend = nil
local button_instance_manager = nil
local current_graph_field = nil
local graph_types = nil -- the relevant graphs follow the following format: type_graph TODO: change population_graphs to pop_graphs | initialized in init
local graphs_enabled = {}

-- Convert year to number format. BC converts the number into negative
local function YearToNumber(input)
	local output :number = tonumber(input:gsub('[A-Z]+', ''):sub(0))
	if input:find("BC") then
		output = output * -1
	end
	return output
end

--[[Determines of the player is valid. A player is valid IF that player exists
	and that player is a major civ. Civ states are not considered valid players in this mode
]]
local function IsValidPlayer(player)
	if player == nil then return false end
	if player:IsMajor() == false then return false end 
	return true
end

--[[ Load the data relevant to the inputted player
]]
local function LoadData(player)
	if IsValidPlayer(player) == false then return -1 end
	local sequence :string = GameConfiguration.GetValue("year_sequence") -- in order to make sure all data is retrieved the year sequence must be retrieved
	local years = {}
	local data = {}
	local complete_data = {}
	if sequence == nil then return -1 end
	sequence:gsub( "%-?%d+", function(i) table.insert(years, i) end)
	local prefix = tostring(player:GetID()) .. "_"
	for x,z in pairs(years) do
		data = {}
		-- use fixed names in global variable
		data["year"] = tonumber(z)
		data["pop"] = GameConfiguration.GetValue(prefix .. tostring(z) .. "_POP")
		data["mil"] = GameConfiguration.GetValue(prefix .. tostring(z) .. "_MIL")
		data["gnp"] = GameConfiguration.GetValue(prefix .. tostring(z) .. "_GNP")
		data["crop"] = GameConfiguration.GetValue(prefix .. tostring(z) .. "_CROP")
		data["land"] = GameConfiguration.GetValue(prefix .. tostring(z) .. "_LAND")
		data["goods"] = GameConfiguration.GetValue(prefix .. tostring(z) .. "_GOODS")
		table.insert(complete_data, data) -- store the current years data into the complete data table
	end

	return complete_data
end

local function Save(key, input)
	if type(input) == "string" or type(input) == "number" then
		GameConfiguration.SetValue(key, input)
	else 
		return -1
	end
end

local function Load(key)
	local value = GameConfiguration.GetValue(key)
	return value
end

--[[ Gets icon for that civilization. anything aside from a number will set the icon to the civilization
	unknown emblem
]]
function SetIcon(control, id)
	local icon = "ICON_"
	if type(id) == "number" then
		local cTop_player = PlayerConfigurations[id]
		local icon = icon .. cTop_player:GetCivilizationTypeName()
		control:SetIcon(icon)
	else
		icon = icon .. "CIVILIZATION_UNKNOWN"
	end
	control:SetIcon(icon)
end

--[[Get "real" land owned by that player. This is done by retrieving the total number of tiles the player owns
	and then multiplying these tiles by 10,000
]]
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

--[[Get real military might for player
	might = sqrt(military_strength)*2000
]]
local function GetMight(player)
	if IsValidPlayer(player) == false then return 0 end
	local might = player:GetStats():GetMilitaryStrength()
	might = math.sqrt(might) * 2000
	return might
end

--[[Get total population of player's empire.
	return total population. The population is retrieved from each city and put into
	the following formula: 1000*population^2.8 then added to the rest of the population
]]
local function GetPop(player)
	if IsValidPlayer(player) == false then return 0 end
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

--[[
	Not currently used. Should get name of the player passed in. May be used in the future
	for easy localization
]]
local function GetName(player)
	return "placeholder"
end

--[[
	Get goods. The sum of all production of the player's cities
]]
local function GetGoods(player)
	local goods = 0
	if IsValidPlayer(player) == false then return 0 end
	for x, c in player:GetCities():Members() do
		goods = goods + c:GetBuildQueue():GetProductionYield()
	end
	return goods
end

--[[ Get a table consisting of all players goods results
]]
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
			if IsValidPlayer(p) then
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
			if IsValidPlayer(p) then
				m_might[p:GetID()] = GetMight(p)
			end
		end
	end
	return m_might
end

--[[ Get a table of all land values for each player
]]
local function GetLandAll()
	local land = {}
	for x, p in pairs(Players) do
		if IsValidPlayer(p) then
			land[p:GetID()] = GetLand(p)
		end
	end
	return land
end

--[[Sum of all cities' yields
]]
local function GetCropYield(player)
	-- get crop yield of player
	local total_yield = 0
	if IsValidPlayer(player) == false then return 0 end
	for x, c in player:GetCities():Members() do
		total_yield = total_yield + c:GetYield()
	end
	return total_yield
end

--[[ Table of all players yields
]]
local function GetCropYieldAll()
	local demographics = {}
	for k, p in pairs(Players) do
		if p then
			if IsValidPlayer(p) then
				demographics[p:GetID()] = GetCropYield(p)
			end
		end
	end
	return demographics
end

--[[ Players gold yield
]]
local function GetGNP(player)
	local GNP = 0
	if IsValidPlayer(player) then
		GNP = player:GetTreasury():GetGoldYield()
	end
	return GNP
end

--[[ Table of all players Gold yield
]]
local function GetGNPAll()
	local gnp = {}
	for x, p in pairs(Players) do
		if IsValidPlayer(p) then
			gnp[p:GetID()] = GetGNP(p)
		end
	end
	return gnp
end

--[[ Get suffix of inputted number. e.g. 1000 = k and the result after division 1000 = 1
]]
local function GetSuffix(input)
	local billion = 1000000000
	local million = 1000000
	local thousand = 1000
	local suffix = ""
	local result = {}
	if input > billion then
		suffix = "B"
		input = input / billion
	elseif input > million then
		suffix = "M"
		input = input / million
	elseif input > thousand then
		suffix = "K"
		input = input / thousand
	else
		suffix = ""
	end

	input = input * 100
	input = math.ceil(input)
	input = input / 100

	--print("after round: ", input)
	result[0] = input
	result[1] = suffix
	return result
end

--[[ Updates corresponding field in the rankings panel
]]
local function UpdateField(field)
	-- place holder to reduce redundant code use flags
	local demographics = nil
	local suffix = ""
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

	--print("getting demographics")
	local rank = 1
	local average = 0
	local worst = 0
	local best = 0
	local count = 0
	local result = nil
	local civ_id = {}
	local control_best = nil
	local control_worst = nil
	
	-- set all fields in civ id to human by default
	civ_id["best"] = human_id
	civ_id["worst"] = human_id
	-- get and set population value
	local tmp = demographics[human_id]
	best = tmp
	worst = tmp
	for i, j in pairs(demographics) do
		if i >= 0 then
			if Players[i]:IsAlive() then
				if j > tmp then rank = rank + 1 end
				if j < worst then 
					worst = j
					civ_id["worst"] = i
				end
				if j > best then 
					best = j
					civ_id["best"] = i
				end
				average = average + j
				count = count + 1
			end
		end
	end

	average = math.floor(average / count)
	worst = math.floor(worst)
	best = math.floor(best)
	local value = math.floor(demographics[human_id])
	-- Set field according to input TODO: change input to match the tables so it can be reused
	-- and makes it easy to iterate tables
	if(field == "population") then 
		result = GetSuffix(value)
		Controls.pop_value:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(rank)
		Controls.pop_rank:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(worst)
		Controls.pop_worst:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(best)
		Controls.pop_best:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(average)
		Controls.pop_average:SetText(tostring(result[0]) .. result[1])

		control_best = Controls.pop_best_icon
		control_worst = Controls.pop_worst_icon

	elseif(field == "gnp") then 
		Controls.gnp_value:SetText(tostring(value) .. suffix)
		Controls.gnp_rank:SetText(tostring(rank) .. suffix)
		Controls.gnp_worst:SetText(tostring(worst) .. suffix)
		Controls.gnp_best:SetText(tostring(best) .. suffix)
		Controls.gnp_average:SetText(tostring(average) .. suffix)

		control_best = Controls.gnp_best_icon
		control_worst = Controls.gnp_worst_icon

	elseif(field == "military") then 
		result = GetSuffix(value)
		Controls.mil_value:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(rank)
		Controls.mil_rank:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(worst)
		Controls.mil_worst:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(best)
		Controls.mil_best:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(average)
		Controls.mil_average:SetText(tostring(result[0]) .. result[1])

		control_best = Controls.mil_best_icon
		control_worst = Controls.mil_worst_icon

	elseif(field == "goods") then 
		Controls.goods_value:SetText(tostring(value) .. suffix)
		Controls.goods_rank:SetText(tostring(rank) .. suffix)
		Controls.goods_worst:SetText(tostring(worst) .. suffix)
		Controls.goods_best:SetText(tostring(best) .. suffix)
		Controls.goods_average:SetText(tostring(average) .. suffix)

		control_best = Controls.goods_best_icon
		control_worst = Controls.goods_worst_icon

	elseif(field == "land") then 
		result = GetSuffix(value)
		Controls.land_value:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(rank)
		Controls.land_rank:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(worst)
		Controls.land_worst:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(best)
		Controls.land_best:SetText(tostring(result[0]) .. result[1])
		result = GetSuffix(average)
		Controls.land_average:SetText(tostring(result[0]) .. result[1])

		control_best = Controls.land_best_icon
		control_worst = Controls.land_worst_icon

	elseif(field == "crop_yield") then
		Controls.crop_value:SetText(tostring(demographics[human_id]) .. suffix)
		Controls.crop_rank:SetText(tostring(rank) .. suffix)
		Controls.crop_worst:SetText(tostring(worst) .. suffix)
		Controls.crop_best:SetText(tostring(best) .. suffix)
		Controls.crop_average:SetText(tostring(average) .. suffix)

		control_best = Controls.crop_best_icon
		control_worst = Controls.crop_worst_icon

	else 
		return 0
	end	

	-- if worst is the best, there is no best or worst. Set to question mark. Else set the icon according to the player id
	if worst == best then
		SetIcon(control_best, "none")
		SetIcon(control_worst, "none")
	else
		if Players[human_id]:GetDiplomacy():HasMet(civ_id["best"]) or human_id == civ_id["best"] then SetIcon(control_best, civ_id["best"])
		else SetIcon(control_best, "none") end
		if Players[human_id]:GetDiplomacy():HasMet(civ_id["worst"]) or human_id == civ_id["worst"] then SetIcon(control_worst, civ_id["worst"])
		else SetIcon(control_worst, "none") end
	end
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

--[[ Closes everything in this context]]
function ClosePanel()
	ContextPtr:SetHide(true)
end

-- displays graph, legend, and pulldown. Hides the info panel
local function ShowGraph()
	Controls.InfoPanel:SetHide(true)
	Controls.ResultsGraph:SetHide(false)
	Controls.GraphDataSetPulldown:SetHide(false)
	Controls.GraphLegendStack:SetHide(false)
end

-- Hide graph, legend, and pulldown. displays the info panel
local function ShowInfoPanel()
	Controls.GraphDataSetPulldown:SetHide(true)
	Controls.GraphLegendStack:SetHide(true)
	Controls.ResultsGraph:SetHide(true)
	Controls.InfoPanel:SetHide(false)
end

-- retrieve data for the corresponding player. Constructs the same key using the player id and year
-- as when storing was used
local function GetData(player)
	if IsValidPlayer(player) == false then return -1 end
	local data = {}
	local prefix = tostring(player:GetID()) .. "_"
	prefix = prefix .. tostring(YearToNumber(Calendar.MakeYearStr(Game.GetCurrentGameTurn()))) .. "_"

	-- get population
	data[prefix  .. "POP"] =  math.floor(GetPop(player))
	data[prefix .. "MIL"] = math.floor(GetMight(player))
	data[prefix .. "GNP"] =   math.floor(GetGNP(player))
	data[prefix .. "CROP"] =   math.floor(GetCropYield(player))
	data[ prefix .. "LAND"] =  math.floor(GetLand(player))
	data[prefix .. "GOODS"] =   math.floor(GetGoods(player))

	return data
end

-- calculate numberinterval of the graph
local function GetInterval(low, high)
	local total = nil
	if low < 0 then
		total = math.abs(math.abs(low) - high * -1)
	elseif low > 0 then
		total = high - low
	else
		total = low + high
	end

	if total <= 10 then return total end
	local number_interval = math.floor(total / 10)
	return number_interval
end

-- display the soldiers graph. must make sure that for the corresponding player, the checkbox enables
-- the lines to be shown
local function ShowMilGraph()
	for x,z in pairs(Players) do
		if IsValidPlayer(z) then
			population_graphs[z:GetID()]:SetVisible(false)
			crops_graphs[z:GetID()]:SetVisible(false)
			land_graphs[z:GetID()]:SetVisible(false)
			gnp_graphs[z:GetID()]:SetVisible(false)
			goods_graphs[z:GetID()]:SetVisible(false)
			mil_graphs[z:GetID()]:SetVisible(true and graphs_enabled[z:GetID()])
		end
	end
	local max = math.ceil(graph_maxes["mil"] * 1.1)
	Controls.ResultsGraph:SetRange(0, max)
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText("Soldiers")
	current_graph_field = "mil"	
end

-- same as soldiers graph for population
local function ShowPopGraph()
	for x,z in pairs(Players) do
		if IsValidPlayer(z) then
			population_graphs[z:GetID()]:SetVisible(true and graphs_enabled[z:GetID()])
			crops_graphs[z:GetID()]:SetVisible(false)
			land_graphs[z:GetID()]:SetVisible(false)
			gnp_graphs[z:GetID()]:SetVisible(false)
			goods_graphs[z:GetID()]:SetVisible(false)
			mil_graphs[z:GetID()]:SetVisible(false)
		end
	end
	local max = math.ceil(graph_maxes["pop"] * 1.1)
	Controls.ResultsGraph:SetRange(0, math.ceil(graph_maxes["pop"] * 1.1))
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText("Population")
	current_graph_field = "pop"	
end

-- same as soldiers graph for crop yield
local function ShowYieldGraph()
	for x,z in pairs(Players) do
		if IsValidPlayer(z) then
			population_graphs[z:GetID()]:SetVisible(false)
			crops_graphs[z:GetID()]:SetVisible(true and graphs_enabled[z:GetID()])
			land_graphs[z:GetID()]:SetVisible(false)
			gnp_graphs[z:GetID()]:SetVisible(false)
			goods_graphs[z:GetID()]:SetVisible(false)
			mil_graphs[z:GetID()]:SetVisible(false)
		end
	end
	local max = math.ceil(graph_maxes["crops"] * 1.1)
	Controls.ResultsGraph:SetRange(0, math.ceil(graph_maxes["crops"] * 1.1))
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText("Crop Yield")
	current_graph_field = "crop"	
end

-- same as soldiers graph for gnp
local function ShowGNPGraph()
	for x,z in pairs(Players) do
		if IsValidPlayer(z) then
			population_graphs[z:GetID()]:SetVisible(false)
			crops_graphs[z:GetID()]:SetVisible(false)
			land_graphs[z:GetID()]:SetVisible(false)
			gnp_graphs[z:GetID()]:SetVisible(true and graphs_enabled[z:GetID()])
			goods_graphs[z:GetID()]:SetVisible(false)
			mil_graphs[z:GetID()]:SetVisible(false)
		end
	end
	local max = math.ceil(graph_maxes["gnp"] * 1.1)
	Controls.ResultsGraph:SetRange(0, math.ceil(graph_maxes["gnp"] * 1.1))
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText("GNP")
	current_graph_field = "gnp"	
end

-- same as soldiers graph for land
local function ShowLandGraph()
	for x,z in pairs(Players) do
		if IsValidPlayer(z) then
			population_graphs[z:GetID()]:SetVisible(false)
			crops_graphs[z:GetID()]:SetVisible(false)
			land_graphs[z:GetID()]:SetVisible(true and graphs_enabled[z:GetID()])
			gnp_graphs[z:GetID()]:SetVisible(false)
			goods_graphs[z:GetID()]:SetVisible(false)
			mil_graphs[z:GetID()]:SetVisible(false)
		end
	end
	local max = math.ceil(graph_maxes["land"] * 1.1)
	Controls.ResultsGraph:SetRange(0, math.ceil(graph_maxes["land"] * 1.1))
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText("Land")
	current_graph_field = "land"	
end

-- same as soldiers graph for land
local function ShowGoodsGraph()
	for x,z in pairs(Players) do
		if IsValidPlayer(z) then
			population_graphs[z:GetID()]:SetVisible(false)
			crops_graphs[z:GetID()]:SetVisible(false)
			land_graphs[z:GetID()]:SetVisible(false)
			gnp_graphs[z:GetID()]:SetVisible(false)
			goods_graphs[z:GetID()]:SetVisible(true and graphs_enabled[z:GetID()])
			mil_graphs[z:GetID()]:SetVisible(false)
		end
	end
	local max = math.ceil(graph_maxes["goods"] * 1.1)
	Controls.ResultsGraph:SetRange(0, math.ceil(graph_maxes["goods"] * 1.1))
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText("Goods")
	current_graph_field = "goods"	
end

--[[ creates/or updates the graph legends
]]
local function UpdateLegend()
	graph_legend:ResetInstances()
	for x, p in pairs(Players) do 
		if IsValidPlayer(p) then
			local instance = graph_legend:GetInstance()
			if Players[human_id]:GetDiplomacy():HasMet(p:GetID()) or human_id == p:GetID() then
				local color = GameInfo.PlayerColors[PlayerConfigurations[p:GetID()]:GetColor()]
				--SetIcon(instance.LegendIcon, p:GetID()) civilizations now use a pin as it is easier to see
				instance.LegendName:SetText(Locale.Lookup(GameInfo.Leaders[PlayerConfigurations[p:GetID()]:GetLeaderTypeName()].Name))
				population_graphs[p:GetID()]:SetColor(UI.GetColorValue(color.PrimaryColor))
				mil_graphs[p:GetID()]:SetColor(UI.GetColorValue(color.PrimaryColor))
				gnp_graphs[p:GetID()]:SetColor(UI.GetColorValue(color.PrimaryColor))
				goods_graphs[p:GetID()]:SetColor(UI.GetColorValue(color.PrimaryColor))
				crops_graphs[p:GetID()]:SetColor(UI.GetColorValue(color.PrimaryColor))
				land_graphs[p:GetID()]:SetColor(UI.GetColorValue(color.PrimaryColor))
				instance.LegendIcon:SetColor(UI.GetColorValue(color.PrimaryColor))
			else
				SetIcon(instance.LegendIcon, "none")
				instance.LegendName:SetText("Undiscovered") -- set to undisovered if the civ hasn't met the player
			end
			instance.ShowHide:RegisterCheckHandler( function(bCheck)
				if bCheck then
					if  current_graph_field == "mil" then mil_graphs[p:GetID()]:SetVisible(bCheck) 
					elseif current_graph_field == "pop" then population_graphs[p:GetID()]:SetVisible(bCheck) 
					elseif current_graph_field == "crop" then crops_graphs[p:GetID()]:SetVisible(bCheck) 
					elseif current_graph_field == "land" then land_graphs[p:GetID()]:SetVisible(bCheck) 
					elseif current_graph_field == "gnp" then gnp_graphs[p:GetID()]:SetVisible(bCheck) 
 					elseif current_graph_field == "goods" then goods_graphs[p:GetID()]:SetVisible(bCheck) end
 					graphs_enabled[p:GetID()] = true
				else
					graphs_enabled[p:GetID()] = false
					mil_graphs[p:GetID()]:SetVisible(false)
					population_graphs[p:GetID()]:SetVisible(false)
					crops_graphs[p:GetID()]:SetVisible(false)
					land_graphs[p:GetID()]:SetVisible(false)
					gnp_graphs[p:GetID()]:SetVisible(false)
					goods_graphs[p:GetID()]:SetVisible(false)
				end
			end)
		end
	end
end

-- Draw graph from scratch TODO: find way to cache resutls so the graph doesn't need to be remade
local function UpdateGraph()
	local years = {}
	years["start"] = start_year
	years["current"] = YearToNumber(Calendar.MakeYearStr(Game.GetCurrentGameTurn() - 1))

	--print("start year: ", years["start"])
	--print("current year: ", years["current"])

	-- set year and intervals constant for all graphs
	Controls.ResultsGraph:SetDomain(years["start"], years["current"])
	local number_interval = {}
	number_interval["x"] = GetInterval(years["start"], years["current"])
	Controls.ResultsGraph:SetXTickInterval(math.floor(number_interval["x"] / 4))
	Controls.ResultsGraph:SetXNumberInterval(number_interval["x"])
	local data = nil
	
	local best = 0
	local worst = 10000000

	-- create all the graphs

	graph_maxes["pop"] = 0;
	graph_maxes["mil"] = 0;
	graph_maxes["gnp"] = 0;
	graph_maxes["crops"] = 0;
	graph_maxes["land"] = 0;
	graph_maxes["goods"] = 0;

	for i, p in pairs(Players)	do
		if IsValidPlayer(p) then
			if population_graphs[p:GetID()] then population_graphs[p:GetID()]:Clear() end
			population_graphs[p:GetID()] = Controls.ResultsGraph:CreateDataSet(tostring(p:GetID()) .. "_population")
			population_graphs[p:GetID()]:SetVisible(false)
			population_graphs[p:GetID()]:SetWidth(2.0)

			if mil_graphs[p:GetID()] then mil_graphs[p:GetID()]:Clear() end
			mil_graphs[p:GetID()] = Controls.ResultsGraph:CreateDataSet(tostring(p:GetID()) .. "_military")
			mil_graphs[p:GetID()]:SetVisible(false)
			mil_graphs[p:GetID()]:SetWidth(2.0)


			if gnp_graphs[p:GetID()] then gnp_graphs[p:GetID()]:Clear() end
			gnp_graphs[p:GetID()] = Controls.ResultsGraph:CreateDataSet(tostring(p:GetID()) .. "_gnp")
			gnp_graphs[p:GetID()]:SetWidth(2.0)
			gnp_graphs[p:GetID()]:SetVisible(false)
			gnp_graphs[p:GetID()]:SetWidth(2.0)

			
			if goods_graphs[p:GetID()] then goods_graphs[p:GetID()]:Clear() end
			goods_graphs[p:GetID()] = Controls.ResultsGraph:CreateDataSet(tostring(p:GetID()) .. "_goods")
			goods_graphs[p:GetID()]:SetVisible(false)
			goods_graphs[p:GetID()]:SetWidth(2.0)

			
			if crops_graphs[p:GetID()] then crops_graphs[p:GetID()]:Clear() end
			crops_graphs[p:GetID()] = Controls.ResultsGraph:CreateDataSet(tostring(p:GetID()) .. "_crops")
			crops_graphs[p:GetID()]:SetVisible(false)
			crops_graphs[p:GetID()]:SetWidth(2.0)
			
			if land_graphs[p:GetID()] then land_graphs[p:GetID()]:Clear() end
			land_graphs[p:GetID()] = Controls.ResultsGraph:CreateDataSet(tostring(p:GetID()) .. "_land")
			land_graphs[p:GetID()]:SetVisible(false)
			land_graphs[p:GetID()]:SetWidth(2.0)
		end
	end
	
	local range_pop = {} -- can remove this, need to make sure it works without
	for i, p in pairs(Players) do
		if IsValidPlayer(p) then
			data = LoadData(p)
			best = 0
			worst = 10000000
			for x,z in pairs(data) do
				for i, j in pairs(z) do
					--print("i: ", i, "j: ", j)

					if best < tonumber(j) then
						best = tonumber(j)
					end

					if(i == "pop") then
						population_graphs[p:GetID()]:AddVertex(tonumber(z["year"]), tonumber(j))
						if tonumber(j) > graph_maxes["pop"] then
							graph_maxes["pop"] = tonumber(j)
						end 
					end

					if(i == "mil") then 
						mil_graphs[p:GetID()]:AddVertex(tonumber(z["year"]), tonumber(j))
						if tonumber(j) > graph_maxes["mil"] then
							graph_maxes["mil"] = tonumber(j)
						end 
					end

					if(i == "gnp") then
						gnp_graphs[p:GetID()]:AddVertex(tonumber(z["year"]), tonumber(j))
						if tonumber(j) > graph_maxes["gnp"] then
							graph_maxes["gnp"] = tonumber(j)
						end 
					end

					if(i == "goods") then
						goods_graphs[p:GetID()]:AddVertex(tonumber(z["year"]), tonumber(j))
						if tonumber(j) > graph_maxes["goods"] then
							graph_maxes["goods"] = tonumber(j)
						end 
					end

					if(i == "crop") then
						crops_graphs[p:GetID()]:AddVertex(tonumber(z["year"]), tonumber(j))
						if tonumber(j) > graph_maxes["crops"] then
							graph_maxes["crops"] = tonumber(j)
						end 
					end

					if(i == "land") then
						land_graphs[p:GetID()]:AddVertex(tonumber(z["year"]), tonumber(j))
						if tonumber(j) > graph_maxes["land"] then
							graph_maxes["land"] = tonumber(j)
						end 					
					end

					-- have better way to set worst
					if worst > tonumber(j) then
						worst = tonumber(j)
					end
				end
			end
		end
	end

	range_pop["best"] = best
	range_pop["worst"] = worst
	number_interval["y"] = math.floor(((range_pop["best"] - range_pop["worst"]) / 4))

	Controls.ResultsGraph:SetRange(range_pop["worst"], range_pop["best"] )
	Controls.ResultsGraph:SetYNumberInterval(number_interval["y"])
	Controls.ResultsGraph:SetYTickInterval(math.floor(number_interval["y"] / 4))


	UpdateLegend()
	ShowPopGraph()
end

function OpenPanel()
	-- add sound effects here
	context_store:SetHide(false)
	ShowInfoPanel()
	local start_time = os.time()
	UpdatePanel()
	UpdateGraph() -- just for tests, move to button
	local end_time = os.time()
	print("generation of panel and graphs: ", (end_time -start_time) / 1000.0, "s")
end

-- Store data for all players
local function StoreAllData()
	local start_time = os.time()
	for i, p in pairs(Players) do
		if IsValidPlayer(p) then 
			local data = GetData(p)
			for x, z in pairs(data) do
				GameConfiguration.SetValue(x, z)
			end
		end
	end
	local sequence = GameConfiguration.GetValue("year_sequence")
	if(sequence == nil) then
		GameConfiguration.SetValue("year_sequence", tostring(YearToNumber(Calendar.MakeYearStr(Game.GetCurrentGameTurn()))))
	else
		GameConfiguration.SetValue("year_sequence", sequence .. "_" .. tostring(YearToNumber(Calendar.MakeYearStr(Game.GetCurrentGameTurn()))))
	end
	local end_time = os.time()
	print("store time: ", (end_time - start_time) / 1000.0, "s")
end

-- add cache so it's not loading all data everytime
local function LoadAllData()

end

-- change in case of multiplayers or hotseat
-- Intialize necessary variables and UI
function Init()
	print("load completed start initizialization")
	for i, j in pairs(Players) do
		if j then
			if j:IsHuman() then human_id = j:GetID() end
		end
		if IsValidPlayer(j) then graphs_enabled[j:GetID()] = true end
	end

	graph_types = {"land", "pop", "mil", "crop", "gnp", "goods"} -- set global graph names/types

	start_year = GameConfiguration.GetStartYear()
	context_store = ContextPtr
	graph_legend = InstanceManager:new("GraphLegendInstance", "GraphLegend", Controls.GraphLegendStack)
	UpdatePanel()
	Controls.Close:RegisterCallback(Mouse.eLClick, ClosePanel)
	Controls.graphs_button:RegisterCallback(Mouse.eLClick, ShowGraph)
	Controls.info_button:RegisterCallback(Mouse.eLClick, ShowInfoPanel)
	
	Controls.show_pop_graph:RegisterCallback(Mouse.eLClick, ShowPopGraph)
	Controls.show_mil_graph:RegisterCallback(Mouse.eLClick, ShowMilGraph)
	Controls.show_gnp_graph:RegisterCallback(Mouse.eLClick, ShowGNPGraph)
	Controls.show_land_graph:RegisterCallback(Mouse.eLClick, ShowLandGraph)
	Controls.show_goods_graph:RegisterCallback(Mouse.eLClick, ShowGoodsGraph)
	Controls.show_crop_graph:RegisterCallback(Mouse.eLClick, ShowYieldGraph)


	-- build pulldown
	local labels = {"Popluation", "Soldiers", "Crop Yield", "GNP", "Land", "Goods"} --  create labels for pulldown
	local pulldown = Controls.GraphDataSetPulldown

	-- return appropriate function to be used in pulldown
	local function DetermineFunction(input)
		if input == "Popluation" then return ShowPopGraph
		elseif input == "Soldiers" then return ShowMilGraph 
		elseif input == "Crop Yield" then return ShowYieldGraph 
		elseif input == "GNP" then return ShowGNPGraph
		elseif input == "Land" then return ShowLandGraph
		elseif input == "Goods" then return ShowGoodsGraph 
		else return 0
		end
	end

	-- create pulldown
	for i, l in pairs(labels) do
		local entry = {}
		pulldown:BuildEntry("InstanceOne", entry)
		entry.Button:SetText(l)
		entry.Button:RegisterCallback(Mouse.eLClick, DetermineFunction(l))
	end
	pulldown:CalculateInternals() -- set appropriate size

	context_store:SetHide(true)
	local top_panel_control = ContextPtr:LookUpControl("/InGame/TopPanel/ViewDemographics")
	top_panel_control:RegisterCallback(Mouse.eLClick, OpenPanel)

	-- compatability testing. Currently doesn't work
	--local panel_test = ContextPtr:LookUpControl("/InGame/TopPanel")
	--button_instance_manager = InstanceManager:new("DemographicsButtonInstance", "demo_button", panel_test.InfoStack)
	--button_instance_manager:ResetInstances()
	--local button_instance = button_instance_manager:GetInstance()
	--button_instance.Button:SetHide(false)
end

-- Set proper events and functions
Events.LoadGameViewStateDone.Add(Init)
Events.TurnEnd.Add(StoreAllData) -- TODO should be moved to init