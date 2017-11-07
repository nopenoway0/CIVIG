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
local pop_graphs = {}
local mil_graphs = {}
local gnp_graphs = {}
local goods_graphs = {}
local crop_graphs = {}
local land_graphs = {}
local graph_maxes = {}
local graph_list = nil
local graph_legend = nil
local button_instance_manager = nil
local current_graph_field = nil
local graph_types = nil -- the relevant graphs follow the following format: type_graph TODO: change pop_graphs to pop_graphs | initialized in init
local graphs_enabled = {}
local current_language = nil
-- Convert year to number format. BC converts the number into negative
local function YearToNumber(input)
	local bc_language_dependencies = {en_US = "BC", es_ES = "a. C.", zh_Hans_CN = '公元前', ja_JP = '紀元前', ru_RU = 'до н. э.', de_DE = 'v. Chr.', fr_FR = 'av. J.-C.', it_IT = 'a.C.', ko_KR = '기원전', pl_PL='p.n.e.', pt_BR='a.C.', zh_Hant_HK = '西元前'} -- Set BC suffixes for each language
	local output :number = 0
	if current_language == "zh_Hans_CN" then 
		output = tonumber(input:gsub('公元前', ''):gsub('年', ''):gsub('公元', ''):gsub('年',''):sub(0)) -- remove AD and BC for chinese
	elseif current_language == "ja_JP" then
		output = tonumber(input:gsub('西暦', ''):gsub('年', ''):gsub('紀元前', ''):gsub('年', ''):sub(0)) -- remove AD and BC equivilents for Japanese
	elseif current_language == "ru_RU" then
		output = tonumber(input:gsub('до н. э.', ''):gsub('н. э.', ''):sub(0)) -- remove AD and BC equivilents for Russain
	elseif current_language == "fr_FR" then
		output = tonumber(input:gsub('av. J.-C.', ''):gsub('ap. J.-C.', ''):sub(0)) -- remove AD and BC equivilents for French
	elseif current_language == "ko_KR" then
		output = tonumber(input:gsub('기원전', ''):gsub('년', ''):gsub('서기', ''):gsub('년',''):sub(0)) -- remove AD and BC equivilents for Korean
	elseif current_language == "zh_Hant_HK" then
		output = tonumber(input:gsub('西元前', ''):gsub('年', ''):gsub('西元', ''):gsub('年', ''):sub(0))
	else
		output = tonumber(input:gsub('[a-zA-Z. ]+', ''):sub(0))
	end
	if input:find(bc_language_dependencies[current_language]) then
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
	local suffixes = {pop = "_POP", mil = "_MIL", gnp="_GNP", crop="_CROP", land="_LAND", goods="_GOODS"} -- create suffixes and indices for loop
	local sequence :string = GameConfiguration.GetValue("year_sequence") -- in order to make sure all data is retrieved the year sequence must be retrieved
	local years = {}
	local data = {}
	local complete_data = {}
	if sequence == nil then return -1 end
	sequence:gsub( "%-?%d+", function(i) table.insert(years, i) end)
	local prefix = tostring(player:GetID()) .. "_"
	for x,z in pairs(years) do
		data = {}
		-- store year into table and then each corresponding field with proper suffix according to
		-- the suffixes table
		data["year"] = tonumber(z)
		for k, s in pairs(suffixes) do 
			data[k] = GameConfiguration.GetValue(prefix .. tostring(z) .. s)
		end
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
	if IsValidPlayer(player) == false or player:IsAlive() == false then return 0 end -- if player is dead or not a valid civ, return 0 might
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
	return math.floor(population)
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
		if IsValidPlayer(p) and p:IsAlive() then
			demographics[p:GetID()] = GetGoods(p)
		end
	end
	return demographics
end

--[[Get the total population of all cities for each player.
	Store in table according to player ID]]
local function GetDemographics()
	local demographics = {}
	for k, p in pairs(Players) do
		if IsValidPlayer(p) and p:IsAlive() then			
				demographics[p:GetID()] =GetPop(p)
		end
	end
	return demographics
