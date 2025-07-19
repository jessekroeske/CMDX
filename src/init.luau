local RunService = game:GetService("RunService")

if RunService:IsClient() then
    local server = script:FindFirstChild("server")
    if server and RunService:IsRunning() then
        server:Destroy()
    end
    require(script.client)
else
    require(script.server)
end