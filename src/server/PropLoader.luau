--!strict
-- Loads the Blender-generated meshes (uploaded via Open Cloud, IDs in ASSETS.md)
-- into ServerStorage.Props before the map is built. Any failure just leaves
-- MapBuilder on its primitive fallbacks.

local InsertService = game:GetService("InsertService")
local ServerStorage = game:GetService("ServerStorage")

local PropLoader = {}

local PROPS: { [string]: number } = {
	LeafPile = 101031408684745,
	MapleLeaf = 85404791493991,
	OakCanopy = 83418390409889,
	OakTrunk = 98419723218144,
	Pumpkin = 113539707798880,
	TreeCanopy = 113492101154866,
}
function PropLoader.load(timeout: number): Folder?
	local folder = ServerStorage:FindFirstChild("Props") or Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = ServerStorage
	local pending = 0
	for name, id in PROPS do
		if folder:FindFirstChild(name) then
			continue
		end
		pending += 1
		task.spawn(function()
			local ok, model = pcall(InsertService.LoadAsset, InsertService, id)
			if ok and model then
				local mesh = model:FindFirstChildWhichIsA("MeshPart", true)
				if mesh then
					mesh.Name = name
					mesh.Anchored = true
					mesh.CanCollide = false
					mesh.CastShadow = false
					mesh.CanTouch = false -- clones inherit these; decor needs no touch/raycast work
					mesh.CanQuery = false
					mesh.Parent = folder
				else
					warn("[Props] no MeshPart in asset " .. id)
				end
				model:Destroy()
			else
				warn("[Props] failed to load " .. name .. ": " .. tostring(model))
			end
			pending -= 1
		end)
	end
	local t0 = os.clock()
	while pending > 0 and os.clock() - t0 < timeout do
		task.wait(0.1)
	end
	-- the client needs the leaf mesh for its local leaves
	local leaf = folder:FindFirstChild("MapleLeaf")
	if leaf then
		local shared = game:GetService("ReplicatedStorage"):FindFirstChild("Props") or Instance.new("Folder")
		shared.Name = "Props"
		shared.Parent = game:GetService("ReplicatedStorage")
		if not shared:FindFirstChild("MapleLeaf") then
			leaf:Clone().Parent = shared
		end
	end
	return if #folder:GetChildren() > 0 then folder :: Folder else nil
end

return PropLoader
