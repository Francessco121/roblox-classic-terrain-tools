--!strict
--[[
  IMPORT TERRAIN

  A script to convert the generated Voxels ModuleScripts created by the ExportTerrain
  script into a bunch of parts that accurately recreate the exported voxels.

  HOW TO RUN:
  - Insert the LegacyTerrainAssets.rbxm file into ServerStorage. This contains necessary
    assets for generating the terrain parts.
  - Copy (right-click -> copy or Ctrl+C) the generated Voxels folder that the
    ExportTerrain script created and then paste it somewhere in a place opened up
    in a modern version of studio. For example, you could paste it under Workspace.
  - Select the Voxels folder in the Explorer window and then run this script by
    clicking Model -> Run Script in the studio ribbonbar. Tip: this script can take
    a while, open the Output window to view its progress.
  - When complete, you will see a LegacyTerrain model appear under workspace.

  TIPS:
  - When re-importing terrain, delete the old LegacyTerrain model first to save on
    memory/processing power.
  - Avoid saving the place with the Voxels folder still in it. This can massively
    increase the file size of the place and may prevent studio from loading it in
    the future (backups are your friend!).
  - Consider closing and re-opening studio after a large or multiple terrain imports.
    Studio tends to leak memory during this process and can very quickly consume all
    of your system's available memory.
  - It's recommended to have at least 16 GB of RAM when running this script. Depending
    on the size of the terrain being imported, this script can result in extreme memory
    utilization. Lower RAM may work but if studio starts hitting your pagefile, this
    script may take a very long time to complete.
--]]

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Helper Functions

local CellOrientation = {
  NegZ = 0,
  X = 1,
  Z = 2,
  NegX = 3
}

local CellBlock = {
  Solid = 0,
  VerticalWedge = 1,
  CornerWedge = 2,
  InverseCornerWedge = 3,
  HorizontalWedge = 4
}

type Surround = {
  IsTop: boolean,
  Bottom: boolean,
  Left: boolean,
  Right: boolean,
  Back: boolean,
  Front: boolean
}

type Extents = {
  PosX: number,
  PosY: number,
  PosZ: number,
  NegX: number,
  NegY: number,
  NegZ: number,
}

type Voxel = {
  X: number,
  Y: number,
  Z: number,
  Mat: number,
  Type: number, -- CellBlock
  Orientation: number, -- CellOrientation
  Surround: Surround,
  Extents: Extents | nil,
  Extended: boolean | nil
}

type VoxelMap = {{{Voxel}}} -- 3d array

local CellFaceType = {
  Empty = 0,
  Square = 1,
  TriBottomRight = 2,
  TriBottomLeft = 3,
  TriTopLeft = 4,
  TriTopRight = 5
}

local function StoreVoxel(voxels: VoxelMap, x: number, y: number, z: number, voxel: Voxel)
  local xt = voxels[x]
  if xt == nil then
    xt = {}
    voxels[x] = xt
  end

  local yt = xt[y]
  if yt == nil then
    yt = {}
    xt[y] = yt
  end

  yt[z] = voxel
end

local function GetVoxel(voxels: VoxelMap, x: number, y: number, z: number): Voxel | nil
  local xt = voxels[x]
  if xt == nil then
    return nil
  end

  local yt = xt[y]
  if yt == nil then
    return nil
  end

  return yt[z]
end

local function ParseSurround(surround) 
  if typeof(surround) == "string" then
    return {
      IsTop = string.sub(surround, 1, 1) == "1",
      Bottom = string.sub(surround, 2, 2) == "1",
      Left = string.sub(surround, 3, 3) == "1",
      Right = string.sub(surround, 4, 4) == "1",
      Back = string.sub(surround, 5, 5) == "1",
      Front = string.sub(surround, 6, 6) == "1",
    }
  else
    return {
      IsTop = (surround == 1),
      Bottom = false,
      Left = false,
      Right = false,
      Back = false,
      Front = false
    }	
  end
end

local function ParseVoxel(cell: any): Voxel
  local x = cell[1]
  local y = cell[2]
  local z = cell[3]
  local cellMat = cell[4] - 2
  local cellType = cell[5] - 1
  local cellOrientation = cell[6] - 1
  local surround = ParseSurround(cell[7])

  local voxel: Voxel = {
    X = x,
    Y = y,
    Z = z,
    Mat = cellMat,
    Type = cellType,
    Orientation = cellOrientation,
    Surround = surround
  }
  
  return voxel
end

local function IsSameVoxel(a: Voxel, b: Voxel)
  return a.Mat == b.Mat
    and a.Type == b.Type
    and a.Orientation == b.Orientation
    and a.Surround.IsTop == b.Surround.IsTop
    and (a.Surround.Bottom == b.Surround.Bottom --[[or (not a.Surround.Bottom and b.Surround.Bottom)]])
    and (a.Surround.Left == b.Surround.Left 		--[[or (not a.Surround.Left and b.Surround.Left)]])
    and (a.Surround.Right == b.Surround.Right		--[[or (not a.Surround.Right and b.Surround.Right)]])
    and (a.Surround.Back == b.Surround.Back 		--[[or (not a.Surround.Back and b.Surround.Back)]])
    and (a.Surround.Front == b.Surround.Front 	--[[or (not a.Surround.Front and b.Surround.Front)]])
end

local function PatchVoxel(voxel: Voxel, voxels: VoxelMap)
  -- Some voxels got exported incorrectly, just fix them here
  if voxel.Type == 3 then
    -- Inverse corner wedge IsTop is incorrect
    local above = GetVoxel(voxels, voxel.X, voxel.Y + 1, voxel.Z)

    if above then
      voxel.Surround.IsTop = not (above.Type == 2 and above.Orientation == voxel.Orientation)
    else
      voxel.Surround.IsTop = true
    end
  elseif voxel.Type == 0 then
    -- Solid IsTop is wrong in some cases
    local above = GetVoxel(voxels, voxel.X, voxel.Y + 1, voxel.Z)

    if above then
      voxel.Surround.IsTop = (above.Type == 2 or above.Type == 4)
    end
  elseif voxel.Type == 4 then
    -- HorizontalWedge IsTop is wrong in some cases
    local above = GetVoxel(voxels, voxel.X, voxel.Y + 1, voxel.Z)

    if above then
      voxel.Surround.IsTop = false
    end
  end
