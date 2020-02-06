env_sounds = {}
local registered_sounds = {}
env_sounds.registered_sounds = registered_sounds

-- Update sound for players. We play the same sound at the same time for all players,
-- so if several players are in the same location they will hear approximately the 
-- same thing at the same time (though the exact position the sound comes from may vary)
local function update_sound(def_name)

	-- we look up the def each time so that if it gets updated we can adapt
	local def = registered_sounds[def_name]
	if not def then
		-- def got removed, no further updates
		return
	end

	-- Look up and cache various values that only need to be calculated once

	local sounds
	local timeofday = minetest.get_timeofday()
	if timeofday > 0.2 and timeofday < 0.8 then
		sounds = def.sounds_day
	else
		sounds = def.sounds_night
	end
	if not sounds then
		-- no sounds defined for this timeframe, so just pass
		minetest.after(math.random(def.delay_min, def.delay_max), update_sound, def_name)
		return
	end

	local radius = def.radius or 8
	local gain_minimum = def.gain_minimum or 0.4
	local gain_maximum = def.gain_maximum or 1
	local nodes = def.nodes
	local sound = sounds[math.random(#sounds)]
	local gain_multiplier
	local adjust_gain = def.adjust_gain ~= false
	local average_pos = def.average_pos ~= false
	if adjust_gain then
		gain_multiplier = 1/(4*radius*radius)
	end

	for _, player in pairs(minetest.get_connected_players()) do
		local player_name = player:get_player_name()
		local player_pos = player:get_pos()
		local area_min = vector.subtract(player_pos, radius)
		local area_max = vector.add(player_pos, radius)
		local node_positions, _ = minetest.find_nodes_in_area(area_min, area_max, nodes)
		local node_count = #node_positions
		if node_count > 0 then
		
			local sound_pos
			if average_pos then
				-- Find average position of node positions
				sound_pos = vector.new()
				for _, pos in ipairs(node_positions) do
					sound_pos.x = sound_pos.x + pos.x
					sound_pos.y = sound_pos.y + pos.y
					sound_pos.z = sound_pos.z + pos.z
				end
				sound_pos = vector.divide(sound_pos, node_count)
			else
				sound_pos = node_positions[math.random(node_count)]
			end
			
			local gain
			if adjust_gain then
				gain = math.min(math.max(node_count * gain_multiplier, gain_minimum), gain_maximum)
			else
				gain = math.random(gain_minimum, gain_maximum)
			end
	
			minetest.sound_play(
				sound,
				{
					pos = sound_pos,
					to_player = player_name,
					gain = gain,
				}
			)
		end
	end
	
	minetest.after(math.random(def.delay_min, def.delay_max), update_sound, def_name)
end

env_sounds.register_sound = function(name, def)
	registered_sounds[name] = def
	minetest.after(0, update_sound, name)
end

if minetest.get_modpath("default") then
	local river_source_sounds = minetest.settings:get_bool("river_source_sounds")

	local water_def = {
		nodes = {"default:water_flowing", "default:river_water_flowing"},
		radius = 8,
		gain_minimum = 0.4,
		gain_maximum = 1,
		adjust_gain = true,
		average_pos = true,
		sounds_day = {"env_sounds_water"},
		sounds_night = {"env_sounds_water"},
		delay_min = 3.5,
		delay_max = 3.5,
	}
	if river_source_sounds then
		table.insert(water_def.nodes, "default:river_water_source")
	end
	
	env_sounds.register_sound("default:water_flowing", water_def)
end