end

--[[Get Military might for all alive players in game]]
local function GetMilitaryMight()
	local m_might = {}
	for k, p in pairs(Players) do
		if IsValidPlayer(p) then
				m_might[p:GetID()] = GetMight(p)
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
		if IsValidPlayer(p) then
				demographics[p:GetID()] = GetCropYield(p)
		end
	end
	return demographics
end

--[[ Players gold yield
]]
local function GetGNP(player)
	local GNP = 0
	local tmp;
	if IsValidPlayer(player) then
		GNP = player:GetTreasury():GetGoldYield()
	end
	local tmp = math.floor(GNP * 10)
	tmp = tmp / 10
	return tmp
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
	local values = {billion = 1000000000, million = 1000000, thousand = 1000}
	local suffix = {billion = "LOC_CIVIG_LOCALE_BILLION_SUFFIX", million = "LOC_CIVIG_LOCALE_MILLION_SUFFIX", thousand = "LOC_CIVIG_LOCALE_THOUSAND_SUFFIX"}
	local result = {}

	local function input_operation(inp, divisor, n)
		result[1] = Locale.Lookup(suffix[n])
		inp = inp / divisor
		return inp
	end

	if input < values.thousand then
		result[1] = ""
	else
		if input > values.billion then input = input_operation(input, values.billion, "billion")
		elseif input > values.million then input = input_operation(input, values.million, "million")
		elseif input >= values.thousand then input = input_operation(input, values.thousand, "thousand")
		else
			input = 0
		end
	end

	input = math.ceil(input * 100)
	input = input / 100
	result[0] = input
	
	return result
end

local function Truncate(input, num) 
	return math.floor(input  * 10^num + .5) / 10^num
end

--[[ Updates corresponding field in the rankings panel
]]
local function UpdateField(field)
	local demographics_functions = {pop = GetDemographics, gnp = GetGNPAll, mil = GetMilitaryMight, goods = GetGoodsDemographics, land = GetLandAll, crop = GetCropYieldAll}
	local panel_values = {value = 0, rank = 0, worst = 0, best = 0, average = 0}
	local demographics = nil
	local truncate_value = 2

	if field == "gnp" or field == "goods" or field == "crops" then truncate_value = 1 end;

	--print("picking functions according to ", field)
	if demographics_functions[field] then
		demographics = demographics_functions[field]()
	else
		print("incorrect demographics field accessed: ", field)
		return -1
	end

	local count = 0
	local result = nil 
	local civ_id = {best = human_id, worst = human_id} 	-- set all fields in civ id to human by default
	local icons = {best = nil, worst = nil}
	
	-- get and set population value
	local tmp = demographics[human_id]
	panel_values.best = tmp - 1
	panel_values.worst = tmp + 1
	for i, j in pairs(demographics) do
		if i >= 0 then
			if Players[i]:IsAlive() then
				if j >= tmp then panel_values.rank = panel_values.rank + 1 end
				if j <= panel_values.worst then 
					panel_values.worst = j
					civ_id.worst = i
				end
				if j > panel_values.best then 
					panel_values.best = j
					civ_id.best = i
				end
				panel_values.average = panel_values.average + j
				count = count + 1
			end
		end
	end

	panel_values.average = Truncate(panel_values.average / count, truncate_value)
	panel_values.worst = Truncate(panel_values.worst, truncate_value)
	panel_values.best = Truncate(panel_values.best, truncate_value)
	panel_values.value = Truncate(demographics[human_id], truncate_value)

	for f, v in pairs(panel_values) do
		result = GetSuffix(v)
		if result[0] == nil or result[1] == nil then return -1 end
		Controls[field .. "_" .. f]:SetText(tostring(result[0]) .. result[1])
	end
	icons.best = Controls[field .. "_best_icon"]
	icons.worst = Controls[field .. "_worst_icon"]

	-- if worst is the best, there is no best or worst. Set to question mark. Else set the icon according to the player id
	if panel_values.worst == panel_values.best then
		SetIcon(icons.best, "none")
		SetIcon(icons.worst, "none")
	else
		if Players[human_id]:GetDiplomacy():HasMet(civ_id.best) or human_id == civ_id.best then 
			SetIcon(icons.best, civ_id.best)
			icons.best:SetToolTipString(Locale.Lookup(GameInfo.Leaders[PlayerConfigurations[civ_id.best]:GetLeaderTypeName()].Name))
		else 
			icons.best:SetToolTipString("")
			SetIcon(icons.best, "none") 
		end
		if Players[human_id]:GetDiplomacy():HasMet(civ_id.worst) or human_id == civ_id.worst then 
			SetIcon(icons.worst, civ_id.worst)
			icons.worst:SetToolTipString(Locale.Lookup(GameInfo.Leaders[PlayerConfigurations[civ_id.worst]:GetLeaderTypeName()].Name))
		else 
			SetIcon(icons.worst, "none")
			icons.worst:SetToolTipString("")
		end
	end