end

--[[
  Rotates a face normal in the direction of the its cell orientation.
--]]
local function RotateFaceNormal(normal: Enum.NormalId, orientation: number)
  if normal == Enum.NormalId.Top or normal == Enum.NormalId.Bottom then
    -- Cells only rotate along the Y axis
    return normal
  end

  if orientation == 0 then
    -- Cell is already at identity orientation
    return normal
  end

  if normal == Enum.NormalId.Back then
    if orientation == 1 then
      return Enum.NormalId.Left
    elseif orientation == 2 then
      return Enum.NormalId.Front
    elseif orientation == 3 then
      return Enum.NormalId.Right
    end
  elseif normal == Enum.NormalId.Front then
    if orientation == 1 then
      return Enum.NormalId.Right
    elseif orientation == 2 then
      return Enum.NormalId.Back
    elseif orientation == 3 then
      return Enum.NormalId.Left
    end
  elseif normal == Enum.NormalId.Left then
    if orientation == 1 then
      return Enum.NormalId.Front
    elseif orientation == 2 then
      return Enum.NormalId.Right
    elseif orientation == 3 then
      return Enum.NormalId.Back
    end
  elseif normal == Enum.NormalId.Right then
    if orientation == 1 then
      return Enum.NormalId.Back
    elseif orientation == 2 then
      return Enum.NormalId.Left
    elseif orientation == 3 then
      return Enum.NormalId.Front
    end
  end

  error("Unimplemented normal/orientation: " .. tostring(normal) .. ", " .. tostring(orientation))
end

--[[
  Rotates a face normal in the inverse direction of the its cell orientation,
  effectively undoing the rotation.
--]]
local function RotateFaceNormalInverse(normal: Enum.NormalId, orientation: number)
  if normal == Enum.NormalId.Top or normal == Enum.NormalId.Bottom then
    -- Cells only rotate along the Y axis
    return normal
  end

  if orientation == 0 then
    -- Cell is already at identity orientation
    return normal
  end

  if normal == Enum.NormalId.Back then
    if orientation == 1 then
      return Enum.NormalId.Right
    elseif orientation == 2 then
      return Enum.NormalId.Front
    elseif orientation == 3 then
      return Enum.NormalId.Left
    end
  elseif normal == Enum.NormalId.Front then
    if orientation == 1 then
      return Enum.NormalId.Left
    elseif orientation == 2 then
      return Enum.NormalId.Back
    elseif orientation == 3 then
      return Enum.NormalId.Right
    end
  elseif normal == Enum.NormalId.Left then
    if orientation == 1 then
      return Enum.NormalId.Back
    elseif orientation == 2 then
      return Enum.NormalId.Right
    elseif orientation == 3 then
      return Enum.NormalId.Front
    end
  elseif normal == Enum.NormalId.Right then
    if orientation == 1 then
      return Enum.NormalId.Front
    elseif orientation == 2 then
      return Enum.NormalId.Left
    elseif orientation == 3 then
      return Enum.NormalId.Back
    end
  end

  error("Unimplemented normal/orientation: " .. tostring(normal) .. ", " .. tostring(orientation))
end

--[[
  Cell face with respect to either: -Z, -X, -Y
--]]
local function GetCellFace(voxel: Voxel, normal: Enum.NormalId)
  local cellType = voxel.Type
  local cellOrientation = voxel.Orientation

  -- Account for cell orientation (below code assumes identity rotation)
  normal = RotateFaceNormal(normal, cellOrientation)

  -- Determine face type
  local face = CellFaceType.Empty

  if cellType == 0 then
    -- Solid
    face = CellFaceType.Square
  elseif cellType == 1 then
    -- VerticalWedge
    if normal == Enum.NormalId.Left or normal == Enum.NormalId.Right then
      face = CellFaceType.TriBottomRight
    elseif normal == Enum.NormalId.Back or normal == Enum.NormalId.Top then
      face = CellFaceType.Empty
    elseif normal == Enum.NormalId.Front or normal == Enum.NormalId.Bottom then
      face = CellFaceType.Square
    end
  elseif cellType == 2 then
    -- CornerWedge
    if normal == Enum.NormalId.Left or normal == Enum.NormalId.Back or normal == Enum.NormalId.Top then
      face = CellFaceType.Empty
    elseif normal == Enum.NormalId.Right or normal == Enum.NormalId.Front or normal == Enum.NormalId.Bottom then
      face = CellFaceType.TriBottomRight
    end
  elseif cellType == 3 then
    -- InverseCornerWedge
    if normal == Enum.NormalId.Left or normal == Enum.NormalId.Back or normal == Enum.NormalId.Top then
      face = CellFaceType.TriBottomRight
    elseif normal == Enum.NormalId.Right or normal == Enum.NormalId.Front or normal == Enum.NormalId.Bottom then
      face = CellFaceType.Square
    end
  elseif cellType == 4 then
    -- HorizontalWedge
    if normal == Enum.NormalId.Left or normal == Enum.NormalId.Back then
      face = CellFaceType.Empty
    elseif normal == Enum.NormalId.Right or normal == Enum.NormalId.Front then
      face = CellFaceType.Square
    elseif normal == Enum.NormalId.Top or normal == Enum.NormalId.Bottom then
      face = CellFaceType.TriBottomRight
    end
  end

  return face
end

