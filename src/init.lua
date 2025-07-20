local RunService = game:GetService("RunService")

-- selene: allow(undefined_variable)
if __LEMUR__ then
    return require(script.server)
end

if RunService:IsClient() then
    local server = script:FindFirstChild("server")
    if server and RunService:IsRunning() then
        server:Destroy()
    end
    return require(script.client)
else
    return require(script.server)
end