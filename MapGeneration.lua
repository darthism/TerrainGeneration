local RunService = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

local CHUNK_SIZE = 15
local RENDER_RADIUS = 100

local NOISE_SETTINGS = {
    FREQUENCY = 0.5,
    AMPLITUDE = 2,
    SEED = math.random(1, 10000)
}
local BOILERPLATE_PART = Instance.new("Part")
BOILERPLATE_PART.Anchored = true
BOILERPLATE_PART.CanCollide = true
BOILERPLATE_PART.Color = Color3.fromRGB(95, 209, 142)
BOILERPLATE_PART.Material = Enum.Material.SmoothPlastic
BOILERPLATE_PART.Size = Vector3.new(16, 1, 10)

local BoilerPlateSizeX = BOILERPLATE_PART.Size.X
local BoilerPlateSizeZ = BOILERPLATE_PART.Size.Z
local RangeX = 1
local RangeZ = 2
local CurrentZone = nil
local function GetPerpindicularVectors(Vector, Axis)
    local Product = Vector:Cross(Axis).Unit * Vector.Magnitude
    return {
        -Vector,
        Product,
        -Product
    }
end
local Set = {}
Set.__index = Set

function Set.new(...)
    local Default = {...}
    local Checker = {}
    for Index, Value in ipairs(Default) do
        Checker[Value] = Index
    end
    return setmetatable({
        Checker = Checker,
        Values = Default,
        Size = #Default
    }, Set)
end
function Set:Insert(Value)
    if self.Checker[Value] then return end
    self.Size += 1
    table.insert(self.Values, Value)
    self.Checker[Value] = self.Size
    return true
end
function Set:Remove(Value)
    local IndexToRemove = self.Checker[Value]
    if not IndexToRemove then return end
    self.Size -= 1
    self.Checker[Value] = nil
    table.remove(self.Values, IndexToRemove)
    return true
end
function Set:Union(B)
    local Union = Set.new()
    for _, Value in ipairs(self.Values) do
        Union:Insert(Value)
    end
    for _, Value in ipairs(B.Values) do
        Union:Insert(Value)
    end
    return Union
end
function Set:Difference(B)
    local Difference = Set.new(unpack(table.clone(B)))
    for _, Value in ipairs(self.Values) do
        if B.Checker[Value] then
            Difference:Remove(Value)
        end
    end
    return Difference
end
function Set:Iterate()
    return ipairs(self.Values)
end
local function GetRelativeChunkDirections()
    local ScaledAxes = Set.new()
    local A = Vector3.new(BoilerPlateSizeX * CHUNK_SIZE, 0, 0)
    local B = Vector3.new(0, 0, BoilerPlateSizeZ * CHUNK_SIZE)
    ScaledAxes:Insert(A)
    ScaledAxes:Insert(B)
    for _, Axis in ScaledAxes:Iterate() do
        ScaledAxes:Insert(-Axis)
    end
    local PositiveDiagonal = A + B
    local Magnitude = PositiveDiagonal.Magnitude
    local Diagonals = Set.new()
    Diagonals:Insert(PositiveDiagonal)
    for _, Vector in ipairs(GetPerpindicularVectors(PositiveDiagonal, Vector3.yAxis)) do
        Diagonals:Insert(Vector)
    end
    return ScaledAxes:Union(Diagonals).Values
end
local RelativeChunkDirections = GetRelativeChunkDirections()
local Chunk = {}
local ChunkStorage = {
    GridCache = {},
    MatrixRanges = {},
    CAPACITY = 20,
}
ChunkStorage.CAPACITY = math.max(9, ChunkStorage.CAPACITY)
function ChunkStorage.GetCenterOfMatrixRange(MatrixRange)
    return {
        MatrixRange.BL[RangeX] + (CHUNK_SIZE / 2) - 1,
        MatrixRange.BL[RangeZ] + (CHUNK_SIZE / 2) - 1,
    }
end
function ChunkStorage.GetLocationOfMatrixRange(MatrixRange)
    local CenterOfRange = ChunkStorage.GetCenterOfMatrixRange(MatrixRange)
    return Vector3.new(BoilerPlateSizeX * CenterOfRange[RangeX], 0, BoilerPlateSizeZ * CenterOfRange[RangeZ])
end
function ChunkStorage.GetMatrixRangeOfLocation(Location)
    local GridLocation = {
        X = Location.X / BoilerPlateSizeX,
        Z = Location.Z / BoilerPlateSizeZ,
    }
    return {
        BL = {GridLocation.X - math.floor(CHUNK_SIZE / 2), GridLocation.Z - math.floor(CHUNK_SIZE / 2)},
        TR = {GridLocation.X + math.floor(CHUNK_SIZE / 2), GridLocation.Z + math.floor(CHUNK_SIZE / 2)},
    }
