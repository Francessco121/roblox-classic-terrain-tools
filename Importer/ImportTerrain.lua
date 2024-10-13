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

--[[
CellOrientation = {
  NegZ = 0,
  X = 1,
  Z = 2,
  NegX = 3
}

CellBlock = {
  Solid = 0,
  VerticalWedge = 1,
  CornerWedge = 2,
  InverseCornerWedge = 3,
  HorizontalWedge = 4
}
--]]

local function StoreVoxel(voxels: {any}, x: number, y: number, z: number, voxel: any)
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

local function GetVoxel(voxels: {any}, x: number, y: number, z: number): any | nil
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

local function ParseVoxel(cell: any)
  local x = cell[1]
  local y = cell[2]
  local z = cell[3]
  local cellMat = cell[4] - 2
  local cellType = cell[5] - 1
  local cellOrientation = cell[6] - 1
  local surround = ParseSurround(cell[7])

  local voxel = {
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

local function IsSameVoxel(a: any, b: any)
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

local function PatchVoxel(voxel: any, voxels: {any})
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

local function TextureCull(voxel: any, voxels: {any})
  -- BEWARE: here be dragons and stupid illogical code

  if voxel.Type == 0 then
    -- Solid
    if not voxel.Surround.Left then
      local left = GetVoxel(voxels, voxel.X - 1, voxel.Y, voxel.Z)

      if left and (
        (left.Type == 0)
          or (left.Type == 1 and left.Orientation == 3)
          or (left.Type == 4 and (left.Orientation == 0 or left.Orientation == 3))
          or (left.Type == 3 and (left.Orientation == 0 or left.Orientation == 3))
        )
      then
        voxel.Surround.Left = true
      end
    end
    if not voxel.Surround.Right then
      local right = GetVoxel(voxels, voxel.X + 1, voxel.Y, voxel.Z)

      if right and (
        (right.Type == 0)
          or (right.Type == 1 and right.Orientation == 1)
          or (right.Type == 4 and (right.Orientation == 1 or right.Orientation == 2))
          or (right.Type == 3 and (right.Orientation == 1 or right.Orientation == 2))
        )
      then
        voxel.Surround.Right = true
      end
    end
    if not voxel.Surround.Back then
      local back = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z - 1)

      if back and (
        (back.Type == 0)
          or (back.Type == 1 and back.Orientation == 2)
          or (back.Type == 4 and (back.Orientation == 2 or back.Orientation == 3))
          or (back.Type == 3 and (back.Orientation == 2 or back.Orientation == 3))
        )
      then
        voxel.Surround.Back = true
      end
    end
    if not voxel.Surround.Front then
      local front = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z + 1)

      if front and (
        (front.Type == 0)
          or (front.Type == 1 and front.Orientation == 0)
          or (front.Type == 4 and (front.Orientation == 0 or front.Orientation == 1))
          or (front.Type == 3 and (front.Orientation == 0 or front.Orientation == 1))
        )
      then
        voxel.Surround.Front = true
      end
    end
  elseif voxel.Type == 1 then
    -- Vertical wedge
    if not voxel.Surround.Bottom then
      local below = GetVoxel(voxels, voxel.X, voxel.Y - 1, voxel.Z)

      if below and below.Type == 0 then
        voxel.Surround.Bottom = true
      end
    end
  elseif voxel.Type == 2 then
    -- CornerWedge
    if not voxel.Surround.Bottom then
      local below = GetVoxel(voxels, voxel.X, voxel.Y - 1, voxel.Z)

      if below and (
        below.Type == 0 
          or (below.Type == 3 and below.Orientation == voxel.Orientation)
          or (below.Type == 4 and below.Orientation == voxel.Orientation)
        )
      then
        voxel.Surround.Bottom = true
      end
    end
  elseif voxel.Type == 3 then
    -- InverseCornerWedge
    if not voxel.Surround.Bottom then
      local below = GetVoxel(voxels, voxel.X, voxel.Y - 1, voxel.Z)

      if below and below.Type == 0 then
        voxel.Surround.Bottom = true
      end
    end
  elseif voxel.Type == 4 then
    -- Horizontal wedge
    if not voxel.Surround.Bottom then
      local below = GetVoxel(voxels, voxel.X, voxel.Y - 1, voxel.Z)

      if below and ((below.Type == 4 and below.Orientation == voxel.Orientation) or below.Type == 0) then
        voxel.Surround.Bottom = true
      end
    end

    if voxel.Orientation == 0 then
      if not voxel.Surround.Front then
        local behind = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z - 1)

        if behind and (behind.Type == 0 or (behind.Type == 4 and behind.Orientation == 3)) then
          voxel.Surround.Front = true
        end
      end
      if not voxel.Surround.Left then
        local right = GetVoxel(voxels, voxel.X + 1, voxel.Y, voxel.Z)

        if right and (right.Type == 0 or (right.Type == 4 and right.Orientation == 1)) then
          voxel.Surround.Left = true
        end
      end
    elseif voxel.Orientation == 1 then
      if not voxel.Surround.Front then
        local left = GetVoxel(voxels, voxel.X - 1, voxel.Y, voxel.Z)

        if left and (left.Type == 0 or (left.Type == 4 and left.Orientation == 0)) then
          voxel.Surround.Front = true
        end
      end
      if not voxel.Surround.Left then
        local behind = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z - 1)

        if behind and (behind.Type == 0 or (behind.Type == 4 and behind.Orientation == 2)) then
          voxel.Surround.Left = true
        end
      end
    elseif voxel.Orientation == 2 then
      if not voxel.Surround.Front then
        local front = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z + 1)

        if front and (front.Type == 0 or (front.Type == 4 and front.Orientation == 1)) then
          voxel.Surround.Front = true
        end
      end
      if not voxel.Surround.Left then
        local left = GetVoxel(voxels, voxel.X - 1, voxel.Y, voxel.Z)

        if left and (left.Type == 0 or (left.Type == 4 and left.Orientation == 3)) then
          voxel.Surround.Left = true
        end
      end
    elseif voxel.Orientation == 3 then
      if not voxel.Surround.Front then
        local right = GetVoxel(voxels, voxel.X + 1, voxel.Y, voxel.Z)

        if right and (right.Type == 0 or (right.Type == 4 and right.Orientation == 2)) then
          voxel.Surround.Front = true
        end
      end
      if not voxel.Surround.Left then
        local front = GetVoxel(voxels, voxel.X, voxel.Y, voxel.Z + 1)

        if front and (front.Type == 0 or (front.Type == 4 and front.Orientation == 0)) then
          voxel.Surround.Left = true
        end
      end
    end
  end
