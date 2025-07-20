local ReplicatedStorage = game:GetService("ReplicatedStorage")
local server = require(ReplicatedStorage.CMDX)

return function()
	it("führt einen einfachen Befehl erfolgreich aus", function()
		local executed = false
		local receivedArgs = nil

		local cmd = server.new({
			prefix = "/",
		})

		cmd:registerCommand("hello", {
			description = "Sagt Hallo!",
			arguments = {},
		}, function(player, args)
			executed = true
			receivedArgs = args
		end)

		local mockPlayer = {
			UserId = 123,
			IsA = function(_, cls) return cls == "Player" end,
			GetRankInGroup = function() return 255 end,
		}

		local success, err = cmd:testCommand(mockPlayer, "/hello")

		expect(success).to.equal(true)
		expect(err).never.to.be.ok()
		expect(executed).to.equal(true)
		expect(receivedArgs).to.be.a("table")
	end)

	it("führt einen Befehl mit Argumenten korrekt aus", function()
		local capturedValue = nil

		local cmd = server.new({
			prefix = "!",
		})

		cmd:registerCommand("echo", {
			description = "Gibt das Argument zurück",
			arguments = {
				message = {
					type = "string",
					required = true,
					shortForm = "m",
					longForm = "message",
				},
			},
		}, function(player, args)
			capturedValue = args.message
		end)

		local mockPlayer = {
			UserId = 1,
			IsA = function(_, cls) return cls == "Player" end,
			GetRankInGroup = function() return 255 end,
		}

		local success, err = cmd:testCommand(mockPlayer, "!echo -mHello")

		expect(success).to.equal(true)
		expect(capturedValue).to.equal("Hello")
	end)

	it("gibt Fehler zurück bei fehlendem Argument", function()
		local cmd = server.new({ prefix = ";" })

		cmd:registerCommand("failtest", {
			description = "Wird fehlschlagen ohne Argument",
			arguments = {
				need = {
					type = "string",
					required = true,
					shortForm = "n",
					longForm = "need",
				},
			},
		}, function() end)

		local mockPlayer = {
			UserId = 1,
			IsA = function(_, cls) return cls == "Player" end,
			GetRankInGroup = function() return 255 end,
		}

		local success, _ = cmd:testCommand(mockPlayer, ";failtest")

		expect(success).to.equal(false)
	end)

	it("verweigert Spieler ohne ausreichenden Rang", function()
		local cmd = server.new({
			prefix = "#",
			requiredRank = 200,
			groupId = 1234,
		})

		cmd:registerCommand("secure", {
			description = "nur für hohe Ränge",
		}, function() end)

		local mockPlayer = {
			UserId = 99,
			IsA = function(_, cls) return cls == "Player" end,
			GetRankInGroup = function() return 100 end, -- zu niedrig
		}

		local success, err = cmd:testCommand(mockPlayer, "#secure")

		expect(success).to.equal(false)
		expect(err).to.equal("Player does not have permission to execute this command.")
	end)

	it("gibt Fehlermeldung bei unbekanntem Befehl", function()
		local cmd = server.new({ prefix = "!" })

		local mockPlayer = {
			UserId = 123,
			IsA = function(_, cls) return cls == "Player" end,
			GetRankInGroup = function() return 255 end,
		}

		local success, err = cmd:testCommand(mockPlayer, "!doesnotexist")

		expect(success).to.equal(false)
		expect(err).to.equal("Command not found")
	end)
end
