-- LocalScript inside StarterGui -> ScreenGui
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Configuration Constants
local COLORS = {
    { name = "Add More",   color = Color3.fromRGB(59, 130, 246) },
    { name = "Big Deal",   color = Color3.fromRGB(234, 179, 8) },
    { name = "Fair Trade", color = Color3.fromRGB(220, 38, 38) },
    { name = "Deal?",  color = Color3.fromRGB(34, 197, 94) },
    { name = "Last Offer", color = Color3.fromRGB(168, 85, 247) },
    { name = "No Thanks",  color = Color3.fromRGB(249, 115, 22) }
}

local NUM_DICE = 4
local selectedDice = nil
local isRolling = false

-- UI Layout Definitions (~30% Scaled Down Dimensions)
local PANEL_HEIGHT = 112
local DIE_SIZE = 76
local GAP = 8
local PAD = 10
local ZONE_WIDTH = (DIE_SIZE * NUM_DICE) + (GAP * (NUM_DICE - 1)) + (PAD * 2)

local BTN_COLS = 3
local BTN_WIDTH = 84
local BTN_HEIGHT = 32
local GAP_X = 6
local GAP_Y = 6

-- Dot Positions for 3D/2D Simulation Matrix
local DOT_LAYOUT = {
    [1] = { {0.5, 0.5} },
    [2] = { {0.28, 0.28}, {0.72, 0.72} },
    [3] = { {0.28, 0.28}, {0.5, 0.5}, {0.72, 0.72} },
    [4] = { {0.28, 0.28}, {0.28, 0.72}, {0.72, 0.28}, {0.72, 0.72} },
    [5] = { {0.28, 0.28}, {0.28, 0.72}, {0.5, 0.5}, {0.72, 0.28}, {0.72, 0.72} },
    [6] = { {0.28, 0.28}, {0.28, 0.5}, {0.28, 0.72}, {0.72, 0.28}, {0.72, 0.5}, {0.72, 0.72} }
}

-- Create Screen GUI Core Frame
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BrainrotDicer"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "MainPanel"
panel.Size = UDim2.new(0, ZONE_WIDTH, 0, PANEL_HEIGHT)
panel.Position = UDim2.new(0.5, -ZONE_WIDTH/2, 1, -(PANEL_HEIGHT + 12))
panel.BackgroundColor3 = Color3.fromRGB(8, 6, 28)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 14)
uiCorner.Parent = panel

local uiStroke = Instance.new("UIStroke")
uiStroke.Thickness = 1.5
uiStroke.Color = Color3.fromRGB(100, 100, 100)
uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
uiStroke.Parent = panel

-- Draggable UI Setup
local dragging, dragInput, dragStart, startPos
panel.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = panel.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        if dragging then
            local delta = input.Position - dragStart
            panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end
end)

--- UI Helper Generators
local function makeVDivider(xPosition)
    local d = Instance.new("Frame")
    d.Size = UDim2.new(0, 1, 1, -16)
    d.Position = UDim2.new(0, xPosition, 0, 8)
    d.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    d.BorderSizePixel = 0
    d.Parent = panel
end

local function clearDots(dieFrame)
    for _, child in ipairs(dieFrame:GetChildren()) do
        if child.Name == "Dot" then
            child:Destroy()
        end
    end
end

local function drawDots(dieFrame, value, color)
    clearDots(dieFrame)
    local layout = DOT_LAYOUT[value]
    if not layout then return end

    -- Calculate luminance to determine adaptive dot color contrast (Black vs White)
    local luminance = (0.299 * color.R) + (0.587 * color.G) + (0.114 * color.B)
    local dotColor = luminance > 0.60 and Color3.fromRGB(0,0,0) or Color3.fromRGB(255,255,255)

    for _, pos in ipairs(layout) do
        local dot = Instance.new("Frame")
        dot.Name = "Dot"
        dot.Size = UDim2.new(0, 13, 0, 13)
        dot.Position = UDim2.new(pos[1], -6.5, pos[2], -6.5)
        dot.BackgroundColor3 = dotColor
        dot.BorderSizePixel = 0
        dot.Parent = dieFrame

        local c = Instance.new("UICorner")
        c.CornerRadius = UDim.new(1, 0)
        c.Parent = dot
    end
