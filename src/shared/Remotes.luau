-- Get-or-create RemoteEvents for client/server communication.
--
-- Both server and client require this module. On the server it creates a
-- `Remotes` Folder under ReplicatedStorage and populates it; on the client
-- it waits for that folder and looks up by name.
--
-- The list of remote names lives in Constants.REMOTES so we don't have
-- string literals scattered through the codebase.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild("Remotes") :: Folder
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	-- Pre-create every event listed in Constants so the client never races.
	for _, name in pairs(Constants.REMOTES) do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Remotes.get(name: string): RemoteEvent
	local ev = folder:WaitForChild(name, 10)
	assert(ev and ev:IsA("RemoteEvent"),
		string.format("Remote '%s' not found or wrong type", name))
	return ev
end

return Remotes