end

local function SetExtentsIfNotZero(voxel, extents)
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

local function TryExtendSolidVoxel(voxel: any, voxels: {any})
  local MAX = 64

  -- Try:
  -- +Y,+X
  -- +Y,+Z
  -- +X,+Z

  local bestAbsorbed = {}
  local bestExtents = {}
  local best = -1

  local function AddAttempt(extents, score, absorbed)
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
    
    SetExtentsIfNotZero(voxel, bestExtents)
  end
end

local function TryExtendVerticalWedgeVoxel(voxel: any, voxels: {any})
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

local function TryExtendHorizontalWedgeVoxel(voxel: any, voxels: {any})
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

local function TryExtendVoxel(voxel: any, voxels: {any})
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
local normals = {Enum.NormalId.Back, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Top}
local textures = {
  [0] = { -- Grass
    Top = "rbxassetid://11150954718",
    Bottom = "rbxassetid://11150955296",
    Side = "rbxassetid://11150955221",
    Side90 = "rbxassetid://11217473234",
    Side270 = "rbxassetid://11227848861",
    SideTop = "rbxassetid://11151277340",
    SideTop90 = "rbxassetid://11217473084",
    SideTop270 = "rbxassetid://11227848666",
    Slope = "rbxassetid://11150955015",
    SlopeTop = "rbxassetid://11151277242"
  },
  [1] = { -- Sand
    Top = "rbxassetid://11228950608",
    Bottom = "rbxassetid://11228952522",
    Side = "rbxassetid://11228952353",
    Side90 = "rbxassetid://11228952122",
    Side270 = "rbxassetid://11228951945",
    SideTop = "rbxassetid://11228951799",
    SideTop90 = "rbxassetid://11228951319",
    SideTop270 = "rbxassetid://11228951137",
    Slope = "rbxassetid://11228950990",
    SlopeTop = "rbxassetid://11228950824"
  },
  [2] = { -- Brick
    Top = "rbxassetid://11228986751",
    Bottom = "rbxassetid://11228988408",
    Side = "rbxassetid://11228988275",
    Side90 = "rbxassetid://11228988117",
    Side270 = "rbxassetid://11228987929",
    SideTop = "rbxassetid://11228987786",
    SideTop90 = "rbxassetid://11228987610",
    SideTop270 = "rbxassetid://11228987380",
    Slope = "rbxassetid://11228987380",
    SlopeTop = "rbxassetid://11228986931"
  },
  [3] = { -- Granite
    Top = "rbxassetid://11229013754",
    Bottom = "rbxassetid://11229015627",
    Side = "rbxassetid://11229015467",
    Side90 = "rbxassetid://11229015300",
    Side270 = "rbxassetid://11229015160",
    SideTop = "rbxassetid://11229014940",
    SideTop90 = "rbxassetid://11229014742",
    SideTop270 = "rbxassetid://11229014464",
    Slope = "rbxassetid://11229014148",
    SlopeTop = "rbxassetid://11229013937"
  },
  [4] = { -- Asphalt
    Top = "rbxassetid://11229069127",
    Bottom = "rbxassetid://11229070661",
    Side = "rbxassetid://11229070532",
    Side90 = "rbxassetid://11229070335",
    Side270 = "rbxassetid://11229070041",
    SideTop = "rbxassetid://11229069898",
    SideTop90 = "rbxassetid://11229069780",
    SideTop270 = "rbxassetid://11229069615",
    Slope = "rbxassetid://11229069427",
    SlopeTop = "rbxassetid://11229069292"
  },
  [5] = { -- Iron
    Top = "rbxassetid://11229094694",
    Bottom = "rbxassetid://11229095894",
    Side = "rbxassetid://11229095803",
    Side90 = "rbxassetid://11229095705",
    Side270 = "rbxassetid://11229095605",
    SideTop = "rbxassetid://11229095443",
    SideTop90 = "rbxassetid://11229095312",
    SideTop270 = "rbxassetid://11229095132",
    Slope = "rbxassetid://11229094909",
    SlopeTop = "rbxassetid://11229094814"
  },
  [6] = { -- Aluminum
    Top = "rbxassetid://11229473497",
    Bottom = "rbxassetid://11229474642",
    Side = "rbxassetid://11229474565",
    Side90 = "rbxassetid://11229474492",
    Side270 = "rbxassetid://11229474389",
    SideTop = "rbxassetid://11229474315",
    SideTop90 = "rbxassetid://11229474141",
    SideTop270 = "rbxassetid://11229473934",
    Slope = "rbxassetid://11229473763",
    SlopeTop = "rbxassetid://11229473623"
  },
  [7] = { -- Gold
    Top = "rbxassetid://11229490857",
    Bottom = "rbxassetid://11229492063",
    Side = "rbxassetid://11229491799",
    Side90 = "rbxassetid://11229491657",
    Side270 = "rbxassetid://11229491527",
    SideTop = "rbxassetid://11229491454",
    SideTop90 = "rbxassetid://11229491360",
    SideTop270 = "rbxassetid://11229491276",
    Slope = "rbxassetid://11229491128",
    SlopeTop = "rbxassetid://11229490998"
  },
  [8] = { -- WoodPlank
    Top = "rbxassetid://11229505497",
    Bottom = "rbxassetid://11229506701",
    Side = "rbxassetid://11229506546",
    Side90 = "rbxassetid://11229506362",
    Side270 = "rbxassetid://11229506235",
    SideTop = "rbxassetid://11229506149",
    SideTop90 = "rbxassetid://11229506015",
    SideTop270 = "rbxassetid://11229505940",
    Slope = "rbxassetid://11229505800",
    SlopeTop = "rbxassetid://11229505681"
  },
  [9] = { -- WoodLog
    Top = "rbxassetid://11229735772",
    Bottom = "rbxassetid://11229737190",
    Side = "rbxassetid://11229737078",
    Side90 = "rbxassetid://11229736954",
    Side270 = "rbxassetid://11229736826",
    SideTop = "rbxassetid://11229736584",
    SideTop90 = "rbxassetid://11229736339",
    SideTop270 = "rbxassetid://11229736207",
    Slope = "rbxassetid://11229736092",
    SlopeTop = "rbxassetid://11229735935"
  },
  [10] = { -- Gravel
    Top = "rbxassetid://11229755077",
    Bottom = "rbxassetid://11229756519",
    Side = "rbxassetid://11229756395",
    Side90 = "rbxassetid://11229756161",
    Side270 = "rbxassetid://11229756045",
    SideTop = "rbxassetid://11229755949",
    SideTop90 = "rbxassetid://11229755873",
    SideTop270 = "rbxassetid://11229755781",
    Slope = "rbxassetid://11229755454",
    SlopeTop = "rbxassetid://132894594750417"
  },
  [11] = { -- CinderBlock
    Top = "rbxassetid://11229900650",
    Bottom = "rbxassetid://11229902465",
    Side = "rbxassetid://11229902261",
    Side90 = "rbxassetid://11229902046",
    Side270 = "rbxassetid://11229901913",
    SideTop = "rbxassetid://11229900912", -- original got content deleted but slope top is identical, so we'll use that
    SideTop90 = "rbxassetid://11229901503",
    SideTop270 = "rbxassetid://11229901192",
    Slope = "rbxassetid://11229901090",
    SlopeTop = "rbxassetid://11229900912"
  },
  [12] = { -- MossyStone
    Top = "rbxassetid://11229925762",
    Bottom = "rbxassetid://11229927127",
    Side = "rbxassetid://11229926936",
    Side90 = "rbxassetid://11229926766",
    Side270 = "rbxassetid://11229926646",
    SideTop = "rbxassetid://11229926510",
    SideTop90 = "rbxassetid://11229926347",
    SideTop270 = "rbxassetid://11229926168",
    Slope = "rbxassetid://11229925989",
    SlopeTop = "rbxassetid://11229925863"
  },
  [13] = { -- Cement
    Top = "rbxassetid://15135162639",
    Bottom = "rbxassetid://15135163971",
    Side = "rbxassetid://15135163815",
    Side90 = "rbxassetid://15135163665",
    Side270 = "rbxassetid://15135163498",
    SideTop = "rbxassetid://15135163343",
    SideTop90 = "rbxassetid://15135163173",
    SideTop270 = "rbxassetid://15135163023",
    Slope = "rbxassetid://15135162905",
    SlopeTop = "rbxassetid://15135162789"
  },
  [14] = { -- RedPlastic
    Top = "rbxassetid://11230008311",
    Bottom = "rbxassetid://121476124804140",
    Side = "rbxassetid://127524203431138",
    Side90 = "rbxassetid://75579022650720",
    Side270 = "rbxassetid://101138022887512",
    SideTop = "rbxassetid://11230008452",
    SideTop90 = "rbxassetid://98401058976118",
    SideTop270 = "rbxassetid://134319060267111",
    Slope = "rbxassetid://80650776012984",
    SlopeTop = "rbxassetid://135185272031647"
  },
  [15] = { -- BluePlastic
    Top = "rbxassetid://121191178544933",
    Bottom = "rbxassetid://137711320455303",
    Side = "rbxassetid://111863168243989",
    Side90 = "rbxassetid://73223131790627",
    Side270 = "rbxassetid://108057622031851",
    SideTop = "rbxassetid://119917720586806",
    SideTop90 = "rbxassetid://79343196909232",
    SideTop270 = "rbxassetid://81634603714667",
    Slope = "rbxassetid://105306404781891",
    SlopeTop = "rbxassetid://105513373464367"
  }
}

