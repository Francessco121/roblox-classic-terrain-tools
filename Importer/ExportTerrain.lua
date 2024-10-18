--[[
  EXPORT TERRAIN

  A script to be ran in an old version of studio (preferably ~2014) that will
  export marked areas of classic terrain into a folder of ModuleScripts that
  can then be pasted into modern studio and imported.
--]]

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Helper Functions
local terrain = workspace.Terrain

local CELL_FACE_TYPE_EMPTY = 0
local CELL_FACE_TYPE_SQUARE = 1
local CELL_FACE_TYPE_TRIANGLE_BOTTOM_LEFT = 2
local CELL_FACE_TYPE_TRIANGLE_BOTTOM_RIGHT = 3
local CELL_FACE_TYPE_TRIANGLE_Y_AXIS = 4 -- for top/bottom faces only

local FACE_CULL_NONE = 0 -- not culled
local FACE_CULL_TRIANGLE = 1 -- culled by triangle
local FACE_CULL_SQUARE = 2 -- culled by square
local FACE_CULL_NO_FACE = 3 -- cell shape has no face for that normal

local CELL_FACE_Y_FLIP_MAP = {
  [CELL_FACE_TYPE_EMPTY] = CELL_FACE_TYPE_EMPTY,
  [CELL_FACE_TYPE_SQUARE] = CELL_FACE_TYPE_SQUARE,
  [CELL_FACE_TYPE_TRIANGLE_BOTTOM_LEFT] = CELL_FACE_TYPE_TRIANGLE_BOTTOM_RIGHT,
  [CELL_FACE_TYPE_TRIANGLE_BOTTOM_RIGHT] = CELL_FACE_TYPE_TRIANGLE_BOTTOM_LEFT,
  [CELL_FACE_TYPE_TRIANGLE_Y_AXIS] = CELL_FACE_TYPE_TRIANGLE_Y_AXIS
}

local CELL_FACE_ORIENTATION_INVERSE_MAP = {
  [Enum.NormalId.Top] = {
    [Enum.CellOrientation.NegZ] = Enum.NormalId.Top,
    [Enum.CellOrientation.X] = Enum.NormalId.Top,
    [Enum.CellOrientation.Z] = Enum.NormalId.Top,
    [Enum.CellOrientation.NegX] = Enum.NormalId.Top
  },
  [Enum.NormalId.Bottom] = {
    [Enum.CellOrientation.NegZ] = Enum.NormalId.Bottom,
    [Enum.CellOrientation.X] = Enum.NormalId.Bottom,
    [Enum.CellOrientation.Z] = Enum.NormalId.Bottom,
    [Enum.CellOrientation.NegX] = Enum.NormalId.Bottom
  },
  [Enum.NormalId.Back] = {
    [Enum.CellOrientation.NegZ] = Enum.NormalId.Back,
    [Enum.CellOrientation.X] = Enum.NormalId.Left,
    [Enum.CellOrientation.Z] = Enum.NormalId.Front,
    [Enum.CellOrientation.NegX] = Enum.NormalId.Right
  },
  [Enum.NormalId.Front] = {
    [Enum.CellOrientation.NegZ] = Enum.NormalId.Front,
    [Enum.CellOrientation.X] = Enum.NormalId.Right,
    [Enum.CellOrientation.Z] = Enum.NormalId.Back,
    [Enum.CellOrientation.NegX] = Enum.NormalId.Left
  },
  [Enum.NormalId.Left] = {
    [Enum.CellOrientation.NegZ] = Enum.NormalId.Left,
    [Enum.CellOrientation.X] = Enum.NormalId.Front,
    [Enum.CellOrientation.Z] = Enum.NormalId.Right,
    [Enum.CellOrientation.NegX] = Enum.NormalId.Back
  },
  [Enum.NormalId.Right] = {
    [Enum.CellOrientation.NegZ] = Enum.NormalId.Right,
    [Enum.CellOrientation.X] = Enum.NormalId.Back,
    [Enum.CellOrientation.Z] = Enum.NormalId.Left,
    [Enum.CellOrientation.NegX] = Enum.NormalId.Front
  }
}

