local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Humanoid = Character:WaitForChild("Humanoid")

local CHUNK_SIZE = 50
local CELL_SIZE = 2
local MAX_GRID_CACHE_SIZE = 3000
local HalfChunkSize = CHUNK_SIZE / 2

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
local function SetDifference(A, B)
    local Difference = ShallowCopy(A)
    for _, Value in A do
        if table.find(B, Value) then
            table.remove(A, table.find(A, Value))
        end
    end
    return Difference
end
local CurrentCell
local Locations = {}
local JustLoaded = {}
local GridCache = {}
local Chunk = {}
function Chunk.LoadChunk()
    local CellX = CurrentCell[IndexX]
    local CellZ = CurrentCell[IndexZ]
    local UpdatedJustLoaded = {}
    for X = CellX - HalfChunkSize, CellX + HalfChunkSize do
        for Z = CellZ - HalfChunkSize, CellZ + HalfChunkSize do
            if not GridCache[X] then
                GridCache[X] = {}
            end
            local Neighbor = GridCache[X][Z]
            local NewLocation
            if Neighbor then
                Neighbor.Parent = workspace
            else
                if #Locations == MAX_GRID_CACHE_SIZE then
                    local Removed = table.remove(Locations, 1)
                    GridCache[Removed[IndexX]][Removed[IndexZ]]:Destroy()
                    GridCache[Removed[IndexX]][Removed[IndexZ]] = nil
                end
                NewLocation = {
                    [IndexX] = X,
                    [IndexZ] = Z,
                }
                table.insert(Locations, NewLocation)
                local Part = BoilerplatePart:Clone()
                Part.Position = Vector3.new(X * CELL_SIZE, 0, Z * CELL_SIZE)
                Part.Parent = workspace
                GridCache[X][Z] = Part
            end
            table.insert(UpdatedJustLoaded, NewLocation or {
                [IndexX] = X,
                [IndexZ] = Z,
            })
        end
    end
    if next(JustLoaded) then
        Chunk.Unload(SetDifference(UpdatedJustLoaded, JustLoaded)) 
    end
    JustLoaded = UpdatedJustLoaded
end
function Chunk.Unload(Difference)
    for _, Object in Difference do
        GridCache[Object[IndexX]][Object[IndexZ]].Parent = nil
        continue
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
