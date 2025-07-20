local LOAD_MODULES = {
	{"src", "CMDX"},
	{"modules/testez/src", "TestEZ"},
}
package.path = "./?.lua;./?/init.lua;./modules/?.lua;./modules/?/init.lua;" .. package.path

-- selene: allow(incorrect_standard_library_use)
local lemur = require("lemur")

local habitat = lemur.Habitat.new()

local ReplicatedStorage = habitat.game:GetService("ReplicatedStorage")

for _, module in ipairs(LOAD_MODULES) do
	local container = habitat:loadFromFs(module[1])
	container.Name = module[2]
	container.Parent = ReplicatedStorage
end

local runTests = habitat:loadFromFs("test/runner.server.lua")
habitat:require(runTests)