local LOAD_MODULES = {
	{"src/init.", "CMDX"},
	{"modules/testez/src", "TestEZ"},
}
local function getScriptDir()
	local str = debug.getinfo(1, "S").source:sub(2)
	return str:match("(.*/)") or str:match("(.*\\)")
end

local path = getScriptDir()
package.path = path .. "modules/lemur/?.lua;" ..
               path .. "modules/lemur/?/init.lua;" ..
               package.path

local lemur = require("init") -- lädt modules/lemur/init.lua

-- selene: allow(incorrect_standard_library_use)
local lemur = require("lemur")

local habitat = lemur.Habitat.new()

local ReplicatedStorage = habitat.game:GetService("ReplicatedStorage")

for _, module in ipairs(LOAD_MODULES) do
	local container = habitat:loadFromFs(module[1])
	container.Name = module[2]
	container.Parent = ReplicatedStorage
end

local runTests = habitat:loadFromFs("test/init.lua")
habitat:require(runTests)