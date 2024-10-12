while game == nil do
	wait(1/30)
end

---------------
--PLUGIN SETUP-
---------------
loaded = false
-- True if the plugin is on, false if not.
on = false

local UserInputService = game:GetService("UserInputService")
local inputBeganConnection = nil

plugin = PluginManager():CreatePlugin()
mouse = plugin:GetMouse()
mouse.Button1Down:connect(function() onClicked(mouse) end)
mouse.Button1Up:connect(function() onClickedUp(mouse) end)
toolbar = plugin:CreateToolbar("Terrain")
toolbarbutton = toolbar:CreateButton("Builder+", "Builder+", "builder.png")
toolbarbutton.Click:connect(function()
	if on then
		Off()
	elseif loaded then
		On()
	end
end)

game:WaitForChild("Workspace")
game.Workspace:WaitForChild("Terrain")

local c = game.Workspace.Terrain
local SetCell = c.SetCell
local SetCells = c.SetCells
local GetCell = c.GetCell
local WorldToCellPreferSolid = c.WorldToCellPreferSolid
local CellCenterToWorld = c.CellCenterToWorld
local AutoWedge = c.AutowedgeCells
local WorldToCellPreferEmpty = c.WorldToCellPreferEmpty
local GetWaterCell = c.GetWaterCell
local SetWaterCell = c.SetWaterCell

local cellOrientations = {
	"-Z",
	"+X",
	"+Z",
	"-X"
}

local cellTypes = {
	"Solid",
	"Vertical Wedge",
	"Corner Wedge",
	"Inverse Corner Wedge",
	"Horizontal Wedge"
}

-----------------
--DEFAULT VALUES-
-----------------

local cellOrientation = 0
local cellType = 0

-- Stores selection properties.
selectionProps = {}
selectionProps.isWater = nil				-- True if what will be built is water.
selectionProps.waterForce = nil				-- Water force.
selectionProps.waterDirection = nil			-- Water direction.
selectionProps.terrainMaterial = 0			-- Terrain material to use
selectionProps.startPos = nil

-- What color to use for the mouse highlighter.
mouseHighlightColor = BrickColor.new("Lime green")

-- Used to create a highlighter that follows the mouse.
-- It is a class mouse highlighter.  To use, call MouseHighlighter.Create(mouse) where mouse is the mouse to track.
MouseHighlighter = {}
MouseHighlighter.__index = MouseHighlighter

