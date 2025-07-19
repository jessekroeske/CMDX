local server = require(script.Parent.Parent.server)

return function()
	it("führt einen einfachen Befehl erfolgreich aus", function()
		-- Arrange
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
		}

		-- Act
		local success, err = cmd:testCommand(mockPlayer, "/hello")

		-- Assert
		expect(success).to.equal(true)
		expect(err).never.to.be.ok()
		expect(executed).to.equal(true)
		expect(receivedArgs).to.be.a("table")
	end)
end