end

--[[Update panel by rewriting to all fields]]
function UpdatePanel()
	for n, f in pairs(graph_types) do
		UpdateField(f)
	end
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
	local data_fields = {POP = GetPop, MIL = GetMight, GNP = GetGNP, CROP = GetCropYield, LAND = GetLand, GOODS = GetGoods}
	-- get population

	--local floor = math.floor
	for l, f in pairs(data_fields) do 
		data[prefix .. l] = f(player)
	end

	return data
end

-- calculate numberinterval of the graph
local function GetInterval(low, high)
	local total = nil
	local abs = math.abs
	if low < 0 then
		total = abs(abs(low) - high * -1)
	elseif low > 0 then
		total = high - low
	else
		total = low + high
	end

	if total <= 10 then return total end
	local number_interval = math.floor(total / 10)
	return number_interval
end

local function ShowGraphByName(graph_name)
	local labels = {pop = "LOC_CIVIG_LOCALE_POPULATION", crop = "LOC_CIVIG_LOCALE_CROP_YIELD", land = "LOC_CIVIG_LOCALE_LAND", gnp = "LOC_CIVIG_LOCALE_GNP", goods = "LOC_CIVIG_LOCALE_GOODS", mil = "LOC_CIVIG_LOCALE_SOLDIERS"}
	for i, p in pairs(Players) do
		if IsValidPlayer(p) then
			for l, g in pairs(graph_list) do
				if l == graph_name then g[p:GetID()]:SetVisible(true and graphs_enabled[p:GetID()])
				else
					g[p:GetID()]:SetVisible(false)
				end
			end
		end
	end

	local max = Truncate(graph_maxes[graph_name] * 1.1, 0)
	Controls.ResultsGraph:SetRange(0, max)
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText(Locale.Lookup(labels[graph_name]))
	current_graph_field = graph_name
end

-- display the soldiers graph. must make sure that for the corresponding player, the checkbox enables
-- the lines to be shown
local function ShowMilGraph()
	ShowGraphByName("mil")
end

-- same as soldiers graph for population
local function ShowPopGraph()
	ShowGraphByName("pop")
end

-- same as soldiers graph for crop yield
local function ShowYieldGraph()
	ShowGraphByName("crop")
end

-- same as soldiers graph for gnp
local function ShowGNPGraph()
	ShowGraphByName("gnp")
end

-- same as soldiers graph for land
local function ShowLandGraph()
	ShowGraphByName("land")	
end

-- same as soldiers graph for land
local function ShowGoodsGraph()
	ShowGraphByName("goods")
end

