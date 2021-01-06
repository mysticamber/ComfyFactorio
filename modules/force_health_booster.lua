-- All entities that own a unit_number of a chosen force gain damage resistance.
-- ignores entity health regeneration

-- Use Public.set_health_modifier(force_index, modifier) to modify health.
-- 1 = original health, 2 = 200% total health, 4 = 400% total health,..

local Global = require 'utils.global'
local Event = require 'utils.event'
local Public = {}

local math_round = math.round

local fhb = {}
Global.register(
    fhb,
    function(tbl)
        fhb = tbl
    end
)

local health_boosted_units = {}
Global.register(
	health_boosted_units,
	function(tbl)
		health_boosted_units = tbl
	end
)

local function init_health_modifiers(force_index, type)
	if not fhb[force_index] then fhb[force_index] = {} end

	if type ~= nil then
		if not fhb[force_index][type] then fhb[force_index][type] = {} end
		return fhb[force_index][type]
	end

	return fhb[force_index]
end

local function get_health_modifiers(force_index, type)
	-- we don't have modifers for this force
	if not fhb[force_index] then return end

	-- type exist and we have a modifier for it
	if type ~= nil and fhb[force_index][type] then
		return fhb[force_index][type].m
	end

	-- fallback to the default
	return fhb[force_index].m
end

function Public.set_health_modifier(force_index, modifier)
	if not game.forces[force_index] then return end
	if not modifier then return end

	init_health_modifiers(force_index).m = math_round(1 / modifier, 4)
end

function Public.set_health_modifier_by_type(force_index, type, modifier)
	if not game.forces[force_index] then return end
	if not modifier then return end

	init_health_modifiers(force_index, type).m = math_round(1 / modifier, 4)
end

function Public.reset_tables()
	for k, v in pairs(fhb) do fhb[k] = nil end
	for k, v in pairs(health_boosted_units) do health_boosted_units[k] = nil end
end

local function is_valid_entity(entity)
	-- Check for a valid entity
	if not entity or not entity.valid then
		return false
	end



	local unit_number = entity.unit_number
	if not unit_number then
		return false
	end

	-- If we have no modifiers for the force, do nothing with this unit
	if not fhb[entity.force.index] then
		return false
	end

	return true
end

-- if the init is successful, return true
local function init_unit_health(entity)
	-- It's a first time a unit from this force was damaged so init
	if not health_boosted_units[entity.force.index] then health_boosted_units[entity.force.index] = {} end

	-- It's the first time this unit was damaged
	if not health_boosted_units[entity.force.index][entity.unit_number] then health_boosted_units[entity.force.index][entity.unit_number] = entity.prototype.max_health end

	return true
end

local function get_adjusted_unit_health(entity)
    if init_unit_health(entity) then
		return health_boosted_units[entity.force.index][entity.unit_number]
	end
end

local function set_adjusted_unit_health(entity, health)
	if init_unit_health(entity) == true then
		health_boosted_units[entity.force.index][entity.unit_number] = health
	end
end

local function on_entity_damaged(event)
	if is_valid_entity(event.entity) == false then return end

	local unit_health = get_adjusted_unit_health(event.entity)

	-- Get modifier and abort if it's nil
	local modifier = get_health_modifiers(event.entity.force.index, event.entity.name)
	if modifier == nil then return end

	-- Calculate and apply new health
	local new_health = unit_health - event.final_damage_amount * modifier
	set_adjusted_unit_health(event.entity, new_health)

	event.entity.health = new_health
end

local function on_entity_died(event)
	if not is_valid_entity(event.entity) then return end
	-- reset unit health state. TODO: fix memory leak where unit number remains in the table
	set_adjusted_unit_health(event.entity, nil)
end

local function on_player_repaired_entity(event)
	if not is_valid_entity(event.entity) then return end
	-- repair rate is not modified
	set_adjusted_unit_health(event.entity, event.entity.health)
end

local function on_init()
	Public.reset_tables()
end

Event.on_init(on_init)
Event.add(defines.events.on_entity_damaged, on_entity_damaged)
Event.add(defines.events.on_entity_died, on_entity_died)
Event.add(defines.events.on_player_repaired_entity, on_player_repaired_entity)

return Public