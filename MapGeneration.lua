local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local CHUNK_SIZE = 50
local CELL_SIZE = 5
local MAX_GRID_CACHE_SIZE = 600
local HalfChunkSize = CHUNK_SIZE / 2
local Seed = math.random() * 10000
local NoiseSettings = {
	Frequency = 0.1,
	Amplitude = 20,
}

local IndexX = 1
local IndexZ = 2
local BoilerplatePart = Instance.new("Part")
BoilerplatePart.Anchored = true
BoilerplatePart.CanCollide = true
BoilerplatePart.Color = Color3.fromRGB(34, 130, 66)
BoilerplatePart.Size = Vector3.new(CELL_SIZE, CELL_SIZE, CELL_SIZE)

local Pos = HumanoidRootPart.Position
local function IsEqual(A, B)
    local Larger = #A > #B and A or B
    local Smaller = Larger == B and A or B
    for Index, Value in Larger do
        if Value ~= Smaller[Index] then
            return false
        end
    end
    return true
end
local function ShallowCopy(Table)
    local Copy = {}
    for Index, Value in Table do
        Copy[Index] = Value
    end
    return Copy
end
local CurrentCell
local GridCache = {}
local Chunk = {}
function Chunk.LoadChunk()
	local CellX = CurrentCell[IndexX]
	local CellZ = CurrentCell[IndexZ]
	local UpdatedJustLoaded = {}
	for X = CellX - HalfChunkSize - 1, CellX + HalfChunkSize + 1 do
		for Z = CellZ - HalfChunkSize - 1, CellZ + HalfChunkSize + 1 do
			if not GridCache[X] then
				GridCache[X] = {}
			end
			local ExteriorRange = X == CellX - HalfChunkSize - 1 or X == CellX + HalfChunkSize + 1 or Z == CellZ - HalfChunkSize - 1 or Z == CellZ + HalfChunkSize + 1
			if ExteriorRange then
				if GridCache[X] and GridCache[X][Z] then
					GridCache[X][Z].Parent = nil
					continue
				end
			else
				local Neighbor = GridCache[X][Z]        
				local NewLocation
				if Neighbor then
					Neighbor.Parent = workspace
				else
					local Noise = math.noise(X * NoiseSettings.Frequency, Z * NoiseSettings.Frequency, Seed) * NoiseSettings.Amplitude
					local Part = BoilerplatePart:Clone()
					Part.Position = Vector3.new(X * CELL_SIZE, Noise, Z * CELL_SIZE)
					Part.Parent = workspace
					GridCache[X][Z] = Part
				end
			end
		end
	end
end
function Chunk.GetNewCellOfPlayer()
    return {
        [IndexX] = math.floor(Pos.X / CELL_SIZE),
        [IndexZ] = math.floor(Pos.Z / CELL_SIZE),
    }
end
CurrentCell = Chunk.GetNewCellOfPlayer()
RunService.Heartbeat:Connect(function()
    Pos = HumanoidRootPart.Position
    local NewCell = Chunk.GetNewCellOfPlayer()
    if Humanoid.MoveDirection.Magnitude > 0 and not IsEqual(CurrentCell, NewCell) then
        CurrentCell = NewCell
        Chunk.LoadChunk()
    end
end)
local Module = {}
function Module.SetChunkSize(ChunkSize)
    CHUNK_SIZE = ChunkSize
end
return Module