--[[ creates/or updates the graph legends
]]
local function UpdateLegend()

		function ColorDistance(color1, color2)
			local distance = nil;
			local pow = math.pow;
			if(distance == nil) then

				local c1:table, c2:table;

				if color1.Color then
					c1 = UIManager:ParseColorString(color1.Color);
				else
					c1 = { color1.Red * 255, color1.Green * 255, color1.Blue * 255 };
				end

				if color2.Color then
					c2 = UIManager:ParseColorString(color2.Color);
				else
					c2 = { color2.Red * 255, color2.Green * 255, color2.Blue * 255 };
				end

				local r2 = pow(c1[1] - c2[1], 2);
				local g2 = pow(c1[2] - c2[2], 2);
				local b2 = pow(c1[3] - c2[3], 2);	
						
				distance = r2 + g2 + b2;
			end
					
			return distance;
		end
	local white = {Red = 1, Blue = 1, Green = 1}
	local black = {Red = 0, Blue = 0, Green = 0}
	graph_legend:ResetInstances()
	for x, p in pairs(Players) do 
		if IsValidPlayer(p) then
			local instance = graph_legend:GetInstance()

			if Players[human_id]:GetDiplomacy():HasMet(p:GetID()) or human_id == p:GetID() then
				local color = GameInfo.PlayerColors[PlayerConfigurations[p:GetID()]:GetColor()]
				local color_name = "PrimaryColor"
				instance.LegendIcon:SetIcon("Controls_LocationPip")-- civilizations now use a pin as it is easier to see
				instance.LegendName:SetText(Locale.Lookup(GameInfo.Leaders[PlayerConfigurations[p:GetID()]:GetLeaderTypeName()].Name))

				--local color = GameInfo.Colors[GameInfo.PlayerColors[PlayerConfigurations[0]:GetColor()].PrimaryColor] print(color.Color)
				-- make print for each color primary
				if ColorDistance(GameInfo.Colors[color.PrimaryColor], white) < 100 or ColorDistance(GameInfo.Colors[color.PrimaryColor], black) < 100 then
					color_name = "SecondaryColor"
					print("below threshold")
				end
				-- check if close to background color: 0,0,0,100, also check if background color is close to white
				for l, g in pairs(graph_list) do
					g[p:GetID()]:SetColor(UI.GetColorValue(color[color_name]))
				end
				instance.LegendIcon:SetColor(UI.GetColorValue(color[color_name]))
			else
				SetIcon(instance.LegendIcon, "none")
				instance.LegendName:SetText(Locale.Lookup("LOC_CIVIG_LOCALE_UNDISCOVERED")) -- set to undisovered if the civ hasn't met the player
			end
			instance.ShowHide:RegisterCheckHandler( function(bCheck)
				if bCheck then
					graph_list[current_graph_field][p:GetID()]:SetVisible(bCheck)
 					graphs_enabled[p:GetID()] = true
				else
					graphs_enabled[p:GetID()] = false
					for l, g in pairs(graph_list) do 
						g[p:GetID()]:SetVisible(false)
					end
				end
			end)
		end
	end
end

