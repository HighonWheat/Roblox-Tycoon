local starterPlayerScripts = game:GetService("Players").LocalPlayer:WaitForChild("PlayerScripts")
local HUDController = require(starterPlayerScripts:WaitForChild("Controllers"):WaitForChild("HUDController"))

HUDController.Init()
print("[Ghostshift] Client initialized successfully.")