local function ShouldCullTexture(ourFace: number, theirFace: number)
  if ourFace == CellFaceType.Empty then return false end
  
  if ourFace ~= CellFaceType.Square and theirFace == CellFaceType.Square then
    return true
  end

  return ourFace == theirFace
end

local function TextureCull(voxel: Voxel, voxels: VoxelMap)
  if not voxel.Surround.Left then
    local left = GetVoxel(voxels, voxel.X - 1, voxel.Y, voxel.Z)

    if left ~= nil and ShouldCullTexture(GetCellFace(voxel, Enum.NormalId.Left), GetCellFace(left, Enum.NormalId.Right)) then
      voxel.Surround.Left = true
    end
  end

  if not voxel.Surround.Right then
    local right = GetVoxel(voxels, voxel.X + 1, voxel.Y, voxel.Z)

    if right ~= nil and ShouldCullTexture(GetCellFace(voxel, Enum.NormalId.Right), GetCellFace(right, Enum.NormalId.Left)) then
      voxel.Surround.Right = true
    end
  end

  if not voxel.Surround.Bottom then
    local below = GetVoxel(voxels, voxel.X, voxel.Y - 1, voxel.Z)

    if below ~= nil and ShouldCullTexture(GetCellFace(voxel, Enum.NormalId.Bottom), GetCellFace(below, Enum.NormalId.Top)) then
      voxel.Surround.Bottom = true
    end
  end

  -- TODO: top culling, IsTop doesn't necessarily mean surrounded on top? check this

  if not voxel.Surround.Back then
    local behind = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z + 1)

    if behind ~= nil and ShouldCullTexture(GetCellFace(voxel, Enum.NormalId.Back), GetCellFace(behind, Enum.NormalId.Front)) then
      voxel.Surround.Back = true
    end
  end

  if not voxel.Surround.Front then
    local front = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z - 1)

    if front ~= nil and ShouldCullTexture(GetCellFace(voxel, Enum.NormalId.Front), GetCellFace(front, Enum.NormalId.Back)) then
      voxel.Surround.Front = true
    end
  end
end

local function SetExtentsIfNotZero(voxel: Voxel, extents: Extents)
  if extents.PosX ~= 0 
    or extents.PosY ~= 0 
    or extents.PosZ ~= 0
    or extents.NegX ~= 0 
    or extents.NegY ~= 0 
    or extents.NegZ ~= 0 
  then
    voxel.Extents = extents
  end
end