-- Draw graph from scratch TODO: find way to cache resutls so the graph doesn't need to be remade
local function UpdateGraph()
	local years = {start = start_year, current = YearToNumber(Calendar.MakeYearStr(Game.GetCurrentGameTurn() - 1))}
	graph_list = {pop = pop_graphs, mil = mil_graphs, land = land_graphs, gnp = gnp_graphs, crop = crop_graphs, goods = goods_graphs}
	local values = {best = 0, worst = 100000}
	-- set year and intervals constant for all graphs
	Controls.ResultsGraph:SetDomain(years.start, years.current)
	local number_interval = GetInterval(years.start, years.current)
	Controls.ResultsGraph:SetXTickInterval(math.floor(number_interval / 4))
	Controls.ResultsGraph:SetXNumberInterval(number_interval)

	-- create all the graphs

	for n, l in pairs(graph_types) do
		graph_maxes[l] = 0
	end

	for i, p in pairs(Players)	do
		if IsValidPlayer(p) then
			for i, l in pairs(graph_types) do
				if graph_list[l][p:GetID()] then graph_list[l][p:GetID()]:Clear() end
				graph_list[l][p:GetID()] = Controls.ResultsGraph:CreateDataSet(tostring(p:GetID()) .. "_population")
				graph_list[l][p:GetID()]:SetVisible(false)
				graph_list[l][p:GetID()]:SetWidth(2.0)
			end
		end
	end
	
	local data = nil
	for i, p in pairs(Players) do
		if IsValidPlayer(p) then
			data = LoadData(p)
			values.best = 0
			values.worst = 10000000
			for x,z in pairs(data) do
				for i, j in pairs(z) do
					if values.best < tonumber(j) then
						values.best = tonumber(j)
					end

					if(i ~= "year") then 
						graph_list[i][p:GetID()]:AddVertex(tonumber(z.year), tonumber(j))					
						if tonumber(j) > graph_maxes[i] then
							graph_maxes[i] = tonumber(j)
						end 

						-- have better way to set worst
						if values.worst > tonumber(j) then
							values.worst = tonumber(j)
						end
					end
				end
			end
		end
	end

	UpdateLegend()
	ShowGraphByName("pop")
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
local function Init()
	print("load completed start initizialization")
	for i, j in pairs(Players) do
		if j then
			if j:IsHuman() then human_id = j:GetID() end
		end
		if IsValidPlayer(j) then graphs_enabled[j:GetID()] = true end
	end

	current_language = Locale.GetCurrentLanguage().Type

	graph_types = {"pop", "mil", "gnp", "crop", "land", "goods"} -- set global graph names/types

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
	local labels = {"LOC_CIVIG_LOCALE_POPULATION", "LOC_CIVIG_LOCALE_SOLDIERS", "LOC_CIVIG_LOCALE_CROP_YIELD", "LOC_CIVIG_LOCALE_GNP", "LOC_CIVIG_LOCALE_LAND", "LOC_CIVIG_LOCALE_GOODS"} --  create labels for pulldown
	local pulldown = Controls.GraphDataSetPulldown

	-- return appropriate function to be used in pulldown
	local function DetermineFunction(input)
		if input == "LOC_CIVIG_LOCALE_POPULATION" then return ShowPopGraph
		elseif input == "LOC_CIVIG_LOCALE_SOLDIERS" then return ShowMilGraph 
		elseif input == "LOC_CIVIG_LOCALE_CROP_YIELD" then return ShowYieldGraph 
		elseif input == "LOC_CIVIG_LOCALE_GNP" then return ShowGNPGraph
		elseif input == "LOC_CIVIG_LOCALE_LAND" then return ShowLandGraph
		elseif input == "LOC_CIVIG_LOCALE_GOODS" then return ShowGoodsGraph 
		else return 0
		end
	end

	-- create pulldown
	for i, l in pairs(labels) do
		local entry = {}
		pulldown:BuildEntry("InstanceOne", entry)
		entry.Button:SetText(Locale.Lookup(l))
		entry.Button:RegisterCallback(Mouse.eLClick, DetermineFunction(l))
	end
	pulldown:CalculateInternals() -- set appropriate size

	context_store:SetHide(true)
	--local top_panel_control = ContextPtr:LookUpControl("/InGame/TopPanel/ViewDemographics")
	--top_panel_control:RegisterCallback(Mouse.eLClick, OpenPanel)

	-- Create button and inject into toppanel
	print("Creating Demographics button and inserting into TopPane.InfoStack")
	local toppanel_infostack = ContextPtr:LookUpControl("/InGame/TopPanel/InfoStack")
	button_instance_manager = InstanceManager:new("DemographicsButtonInstance", "ViewDemographics", toppanel_infostack)
	local button_instance = button_instance_manager:GetInstance()
	button_instance.ViewDemographics:RegisterCallback(Mouse.eLClick, OpenPanel)
	button_instance.ViewDemographics:SetHide(false)
	print("Insertion Complete")
end

-- Set proper events and functions
Events.LoadGameViewStateDone.Add(Init)
Events.TurnEnd.Add(StoreAllData) -- TODO should be moved to init