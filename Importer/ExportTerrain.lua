--[[
  EXPORT TERRAIN

  A script to be ran in an old version of studio (preferably ~2014) that will
  export marked areas of classic terrain into a folder of ModuleScripts that
  can then be pasted into modern studio and imported.

  HOW TO RUN:
  - Create a Folder in Workspace named whatever you'd like. This will designate
    the areas of terrain you want to export.
  - In the folder, add Parts named KeepArea. These must be positioned and sized
    to cover any voxels that should be exported. Voxels not inside a KeepArea
    will be ignored.
  - When you're ready to export, select the folder and then run this script by
    clicking the Test -> Run Script button in the studio ribbonbar. Tip: this
    script can take a while, open the Output window to view its progress.
  - When complete, you will see a Voxels folder inside the terrain folder. See
    the ImportTerrain script for what to do with this.

  TIPS FOR AVOIDING STUDIO FREEZING/CRASHING:
  - Never use the move/resize tools on a KeepArea while it's touching/inside of
    terrain. This WILL horribly freeze studio once the part is a decent size
    and touches a lot of voxels.
  - For the same reason as above, never set the Size property of a KeepArea while
    it's inside of the terrain. Setting the Position property is OK.
  - Resize KeepAreas above the terrain out in the open and then set the Position.Y
    property in the Properties window directly to move it down into the terrain.
    Be sure to use the Position.Y property again to move it out of the terrain
    before resizing the area again!
  - Don't modify areas of terrain touching KeepAreas, this will lag about as much
    moving the KeepAreas around.
  - Use the command bar to move terrain folders out of workspace and into something
    else like Lighting when you need to edit the actual terrain. Dragging the folder
    will cause all of the areas to pop out of the terrain, you have to script it.
  - Avoid saving the place file with a generated Voxels folder. This can massively
    increase the file size of the place and may prevent studio from loading it in
    the future (backups are your friend!).
--]]

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Preparation
local terrainFolder = game:GetService("Selection"):Get()[1]

if terrainFolder == nil then
  error("A terrain folder must be selected to run this script.", 0)
end

-- Precalculate boundaries of all KeepAreas
print("Preparing...")

local bounds = {}

for i, part in ipairs(terrainFolder:GetChildren()) do
  if part.Name == "KeepArea" then
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
    
    table.insert(bounds, bound)
  end
end