type Surround = {
  IsTop: boolean,
  Bottom: boolean,
  Left: boolean,
  Right: boolean,
  Back: boolean,
  Front: boolean
}

local function FixSolidVertNormal(normal)
  -- idk why left and right are flipped
  if normal == Enum.NormalId.Left then
    return Enum.NormalId.Right
  elseif normal == Enum.NormalId.Right then
    return Enum.NormalId.Left
  else
    return normal
  end
end

local horizontalWedgeNormalFaceMap = {
  [Enum.NormalId.Back] = Enum.NormalId.Back,
  [Enum.NormalId.Front] = Enum.NormalId.Front,
  [Enum.NormalId.Bottom] = Enum.NormalId.Right,
  [Enum.NormalId.Top] = Enum.NormalId.Left,
  [Enum.NormalId.Right] = Enum.NormalId.Bottom,
  [Enum.NormalId.Left] = Enum.NormalId.Top,
}

local function SetUpTextures(part: BasePart, surround: Surround, cellType: number, cellMat: number)
  local texs = textures[cellMat]
    
  if texs == nil then
    error("unknown material id " .. cellMat)
  end

  local function ApplyInverseCornerWedgeSlopeTexture()
    local slope = part:FindFirstChild("Slope") :: BasePart
    local normal = Enum.NormalId.Right
    local face = normal

    local xUV = (part.Position.Z - (part.Size.Z / 2)) / 4
    local yUV = (part.Position.Y + (part.Size.Y / 2)) / 4

    -- Slope of inverse corner wedge
    if surround.IsTop then
      -- Solid side (vertical, top)
      local tex = Instance.new("Texture")
      tex.Name = "Tex" .. normal.Name
      tex.Texture = texs.SlopeTop
      tex.Face = FixSolidVertNormal(face)
      tex.StudsPerTileU = 8 -- 2x1 tiles per tex, 4 studs per tile
      tex.StudsPerTileV = 48 / 8
      tex.OffsetStudsU = 4 * (xUV % 2)
      tex.OffsetStudsV = 1 -- move passed the 8 pixel border for bilinear filtering on wrapped edges

      if cellType == 2 or cellType == 3 then
        tex.OffsetStudsU = tex.OffsetStudsU + 2
        tex.OffsetStudsV = tex.OffsetStudsV + 2
      end

      tex.Parent = slope
    else
      -- Solid side (vertical)
      local tex = Instance.new("Texture")
      tex.Name = "Tex" .. normal.Name
      tex.Texture = texs.Slope
      tex.Face = FixSolidVertNormal(face)
      tex.StudsPerTileU = 8 -- 2x4 tiles per tex, 4 studs per tile
      tex.StudsPerTileV = 16
      tex.OffsetStudsU = 4 * (xUV % 2)
      tex.OffsetStudsV = 4 * (yUV % 4)

      if cellType == 2 or cellType == 3 then
        tex.OffsetStudsU = tex.OffsetStudsU + 2
        tex.OffsetStudsV = tex.OffsetStudsV + 2
      end

      tex.Parent = slope
    end
  end
  
  local function ApplyTexture(normal)
    local face = normal

    if cellType == 4 then
      face = horizontalWedgeNormalFaceMap[normal]
    end

    if normal == Enum.NormalId.Top and surround.IsTop then
      local xUV = (part.Position.X + (part.Size.X / 2)) / 4
      local yUV = (part.Position.Z + (part.Size.Z / 2)) / 4

      if cellType ~= 1 and cellType ~= 2 then
        local tex = Instance.new("Texture")
        tex.Name = "Tex" .. normal.Name
        tex.Texture = texs.Top
        tex.Face = face
        tex.StudsPerTileU = 16 -- 4x4 tiles per tex, 4 studs per tile
        tex.StudsPerTileV = 16
        tex.OffsetStudsU = 4 * (-xUV % 4)
        tex.OffsetStudsV = 4 * (-yUV % 4)

        if cellType == 3 then
          tex.OffsetStudsU = tex.OffsetStudsU + 2
          tex.OffsetStudsV = tex.OffsetStudsV + 2
        end

        tex.Parent = part
      end
    elseif (normal == Enum.NormalId.Front and (not surround.Back)) 
        or (normal == Enum.NormalId.Back and (not surround.Front))
        or (normal == Enum.NormalId.Left and (not surround.Right))
        or (normal == Enum.NormalId.Right and (not surround.Left))
    then
      local xUV, yUV

      if normal == Enum.NormalId.Left then
        xUV = (part.Position.Z + (part.Size.Z / 2)) / 4
        yUV = (part.Position.Y + (part.Size.Y / 2)) / 4
      elseif normal == Enum.NormalId.Right then
        xUV = (part.Position.Z - (part.Size.Z / 2)) / 4
        yUV = (part.Position.Y + (part.Size.Y / 2)) / 4
      elseif normal == Enum.NormalId.Back then
        xUV = (part.Position.X - (part.Size.X / 2)) / 4
        yUV = (part.Position.Y + (part.Size.Y / 2)) / 4
      else -- Front
        xUV = (part.Position.X + (part.Size.X / 2)) / 4
        yUV = (part.Position.Y + (part.Size.Y / 2)) / 4
      end

      if (normal == Enum.NormalId.Front and cellType == 1) or
         (normal == Enum.NormalId.Right and cellType == 2)
      then
        -- Front of VerticalWedge, CornerWedge
        -- Use slope textures
        if surround.IsTop then
          -- Solid side (vertical, top)
          local tex = Instance.new("Texture")
          tex.Name = "Tex" .. normal.Name
          tex.Texture = texs.SlopeTop
          tex.Face = FixSolidVertNormal(face)
          tex.StudsPerTileU = 8 -- 2x1 tiles per tex, 4 studs per tile
          tex.StudsPerTileV = 48 / 8
          tex.OffsetStudsU = 4 * (xUV % 2)
          tex.OffsetStudsV = 1 -- move passed the 8 pixel border for bilinear filtering on wrapped edges

          if cellType == 2 or cellType == 3 then
            tex.OffsetStudsU = tex.OffsetStudsU + 2
            tex.OffsetStudsV = tex.OffsetStudsV + 2
          end

          tex.Parent = part
        else
          -- Solid side (vertical)
          local tex = Instance.new("Texture")
          tex.Name = "Tex" .. normal.Name
          tex.Texture = texs.Slope
          tex.Face = FixSolidVertNormal(face)
          tex.StudsPerTileU = 8 -- 2x4 tiles per tex, 4 studs per tile
          tex.StudsPerTileV = 16
          tex.OffsetStudsU = 4 * (xUV % 2)
          tex.OffsetStudsV = 4 * (yUV % 4)

          if cellType == 2 or cellType == 3 then
            tex.OffsetStudsU = tex.OffsetStudsU + 2
            tex.OffsetStudsV = tex.OffsetStudsV + 2
          end

          tex.Parent = part
        end
      elseif cellType ~= 2 or normal ~= Enum.NormalId.Back then -- Corner wedges don't need a back texture
        -- Use side textures
        if cellType == 4 then
          if face ~= Enum.NormalId.Front then
            -- HorizontalWedges are a special case since they're rotated 90 on their side
            if surround.IsTop then
              -- Solid side (vertical, top)
              local tex = Instance.new("Texture")
              if face == Enum.NormalId.Top then
                tex.Texture = texs.SideTop90
              else
                tex.Texture = texs.SideTop270
              end
              tex.Name = "Tex" .. normal.Name
              tex.Face = FixSolidVertNormal(face)
              tex.StudsPerTileU = 48 / 8 -- 1x2 tiles per tex, 4 studs per tile
              tex.StudsPerTileV = 8
              tex.OffsetStudsU = 1 -- move passed the 8 pixel border for bilinear filtering on wrapped edges
              tex.OffsetStudsV = 4 * (yUV % 2)
              tex.Parent = part
            else
              -- Solid side (vertical)
              local tex = Instance.new("Texture")
              if face == Enum.NormalId.Top then
                tex.Texture = texs.Side90
              else
                tex.Texture = texs.Side270
              end
              tex.Name = "Tex" .. normal.Name
              tex.Face = FixSolidVertNormal(face)
              tex.StudsPerTileU = 16 -- 4x2 tiles per tex, 4 studs per tile
              tex.StudsPerTileV = 8
              tex.OffsetStudsU = 4 * (yUV % 4)
              tex.OffsetStudsV = 4 * (xUV % 2)
              tex.Parent = part
            end
          end
        else
          if surround.IsTop then
            -- Solid side (vertical, top)
            local tex = Instance.new("Texture")
            tex.Name = "Tex" .. normal.Name
            tex.Texture = texs.SideTop
            tex.Face = FixSolidVertNormal(face)
            tex.StudsPerTileU = 8 -- 2x1 tiles per tex, 4 studs per tile
            tex.StudsPerTileV = 48 / 8
            tex.OffsetStudsU = 4 * (xUV % 2)
            tex.OffsetStudsV = 1 -- move passed the 8 pixel border for bilinear filtering on wrapped edges

            if cellType == 2 or cellType == 3 then
              tex.OffsetStudsU = tex.OffsetStudsU + 2
              tex.OffsetStudsV = tex.OffsetStudsV + 2
            end

            tex.Parent = part
          else
            -- Solid side (vertical)
            local tex = Instance.new("Texture")
            tex.Name = "Tex" .. normal.Name
            tex.Texture = texs.Side
            tex.Face = FixSolidVertNormal(face)
            tex.StudsPerTileU = 8 -- 2x4 tiles per tex, 4 studs per tile
            tex.StudsPerTileV = 16
            tex.OffsetStudsU = 4 * (xUV % 2)
            tex.OffsetStudsV = 4 * (yUV % 4)

            if cellType == 2 or cellType == 3 then
              tex.OffsetStudsU = tex.OffsetStudsU + 2
              tex.OffsetStudsV = tex.OffsetStudsV + 2
            end

            tex.Parent = part
          end
        end

      end
    elseif normal == Enum.NormalId.Bottom and (not surround.Bottom) then
      local xUV = (part.Position.X + (part.Size.X / 2)) / 4
      local yUV = (part.Position.Z + (part.Size.Z / 2)) / 4

      local tex = Instance.new("Texture")
      tex.Name = "Tex" .. normal.Name
      tex.Texture = texs.Bottom
      tex.Face = face
      tex.StudsPerTileU = 8 -- 2x2 tiles per tex, 4 studs per tile
      tex.StudsPerTileV = 8
      tex.OffsetStudsU = 4 * (-xUV % 2)
      tex.OffsetStudsV = 4 * (-yUV % 2)

      tex.Parent = part
    end
  end

  for _, normal in ipairs(normals) do
    ApplyTexture(normal)
  end

  if cellType == 3 then
    ApplyInverseCornerWedgeSlopeTexture()
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

