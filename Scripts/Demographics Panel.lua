-- LuaScript1
-- Author: Benji
-- DateCreated: 10/25/2017 6:27:12 PM
--------------------------------------------------------------
include("SupportFunctions")
include("InstanceManager")

-- data is stored in the following fashion:
-- 
active_player = nil
local context_store = nil
local button_instance_manager = nil
local graph_types = nil -- the relevant graphs follow the following format: type_graph TODO: change pop_graphs to pop_graphs | initialized in init
local graphs_enabled = {}
graphs = {}
panels = {}
players = {}
config = nil
-- Convert year to number format. BC converts the number into negative
function Config(o)
	local data = {language = Locale.GetCurrentLanguage().Type, players = {}, start_year = GameConfiguration.GetStartYear()}
	data["context_store"] = ContextPtr
	data["min_points"] = 100 -- if less than interpolate
	data["legend"] = InstanceManager:new("GraphLegendInstance", "GraphLegend", Controls.GraphLegendStack)
	function data.get_players()
		return data.players
	end
	function data.get_player(id)
		return data.players[id]
	end
	function data.add_player(id)
		data.players[id] = DMPlayer(id)
	end
	return data
end

function __Init_Config()
	config = Config({})
end

-- remove language specific prefixes to the year to parse the number. bc is negative and ad positive
function YearToNumber(input)
	local bc_language_dependencies = {en_US = "BC", es_ES = "a. C.", zh_Hans_CN = '公元前', ja_JP = '紀元前', ru_RU = 'до н. э.', de_DE = 'v. Chr.', fr_FR = 'av. J.-C.', it_IT = 'a.C.', ko_KR = '기원전', pl_PL='p.n.e.', pt_BR='a.C.', zh_Hant_HK = '西元前'} -- Set BC suffixes for each language
	local output :number = 0
	if config.language == "zh_Hans_CN" then 
		output = tonumber(input:gsub('公元前', ''):gsub('年', ''):gsub('公元', ''):gsub('年',''):sub(0)) -- remove AD and BC for chinese
	elseif config.language == "ja_JP" then
		output = tonumber(input:gsub('西暦', ''):gsub('年', ''):gsub('紀元前', ''):gsub('年', ''):sub(0)) -- remove AD and BC equivilents for Japanese
	elseif config.language == "ru_RU" then
		output = tonumber(input:gsub('до н. э.', ''):gsub('н. э.', ''):sub(0)) -- remove AD and BC equivilents for Russain
	elseif config.language == "fr_FR" then
		output = tonumber(input:gsub('av. J.-C.', ''):gsub('ap. J.-C.', ''):sub(0)) -- remove AD and BC equivilents for French
	elseif config.language == "ko_KR" then
		output = tonumber(input:gsub('기원전', ''):gsub('년', ''):gsub('서기', ''):gsub('년',''):sub(0)) -- remove AD and BC equivilents for Korean
	elseif config.language == "zh_Hant_HK" then
		output = tonumber(input:gsub('西元前', ''):gsub('年', ''):gsub('西元', ''):gsub('年', ''):sub(0))
	else
		output = tonumber(input:gsub('[a-zA-Z. ]+', ''):sub(0))
	end
	if input:find(bc_language_dependencies[config.language]) then
		output = output * -1
	end
	return output
end

local function GetPlayerPrefix(player)
	local prefix = ""
	if GameConfiguration:IsAnyMultiplayer() and player:IsHuman() then
		-- hotseat or multiplayer add prefix
		prefix = PlayerConfigurations[player:GetID()]:GetPlayerName() .. "_"		
	end
	return prefix
end

--[[Determines of the player is valid. A player is valid IF that player exists
	and that player is a major civ. Civ states are not considered valid players in this mode
]]
function IsValidPlayer(player)
	if player._player == nil or player.isMajor() == false then return false end
	return true
end