print("Found " .. tostring(#bounds) .. " KeepArea parts")

-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- 
-- MARK: Looping
local terrain = workspace.Terrain

local checkedVoxels = {}

-- Whether a non-empty/non-water voxel exists at the coordinates with the given
-- cell type and orientation
local function IsVoxelAt(x, y, z, type, orientation)
  local cellMat, cellType, cellOrientation = terrain:GetCell(x, y, z)
  
  if cellMat == Enum.CellMaterial.Empty or cellMat == Enum.CellMaterial.Water then
    return false
  end
  
  if cellType ~= type then
    return false
  end
  
  if orientation ~= nil and cellOrientation ~= orientation then
    return false
  end
  
  return true	
end

-- Whether the voxel at the coordinates should be culled
local function IsCulled(x, y, z)
  return IsVoxelAt(x - 1, y, z, Enum.CellBlock.Solid) 
    and IsVoxelAt(x + 1, y, z, Enum.CellBlock.Solid)
    and IsVoxelAt(x, y - 1, z, Enum.CellBlock.Solid) 
    and IsVoxelAt(x, y + 1, z, Enum.CellBlock.Solid) 
    and IsVoxelAt(x, y, z - 1, Enum.CellBlock.Solid) 
    and IsVoxelAt(x, y, z + 1, Enum.CellBlock.Solid) 
end

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

-- Util to map enums to their indices
local function MakeMap(enums)
  local tbl = {}

  for i, enum in ipairs(enums) do
    tbl[enum] = i
  end		
  
  return tbl
end

-- Set up maps to convert enums to numbers
--
-- These enums doesn't exist the same way in newer versions of Roblox, so
-- we can only send them over as integers and not as the actual enum type
local cellMats = MakeMap(Enum.CellMaterial:GetEnumItems())
local cellBlocks = MakeMap(Enum.CellBlock:GetEnumItems())
local cellOrientations = MakeMap(Enum.CellOrientation:GetEnumItems())

-- Loop through all bounds and export voxels into scripts
print("Looping...")
wait()

local scripts = {}
local lines = {}
table.insert(scripts, lines)

local count = 0

for i, bound in ipairs(bounds) do
  -- Sanity checks
  if bound.right < bound.left then error("bound.right is bigger than left!") end
  if bound.top < bound.bottom then error("bound.top is bigger than bottom!") end
  if bound.front < bound.back then error("bound.front is bigger than back!") end
  
  -- Loop all voxels in bound
  for x = bound.left, bound.right do
    for y = bound.bottom, bound.top do
      for z = bound.back, bound.front do
        local cellMat, cellType, cellOrientation = terrain:GetCell(x, y, z)
        local cull = false
        
        -- Skip empty and already exported voxels
        if cellMat ~= Enum.CellMaterial.Empty and DeDupeVoxel(x, y, z) then
          -- Determine voxel side culling
          local isNotTop = true
          local solidBottom = false
          local solidLeft = false
          local solidRight = false
          local solidBack = false
          local solidFront = false
          if cellType == Enum.CellBlock.Solid then
            -- Solid
            cull = IsCulled(x, y, z)

            if not cull then
              isNotTop = IsVoxelAt(x, y + 1, z, Enum.CellBlock.Solid)
              solidBottom = IsVoxelAt(x, y - 1, z, Enum.CellBlock.Solid)
              solidLeft = IsVoxelAt(x - 1, y, z, Enum.CellBlock.Solid)
              solidRight = IsVoxelAt(x + 1, y, z, Enum.CellBlock.Solid)
              solidBack = IsVoxelAt(x, y, z + 1, Enum.CellBlock.Solid)
              solidFront = IsVoxelAt(x, y, z - 1, Enum.CellBlock.Solid)
            end
          elseif cellType == Enum.CellBlock.VerticalWedge then
            -- VerticalWedge
            if cellOrientation == Enum.CellOrientation.NegZ then
              isNotTop = IsVoxelAt(x, y + 1, z - 1, Enum.CellBlock.VerticalWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.X then
              isNotTop = IsVoxelAt(x + 1, y + 1, z, Enum.CellBlock.VerticalWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.Z then
              isNotTop = IsVoxelAt(x, y + 1, z + 1, Enum.CellBlock.VerticalWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.NegX then
              isNotTop = IsVoxelAt(x - 1, y + 1, z, Enum.CellBlock.VerticalWedge, cellOrientation)
            end
          elseif cellType == Enum.CellBlock.HorizontalWedge then
            -- HorizontalWedge
            isNotTop = IsVoxelAt(x, y + 1, z, Enum.CellBlock.HorizontalWedge, cellOrientation)
          elseif cellType == Enum.CellBlock.CornerWedge then
            -- CornerWedge
            if cellOrientation == Enum.CellOrientation.NegZ then
              isNotTop = IsVoxelAt(x + 1, y + 1, z - 1, Enum.CellBlock.InverseCornerWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.X then
              isNotTop = IsVoxelAt(x + 1, y + 1, z - 1, Enum.CellBlock.InverseCornerWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.Z then
              isNotTop = IsVoxelAt(x - 1, y + 1, z + 1, Enum.CellBlock.InverseCornerWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.NegX then
              isNotTop = IsVoxelAt(x - 1, y + 1, z + 1, Enum.CellBlock.InverseCornerWedge, cellOrientation)
            end
          elseif cellType == Enum.CellBlock.InverseCornerWedge then
            -- InverseCornerWedge
            if cellOrientation == Enum.CellOrientation.NegZ then
              isNotTop = IsVoxelAt(x + 1, y + 1, z - 1, Enum.CellBlock.CornerWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.X then
              isNotTop = IsVoxelAt(x + 1, y + 1, z - 1, Enum.CellBlock.CornerWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.Z then
              isNotTop = IsVoxelAt(x - 1, y + 1, z + 1, Enum.CellBlock.CornerWedge, cellOrientation)
            elseif cellOrientation == Enum.CellOrientation.NegX then
              isNotTop = IsVoxelAt(x - 1, y + 1, z + 1, Enum.CellBlock.CornerWedge, cellOrientation)
            end
          end
          
          -- Skip if the whole voxel was determined to be culled
          if not cull then
            -- Add voxel to script source
            local isTop
            if isNotTop then isTop = 0 else isTop = 1 end
            
            local surroundBits
            if cellType == Enum.CellBlock.Solid then
              if solidBottom then solidBottom = 1 else solidBottom = 0 end
              if solidLeft then solidLeft = 1 else solidLeft = 0 end
              if solidRight then solidRight = 1 else solidRight = 0 end
              if solidBack then solidBack = 1 else solidBack = 0 end
              if solidFront then solidFront = 1 else solidFront = 0 end
            
              surroundBits = "\"" 
                .. tostring(isTop) 
                .. tostring(solidBottom) 
                .. tostring(solidLeft) 
                .. tostring(solidRight) 
                .. tostring(solidBack) 
                .. tostring(solidFront) 
                .. "\""
            else
              surroundBits = tostring(isTop)
            end 							
            
            local str = "{" ..
              tostring(x) .. "," .. tostring(y) .. "," .. tostring(z) .. "," ..
              tostring(cellMats[cellMat]) .. "," .. 
              tostring(cellBlocks[cellType]) .. ","  ..
              tostring(cellOrientations[cellOrientation]) .. "," ..
              surroundBits ..
              "}\n"
            
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

f.Parent = terrainFolder

print("Done!")
