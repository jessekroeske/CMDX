local completed, result = xpcall(function()
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local TestEZ = require(ReplicatedStorage.TestEZ)

	local results = TestEZ.TestBootstrap:run({ ReplicatedStorage.CMDX }, TestEZ.Reporters.TextReporter,{
		tttest = "teeest"
	})

	return results.failureCount == 0 and 0 or 1
end, debug.traceback)

local statusCode
local errorMessage = nil
if completed then
	statusCode = result
else
	statusCode = 1
	errorMessage = result
end

if errorMessage ~= nil then
	print(errorMessage)
end
-- selene: allow(incorrect_standard_library_use)
os.exit(statusCode)