--[[ Load the data relevant to the inputted player
]]
local function LoadData(player)
	if player.isValid() == false then return -1 end
	local suffixes = {pop = "_POP", mil = "_MIL", gnp="_GNP", crop="_CROP", land="_LAND", goods="_GOODS"} -- create suffixes and indices for loop
	local sequence :string = GameConfiguration.GetValue("year_sequence") -- in order to make sure all data is retrieved the year sequence must be retrieved
	local years = {} 
	local data = {}
	local complete_data = {}
	if sequence == nil then return -1 end
	sequence:gsub( "%-?%d+", function(i) table.insert(years, i) end)
	local prefix = tostring(player.id) .. "_" .. player.prefix()
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
		icon = icon .. cTop_player:GetCivilizationTypeName()
		control:SetIcon(icon)
	elseif id == "none" then
		icon = icon .. "CIVILIZATION_UNKNOWN"
	else
		icon = icon .. id
	end
	control:SetIcon(icon)
end

--[[Get "real" land owned by that player. This is done by retrieving the total number of tiles the player owns
	and then multiplying these tiles by 10,000
]]
function GetLand(player)
	local size = 0
	if player.isValid() then
		for i, c in player.cities() do
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
	if player.isValid() == false or player.isAlive() == false then return 0 end -- if player is dead or not a valid civ, return 0 might
	local might = player.military_strength()
	might = math.sqrt(might) * 2000
	return math.floor(might)
end

--[[Get total population of player's empire.
	return total population. The population is retrieved from each city and put into
	the following formula: 1000*population^2.8 then added to the rest of the population
]]
local function GetPop(player)
	if player.isValid() == false then return 0 end
	if(player.cities() == nil) then return 0 end

	local population = 0
	for i, c in player.cities() do
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
	if player.isValid() == false then return 0 end
	for x, c in player.cities() do
		goods = goods + c:GetBuildQueue():GetProductionYield()
	end
	return goods
end

--[[ Get a table consisting of all players goods results
]]
function GetGoodsDemographics()
	local demographics = {}
	for i, p in pairs(config.get_players()) do
		if p.isValid() and p.isAlive() then
			demographics[p.id] = p.goods()
		end
	end
	return demographics
end

--[[Get the total population of all cities for each player.
	Store in table according to player ID]]
function GetDemographics()
	local demographics = {}
	--for k, p in pairs(Players) do
	--	if IsValidPlayer(p) and p:IsAlive() then			
	--			demographics[p:GetID()] =GetPop(p)
	--	end
	--end
	for id, p in pairs(config.get_players()) do
		demographics[id] = p.pop()
	end
	return demographics
end

--[[Get Military might for all alive players in game]]
function GetMilitaryMight()
	local m_might = {}
	for i, p in pairs(config.get_players()) do
		if p.isValid() then
			m_might[p.id] = p.might()
		end
	end
	return m_might
end

--[[ Get a table of all land values for each player
]]
function GetLandAll()
	local land = {}
	for x, p in pairs(config.get_players()) do
		if p.isValid() then
			land[p.id] = p.land()
		end
	end
	return land
end

--[[Sum of all cities' yields
]]
function GetCropYield(player)
	-- get crop yield of player
	local total_yield = 0
	if player.isValid() == false then return 0 end
	for x, c in player.cities() do
		total_yield = total_yield + c:GetYield()
	end
	return total_yield
end

--[[ Table of all players yields
]]
function GetCropYieldAll()
	local demographics = {}
	for k, p in pairs(config.get_players()) do
		if p.isValid() then
				demographics[p.id] = p.crop_yield()
		end
	end
	return demographics
end

--[[ Players gold yield
]]
function GetGNP(player)
	local GNP = 0
	local tmp;
	if player.isValid() then
		GNP = player.treasury():GetGoldYield()--player:GetTreasury():GetGoldYield()
	end
	local tmp = math.floor(GNP * 10)
	tmp = tmp / 10
	return tmp
end

--[[ Table of all players Gold yield
]]
local function GetGNPAll()
	local gnp = {}
	for x, p in pairs(config.get_players()) do
		if p.isValid() then
			gnp[p.id] = p.gnp()
		end
	end
	return gnp
end

--[[ Get suffix of inputted number. e.g. 1000 = k and the result after division 1000 = 1
]]
function GetSuffix(input)
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
	local human_id = active_player.id
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
	print(demographics[0])
	for id, n in pairs(demographics) do
		print(id)
	end
	print(field)
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
	Controls.smooth_button:SetHide(false)
	Controls.GraphDataSetPulldown:SetHide(false)
	Controls.GraphLegendStack:SetHide(false)
end