local cornerWedgeTemplate = assetsFolder:FindFirstChild("CornerWedge") :: BasePart?
local inverseCornerWedgeTemplate = assetsFolder:FindFirstChild("InverseCornerWedge") :: BasePart?
if cornerWedgeTemplate == nil then
  error("LegacyTerrainAssets is missing the child CornerWedge.", 0)
end
if inverseCornerWedgeTemplate == nil then
  error("LegacyTerrainAssets is missing the child InverseCornerWedge.", 0)
end

local function MakePart(voxel: any): BasePart | nil
  local x = voxel.X * 4 + 2
  local y = voxel.Y * 4 + 2
  local z = voxel.Z * 4 + 2
  local cellMat = voxel.Mat
  local cellType = voxel.Type
  local cellOrientation = voxel.Orientation
  local surround = voxel.Surround
  local extents = voxel.Extents

  local p: BasePart
  local baseRotationY = 0
  local baseRotationZ = 0

  if cellType == 0 then
    p = Instance.new("Part")
    baseRotationY = 0
    cellOrientation = 0 -- HACK: we dont support rotated solids
  elseif cellType == 1 or cellType == 4 then
    p = Instance.new("WedgePart")
    baseRotationY = 180

    if cellType == 4 then
      baseRotationZ = -90
    end
  elseif cellType == 2 then
    p = cornerWedgeTemplate:Clone()
  elseif cellType == 3 then
    p = inverseCornerWedgeTemplate:Clone()
  end

  p.Name = "Cell" .. tostring(cellOrientation)
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
    if cellType == 1 and (cellOrientation == 1 or cellOrientation == 3) then
      p.Size = Vector3.new(4 * zs, 4 * ys, 4 * xs)
    elseif cellType == 4 then
      p.Size = Vector3.new(4 * ys, 4 * xs, 4 * zs)
    else
      p.Size = Vector3.new(4 * xs, 4 * ys, 4 * zs)
    end
  else
    p.CFrame = CFrame.new(x, y, z)
    p.Size = Vector3.new(4, 4, 4)
  end

  p.Orientation = Vector3.new(0, baseRotationY + (cellOrientation * 90), baseRotationZ)

  if cellType == 3 then
    local slope = p:FindFirstChild("Slope") :: BasePart
    slope.CFrame = p.CFrame
    slope.Size = p.Size
  end

  SetUpTextures(p, surround, cellType, cellMat)

  return p
end

local voxels: any = {} -- 3d array
local queue: any = {}

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