end

-- Initialize the Dice Elements
local diceList = {}
for i = 1, NUM_DICE do
    local xPos = PAD + ((i - 1) * (DIE_SIZE + GAP))

    local die = Instance.new("TextButton")
    die.Name = "Die" .. i
    die.Size = UDim2.new(0, DIE_SIZE, 0, DIE_SIZE)
    die.Position = UDim2.new(0, xPos, 0, PAD)
    die.BackgroundColor3 = COLORS[i].color
    die.Text = ""
    die.AutoButtonColor = false
    die.Parent = panel

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 16)
    c.Parent = die

    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 2
    stroke.Color = Color3.fromRGB(255,255,255)
    stroke.Enabled = false
    stroke.Parent = die

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(1, 0, 1, 0)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(i)
    valLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    valLabel.TextSize = 24
    valLabel.Font = Enum.Font.GothamBlack
    valLabel.TextXAlignment = Enum.TextXAlignment.Center
    valLabel.Parent = die

    diceList[i] = { frame = die, stroke = stroke, label = valLabel, currentVal = i, baseColor = COLORS[i].color }
    drawDots(die, i, COLORS[i].color)

    -- Selector Logic Click Connections (no outline on select)
    die.MouseButton1Click:Connect(function()
        if isRolling then return end
        if selectedDice == diceList[i] then
            selectedDice = nil
        else
            if selectedDice then selectedDice.stroke.Enabled = false end
            selectedDice = diceList[i]
            -- stroke.Enabled = true  ← removed: no white outline shown on click
        end
    end)
end

-- Status Label Setup
local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0, ZONE_WIDTH, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, PANEL_HEIGHT + 4)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Tap a die to highlight it"
statusLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
statusLabel.TextSize = 13
statusLabel.Font = Enum.Font.SourceSansItalic
statusLabel.Parent = panel

-- Roll Action Core Engine Loop
local function rollDice()
    if isRolling or not selectedDice then return end
    isRolling = true
    statusLabel.Text = "Rolling dynamic probabilities..."

    local rollDuration = 1.2
    local startTime = os.clock()

    local connection
    connection = RunService.Heartbeat:Connect(function()
        local elapsed = os.clock() - startTime
        if elapsed >= rollDuration then
            connection:Disconnect()

            -- Set final structured values
            local finalVal = math.random(1, 6)
            selectedDice.currentVal = finalVal
            selectedDice.label.Text = tostring(finalVal)
            drawDots(selectedDice.frame, finalVal, selectedDice.baseColor)

            selectedDice.stroke.Enabled = false
            selectedDice = nil
            isRolling = false
            statusLabel.Text = "Tap a die to highlight it"
        else
            -- Rapid random shifting simulation visualizer
            local rapidRandom = math.random(1, 6)
            selectedDice.label.Text = tostring(rapidRandom)
            drawDots(selectedDice.frame, rapidRandom, selectedDice.baseColor)
        end
    end)
end

-- Create the Trigger Action Activation Module Button
local rollButton = Instance.new("TextButton")
rollButton.Size = UDim2.new(0, 100, 0, 36)
rollButton.Position = UDim2.new(1, -110, 0, (PANEL_HEIGHT / 2) - 18)
rollButton.BackgroundColor3 = Color3.fromRGB(16, 185, 129)
rollButton.Text = "ROLL"
rollButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rollButton.Font = Enum.Font.GothamBold
rollButton.TextSize = 14
rollButton.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 8)
btnCorner.Parent = rollButton

rollButton.MouseButton1Click:Connect(rollDice)