-- Hide graph, legend, and pulldown. displays the info panel
local function ShowInfoPanel()
	Controls.smooth_button:SetHide(true)

	Controls.GraphDataSetPulldown:SetHide(true)
	Controls.GraphLegendStack:SetHide(true)
	Controls.ResultsGraph:SetHide(true)
	Controls.InfoPanel:SetHide(false)
end

-- retrieve data for the corresponding player. Constructs the same key using the player id and year
-- as when storing was used
function GetData(player)
	if player.isValid() == false then return -1 end
	local data = {}
	local prefix = tostring(player.id) .. "_" .. player.prefix() --tostring(player:GetID()) .. "_" .. GetPlayerPrefix(player)
	prefix = prefix .. tostring(YearToNumber(Calendar.MakeYearStr(Game.GetCurrentGameTurn()))) .. "_"
	local data_fields = {POP = "pop", MIL = "might", GNP = "gnp", CROP = "crop_yield", LAND = "land", GOODS = "goods"}
	-- get population

	--local floor = math.floor
	for l, f in pairs(data_fields) do 
		data[prefix .. l] = player[f]()
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
	for i, g in pairs(graphs) do
		g.destroy_graph()
	end
	graphs[graph_name].generate_graph()
	local max = Truncate(graphs[graph_name].high() * 1.1, 0)--Truncate(graph_maxes[graph_name] * 1.1, 0)
	Controls.ResultsGraph:SetRange(0, max)
	local number_interval = GetInterval(0, max)
	Controls.ResultsGraph:SetYNumberInterval(number_interval)
	Controls.ResultsGraph:SetYTickInterval(number_interval / 4)
	Controls.GraphDataSetPulldown:GetButton():SetText(Locale.Lookup(labels[graph_name]))
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

function OpenPanel()
	-- add sound effects here
	--UpdateHumanID();
	context_store:SetHide(false)
	ShowInfoPanel()
	local start_time = os.time()
	for name, panel in pairs(panels) do
		panel.generate_panel()
	end
	ShowGraphByName("pop") -- just for tests, move to button
	local end_time = os.time()
	print("generation of panel and graphs: ", (end_time - start_time) / 1000.0, "s")
end

-- Store data for all players
function StoreAllData()
	local start_time = os.time()
	for i, p in pairs(config.get_players()) do
		if p.isValid() then 
			local data = p.data()
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

function TestDMPlayer()
	__Init_Config()
	p = DMPlayer(0)
	print(p.land())
	print(p.goods())
	print(p.pop())
	print(p.gnp())
	print(p.might())
	print(p.crop_yield())
	print(p.prefix())
	print(p.isValid())
	print(p.icon())
	print(p.data())
end


function ToggleSmooth()
	local graph_type = "pop"
	for i, g in pairs(graphs) do
		g.toggleSmooth()
		if g.isValid() then
			graph_type = g._graph_type
		end
		g.destroy_graph()
	end
	ShowGraphByName(graph_type)
end