end
function ChunkStorage.GetMatrixRangeComponentString(Component)
    return tostring(Component[RangeX])..tostring(Component[RangeZ])
end
function ChunkStorage.InsertMatrixRange(MatrixRange)
    local MatrixRanges = ChunkStorage.MatrixRanges
    local Size = #MatrixRanges
    if Size == ChunkStorage.CAPACITY then
        local Removed = table.remove(MatrixRanges, 1)
        Chunk.UnloadChunk(ChunkStorage.GetLocationOfMatrixRange(Removed), true)
    end
    table.insert(MatrixRanges, MatrixRange)
end
local NearestChunkLocations = Set.new()
function Chunk.LoadChunk(Location)
    local GridCache = ChunkStorage.GridCache
    local MatrixRange = ChunkStorage.GetMatrixRangeOfLocation(Location)
    local BL = MatrixRange.BL
    local TR = MatrixRange.TR
    print(MatrixRange)
    if GridCache[ChunkStorage.GetMatrixRangeComponentString(MatrixRange.BL)] then
        for X = BL[RangeX], TR[RangeX] do
            for Z = BL[RangeZ], TR[RangeZ] do
                -- print(tostring(X)..tostring(Z))
                GridCache[tostring(X)..tostring(Z)].Parent = workspace
            end
        end
    else
        for X = BL[RangeX], TR[RangeX] do
            for Z = BL[RangeZ], TR[RangeZ] do
                local YNoise = math.noise(
                    X * NOISE_SETTINGS.FREQUENCY,
                    Z * NOISE_SETTINGS.FREQUENCY,
                    NOISE_SETTINGS.SEED) * NOISE_SETTINGS.AMPLITUDE
                local Part = BOILERPLATE_PART:Clone()
                Part.Position = Vector3.new(X * BoilerPlateSizeX, YNoise, Z * BoilerPlateSizeZ)
                Part.Parent = workspace
                GridCache[tostring(X)..tostring(Z)] = Part
            end
        end
        ChunkStorage.InsertMatrixRange(MatrixRange)
    end
end
function Chunk.UnloadChunk(Location, ShouldDelete)
    local GridCache = ChunkStorage.GridCache
    local MatrixRange = ChunkStorage.GetMatrixRangeOfLocation(Location)
    local BL = MatrixRange.BL
    local TR = MatrixRange.TR
    for X = BL[RangeX], TR[RangeX] do
        for Z = BL[RangeZ], TR[RangeZ] do
            if ShouldDelete then
                -- Will use a part cache eventually
                GridCache[tostring(X)..tostring(Z)]:Destroy()
            else
                GridCache[tostring(X)..tostring(Z)].Parent = nil
            end
        end
    end
end
function Chunk.IsInChunk(Location)
    local Pivot = Character:GetPivot()
    local CharacterPosition = Vector3.new(Pivot.X, 0, Pivot.Z) - CurrentZone
    return math.abs(CharacterPosition.X) < CHUNK_SIZE * BoilerPlateSizeX and math.abs(CharacterPosition.Z) < CHUNK_SIZE * BoilerPlateSizeZ
end
Chunk.LoadChunk(Vector3.zero)
CurrentZone = Vector3.zero
for _, Direction in ipairs(RelativeChunkDirections) do
    local Sum = CurrentZone + Direction
    NearestChunkLocations:Insert(Sum)
    Chunk.LoadChunk(Sum)
end
local IsGridRefreshed = false
local function LoadChunks()
    if IsGridRefreshed then return end
    if Humanoid.MoveDirection.Magnitude > 0 then
        local IsInChunk = Chunk.IsInChunk(CurrentZone)
        if not IsInChunk then
            for _, Location in NearestChunkLocations:Iterate() do
                IsInChunk = Chunk.IsInChunk(Location)
                if IsInChunk then
                    CurrentZone = Location
                    break
                end
            end
            local UpdatedChunkLocations = Set.new()
            for _, Direction in ipairs(RelativeChunkDirections) do
                UpdatedChunkLocations:Insert(CurrentZone + Direction)
            end
            local ToUnload = NearestChunkLocations:Difference(UpdatedChunkLocations)
            for _, Location in ToUnload:Iterate() do
                Chunk.UnloadChunk(Location, false)
            end
            for _, Location in UpdatedChunkLocations:Iterate() do
                Chunk.LoadChunk(Location)
            end
            NearestChunkLocations = UpdatedChunkLocations
        end
    end
end
RunService.Heartbeat:Connect(LoadChunks)
local Module = {}
function Module.RefreshGrid()
    IsGridRefreshed = true
end
return Module