local NORMAL_FLIP_MAP = {
  [Enum.NormalId.Right] = Enum.NormalId.Left,
  [Enum.NormalId.Top] = Enum.NormalId.Bottom,
  [Enum.NormalId.Back] = Enum.NormalId.Front,
  [Enum.NormalId.Left] = Enum.NormalId.Right,
  [Enum.NormalId.Bottom] = Enum.NormalId.Top,
  [Enum.NormalId.Front] = Enum.NormalId.Back
}

local function GetCellFace(cellType, cellOrientation, normal)
  -- Account for cell orientation (below code assumes identity rotation)
  normal = CELL_FACE_ORIENTATION_INVERSE_MAP[normal][cellOrientation]

  -- Determine face type
  local face = CELL_FACE_TYPE_EMPTY

  if cellType == Enum.CellBlock.Solid then
    -- Solid
    face = CELL_FACE_TYPE_SQUARE
  elseif cellType == Enum.CellBlock.VerticalWedge then
    -- VerticalWedge
    if normal == Enum.NormalId.Left then
      face = CELL_FACE_TYPE_TRIANGLE_BOTTOM_LEFT
    elseif normal == Enum.NormalId.Right then
      face = CELL_FACE_TYPE_TRIANGLE_BOTTOM_RIGHT
    elseif normal == Enum.NormalId.Back or normal == Enum.NormalId.Top then
      face = CELL_FACE_TYPE_EMPTY
    elseif normal == Enum.NormalId.Front or normal == Enum.NormalId.Bottom then
      face = CELL_FACE_TYPE_SQUARE
    end
  elseif cellType == Enum.CellBlock.CornerWedge then
    -- CornerWedge
    if normal == Enum.NormalId.Left or normal == Enum.NormalId.Back or normal == Enum.NormalId.Top then
      face = CELL_FACE_TYPE_EMPTY
    elseif normal == Enum.NormalId.Right then
      face = CELL_FACE_TYPE_TRIANGLE_BOTTOM_RIGHT
    elseif normal == Enum.NormalId.Front then
      face = CELL_FACE_TYPE_TRIANGLE_BOTTOM_LEFT
    elseif normal == Enum.NormalId.Bottom then
      face = CELL_FACE_TYPE_TRIANGLE_Y_AXIS
    end
  elseif cellType == Enum.CellBlock.InverseCornerWedge then
    -- InverseCornerWedge
    if normal == Enum.NormalId.Back then
      face = CELL_FACE_TYPE_TRIANGLE_BOTTOM_RIGHT
    elseif normal == Enum.NormalId.Left then
      face = CELL_FACE_TYPE_TRIANGLE_BOTTOM_LEFT
    elseif normal == Enum.NormalId.Top then
      face = CELL_FACE_TYPE_TRIANGLE_Y_AXIS
    elseif normal == Enum.NormalId.Right or normal == Enum.NormalId.Front or normal == Enum.NormalId.Bottom then
      face = CELL_FACE_TYPE_SQUARE
    end
  elseif cellType == Enum.CellBlock.HorizontalWedge then
    -- HorizontalWedge
    if normal == Enum.NormalId.Left or normal == Enum.NormalId.Back then
      face = CELL_FACE_TYPE_EMPTY
    elseif normal == Enum.NormalId.Right or normal == Enum.NormalId.Front then
      face = CELL_FACE_TYPE_SQUARE
    elseif normal == Enum.NormalId.Top or normal == Enum.NormalId.Bottom then
      face = CELL_FACE_TYPE_TRIANGLE_Y_AXIS
    end
  end

  return face
end

