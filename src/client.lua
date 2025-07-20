local commandsFolder = nil
local reliableCommand = nil
local unreliableCommand = nil

local function getCommandsFolder()
	if not commandsFolder then
		commandsFolder = (script.Parent :: Instance):WaitForChild("Commands", 5)
		if not commandsFolder then
			error("Commands folder not found in script parent.")
		end
	end
	return commandsFolder
end

local function getReliableCommand()
	if not reliableCommand then
		local folder = getCommandsFolder()
		if not folder then
			error("Command engine not initialized.")
		end
		reliableCommand = (getCommandsFolder() :: Instance):WaitForChild("ReliableCommand", 5)
	end
	return reliableCommand
end

local function getUnreliableCommand()
	if not unreliableCommand then
		local folder = getCommandsFolder()
		if not folder then
			error("Command engine not initialized.")
		end
		unreliableCommand = (getCommandsFolder() :: Instance):WaitForChild("UnreliableCommand", 5)
	end
	return unreliableCommand
end

local client = {}

--[=[
    Is used to send a command message to the server.
    This function can be used as an alternative to the default chat system.
    @param message string -- The message to send to the server.
]=]
function client:send(message: string, unreliable: boolean?)
	local event = unreliable and getUnreliableCommand() or getReliableCommand()
	if not event then
		error("Command engine not initialized.")
		return
	end
	event:FireServer(message)
end

return client