-- Create a mouse movement highlighter.
-- plugin - Plugin to get the mouse from.
function MouseHighlighter.Create(mouseUse)
	local highlighter = {}
	
	local mouse = mouseUse
	highlighter.OnClicked = nil
	highlighter.mouseDown = false
	
	-- Store the last point used to draw.
	highlighter.lastUsedPoint = nil
	
	-- Will hold a part the highlighter will be attached to.  This will be moved where the mouse is.
	highlighter.selectionPart = nil

	-- Hook the mouse up to check for movement.
	mouse.Move:connect(function() MouseMoved() end)	
	
	mouse.Button1Down:connect(function() highlighter.mouseDown = true end)
	mouse.Button1Up:connect(function() highlighter.mouseDown = false
                                      end)
	
	
	-- Create the part that the highlighter will be attached to.
	highlighter.selectionPart = Instance.new("Part")
	highlighter.selectionPart.Name = "SelectionPart"
	highlighter.selectionPart.Archivable = false
	highlighter.selectionPart.Transparency = 1
	highlighter.selectionPart.Anchored = true
	highlighter.selectionPart.Locked = true
	highlighter.selectionPart.CanCollide = false
	highlighter.selectionPart.FormFactor = Enum.FormFactor.Custom

	highlighter.selectionBox = Instance.new("SelectionBox")
	highlighter.selectionBox.Archivable = false
	highlighter.selectionBox.Color = mouseHighlightColor
	highlighter.selectionBox.Adornee = highlighter.selectionPart
	mouse.TargetFilter = highlighter.selectionPart	
	setmetatable(highlighter, MouseHighlighter)

	-- Function to call when the mouse has moved.  Updates where to display the highlighter.
	function MouseMoved()
		if on then
			UpdatePosition(mouse.Hit)
		end
	end
	
	-- Do a line/plane intersection.  The line starts at the camera.  The plane is at y == 0, normal(0, 1, 0)
	--
	-- vectorPos - End point of the line.
	-- 
	-- Return:
	-- success - Value is true if there was a plane intersection, false if not.
	-- cellPos - Value is the terrain cell intersection point if there is one, vectorPos if there isn't.
	function PlaneIntersection(vectorPos)
		local currCamera = game.Workspace.CurrentCamera
		local startPos = Vector3.new(currCamera.CoordinateFrame.p.X, currCamera.CoordinateFrame.p.Y, currCamera.CoordinateFrame.p.Z)
		local endPos = Vector3.new(vectorPos.X, vectorPos.Y, vectorPos.Z)
		local normal = Vector3.new(0, 1, 0)
		local p3 = Vector3.new(0, 0, 0)
		local startEndDot = normal:Dot(endPos - startPos)
		local cellPos = vectorPos
		local success = false
		
		if startEndDot ~= 0  then
			local t = normal:Dot(p3 - startPos) / startEndDot
			if(t >=0 and t <=1) then
				local intersection = ((endPos - startPos) * t) + startPos
				cellPos = c:WorldToCell(intersection)
				success = true
			end
		end

		return success, cellPos
	end

	-- Update where the highlighter is displayed.
	-- position - Where to display the highlighter, in world space.
	function UpdatePosition(position)
		if not position then 
			return 
		end
		
		-- NOTE:
		-- Change this gui to be the one you want to use.
		highlighter.selectionBox.Parent = game:GetService("CoreGui")
		
		local vectorPos = Vector3.new(position.x,position.y,position.z)
		local cellPos = WorldToCellPreferEmpty(c, vectorPos)
		local solidCell = WorldToCellPreferSolid(c, vectorPos)
		local success = false
		
		-- If nothing was hit, do the plane intersection.
		if 0 == GetCell(c, solidCell.X, solidCell.Y, solidCell.Z).Value then
			success, cellPos = PlaneIntersection(vectorPos)
			if not success then
				cellPos = solidCell
			end
		else
			highlighter.lastUsedPoint = cellPos
		end		
		
		local regionToSelect = nil

		local lowVec = CellCenterToWorld(c, cellPos.x , cellPos.y - 1, cellPos.z)
		local highVec = CellCenterToWorld(c, cellPos.x, cellPos.y + 1, cellPos.z)

		if selectionProps.startPos ~= nil then
			local lowVec2 = CellCenterToWorld(c, selectionProps.startPos.X, selectionProps.startPos.Y - 1, selectionProps.startPos.Z)
			local highVec2 = CellCenterToWorld(c, selectionProps.startPos.X, selectionProps.startPos.Y + 1, selectionProps.startPos.Z)

			lowVec = Vector3.new(
				math.min(lowVec.X, lowVec2.X),
				math.min(lowVec.Y, lowVec2.Y),
				math.min(lowVec.Z, lowVec2.Z)
			)

			highVec = Vector3.new(
				math.max(highVec.X, highVec2.X),
				math.max(highVec.Y, highVec2.Y),
				math.max(highVec.Z, highVec2.Z)
			)
		end
		
		regionToSelect = Region3.new(lowVec, highVec)

		highlighter.selectionPart.Size = regionToSelect.Size - Vector3.new(-4, 4, -4)
		highlighter.selectionPart.CFrame = regionToSelect.CFrame
		
		if nil ~= highlighter.OnClicked and highlighter.mouseDown then
			if nil == highlighter.lastUsedPoint then 
				highlighter.lastUsedPoint = WorldToCellPreferEmpty(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
			else
				cellPos = WorldToCellPreferEmpty(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
			end
		end		
	end	
	
	return highlighter
end

-- Hide the highlighter.
function MouseHighlighter:DisablePreview()
	self.selectionBox.Parent = nil
end

-- Show the highlighter.
function MouseHighlighter:EnablePreview()
	self.selectionBox.Parent = game:GetService("CoreGui") -- This will make it not show up in workspace.
end	

-- Create the mouse movement highlighter.
mouseHighlighter = MouseHighlighter.Create(mouse)
mouseHighlighter:DisablePreview()

-- Create a standard text label.  Use this for all lables in the popup so it is easy to standardize.
-- labelName - What to set the text label name as.
-- pos    	 - Where to position the label.  Should be of type UDim2.
-- size   	 - How large to make the label.	 Should be of type UDim2.
-- text   	 - Text to display.
-- parent 	 - What to set the text parent as.
-- Return:
-- Value is the created label.
function CreateStandardLabel(labelName,
                             pos,
							 size,
							 text,
							 parent)
	local label = Instance.new("TextLabel", parent)
	label.Name = labelName
	label.Position = pos
	label.Size = size
	label.Text = text
	label.TextColor3 = Color3.new(0.95, 0.95, 0.95)
	label.Font = Enum.Font.ArialBold
	label.FontSize = Enum.FontSize.Size14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.BackgroundTransparency = 1	
	label.Parent = parent	
	
	return label
end

------
--GUI-
------
--screengui
g = Instance.new("ScreenGui", game:GetService("CoreGui"))
g.Name = 'BuilderGui'

-- UI gui load.  Required for sliders.
local RbxGui = LoadLibrary("RbxGui")

-- Store properties here.
local properties = {autoWedgeEnabled = false}

-- Gui frame for the plugin.
builderPropertiesDragBar, builderFrame, builderHelpFrame, builderCloseEvent = RbxGui.CreatePluginFrame("Builder+",UDim2.new(0,123,0,60),UDim2.new(0,0,0,0),false,g)
builderPropertiesDragBar.Visible = false
builderCloseEvent.Event:connect(function (  )
	Off()
end)


builderHelpFrame.Size = UDim2.new(0,160,0,105)

local builderHelpText = Instance.new("TextLabel",builderHelpFrame)
builderHelpText.Name = "HelpText"
builderHelpText.Font = Enum.Font.ArialBold
builderHelpText.FontSize = Enum.FontSize.Size12
builderHelpText.TextColor3 = Color3.new(227/255,227/255,227/255)
builderHelpText.TextXAlignment = Enum.TextXAlignment.Left
builderHelpText.TextYAlignment = Enum.TextYAlignment.Top
builderHelpText.Position = UDim2.new(0,4,0,4)
builderHelpText.Size = UDim2.new(1,-8,0,177)
builderHelpText.BackgroundTransparency = 1
builderHelpText.TextWrap = true
builderHelpText.Text = [[
Clicking terrain adds a single block into the selection box shown. The terrain material and type will be the same as the cell that was clicked on.
Press R to cycle the block orientation and T to change the block type.
]]

local orientationText = Instance.new("TextLabel", builderFrame)
orientationText.Name = "Orientation"
orientationText.Font = Enum.Font.ArialBold
orientationText.FontSize = Enum.FontSize.Size12
orientationText.TextColor3 = Color3.new(227/255,227/255,227/255)
orientationText.TextXAlignment = Enum.TextXAlignment.Left
orientationText.TextYAlignment = Enum.TextYAlignment.Top
orientationText.Position = UDim2.new(0,4,0,40)
orientationText.Size = UDim2.new(1,-8,0,177)
orientationText.BackgroundTransparency = 1
orientationText.Text = cellOrientations[cellOrientation + 1]

local typeText = Instance.new("TextLabel", builderFrame)
typeText.Name = "Type"
typeText.Font = Enum.Font.ArialBold
typeText.FontSize = Enum.FontSize.Size12
typeText.TextColor3 = Color3.new(227/255,227/255,227/255)
typeText.TextXAlignment = Enum.TextXAlignment.Right
typeText.TextYAlignment = Enum.TextYAlignment.Top
typeText.Position = UDim2.new(0,-4,0,40)
typeText.Size = UDim2.new(1,-8,0,177)
typeText.BackgroundTransparency = 1
typeText.Text = cellTypes[cellType + 1]

addText = CreateStandardLabel("AddText", UDim2.new(0, 8, 0, 10), UDim2.new(0, 67, 0, 14), "Click to add terrain.", builderFrame)

function onClickedUp(mouse)
	if on then
		local cellPos = WorldToCellPreferEmpty(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local x = cellPos.x
		local y = cellPos.y 
		local z = cellPos.z

		local solidCellPos = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))

		local celMat = GetCell(c, solidCellPos.x, solidCellPos.y, solidCellPos.z)
		local success = false
		
		if celMat.Value == 0 then 
			success, cellPos = PlaneIntersection(Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
			if not success then
				cellPos = solidCellPos
			end
			
			x = cellPos.x
			y = cellPos.y
			z = cellPos.z			
		end

		local minX = math.min(selectionProps.startPos.X, x)
		local minY = math.min(selectionProps.startPos.Y, y)
		local minZ = math.min(selectionProps.startPos.Z, z)

		local maxX = math.max(selectionProps.startPos.X, x)
		local maxY = math.max(selectionProps.startPos.Y, y)
		local maxZ = math.max(selectionProps.startPos.Z, z)

		local lowVec = Vector3int16.new(minX, minY, minZ)
		local highVec = Vector3int16.new(maxX, maxY, maxZ)
		local regionToFill = Region3int16.new(lowVec, highVec)

		if selectionProps.isWater and 17 == selectionProps.terrainMaterial then
			SetCells(c, regionToFill, selectionProps.terrainMaterial, selectionProps.waterForce, selectionProps.waterDirection)
		else
			local orientation = cellOrientation
			if cellType == 0 then
				orientation = 0 -- dont rotate solids
			end
			SetCells(c, regionToFill, selectionProps.terrainMaterial, cellType, orientation)
		end

		if properties.autoWedgeEnabled then
			AutoWedge(c, regionToFill)
		end

		-- for _x=minX,maxX do
		-- 	for _y=minY,maxY do
		-- 		for _z=minZ,maxZ do
		-- 			if selectionProps.isWater and 17 == selectionProps.terrainMaterial then
		-- 				SetWaterCell(c, _x, _y, _z, selectionProps.waterForce, selectionProps.waterDirection)
		-- 			else
		-- 				SetCell(c, _x, _y, _z, selectionProps.terrainMaterial, cellType, cellOrientation)
		-- 			end
					
		-- 			if properties.autoWedgeEnabled then
		-- 				AutoWedge(c, Region3int16.new(Vector3int16.new(x - 1, y - 1, z - 1), Vector3int16.new(x + 1, y + 1, z + 1)))	
		-- 			end
		-- 		end
		-- 	end
		-- end
		
		-- Mark undo point.
		game:GetService("ChangeHistoryService"):SetWaypoint("Builder+")

		selectionProps.startPos = nil
	
		UpdatePosition(mouse.Hit)
	end
end

-- Function to connect to the mouse button 1 down event.  This is what will run when the user clicks.
-- Adding and autowedging done here.
-- mouse 	- Mouse data.
function onClicked(mouse)
	if on then		
		local cellPos = WorldToCellPreferEmpty(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
		local x = cellPos.x
		local y = cellPos.y 
		local z = cellPos.z

		local solidCellPos = WorldToCellPreferSolid(c, Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))

		local celMat = GetCell(c, solidCellPos.x, solidCellPos.y, solidCellPos.z)
		local success = false
		
		if celMat.Value > 0 then 
			selectionProps.terrainMaterial = celMat.Value 
			selectionProps.isWater, selectionProps.waterForce, selectionProps.waterDirection = GetWaterCell(c, solidCellPos.X, solidCellPos.Y, solidCellPos.Z)					
		else
			if 0 == selectionProps.terrainMaterial then
				-- It was nothing, give it a default type and the plane intersection. 
				selectionProps.isWater = false
				selectionProps.terrainMaterial = 1
			end
			
			success, cellPos = PlaneIntersection(Vector3.new(mouse.Hit.x, mouse.Hit.y, mouse.Hit.z))
			if not success then
				cellPos = solidCellPos
			end
			
			x = cellPos.x
			y = cellPos.y
			z = cellPos.z			
		end

		selectionProps.startPos = Vector3.new(x, y, z)
		
		UpdatePosition(mouse.Hit)
	end
end

mouseHighlighter.OnClicked = onClicked

local function OnInputBegan(input, gameProcessedEvent)
	if input.KeyCode == Enum.KeyCode.R then
		cellOrientation = (cellOrientation + 1) % 4
		orientationText.Text = cellOrientations[cellOrientation + 1]
	elseif input.KeyCode == Enum.KeyCode.T then
		cellType = (cellType + 1) % 5
		typeText.Text = cellTypes[cellType + 1]
	end
end

-- Run when the popup is activated.
function On()
	if not c then
		return
	end
	plugin:Activate(true)
	toolbarbutton:SetActive(true)
	builderPropertiesDragBar.Visible = true
	inputBeganConnection = UserInputService.InputBegan:connect(OnInputBegan)
	on = true
end

-- Run when the popup is deactivated.
function Off()
	toolbarbutton:SetActive(false)
	if inputBeganConnection ~= nil then
		inputBeganConnection:disconnect()
	end
	on = false
	
	-- Hide the popup gui.
	builderPropertiesDragBar.Visible = false	
	mouseHighlighter:DisablePreview()
end

plugin.Deactivation:connect(function()
	Off()
end)

loaded = true