local function CullFace(
    ourCellType, ourCellOrientation, 
    theirX, theirY, theirZ, 
    ourNormal)
  local ourFace = GetCellFace(ourCellType, ourCellOrientation, ourNormal)

  if ourFace == CELL_FACE_TYPE_EMPTY then
    -- Empty face, can't cull
    return FACE_CULL_NO_FACE
  end

  local theirCellMat, theirCellType, theirCellOrientation = terrain:GetCell(theirX, theirY, theirZ) 

  if theirCellMat == Enum.CellMaterial.Empty or theirCellMat == Enum.CellMaterial.Water then
    -- Other cell is empty
    return FACE_CULL_NONE 
  end

  local theirNormal = NORMAL_FLIP_MAP[ourNormal]
  local theirFace = GetCellFace(theirCellType, theirCellOrientation, theirNormal)

  if theirFace == CELL_FACE_TYPE_EMPTY then
    -- Empty faces never cull our face
    return FACE_CULL_NONE
  end

  if theirFace == CELL_FACE_TYPE_SQUARE then
    -- Square faces always cull our face
    return FACE_CULL_SQUARE
  end

  if ourFace == CELL_FACE_TYPE_SQUARE then
    -- Only squares can cull our square face
    return FACE_CULL_NONE
  end

  -- Only triangle faces from here on

  -- For top/bottom, if the cell orientation matches then the faces line up
  if ourNormal == Enum.NormalId.Top or ourNormal == Enum.NormalId.Bottom then
    if ourCellOrientation == theirCellOrientation then
      return FACE_CULL_TRIANGLE
    else
      return FACE_CULL_NONE
    end
  end

  -- For left/right/back/front, if the faces are flipped versions of each other 
  -- along the Y-axis, then the faces line up
  if ourFace == CELL_FACE_Y_FLIP_MAP[theirFace] then
    return FACE_CULL_TRIANGLE
  else
    return FACE_CULL_NONE
  end
end

-- Whether a non-empty/non-water voxel exists at the coordinates with the given
-- cell type and orientation
local function IsVoxelAt(x, y, z, type, orientation)
  local cellMat, cellType, cellOrientation = terrain:GetCell(x, y, z)
  
  if cellMat == Enum.CellMaterial.Empty or cellMat == Enum.CellMaterial.Water then
    return false
  end
  
  if type ~= nil and cellType ~= type then
    return false
  end
  
  if orientation ~= nil and cellOrientation ~= orientation then
    return false
  end
  
  return true	
end

local function BitPackSurround(isTop, top, bottom, left, right, front, back)
  local n = 0

  if isTop then n = n + 1 end
  n = n * 2
  if top ~= FACE_CULL_NONE then n = n + 1 end
  n = n * 2
  if bottom ~= FACE_CULL_NONE then n = n + 1 end
  n = n * 2
  if left ~= FACE_CULL_NONE then n = n + 1 end
  n = n * 2
  if right ~= FACE_CULL_NONE then n = n + 1 end
  n = n * 2
  if front ~= FACE_CULL_NONE then n = n + 1 end
  n = n * 2
  if back ~= FACE_CULL_NONE then n = n + 1 end

  return n
end

local function DoBoundsOverlap(a, b)
  -- if b's left or right is within a
  -- and b's bottom or top is within a
  -- and b's front or back is within a
  -- then... they overlap
  return ((b.left >= a.left and b.left <= a.right) or (b.right >= a.left and b.right <= a.right))
    and ((b.bottom >= a.bottom and b.bottom <= a.top) or (b.top >= a.bottom and b.top <= a.top))
    and ((b.back >= a.back and b.back <= a.front) or (b.front >= a.back and b.front <= a.front))
end

local function FindOverlappingBreakableBounds(bound, breakableBounds)
  local breakable = {}
  
  for i, breakableBound in ipairs(breakableBounds) do
    if DoBoundsOverlap(bound, breakableBound) then
      table.insert(breakable, breakableBound)
    end
  end
  
  return breakable
end

local function IsVoxelInBound(x, y, z, bound)
  return x >= bound.left and x < bound.right
    and y >= bound.bottom and y < bound.top
    and z >= bound.back and z < bound.front
end

local function FindFirstOverlappingBound(x, y, z, _bounds)
  for i, bound in ipairs(_bounds) do
    if IsVoxelInBound(x, y, z, bound) then
      return bound
    end
  end
  
  return nil
end

-- Util to map enums to their indices
local function MakeMap(enums)
  local tbl = {}

  for i, enum in ipairs(enums) do
    tbl[enum] = i
  end		
  
  return tbl
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Preparation
local startTime = os.time()
local terrainFolder = game:GetService("Selection"):Get()[1]

if terrainFolder == nil then
  error("A terrain folder must be selected to run this script.", 0)
end

