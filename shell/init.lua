--[[
    shell mod for Minetest - A mod for adding a shell mode chat for test 
    purposes
    (c) Pierre-Yves Rollo

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
--]]

shell = {
	name = minetest.get_current_modname(),
	path = minetest.get_modpath(minetest.get_current_modname()),
}

local color = {
    normal = string.char(0x1b).."(c@#ffffff)",
	bad = string.char(0x1b).."(c@#ff0000)",
    name = string.char(0x1b).."(c@#ffff00)",
    good = string.char(0x1b).."(c@#00ff00)",
    dummy = string.char(0x1b).."(c@#00007f)",
}

-- Registered commands
local commands = {}

-- Per player environments
local player_envs = {}

minetest.register_privilege("shell",  {
	description = "Player can enter in shell mode.",
	give_to_singleplayer= true,
})

-- Default player environment
minetest.register_on_joinplayer(function(player)
	local name = player:get_player_name()
	if player_envs[name] == nil then
		player_envs[name] = {
			shell = false, -- Shell mode off
			echo = true,   -- Echo on (see chat messages)
		}
	end
	player_envs[name].shell = false -- Reset normal mod on join
end)

-- Chat hack
local send = minetest.chat_send_player

minetest.chat_send_all = function(message)
	for _,player in ipairs(minetest.get_connected_players()) do
		minetest.chat_send_player(player:get_player_name(), message)
	end
end

minetest.chat_send_player = function(name, message)
	-- Display other chat messages only if echo is set when in shell mode
	if not player_envs[name].shell or player_envs[name].echo then
		send(name, message)
	end
end

-- Command management
minetest.register_on_chat_message(function(name, message)
	if player_envs[name].shell then
		-- Echo command
		send(name, "]"..message)
		local command, param = message:match("^([^ ]+)[ ]*(.*)$")

		if command == nil then
			return true
		end

		if commands[command] == nil then
			send(name, "Unknown command \""..command.."\".")
			return true
		end

		commands[command].func(name, param)
		return true		
	end
end)

-- Register command 
-- Definition is similar to register_chatcommand definition :
--   func : the function to call
--   description : Description text displayed in help
--   params : parameter list displayed in help

function shell.register_command(name, definition)
	assert(type(name) == "string", 
		"["..shell.name.."] register_command:"..
		" name argument should be a string.")
	assert(type(definition) == "table", 
		"["..shell.name.."] register_command:"..
		" definition argument should be a table.")
	assert(type(definition.func) == "function", 
		"["..shell.name.."] register_command:"..
		" definition func field should be a function.")
	
	commands[name] = { desctiption = "", params = "" }
	
	for key, value in pairs(definition) do
		commands[name][key] = value
	end
end

-- Base commands
shell.register_command("exit", {
	func = function(name)
		send(name, "Leaving shell mode.")
		player_envs[name].shell = false
	end,
	description = "Leave the shell mode",
})

shell.register_command("help", {
	func = function(name, param)
		if param == "" then
			send(name, "You are in shell mod. Type \"exit\" to leave.")
			send(name, "Available commands are:")
			local text
			for command, def in pairs(commands) do
				text = command
				if def.description ~= "" then
					text = text..": "..def.description
				end
				send(name, text)
			end
		else
			if commands[param] ~= nil then
				text = param
				def = commands[param]
				if def.params ~= "" then
					text = text.." "..def.params
				end
				if def.description ~= "" then
					text = text.."\n"..def.description
				end
				send(name, text)
			else
				send(name, "No \""..param.."\" command registered.")
			end
		end
	end,
	params = "<command>",
	description = "Help on a command or list commands",
})


minetest.register_chatcommand("shell", 
{
	params = "",
	description = "Enter in shell mode",
	func = function(name, param)
		local player = minetest.get_player_by_name(name)
		if not player then
			return false, "Player not found"
		end
		
		if not minetest.check_player_privs(name, {shell = true}) then
			return false, "No shell priv"
		end
		
		player_envs[name].shell = true
		send(name, "Entering shell mode, type \"exit\" to leave.")
	end,
})

