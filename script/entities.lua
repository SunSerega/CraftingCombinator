local config = require ".config"
local util = require ".util"
local recipe_selector = require ".recipe-selector"


local entities = {}
entities.names = {[config.CC_NAME] = true, [config.RC_NAME]= true}

function entities.try_destroy(entity)
	if entities.names[entity.name] then
		local e = entities.find_in_global(entity)
		if e then
			e:destroy()
			return true
		end
	end
	return false
end

function entities.find_in_global(entity)
	for i = 0, config.REFRESH_RATE - 1 do
		for _, v in pairs(global.combinators[i]) do
			if v.entity == entity then return v; end
		end
	end
end

entities.RecipeCombinator = {}
-------------------------------------------------------
function entities.RecipeCombinator:new(entity)
	local res = {
		tab = global.combinators[global.combinators.get_next_index()],
		entity = entity,
		control_behavior = entity.get_or_create_control_behavior(),
	}
	
	setmetatable(res, self)
	self.__index = self
	
	table.insert(res.tab, res)
	
	return res
end

function entities.RecipeCombinator:extend()
	child = {}
	setmetatable(child, self)
	self.__index = self
	return child
end

function entities.RecipeCombinator:destroy()
	table.remove(self.tab, self:get_index())
end

function entities.RecipeCombinator:get_index()
	for i, v in pairs(self.tab) do
		if v.entity == self.entity then return i; end
	end
end

function entities.RecipeCombinator:update()
	--TODO: implement
end

entities.CraftingCombinator = entities.RecipeCombinator:extend()
--------------------------------
function entities.CraftingCombinator.update_assemblers_around(surface, position)
	local combinators = surface.find_entities_filtered{area = util.get_area(position, config.CC_SEARCH_DISTANCE), name = config.CC_NAME}
	for _, combinator in pairs(combinators) do
		entities.find_in_global(combinator):get_assembler()
	end
end

function entities.CraftingCombinator:new(entity)
	local res = entities.RecipeCombinator:new(entity)
	
	setmetatable(res, self)
	self.__index = self
	
	res:get_assembler()
	
	return res
end

function entities.CraftingCombinator:get_assembler()
	self.assembler = self.entity.surface.find_entities_filtered{
		area = util.get_directional_search_area(self.entity.position, self.entity.direction, config.CC_ASSEMBLER_SEARCH_DISTANCE, config.CC_ASSEMBLER_SEARCH_OFFSET),
		type = "assembling-machine",
	}[1]
end

function entities.CraftingCombinator:update()
	if self.assembler and self.assembler.valid then
		self.assembler.recipe = recipe_selector.get_recipe(self.control_behavior)
	end
end

return entities