-- Precalculate boundaries of all KeepAreas
print("Preparing...")

local bounds = {}
local breakableBounds = {}

for i, part in ipairs(terrainFolder:GetChildren()) do
  if part.Name == "KeepArea" or part.Name == "BreakArea" then
    local xs = part.Size.X / 2
    local ys = part.Size.Y / 2
    local zs = part.Size.Z / 2
    
    local bound = {
      left = math.floor((part.Position.X - xs) / 4),
      right = math.floor((part.Position.X + xs) / 4),
      back = math.floor((part.Position.Z - zs) / 4),
      front = math.floor((part.Position.Z + zs) / 4),
      bottom = math.floor((part.Position.Y - ys) / 4),
      top = math.floor((part.Position.Y + ys) / 4)
    }

    if part.Name == "KeepArea" then
      table.insert(bounds, bound)
    else
      local areaNameVal = part:FindFirstChild("AreaName")
      if areaNameVal == nil then
        error(part:GetFullName() .. " is missing a child AreaName StringValue!")
      end
      
      bound.name = areaNameVal.Value
      table.insert(breakableBounds, bound)
    end
  end
end

print("Found " .. tostring(#bounds) .. " KeepArea parts")

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Looping
local checkedVoxels = {}

-- Checks if a voxel was not already exported
local function DeDupeVoxel(x, y, z)
  local ytbl = checkedVoxels[x]
  if ytbl == nil then
    ytbl = {}
    checkedVoxels[x] = ytbl
  end
  
  local ztbl = ytbl[y]
  if ztbl == nil then
    ztbl = {}
    ytbl[y] = ztbl
  end
  
  if ztbl[z] == nil then
    ztbl[z] = true
    return true
  else
    return false
  end
end

-- Set up maps to convert enums to numbers
--
-- The generated ModuleScripts will be way smaller if we send these as 1-2
-- character integers instead of the full "Enum.EnumType.Value" syntax.
local cellMats = MakeMap(Enum.CellMaterial:GetEnumItems())
local cellBlocks = MakeMap(Enum.CellBlock:GetEnumItems())
local cellOrientations = MakeMap(Enum.CellOrientation:GetEnumItems())

-- Loop through all bounds and export voxels into scripts
print("Looping...")
wait()

local scripts = {}
local lines = {}
table.insert(scripts, lines)

local breakableScripts = {}

local count = 0

for i, bound in ipairs(bounds) do
  -- Sanity checks
  if bound.right < bound.left then error("bound.right is bigger than left!") end
  if bound.top < bound.bottom then error("bound.top is bigger than bottom!") end
  if bound.front < bound.back then error("bound.front is bigger than back!") end

  -- Get possible breakable bounds
  local overlappingBreakableBounds = FindOverlappingBreakableBounds(bound, breakableBounds)
  
  -- Loop all voxels in bound
  for x = bound.left, bound.right do
    for y = bound.bottom, bound.top do
      for z = bound.back, bound.front do
        local cellMat, cellType, cellOrientation = terrain:GetCell(x, y, z)
        
        -- Skip empty and already exported voxels
        if cellMat ~= Enum.CellMaterial.Empty and cellMat ~= Enum.CellMaterial.Water and DeDupeVoxel(x, y, z) then
          -- Ignore orientation of solids
          if cellType == Enum.CellBlock.Solid then
            cellOrientation = Enum.CellOrientation.NegZ
          end

          -- Check if voxel is in a breakable bound
          local breakableBound = FindFirstOverlappingBound(x, y, z, overlappingBreakableBounds)
          
          -- Determine voxel side culling
          local cullLeft = CullFace(cellType, cellOrientation, x - 1, y, z, Enum.NormalId.Left)
          local cullRight = CullFace(cellType, cellOrientation, x + 1, y, z, Enum.NormalId.Right)
          local cullBottom = CullFace(cellType, cellOrientation, x, y - 1, z, Enum.NormalId.Bottom)
          local cullTop = CullFace(cellType, cellOrientation, x, y + 1, z, Enum.NormalId.Top)
          local cullBack = CullFace(cellType, cellOrientation, x, y, z + 1, Enum.NormalId.Back)
          local cullFront = CullFace(cellType, cellOrientation, x, y, z - 1, Enum.NormalId.Front)

          local cullVoxel = breakableBound == nil and -- Never cull if within a breakable bound
            cullTop == FACE_CULL_SQUARE and 
            cullBottom == FACE_CULL_SQUARE and 
            cullLeft == FACE_CULL_SQUARE and 
            cullRight == FACE_CULL_SQUARE and 
            cullBack == FACE_CULL_SQUARE and 
            cullFront == FACE_CULL_SQUARE
          
          -- Skip if the whole voxel was determined to be culled
          if not cullVoxel then
            -- Determine if voxel is a top voxel
            local isTop
            if cellType == Enum.CellBlock.VerticalWedge then
              -- VerticalWedge
              if cellOrientation == Enum.CellOrientation.NegZ then
                isTop = not IsVoxelAt(x, y + 1, z - 1)
              elseif cellOrientation == Enum.CellOrientation.X then
                isTop = not IsVoxelAt(x - 1, y + 1, z)
              elseif cellOrientation == Enum.CellOrientation.Z then
                isTop = not IsVoxelAt(x, y + 1, z + 1)
              elseif cellOrientation == Enum.CellOrientation.NegX then
                isTop = not IsVoxelAt(x + 1, y + 1, z)
              end
            elseif cellType == Enum.CellBlock.CornerWedge then
              -- CornerWedge
              if cellOrientation == Enum.CellOrientation.NegZ then
                isTop = not IsVoxelAt(x + 1, y + 1, z - 1)
              elseif cellOrientation == Enum.CellOrientation.X then
                isTop = not IsVoxelAt(x - 1, y + 1, z - 1)
              elseif cellOrientation == Enum.CellOrientation.Z then
                isTop = not IsVoxelAt(x - 1, y + 1, z + 1)
              elseif cellOrientation == Enum.CellOrientation.NegX then
                isTop = not IsVoxelAt(x + 1, y + 1, z + 1)
              end
            else
              -- Solid/InverseCornerWedge/HorizontalWedge
              isTop = not IsVoxelAt(x, y + 1, z)
            end

            -- Add voxel to script source
            local surroundBits = BitPackSurround(isTop, cullTop, cullBottom, cullLeft, cullRight, cullFront, cullBack)					
            
            local str = "{" ..
              tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. "," ..
              tostring(cellMats[cellMat]) .. "," .. 
              tostring(cellBlocks[cellType]) .. ","  ..
              tostring(cellOrientations[cellOrientation]) .. ","  ..
              tostring(surroundBits) ..
              "}\n"
            
            if breakableBound == nil then
              if count > 0 then
                str = "," .. str
              end
              
              table.insert(lines, str)
              
              count = count + 1
              
              -- Every 4000 voxels, start a new chunk
              --
              -- If the scripts get too big, studio starts having a hard time with them
              if count >= 4000 then
                print("Chunk " .. tostring(#scripts) .. "...")
                
                lines = {}
                table.insert(scripts, lines)
                count = 0
                
                wait()
              end
            else
              local breakableLines = breakableScripts[breakableBound.name]
              if breakableLines == nil then
                breakableLines = {}
                breakableScripts[breakableBound.name] = breakableLines
              end
              
              if #breakableLines > 0 then
                str = "," .. str
              end
              
              table.insert(breakableLines, str)
            end

          end
        end
      end
    end
  end
end

if count > 0 then
  print("Chunk " .. tostring(#scripts) .. "...")
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Script generation
print("Generating scripts...")
wait()

local f = Instance.new("Folder")
f.Name = "Voxels"

for _, _lines in ipairs(scripts) do
  local s = Instance.new("ModuleScript")
  s.Name = "Chunk"
  s.Source = "return {\n" .. table.concat(_lines) .. "\n}"
  s.Parent = f
end

for name, _lines in pairs(breakableScripts) do
  local s = Instance.new("ModuleScript")
  s.Name = "Breakable_" .. name
  s.Source = "return {\n" .. table.concat(_lines) .. "\n}"
  s.Parent = f
end

f.Parent = terrainFolder

local elapsed = os.time() - startTime
print("Done! Took " .. tostring(elapsed) .. " seconds.")
