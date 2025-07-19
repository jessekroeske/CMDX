local eventFolder = Instance.new("Folder")
eventFolder.Name = "Commands"
eventFolder.Parent = script.Parent

local unreliableCommandEvent = Instance.new("UnreliableRemoteEvent")
local reliableCommandEvent = Instance.new("RemoteEvent")
local defaultConfig = require(script.Parent.config)

local serverInstances = {}
local commandInstanceMap = {}

unreliableCommandEvent.Name = "UnreliableCommand"
reliableCommandEvent.Name = "ReliableCommand"
unreliableCommandEvent.Parent = eventFolder

local function splitMessage(input): (table?, string?)
	local text = input
	local result = {}
	-- selene: allow(unbalanced_assignments)
	local spat, epat, buf, quoted = [=[^(['"])]=], [=[(['"])$]=]
	for str in text:gmatch("%S+") do
		local squoted = str:match(spat)
		local equoted = str:match(epat)
		local escaped = str:match([=[(\*)['"]$]=])
		if squoted and not quoted and not equoted then
			buf, quoted = str, squoted
		elseif buf and equoted == quoted and #escaped % 2 == 0 then
			str, buf, quoted = buf .. " " .. str, nil, nil
		elseif buf then
			buf = buf .. " " .. str
		end
		if not buf then
			table.insert(result, (str:gsub(spat, ""):gsub(epat, "")))
		end
	end
	if buf then
		return nil, "Unmatched quote in command message."
	end
	return result
end

local function buildFQCN(prefix: string, namespace: string?, commandName: string): string
	return prefix .. (namespace and namespace .. " " or "") .. commandName
end

local function handleError(self, player, message)
	if self._globalConfig.onError then
		self._globalConfig.onError(player, message)
	else
		warn(message)
	end
end

local function parseType(value, type)
	if type == "number" then
		return tonumber(value)
	elseif type == "boolean" then
		if typeof(value) == "boolean" then
			return value
		end
		if value:lower() == "true" then
			return true
		elseif value:lower() == "false" then
			return false
		else
			return true
		end
	elseif type == "string" then
		return tostring(value)
	end
	return value
end

local function deepMerge(base, override)
	for k, v in pairs(override) do
		if typeof(v) == "table" and typeof(base[k]) == "table" then
			base[k] = deepMerge(base[k], v)
		else
			base[k] = v
		end
	end
	return base
end

local function findOptionValue(argName, split, short, long, type): any?
	assert(type(split) == "table", "Split must be a table")
	if short then
		assert(type(short) == "string", "Short form must be a string")
	end
	if long then
		assert(type(long) == "string", "Long form must be a string")
	end
	assert(type(type) == "string", "Type must be a string")

	if not short and not long then
		return parseType(split[argName], type)
	end

	for _, v in ipairs(split) do
		if v:sub(1, #short) == short then
			return parseType(v:sub(#short + 1), type)
		elseif v:sub(1, #long) == long then
			return parseType(v:sub(#long + 1), type)
		end
	end

	return nil
end

local function onCommand(instance, commandName, player, message)
	if not instance or not instance._commands then
		warn("Command instance is not initialized or has no commands.")
		return
	end
	if not commandName then
		return
	end
	local command = instance._commands[commandName]
	if command then
		local cooldown = command.config.playerCooldown or instance._globalConfig.playerCooldown
		local key = player.UserId .. "_" .. commandName
		if cooldown then
			instance._lastExecution = instance._lastExecution or {}
			local last = instance._lastExecution[key] or 0
			if os.time() - last < cooldown then
				handleError(instance, player, "You're sending commands too fast!")
				return
			end
			instance._lastExecution[key] = os.time()
		end
		local result, err, help = instance:resolveCommand(player, command.config, message)
		if err then
			handleError(instance, player, err)
		end
		local onBeforeCallback = command.config.onBeforeCallback or instance._globalConfig.onBeforeCallback
		if onBeforeCallback then
			local allow, reason = onBeforeCallback(player, result, err, help)
			if not allow then
				handleError(instance, player, reason or "An error occurred in onBeforeCallback.")
				return
			end
		end
		command.callback(player, result, err, help)
	else
		if instance._globalConfig.onUnknownCommand then
			instance._globalConfig.onUnknownCommand(player, commandName, message)
		end
		warn("Unreliable command not found: " .. commandName)
	end
end

local function getInstanceByMessage(message)
	for fqcn, i in pairs(commandInstanceMap) do
		if message:sub(1, #fqcn + 1) == fqcn .. " " then
			return i.instance, i.name
		end
	end
end

unreliableCommandEvent.OnServerEvent:Connect(function(player, message)
	if not player or not player:IsA("Player") then
		warn("Invalid player in unreliable command event.")
		return
	end
	local instance, commandName = getInstanceByMessage(message)
	onCommand(instance, commandName, player, message)
end)
reliableCommandEvent.OnServerEvent:Connect(function(player, message)
	if not player or not player:IsA("Player") then
		warn("Invalid player in unreliable command event.")
		return
	end
	local instance, commandName = getInstanceByMessage(message)
	onCommand(instance, commandName, player, message)
end)

game.Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		if not player or not player:IsA("Player") then
			warn("Invalid player in unreliable command event.")
			return
		end
		local instance, commandName = getInstanceByMessage(message)
		onCommand(instance, commandName, player, message)
	end)
end)

local server = {}
server.__index = server

function server.new(globalConfigOverride: table?)
	local self = setmetatable({}, server)
	self._commands = {}
	self._globalConfig = deepMerge(table.clone(defaultConfig), globalConfigOverride or {})
	table.insert(serverInstances, self)
	return self
end

function server:getRegisteredCommands(player)
	local list = {}
	for _, instance in ipairs(serverInstances) do
		for name, info in pairs(instance._commands) do
			if instance:verifyPlayer(player, info.config) then
				table.insert(list, {
					name = name,
					args = info.config.arguments,
					description = info.config.description or "No description.",
				})
			end
		end
	end
	return list
end

function server:registerCommand(commandName, config, callback)
	assert(type(self) == "table", "Server must be initialized before registering commands")
	assert(type(commandName) == "string", "Command name must be a string")
	assert(type(config) == "table", "Config must be a table")
	assert(type(callback) == "function", "Callback must be a function")
	if self._commands[commandName] and not config.override then
		local msg = "Command already registered: " .. commandName
		if self._globalConfig.strict then
			error(msg)
		else
			warn(msg)
			return
		end
	end
	self._commands[commandName] = {
		config = config,
		callback = callback,
	}
	local fullyQualifiedName = buildFQCN(self._globalConfig.prefix, self._globalConfig.namespace, commandName)
	if commandInstanceMap[fullyQualifiedName] then
		warn("Command already registered with fully qualified name: " .. fullyQualifiedName)
	end
	commandInstanceMap[fullyQualifiedName] = {
		instance = self,
		name = commandName,
	}
end

function server:resolveCommand(player, config, message): (table?, string?, string?)
	local onCommandReceived = config.onCommandReceived or self._globalConfig.onCommandReceived
	if onCommandReceived then
		onCommandReceived(player, message)
	end
	assert(type(player) == "Instance" and player:IsA("Player"), "Player must be a valid Player instance")
	assert(type(config) == "table", "Config must be a table")
	assert(type(message) == "string", "Message must be a string")

	if not self:verifyPlayer(player, config) then
		return nil, "Player does not have permission to execute this command.", nil
	end

	local configArguments = config.arguments or {}

	local argValues = {}
	local messageArgs, err = splitMessage(message)

	if not messageArgs then
		return nil, err, nil
	end

	if messageArgs[2] == "?" and configArguments.help then
		return nil, nil, configArguments.help
	end

	for argName, argConfig in pairs(configArguments) do
		local value = findOptionValue(
			argName,
			messageArgs,
			(config.shortOptionPrefix or self._globalConfig.shortOptionPrefix or "") .. argConfig.shortForm,
			(config.longOptionPrefix or self._globalConfig.longOptionPrefix or "") .. argConfig.longForm,
			argConfig.type
		)
		if argConfig.required and not value then
			return nil, "Missing required argument: " .. argName
		end
		if value then
			argValues[argName] = value
		end
	end

	return argValues
end

function server:verifyPlayer(player, config)
	if
		not config.requiredRank
		and not config.whiteListedUserIds
		and not self._globalConfig.requiredRank
		and not self._globalConfig.whiteListedUserIds
	then
		return true
	end
	local hasLocalRequiredRank = config.requiredRank
		and player:GetRankInGroup(config.groupId or self._globalConfig.groupId) >= config.requiredRank
	local isLocalWhitelisted = config.whiteListedUserIds and table.find(config.whiteListedUserIds, player.UserId)
	local hasGlobalRequiredRank = false
	if not config.requiredRank then
		hasGlobalRequiredRank = self._globalConfig.requiredRank
			and player:GetRankInGroup(self._globalConfig.groupId) >= self._globalConfig.requiredRank
	end
	local isGlobalWhitelisted = false
	if not config.whiteListedUserIds then
		isGlobalWhitelisted = self._globalConfig.whiteListedUserIds
			and table.find(self._globalConfig.whiteListedUserIds, player.UserId)
	end
	return hasLocalRequiredRank or isLocalWhitelisted or hasGlobalRequiredRank or isGlobalWhitelisted
end

function server:extractCommandName(message): string?
	local prefix = self._globalConfig.prefix
	local ns = self._globalConfig.namespace
	local pattern = "^" .. prefix .. (ns and ns .. " " or "") .. "(%w+)"
	return message:match(pattern)
end

function server:testCommand(player, rawMessage)
	local commandName = self:extractCommandName(rawMessage)
	if not commandName then
		return false, "Command not found"
	end

	local command = self._commands[commandName]
	if not command then
		return false, "Command not found"
	end

	local result, err, help = self:resolveCommand(player, command.config, rawMessage)
	if err then
		return false, err
	end

	local onBefore = command.config.onBeforeCallback or self._globalConfig.onBeforeCallback
	if onBefore then
		local allow, reason = onBefore(player, result, err, help)
		if not allow then
			return false, reason or "Blocked by onBeforeCallback"
		end
	end

	local ok, response = pcall(command.callback, player, result, err, help)
	if not ok then
		return false, "Callback error: " .. tostring(response)
	end

	return true, response
end

return server