local function TryExtendSolidVoxel(voxel: Voxel, voxels: VoxelMap)
  local MAX = 64

  -- Try:
  -- +Y,+X
  -- +Y,+Z
  -- +X,+Z

  local bestAbsorbed: {Voxel} = {}
  local bestExtents: Extents | nil = nil
  local best = -1

  local function AddAttempt(extents: Extents, score: number, absorbed: {Voxel})
    if score > best then
      best = score
      bestExtents = extents
      bestAbsorbed = absorbed
    end
  end

  -- +Y,+X
  do
    local py = 0
    local ny = 0
    local px = 0
    local nx = 0
    local absorbed = {}

    while py < MAX do
      local other = GetVoxel(voxels, voxel.X, voxel.Y + py + 1, voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        table.insert(absorbed, other)
        py = py + 1
      else
        break
      end
    end
    
    while ny > -MAX do
      local other = GetVoxel(voxels, voxel.X, voxel.Y + (ny - 1), voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        table.insert(absorbed, other)
        ny = ny - 1
      else
        break
      end
    end

    while px < MAX do
      local seen = {}
      local fullRow = true
      for yy=ny, py do
        local other = GetVoxel(voxels, voxel.X + px + 1, voxel.Y + yy, voxel.Z)
        if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
          table.insert(seen, other)
        else
          fullRow = false
          break
        end
      end

      if fullRow then
        for _, other in ipairs(seen) do
          table.insert(absorbed, other)
        end
        px = px + 1
      else
        break
      end
    end
    
    while nx > -MAX do
      local seen = {}
      local fullRow = true
      for yy=ny, py do
        local other = GetVoxel(voxels, voxel.X + (nx - 1), voxel.Y + yy, voxel.Z)
        if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
          table.insert(seen, other)
        else
          fullRow = false
          break
        end
      end

      if fullRow then
        for _, other in ipairs(seen) do
          table.insert(absorbed, other)
        end
        nx = nx - 1
      else
        break
      end
    end

    AddAttempt(
      {PosX = px, PosY = py, PosZ = 0, NegX = nx, NegY = ny, NegZ = 0}, 
      px + math.abs(nx) + py + math.abs(ny), 
      absorbed)
  end

  -- +Y,+Z
  do
    local py = 0
    local ny = 0
    local pz = 0
    local nz = 0
    local absorbed = {}

    while py < MAX do
      local other = GetVoxel(voxels, voxel.X, voxel.Y + py + 1, voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        table.insert(absorbed, other)
        py = py + 1
      else
        break
      end
    end
    
    while ny > -MAX do
      local other = GetVoxel(voxels, voxel.X, voxel.Y + (ny - 1), voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        table.insert(absorbed, other)
        ny = ny - 1
      else
        break
      end
    end

    while pz < MAX do
      local seen = {}
      local fullRow = true
      for yy=ny, py do
        local other = GetVoxel(voxels, voxel.X, voxel.Y + yy, voxel.Z + pz + 1)
        if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
          table.insert(seen, other)
        else
          fullRow = false
          break
        end
      end

      if fullRow then
        for _, other in ipairs(seen) do
          table.insert(absorbed, other)
        end
        pz = pz + 1
      else
        break
      end
    end
    
    while nz > -MAX do
      local seen = {}
      local fullRow = true
      for yy=ny, py do
        local other = GetVoxel(voxels, voxel.X, voxel.Y + yy, voxel.Z + (nz - 1))
        if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
          table.insert(seen, other)
        else
          fullRow = false
          break
        end
      end

      if fullRow then
        for _, other in ipairs(seen) do
          table.insert(absorbed, other)
        end
        nz = nz - 1
      else
        break
      end
    end

    AddAttempt(
      {PosX = 0, PosY = py, PosZ = pz, NegX = 0, NegY = ny, NegZ = nz}, 
      pz + math.abs(nz) + py + math.abs(ny), 
      absorbed)
  end

  -- +X,+Z
  do
    local px = 0
    local nx = 0
    local pz = 0
    local nz = 0
    local absorbed = {}

    while px < MAX do
      local other = GetVoxel(voxels, voxel.X + px + 1, voxel.Y, voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        table.insert(absorbed, other)
        px = px + 1
      else
        break
      end
    end
    
    while nx > -MAX do
      local other = GetVoxel(voxels, voxel.X + (nx - 1), voxel.Y, voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        table.insert(absorbed, other)
        nx = nx - 1
      else
        break
      end
    end

    while pz < MAX do
      local seen = {}
      local fullRow = true
      for xx=nx, px do
        local other = GetVoxel(voxels, voxel.X + xx, voxel.Y, voxel.Z + pz + 1)
        if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
          table.insert(seen, other)
        else
          fullRow = false
          break
        end
      end

      if fullRow then
        for _, other in ipairs(seen) do
          table.insert(absorbed, other)
        end
        pz = pz + 1
      else
        break
      end
    end
    
    while nz > -MAX do
      local seen = {}
      local fullRow = true
      for xx=nx, px do
        local other = GetVoxel(voxels, voxel.X + xx, voxel.Y, voxel.Z + (nz - 1))
        if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
          table.insert(seen, other)
        else
          fullRow = false
          break
        end
      end

      if fullRow then
        for _, other in ipairs(seen) do
          table.insert(absorbed, other)
        end
        nz = nz - 1
      else
        break
      end
    end

    AddAttempt(
      {PosX = px, PosY = 0, PosZ = pz, NegX = nx, NegY = 0, NegZ = nz}, 
      px + math.abs(nx) + pz + math.abs(nz), 
      absorbed)
  end

  if best > -1 then
    for _, other in ipairs(bestAbsorbed) do
      other.Extended = true
    end
    
    SetExtentsIfNotZero(voxel, bestExtents :: Extents)
  end
end

local function TryExtendVerticalWedgeVoxel(voxel: Voxel, voxels: VoxelMap)
  if voxel.Orientation == 1 or voxel.Orientation == 3 then
    -- Orientated X, extend Z
    local pz = 0
    local nz = 0

    while true do
      local other = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z + pz + 1)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        other.Extended = true
        pz = pz + 1
      else
        break
      end
    end
    
    while true do
      local other = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z + (nz - 1))
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        other.Extended = true
        nz = nz - 1
      else
        break
      end
    end
    
    SetExtentsIfNotZero(voxel, {PosX = 0, PosY = 0, PosZ = pz, NegX = 0, NegY = 0, NegZ = nz})
  elseif voxel.Orientation == 0 or voxel.Orientation == 2 then
    -- Orientated Z, extend X
    local px = 0
    local nx = 0

    while true do
      local other = GetVoxel(voxels, voxel.X + px + 1, voxel.Y, voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        other.Extended = true
        px = px + 1
      else
        break
      end
    end
    
    while true do
      local other = GetVoxel(voxels, voxel.X + (nx - 1), voxel.Y, voxel.Z)
      if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
        other.Extended = true
        nx = nx - 1
      else
        break
      end
    end
    
    SetExtentsIfNotZero(voxel, {PosX = px, PosY = 0, PosZ = 0, NegX = nx, NegY = 0, NegZ = 0})
  end
end

local function TryExtendHorizontalWedgeVoxel(voxel: Voxel, voxels: VoxelMap)
  local py = 0
  local ny = 0

  while true do
    local other = GetVoxel(voxels, voxel.X, voxel.Y + py + 1, voxel.Z)
    if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
      other.Extended = true
      py = py + 1
    else
      break
    end
  end
  
  while true do
    local other = GetVoxel(voxels, voxel.X, voxel.Y + (ny - 1), voxel.Z)
    if other ~= nil and not other.Extended and other.Extents == nil and IsSameVoxel(voxel, other) then
      other.Extended = true
      ny = ny - 1
    else
      break
    end
  end
  
  SetExtentsIfNotZero(voxel, {PosX = 0, PosY = py, PosZ = 0, NegX = 0, NegY = ny, NegZ = 0})
end

local function TryExtendVoxel(voxel: Voxel, voxels: VoxelMap)
  if voxel.Type == 0 then
    TryExtendSolidVoxel(voxel, voxels)
  elseif voxel.Type == 1 then
    TryExtendVerticalWedgeVoxel(voxel, voxels)
  elseif voxel.Type == 4 then
    TryExtendHorizontalWedgeVoxel(voxel, voxels)
  end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Texture Functions
type MaterialTextures = {
  Top: {string},
  Bottom: {string},
  Side: string,
  SideTop: string,
  Slope: {string},
  SlopeTop: {string},
}

local normals = {Enum.NormalId.Back, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top}
-- Top/bottom are 0,90,180,270 rotations
-- Slopes are 0,180 rotations
local textures: { [number]: MaterialTextures } = {
  [0] = { -- Grass
    Top = {
      "rbxassetid://11150954718",
      "rbxassetid://132700481701194",
      "rbxassetid://135534695323360",
      "rbxassetid://131048213926699"
    },
    Bottom = {
      "rbxassetid://11150955296",
      "rbxassetid://81329967401529",
      "rbxassetid://114095893549344",
      "rbxassetid://114910484910712"
    },
    Side = "rbxassetid://11150955221",
    SideTop = "rbxassetid://11151277340",
    Slope = {
      "rbxassetid://11150955015",
      "rbxassetid://76611971396851"
    },
    SlopeTop = {
      "rbxassetid://11151277242",
      "rbxassetid://89438149722688"
    }
  },
  [1] = { -- Sand
    Top = {
      "rbxassetid://11228950608",
      "rbxassetid://114910484910712",
      "rbxassetid://116200458297439",
      "rbxassetid://109997039768455"
    },
    Bottom = {
      "rbxassetid://11228952522",
      "rbxassetid://83675275620407",
      "rbxassetid://88105793395535",
      "rbxassetid://105653154337161"
    },
    Side = "rbxassetid://11228952353",
    SideTop = "rbxassetid://11228951799",
    Slope = {
      "rbxassetid://11228950990",
      "rbxassetid://91226981041323"
    },
    SlopeTop = {
      "rbxassetid://11228950824",
      "rbxassetid://133094709182022"
    }
  },
  [2] = { -- Brick
    Top = {
      "rbxassetid://11228986751",
      "rbxassetid://113890276933929",
      "rbxassetid://118600815877286",
      "rbxassetid://70631076357072"
    },
    Bottom = {
      "rbxassetid://11228988408",
      "rbxassetid://107163992921756",
      "rbxassetid://135039369526656",
      "rbxassetid://97671686655977"
    },
    Side = "rbxassetid://11228988275",
    SideTop = "rbxassetid://11228987786",
    Slope = {
      "rbxassetid://11228987380",
      "rbxassetid://77693233094499"
    },
    SlopeTop = {
      "rbxassetid://11228986931",
      "rbxassetid://135112837838649"
    }
  },
  [3] = { -- Granite
    Top = {
      "rbxassetid://11229013754",
      "rbxassetid://90214571372944",
      "rbxassetid://119396348297350",
      "rbxassetid://108629607840968"
    },
    Bottom = {
      "rbxassetid://11229015627",
      "rbxassetid://119990704136082",
      "rbxassetid://76553001814162",
      "rbxassetid://77076037085811"
    },
    Side = "rbxassetid://11229015467",
    SideTop = "rbxassetid://11229014940",
    Slope = {
      "rbxassetid://11229014148",
      "rbxassetid://104951331981345"
    },
    SlopeTop = {
      "rbxassetid://11229013937",
      "rbxassetid://92160981802717"
    }
  },
  [4] = { -- Asphalt
    Top = {
      "rbxassetid://11229069127",
      "rbxassetid://70440526124322",
      "rbxassetid://72856038224052",
      "rbxassetid://72257015099024"
    },
    Bottom = {
      "rbxassetid://11229070661",
      "rbxassetid://90382487533529",
      "rbxassetid://88418364139842",
      "rbxassetid://75198552652468"
    },
    Side = "rbxassetid://11229070532",
    SideTop = "rbxassetid://11229069898",
    Slope = {
      "rbxassetid://11229069427",
      "rbxassetid://123484758854006"
    },
    SlopeTop = {
      "rbxassetid://11229069292",
      "rbxassetid://71764889929710"
    }
  },
  [5] = { -- Iron
    Top = {
      "rbxassetid://11229094694",
      "rbxassetid://108572828866764",
      "rbxassetid://93324259149291",
      "rbxassetid://86223828902625"
    },
    Bottom = {
      "rbxassetid://11229095894",
      "rbxassetid://86223828902625",
      "rbxassetid://125475051819813",
      "rbxassetid://79838821662143"
    },
    Side = "rbxassetid://11229095803",
    SideTop = "rbxassetid://11229095443",
    Slope = {
      "rbxassetid://11229094909",
      "rbxassetid://115511794085244"
    },
    SlopeTop = {
      "rbxassetid://11229094814",
      "rbxassetid://109762797609850"
    }
  },
  [6] = { -- Aluminum
    Top = {
      "rbxassetid://11229473497",
      "rbxassetid://74135812723508",
      "rbxassetid://84157702557616",
      "rbxassetid://136627340342529"
    },
    Bottom = {
      "rbxassetid://11229474642",
      "rbxassetid://94959201323190",
      "rbxassetid://82811884968401",
      "rbxassetid://79027517414385"
    },
    Side = "rbxassetid://11229474565",
    SideTop = "rbxassetid://11229474315",
    Slope = {
      "rbxassetid://11229473763",
      "rbxassetid://107713581380909"
    },
    SlopeTop = {
      "rbxassetid://11229473623",
      "rbxassetid://121997152611680"
    }
  },
  [7] = { -- Gold
    Top = {
      "rbxassetid://11229490857",
      "rbxassetid://99409269519914",
      "rbxassetid://135093708523274",
      "rbxassetid://127841475200679"
    },
    Bottom = {
      "rbxassetid://11229492063",
      "rbxassetid://118674625772286",
      "rbxassetid://109742557967870",
      "rbxassetid://107966354617569"
    },
    Side = "rbxassetid://11229491799",
    SideTop = "rbxassetid://11229491454",
    Slope = {
      "rbxassetid://11229491128",
      "rbxassetid://123998296667796"
    },
    SlopeTop = {
      "rbxassetid://11229490998",
      "rbxassetid://98487774819720"
    }
  },
  [8] = { -- WoodPlank
    Top = {
      "rbxassetid://11229505497",
      "rbxassetid://78917320565520",
      "rbxassetid://101575998261632",
      "rbxassetid://135747555975908"
    },
    Bottom = {
      "rbxassetid://11229506701",
      "rbxassetid://71512903176305",
      "rbxassetid://120404629839065",
      "rbxassetid://95201796578631"
    },
    Side = "rbxassetid://11229506546",
    SideTop = "rbxassetid://11229506149",
    Slope = {
      "rbxassetid://11229505800",
      "rbxassetid://121147320993088"
    },
    SlopeTop = {
      "rbxassetid://11229505681",
      "rbxassetid://95248634765840"
    }
  },
  [9] = { -- WoodLog
    Top = {
      "rbxassetid://11229735772",
      "rbxassetid://102760047716956",
      "rbxassetid://96539236481058",
      "rbxassetid://119800024845883"
    },
    Bottom = {
      "rbxassetid://11229737190",
      "rbxassetid://128658362944693",
      "rbxassetid://71254770597104",
      "rbxassetid://99233448961610"
    },
    Side = "rbxassetid://11229737078",
    SideTop = "rbxassetid://11229736584",
    Slope = {
      "rbxassetid://11229736092",
      "rbxassetid://75361996581481"
    },
    SlopeTop = {
      "rbxassetid://11229735935",
      "rbxassetid://111853442929899"
    }
  },
  [10] = { -- Gravel
    Top = {
      "rbxassetid://11229755077",
      "rbxassetid://80944907612187",
      "rbxassetid://110985021551753",
      "rbxassetid://136797962154383"
    },
    Bottom = {
      "rbxassetid://11229756519",
      "rbxassetid://136797962154383",
      "rbxassetid://100865714400684",
      "rbxassetid://104915323326651"
    },
    Side = "rbxassetid://11229756395",
    SideTop = "rbxassetid://11229755949",
    Slope = {
      "rbxassetid://11229755454",
      "rbxassetid://108560867101329"
    },
    SlopeTop = {
      "rbxassetid://132894594750417",
      "rbxassetid://72265518449676"
    }
  },
  [11] = { -- CinderBlock
    Top = {
      "rbxassetid://11229900650",
      "rbxassetid://111969604395109",
      "rbxassetid://77631452675902",
      "rbxassetid://91535581462804"
    },
    Bottom = {
      "rbxassetid://11229902465",
      "rbxassetid://119037096445285",
      "rbxassetid://90669640234473",
      "rbxassetid://128799667423315"
    },
    Side = "rbxassetid://11229902261",
    SideTop = "rbxassetid://11229900912", -- original got content deleted but slope top is identical, so we'll use that
    Slope = {
      "rbxassetid://11229901090",
      "rbxassetid://114772405775361"
    },
    SlopeTop = {
      "rbxassetid://11229900912",
      "rbxassetid://92361368227802"
    }
  },
  [12] = { -- MossyStone
    Top = {
      "rbxassetid://11229925762",
      "rbxassetid://115302027439149",
      "rbxassetid://123505674147433",
      "rbxassetid://80133780443227"
    },
    Bottom = {
      "rbxassetid://11229927127",
      "rbxassetid://120392031198196",
      "rbxassetid://89151348729911",
      "rbxassetid://125364716562262"
    },
    Side = "rbxassetid://11229926936",
    SideTop = "rbxassetid://11229926510",
    Slope = {
      "rbxassetid://11229925989",
      "rbxassetid://115232543736770"
    },
    SlopeTop = {
      "rbxassetid://11229925863",
      "rbxassetid://137940345124981"
    }
  },
  [13] = { -- Cement
    Top = {
      "rbxassetid://15135162639",
      "rbxassetid://119268658469527",
      "rbxassetid://87573013131927",
      "rbxassetid://138136636506214"
    },
    Bottom = {
      "rbxassetid://15135163971",
      "rbxassetid://108467167500980",
      "rbxassetid://72120162770595",
      "rbxassetid://91160692302439"
    },
    Side = "rbxassetid://15135163815",
    SideTop = "rbxassetid://15135163343",
    Slope = {
      "rbxassetid://15135162905",
      "rbxassetid://139922130129180"
    },
    SlopeTop = {
      "rbxassetid://15135162789",
      "rbxassetid://92029945960613"
    }
  },
  [14] = { -- RedPlastic
    Top = {
      "rbxassetid://11230008311",
      "rbxassetid://71072831712887",
      "rbxassetid://108423202075661",
      "rbxassetid://127318430123644"
    },
    Bottom = {
      "rbxassetid://121476124804140",
      "rbxassetid://103704922945451",
      "rbxassetid://87627019328692",
      "rbxassetid://79300765533953"
    },
    Side = "rbxassetid://127524203431138",
    SideTop = "rbxassetid://11230008452",
    Slope = {
      "rbxassetid://80650776012984",
      "rbxassetid://71660313915666"
    },
    SlopeTop = {
      "rbxassetid://135185272031647",
      "rbxassetid://84965323538160"
    }
  },
  [15] = { -- BluePlastic
    Top = {
      "rbxassetid://121191178544933",
      "rbxassetid://90529222971446",
      "rbxassetid://136352161710299",
      "rbxassetid://139765033304563"
    },
    Bottom = {
      "rbxassetid://137711320455303",
      "rbxassetid://75632011469183",
      "rbxassetid://136379758461423",
      "rbxassetid://113049137512589"
    },
    Side = "rbxassetid://111863168243989",
    SideTop = "rbxassetid://119917720586806",
    Slope = {
      "rbxassetid://105306404781891",
      "rbxassetid://105496994608925"
    },
    SlopeTop = {
      "rbxassetid://105513373464367",
      "rbxassetid://77750535561804"
    }
  }
}

local function GetSurroundFromNormal(surround: Surround, normal: Enum.NormalId)
  if normal == Enum.NormalId.Top then
    return not surround.IsTop
  elseif normal == Enum.NormalId.Bottom then
    return surround.Bottom
  elseif normal == Enum.NormalId.Left then
    return surround.Left
  elseif normal == Enum.NormalId.Right then
    return surround.Right
  elseif normal == Enum.NormalId.Back then
    return surround.Back
  else -- Front
    return surround.Front
  end
end

local function SetUpTexture(part: BasePart, voxel: Voxel, texs: MaterialTextures, normal: Enum.NormalId, face: Enum.NormalId, slope: boolean)
  -- Calculate UVs
  local xUV, yUV
  if voxel.Type == 0 then
    -- UVs depending on part world position, top left of face
    if normal == Enum.NormalId.Top then
      xUV = -(part.Position.X + (part.Size.X / 2))
      yUV = -(part.Position.Z + (part.Size.Z / 2))
    elseif normal == Enum.NormalId.Bottom then
      xUV = (part.Position.X - (part.Size.X / 2))
      yUV = -(part.Position.Z + (part.Size.Z / 2))
    elseif normal == Enum.NormalId.Left then
      xUV = (part.Position.Z - (part.Size.Z / 2))
      yUV = -(part.Position.Y + (part.Size.Y / 2)) 
    elseif normal == Enum.NormalId.Right then
      xUV = -(part.Position.Z + (part.Size.Z / 2))
      yUV = -(part.Position.Y + (part.Size.Y / 2))
    elseif normal == Enum.NormalId.Back then
      xUV = (part.Position.X - (part.Size.X / 2))
      yUV = -(part.Position.Y + (part.Size.Y / 2))
    else -- Front
      xUV = -(part.Position.X + (part.Size.X / 2))
      yUV = -(part.Position.Y + (part.Size.Y / 2))
    end
  else
    -- UVs depending part world position, center of face (MeshParts tile from center)
    if normal == Enum.NormalId.Top then
      xUV = -part.Position.X
      yUV = -part.Position.Z
    elseif normal == Enum.NormalId.Bottom then
      xUV = part.Position.X
      yUV = -part.Position.Z
    elseif normal == Enum.NormalId.Left then
      xUV = part.Position.Z
      yUV = -part.Position.Y
    elseif normal == Enum.NormalId.Right then
      xUV = -part.Position.Z
      yUV = -part.Position.Y
    elseif normal == Enum.NormalId.Back then
      xUV = part.Position.X
      yUV = -part.Position.Y
    else -- Front
      xUV = -part.Position.X
      yUV = -part.Position.Y
    end
  end

  -- Create texture instance
  local tex = Instance.new("Texture")
  tex.Name = "Tex" .. normal.Name
  tex.Face = face

  if normal == Enum.NormalId.Top then
    xUV = xUV % 16
    yUV = yUV % 16

    local orientation = voxel.Orientation

    if orientation == 1 then
      local _xUV = xUV
      xUV = 16 - yUV
      yUV = _xUV
    elseif orientation == 2 then
      xUV = 16 - xUV
      yUV = 16 - yUV
    elseif orientation == 3 then
      local _xUV = xUV
      xUV = yUV
      yUV = 16 - _xUV
    end

    tex.Texture = texs.Top[((orientation + 2) % 4) + 1] -- Top textures need to be rotated 180
    tex.StudsPerTileU = 16 -- 4x4 tiles per tex, 4 studs per tile
    tex.StudsPerTileV = 16
    tex.OffsetStudsU = xUV
    tex.OffsetStudsV = yUV
  elseif normal == Enum.NormalId.Bottom then
    xUV = xUV % 8
    yUV = yUV % 8

    local orientation = (4 - voxel.Orientation) % 4

    if orientation == 1 then
      local _xUV = xUV
      xUV = 8 - yUV
      yUV = _xUV
    elseif orientation == 2 then
      xUV = 8 - xUV
      yUV = 8 - yUV
    elseif orientation == 3 then
      local _xUV = xUV
      xUV = yUV
      yUV = 8 - _xUV
    end

    tex.Texture = texs.Bottom[orientation + 1]
    tex.StudsPerTileU = 8 -- 2x2 tiles per tex, 4 studs per tile
    tex.StudsPerTileV = 8
    tex.OffsetStudsU = xUV
    tex.OffsetStudsV = yUV
  else -- Left, Right, Back, Front
    if voxel.Surround.IsTop then
      if slope then
        tex.Texture = texs.SlopeTop[if voxel.Type == 1 then 2 else 1]
      else
        tex.Texture = texs.SideTop
      end
      tex.StudsPerTileU = 8 -- 2x1 tiles per tex, 4 studs per tile
      tex.StudsPerTileV = 48 / 8
      tex.OffsetStudsU = xUV % 8
      tex.OffsetStudsV = if voxel.Type == 0 then 1 else 3 -- move passed the 8 pixel border for bilinear filtering on wrapped edges
    else
      if slope then
        tex.Texture = texs.Slope[if voxel.Type == 1 then 2 else 1]
      else
        tex.Texture = texs.Side
      end
      tex.StudsPerTileU = 8 -- 2x4 tiles per tex, 4 studs per tile
      tex.StudsPerTileV = 16
      tex.OffsetStudsU = xUV % 8
      tex.OffsetStudsV = yUV % 16
    end
  end

  if voxel.Type == 3 and slope then
    -- Slopes on InverseCornerWedges are actually a child part
    tex.Parent = part:FindFirstChild("Slope")
  else
    tex.Parent = part
  end
end

local function SetUpTextures(part: BasePart, voxel: Voxel)
  local cellType = voxel.Type
  local cellOrientation = voxel.Orientation
  local surround = voxel.Surround

  local texs = textures[voxel.Mat]
    
  if texs == nil then
    error("unknown material id " .. tostring(voxel.Mat))
  end

  -- Normal faces
  for _, normal in ipairs(normals) do
    if not GetSurroundFromNormal(surround, normal) and GetCellFace(voxel, normal) ~= CellFaceType.Empty then
      SetUpTexture(part, voxel, texs, normal, RotateFaceNormal(normal, cellOrientation), --[[slope]]false)
    end
  end

  -- Slope/diagonal faces
  if cellType == 1 then
    SetUpTexture(part, voxel, texs, RotateFaceNormalInverse(Enum.NormalId.Back, cellOrientation), Enum.NormalId.Top, --[[slope]]true)
  elseif cellType == 2 or cellType == 3 then
    local normal = RotateFaceNormalInverse(Enum.NormalId.Left, cellOrientation)
    local face = RotateFaceNormal(normal, cellOrientation)
    SetUpTexture(part, voxel, texs, normal, face, --[[slope]]true)
  elseif cellType == 4 then
    local normal = RotateFaceNormalInverse(Enum.NormalId.Left, cellOrientation)
    local face = RotateFaceNormal(normal, cellOrientation)
    SetUpTexture(part, voxel, texs, normal, face, --[[slope]]false)
  end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Parsing
local voxelsFolder: Instance? = game:GetService("Selection"):Get()[1]
if voxelsFolder == nil then
  error("A voxels folder must be selected to run this script.", 0)
end

local assetsFolder = game:GetService("ServerStorage"):FindFirstChild("LegacyTerrainAssets")
if assetsFolder == nil then
  error("ServerStorage must contain a folder named LegacyTerrainAssets.", 0)
end

local function AssertAsset(name: string)
  local asset = assetsFolder:FindFirstChild(name)
  if asset == nil then
    error("LegacyTerrainAssets is missing the child " .. name .. ".", 0)
  end

  return asset
end

local assets = {
  VerticalWedge = AssertAsset("VerticalWedge"),
  CornerWedge = AssertAsset("CornerWedge"),
  InverseCornerWedge = AssertAsset("InverseCornerWedge"),
  HorizontalWedge = AssertAsset("HorizontalWedge")
}

local function MakePart(voxel: Voxel): BasePart | nil
  local x = voxel.X * 4 + 2
  local y = voxel.Y * 4 + 2
  local z = voxel.Z * 4 + 2
  local cellType = voxel.Type
  local cellOrientation = voxel.Orientation
  local extents = voxel.Extents

  local p: BasePart

  if cellType == 0 then
    p = Instance.new("Part")
    cellOrientation = 0 -- We dont support rotated solids, but also don't need them
  elseif cellType == 1 then
    p = assets.VerticalWedge:Clone() :: BasePart
  elseif cellType == 2 then
    p = assets.CornerWedge:Clone() :: BasePart
  elseif cellType == 3 then
    p = assets.InverseCornerWedge:Clone() :: BasePart
  elseif cellType == 4 then
    p = assets.HorizontalWedge:Clone() :: BasePart
  end

  p.Name = "CellT" .. tostring(cellType) .. "R" .. tostring(cellOrientation)
  p.Anchored = true
  p.Locked = true
  p.TopSurface = Enum.SurfaceType.Smooth
  p.BottomSurface = Enum.SurfaceType.Smooth
  if extents ~= nil then
    local hx = ((4 * extents.PosX) / 2) + ((4 * extents.NegX) / 2)
    local hy = ((4 * extents.PosY) / 2) + ((4 * extents.NegY) / 2)
    local hz = ((4 * extents.PosZ) / 2) + ((4 * extents.NegZ) / 2)
    
    local xs = math.abs(extents.NegX) + extents.PosX + 1
    local ys = math.abs(extents.NegY) + extents.PosY + 1
    local zs = math.abs(extents.NegZ) + extents.PosZ + 1

    p.CFrame = CFrame.new(x + hx, y + hy, z + hz)
    if cellOrientation == 1 or cellOrientation == 3 then
      p.Size = Vector3.new(4 * zs, 4 * ys, 4 * xs)
    else
      p.Size = Vector3.new(4 * xs, 4 * ys, 4 * zs)
    end
  else
    p.CFrame = CFrame.new(x, y, z)
    p.Size = Vector3.new(4, 4, 4)
  end

  p.Orientation = Vector3.new(0, cellOrientation * 90, 0)

  if cellType == 3 then
    local slope = p:FindFirstChild("Slope") :: BasePart

    slope.Anchored = true
    slope.Locked = true

    slope.CFrame = p.CFrame
    slope.Size = p.Size
  end

  SetUpTextures(p, voxel)

  return p
end

local voxels: VoxelMap = {} -- 3d array
local queue: {Voxel} = {}

local model = Instance.new("Model")
model.Name = "LegacyTerrain"

print("Parsing chunks...")
wait()

for _, chunk in ipairs(voxelsFolder:GetChildren()) do
  if not chunk:IsA("ModuleScript") then
    continue
  end

  local cells = require(chunk)

  for i, cell in ipairs(cells) do
    if (cell[4] - 2) ~= 16 then
      local voxel = ParseVoxel(cell)
      
      StoreVoxel(voxels, voxel.X, voxel.Y, voxel.Z, voxel)
      table.insert(queue, voxel)
    end
  end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Patching
print("Patching...")
wait()

for i, voxel in ipairs(queue) do
  PatchVoxel(voxel, voxels)
  TextureCull(voxel, voxels)

  if i % 5000 == 0 then
    print(tostring(i) .. "/" .. tostring(#queue))
    wait()
  end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Optimization
print("Optimizing...")
wait()

for i, voxel in ipairs(queue) do
  if not voxel.Extended then
    TryExtendVoxel(voxel, voxels)
  end

  if i % 5000 == 0 then
    print(tostring(i) .. "/" .. tostring(#queue))
    wait()
  end
end

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Part Building
print("Building parts...")
wait()

local count = 0
local submodel = Instance.new("Model")
submodel.Name = "Chunk"

for _, voxel in ipairs(queue) do
  if not voxel.Extended then
    local part = MakePart(voxel)
    if part ~= nil then
      part.Parent = submodel
      count = count + 1

      if (count % 2000) == 0 then
        submodel.Parent = model
        submodel = Instance.new("Model")
        submodel.Name = "Chunk"
      end
    end
  end
end

submodel.Parent = model

print("Done. Part count = " .. tostring(count))

model.Parent = workspace