-- instantiate all player info here
function DMPlayer(id)
	local player = {id=id, isHuman = PlayerConfigurations[id]:IsHuman(), name = Locale.Lookup(PlayerConfigurations[id]:GetPlayerName())}
	player["_player"] = Players[id]
	
	--if Locale.Lookup(GameInfo.Leaders[PlayerConfigurations[player.id]:GetLeaderTypeName()] == nil then
	--	player["_tooltip_name"] = Locale.Lookup(GameInfo.Leaders[PlayerConfigurations[player.id]:GetLeaderTypeName()].Name 
	--end
	function player.historic_data()
		return LoadData(player)
	end
	function player.primary_color()
		return UI.GetColorValue(GameInfo.PlayerColors[PlayerConfigurations[player.id]:GetColor()]["PrimaryColor"])
	end
	function player.secondary_color()
		return UI.GetColorValue(GameInfo.PlayerColors[PlayerConfigurations[player.id]:GetColor()]["SecondaryColor"])
	end
	function player.land()
		return GetLand(player)
	end
	function player.isAlive()
		return player._player:IsAlive()
	end
	function player.pop()
		return GetPop(player)
	end
	function player.goods()
		return GetGoods(player)
	end
	function player.gnp()
		return GetGNP(player)
	end
	function player.might()
		return GetMight(player)
	end
	function player.military_strength()
		return player._player:GetStats():GetMilitaryStrength()
	end
	function player.crop_yield()
		return GetCropYield(player)
	end
	function player.prefix()
		return GetPlayerPrefix(player._player)
	end
	function player.isValid()
		return IsValidPlayer(player)
	end
	function player.treasury()
		return player._player:GetTreasury()
	end
	function player.isMajor()
		return player._player:IsMajor()
	end
	function player.data()
		return GetData(player)
	end
	function player.cities()
		return player._player:GetCities():Members()
	end
	function player.has_met(other_player)
		return player._player:GetDiplomacy():HasMet(other_player.id)
	end
	function player.icon()
		local pre = "ICON_"
		if type(player.id) == "number" then
			return pre .. PlayerConfigurations[player.id]:GetCivilizationTypeName()
		elseif player.id == "none" then
			return pre .. "CIVILIZATION_UNKNOWN"
		else
			return pre .. player.id
		end
	end
	-- do instantiation here
	return player
end

function DMPanel(gather_function, graph_type)
	local data = {_gather_function=gather_function, _data=nil, _graph_type=graph_type}
	data["_best"] = {}
	data["_worst"] = {}
	data["_average"] = {score=0}
	data["_rank"] = {score=0}
	data["_icon_fields"] = {best=Controls[graph_type .. "_best_icon"], worst=Controls[graph_type .. "_worst_icon"]}
	-- players score
	data["_value"] = {score=0}
	function data._gather_data()
		data._data = data._gather_function()
	end
	function data.generate_panel()
		data._gather_data()
		local counter = 0
		local total_score = 0
		local rank = 1
		-- find best and worst scores
		local active_player_score = data._data[active_player.id]
		data._best = {player=active_player, score=data._data[active_player.id]}
		data._worst = {player=active_player, score=data._data[active_player.id]}
		for id, score in pairs(data._data) do
			local player = config.get_player(id)
			if player.isValid() and player.isAlive() then
				if id ~= active_player.id and score > active_player_score then
					rank = rank + 1
				end
				if score > data._best.score then
					data._best = {player=player, score=score}
				end
				if score < data._worst.score then
					data._worst = {player=player, score=score}
				end
				total_score = total_score + score
				counter = counter + 1
			end
		end
		data._rank["score"] = rank
		-- do truncation to avoid ugly numbers
		data._worst.score = Truncate(data._worst.score, 2)
		data._best.score = Truncate(data._best.score, 2)
		data._average.score = Truncate(total_score / counter, 2)
		data._value.score = Truncate(data._data[active_player.id], 2)

		-- Set unit amount e.g. million/billion
		for index, score_type in pairs({"_worst", "_best", "_average", "_value", "_rank"}) do
			suffix = GetSuffix(data[score_type].score)
			Controls[data._graph_type .. score_type]:SetText(tostring(suffix[0]) .. suffix[1])
		end
		-- get suffix depending on how big the number is
		--if data._worst.score == data._best.score then
		--	SetIcon(data._icon_fields.best, "none")
		--	SetIcon(data._icon_fields.worst, "none")
		--else
		if active_player.has_met(data._best.player) or active_player.id == data._best.player.id then
			SetIcon(data._icon_fields.best, data._best.player.id)
			data._icon_fields.best:SetToolTipString(data._best.player.name)
		else
			data._icon_fields.best:SetToolTipString("")
			SetIcon(data._icon_fields.best, "none")
		end
		if active_player.has_met(data._worst.player) or active_player.id == data._best.player.id then
			SetIcon(data._icon_fields.worst, data._worst.player.id)
			data._icon_fields.worst:SetToolTipString(data._worst.player.name)
		else
			data._icon_fields.worst:SetToolTipString("")
			SetIcon(data._icon_fields.worst, "none")
		end
		--end

	end
	return data
end


function DMLegend(graph, graph_legend)
	local legend = {_legend=graph_legend, _graph=graph}
	function legend._colorDistance(color1, color2)
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

	function legend.set_graph(graph)
		legend._graph = graph
	end

	function legend.update()
		legend._legend:ResetInstances()
		for id, player in pairs(config.get_players()) do
			if player.isValid() then
				local instance = legend._legend:GetInstance()
				if active_player.has_met(player) or active_player.id == player.id then
					SetIcon(instance.LegendIcon, player.id)
					instance.LegendName:SetText(player.name)
					local primary, secondary = UI.GetPlayerColors(player.id)
					local color = primary
					--if ColorDistance(primary, white) < 100 or ColorDistance(primary, black) < 100 then
					--	color = secondary
					--end
					legend._graph[player.id]:SetColor(color)
					instance.LegendIcon:SetColor(color)
				else
					SetIcon(instance.LegendIcon, "none")
					instance.LegendIcon:SetColor(1,1,1,1)
					instance.LegendName:SetText(Locale.Lookup("LOC_CIVIG_LOCALE_UNDISCOVERED")) -- set to undisovered if the civ hasn't met the player
				end
				instance.ShowHide:SetCheck(true)
				instance.ShowHide:RegisterCheckHandler( function(bCheck)
					legend._graph[player.id]:SetVisible(bCheck)
				end)
			end
		end
	end
	return legend
end

-- create a graph for changes over turns (years)
function DMGraph(gather_function, graph_type, graph_control, legend_manager)
	local data = {_gather_function = gather_function, _data=nil, _graph_type=graph_type, _smooth=true, _pad=3, _valid=false}
	data["_control"] = graph_control
	data._high = 0;
	data._legend_manager = legend_manager
	data._low = 100000000
	data._legend = nil

	function data.destroy_graph()
		if data._datasets then
			for i, d in pairs(data._datasets) do
				d:Clear()
			end
			data._legend_manager:ResetInstances()
		end
		data._valid = false
	end

	function data.isValid()
		return data._valid
	end

	function data.toggleSmooth()
		if data._smooth then
			data._smooth = false
		else
			data._smooth = true
		end
	end

	function data.get_smoothing_factor()
		-- we want 95% accuracy is dependent on stages = 3/x = therefore x = 3 / stages
		if data._smooth == false then
			return 1
		else
			return 3 / data._data._size
		end
	end

	function data._gather_data()
		-- gather data for y axis
		data._data = data._gather_function()
		if data._smooth then
			local min_points = math.ceil(400 / data._data._size)
			if min_points > 1 then
				data.pad_data(min_points)
			end
			data.interpolate(.1)
		end
	end

	function data.high()
		return data._high
	end

	function data.low()
		return data._low
	end

	function data._generate_datasets()
		if data._datasets then
			data.destroy_graph()
		else
			data._datasets = {}
		end
		for id, value in pairs(data._data) do
			if id == "_high" or id == "_low" or id == "_size" then
				data[id] = value
			else
				local player = config.get_player(id)
				if player.isValid() then
					data._datasets[player.id] = data._control:CreateDataSet(tostring(player.id) .. "_" .. data._graph_type)
					data._datasets[player.id]:SetVisible(true)
					data._datasets[player.id]:SetWidth(2.0)
					for id, gathered_data in pairs(data._data[player.id]) do
						--for key, value in pairs(gathered_data) do
						--	data._datasets[player.id]:AddVertex(tonumber(key), tonumber(value))
						--end
						data._datasets[player.id]:AddVertex(tonumber(gathered_data.year), tonumber(gathered_data.val))
					end
				end
			end
		end
		data._legend = DMLegend(data._datasets, data._legend_manager)
		data._valid = true
	end
	function data.generate_graph()
		data._gather_data()
		data._generate_datasets()
		local years = {start = config.start_year, stop=YearToNumber(Calendar.MakeYearStr(Game.GetCurrentGameTurn() - 1))}
		data._control:SetDomain(years.start, years.stop)
		data._control:SetXTickInterval(math.floor(GetInterval(years.start, years.stop)/4))
		data._control:SetXNumberInterval(GetInterval(years.start, years.stop))
		data._legend.update()
	end
	function data.pad_data(pad)
		for id, d in pairs(data._data) do
			local tmp_data = {}
			local counter = 2
			if id == "_high" or id == "_low" or id == "_size" then
			else
				local prev_value = {val=data._data[id][1].val,year=data._data[id][1].year}
				for index, gathered_data in pairs(data._data[id]) do
					local step = {val=(gathered_data.val - prev_value.val)/pad,year=(gathered_data.year-prev_value.year)/pad}
					for i=0,pad do
						tmp_data[counter-1] = {year=prev_value.year+step.year*i,val=prev_value.val+step.val*i}
						counter = counter + 1
					end
					prev_value = {val=gathered_data.val, year=gathered_data.year}
				end
				data._data[id] = tmp_data
			end
		end
	end
	function data.interpolate(smoothing_factor)
		for id, d in pairs(data._data) do
			local tmp_data = {}
			local counter = 1
			if id == "_high" or id == "_low" or id == "_size" then
			else
				local prev_value = 0
				for index, gathered_data in pairs(data._data[id]) do
					tmp_data[counter] = {}
					if counter > 1 then
						tmp_data[counter]= {year=gathered_data.year,val=prev_value+smoothing_factor*(gathered_data.val-prev_value)}
					else
						tmp_data[counter]= {year=gathered_data.year,val=gathered_data.val}
					end
						prev_value = tmp_data[counter].val
					counter = counter + 1
				end
				data._data[id] = tmp_data
			end
		end
	end
	return data
end

function DataLoader (data_type)
	data = {}
	counter = 1
	data["_high"] = 0
	data["_low"] = 1000000
	for i, player in pairs(config.get_players()) do
		if player.isValid() then
			counter = 1
			data[player.id] = {}
			for index, historic_data in pairs(player.historic_data()) do
				value = historic_data[data_type]
				data._high = math.max(data._high, value)
				data._low = math.min(data._low, value)
				data[player.id][counter] = {year=historic_data["year"], val=value}
				counter = counter + 1
			end
		end
	end
	data["_size"] = counter
	return data
end
-- change in case of multiplayers or hotseat
-- Intialize necessary variables and UI
function Init()
	print("load completed start initizialization")
	config = Config({})
	for i, j in pairs(Players) do
		if j and j:GetID() and j:GetID() >= 0 and PlayerConfigurations[j:GetID()] and Players[j:GetID()]then
			config.add_player(j:GetID())
			if config.get_player(j:GetID()).isHuman then
				active_player = config.get_player(j:GetID())
			end
		end
	end

	local LoadPop = function()
		return DataLoader("pop")
	end

	graph_legend = InstanceManager:new("GraphLegendInstance", "GraphLegend", Controls.GraphLegendStack)

	graphs = {pop= DMGraph(function() return DataLoader("pop") end, "pop", Controls.ResultsGraph, graph_legend),
				land=DMGraph(function() return DataLoader("land") end, "land", Controls.ResultsGraph, graph_legend),
				mil=DMGraph(function() return DataLoader("mil") end, "mil", Controls.ResultsGraph, graph_legend),
				gnp=DMGraph(function() return DataLoader("gnp") end, "gnp", Controls.ResultsGraph, graph_legend),
				crop=DMGraph(function() return DataLoader("crop") end, "crop", Controls.ResultsGraph, graph_legend),
				goods=DMGraph(function() return DataLoader("goods") end, "goods", Controls.ResultsGraph, graph_legend)}

	panels = {pop=DMPanel(GetDemographics, "pop"),land=DMPanel(GetLandAll, "land"), crop=DMPanel(GetCropYieldAll, "crop"), 
				gnp=DMPanel(GetGNPAll, "gnp"),
				mil=DMPanel(GetMilitaryMight, "mil"), goods=DMPanel(GetGoodsDemographics, "goods")}
	context_store = ContextPtr
	--UpdatePanel()
	Controls.Close:RegisterCallback(Mouse.eLClick, ClosePanel)
	Controls.graphs_button:RegisterCallback(Mouse.eLClick, ShowGraph)
	Controls.info_button:RegisterCallback(Mouse.eLClick, ShowInfoPanel)
	
	Controls.show_pop_graph:RegisterCallback(Mouse.eLClick, ShowPopGraph)
	Controls.show_mil_graph:RegisterCallback(Mouse.eLClick, ShowMilGraph)
	Controls.show_gnp_graph:RegisterCallback(Mouse.eLClick, ShowGNPGraph)
	Controls.show_land_graph:RegisterCallback(Mouse.eLClick, ShowLandGraph)
	Controls.show_goods_graph:RegisterCallback(Mouse.eLClick, ShowGoodsGraph)
	Controls.show_crop_graph:RegisterCallback(Mouse.eLClick, ShowYieldGraph)
	Controls.smooth_button:RegisterCallback(Mouse.eLClick, ToggleSmooth)

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

	-- create pulldowns
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