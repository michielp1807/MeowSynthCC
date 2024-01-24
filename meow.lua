local blittle = require("betterblittle")
local synth = require("synth")
if not synth then return end

local draggable = require("draggable")

local min = math.min
local max = math.max

local ALL_COLORS = {
    colors.white,
    colors.orange,
    colors.magenta,
    colors.lightBlue,
    colors.yellow,
    colors.lime,
    colors.pink,
    colors.gray,
    colors.lightGray,
    colors.cyan,
    colors.purple,
    colors.blue,
    colors.brown,
    colors.green,
    colors.red,
    colors.black
}

local NEW_COLOR_VALUES = {
    0xf0f0f0,
    0xe1d8be,
    0xcdc39f,
    0x77a1b5,
    0xffde00,
    0xa79b68,
    0x9d967f,
    0x4c4c4c,
    0x999999,
    0x4682a2,
    0xc39e70,
    0x244d61,
    0x7f664c,
    0x625538,
    0x3e3623,
    0x191919
}

local OLD_COLOR_VALUES = {}

-- Set palette colors
for i = 1, #ALL_COLORS do
    OLD_COLOR_VALUES[i] = {}
    local r, g, b = term.getPaletteColor(ALL_COLORS[i])
    OLD_COLOR_VALUES[i][1] = r
    OLD_COLOR_VALUES[i][2] = g
    OLD_COLOR_VALUES[i][3] = b
    term.setPaletteColour(ALL_COLORS[i], NEW_COLOR_VALUES[i])
end

local function resetPalette()
    for i = 1, #ALL_COLORS do
        term.setPaletteColour(ALL_COLORS[i], OLD_COLOR_VALUES[i][1], OLD_COLOR_VALUES[i][2], OLD_COLOR_VALUES[i][3])
    end
end

-- Draw main UI background
-- $ ./convert_nfp.py --skip-resize ui.png
local ui = paintutils.loadImage("images/ui.nfp")

local cats = {}
for i = 0, 7 do
    -- $ ./convert_nfp.py --resize-width 53 --resize-height 39 meowcat*.png
    cats[i + 1] = paintutils.loadImage("images/meowcat" .. i .. ".nfp")
    -- Insert border on left side
    for y = 1, #cats[i + 1] do
        table.insert(cats[i + 1][y], 1, colors.blue)
    end
end

blittle.drawBuffer(ui, term)

local cat_window = window.create(term.current(), 2, 2, 27, 13)
blittle.drawBuffer(cats[1], cat_window)

synth.setNewCutoffLevelListener(function(level)
    blittle.drawBuffer(cats[level], cat_window)
end)

---@param text string
---@param x number
---@param y number
---@param fg? color
---@param bg? color
local function drawText(text, x, y, fg, bg)
    term.setBackgroundColor(bg or colors.black)
    term.setTextColor(fg or colors.white)
    term.setCursorPos(x, y)
    term.write(text)
end

---@type Key[]
local pianoKeys = {}
local keyChars = "zsxdcvgbhnjm,l.;/q2w3e4rt6y7ui9o0p-[]"
local keyIsBlack = {false, true, false, true, false, false, true, false, true, false, true, false}
for i = 1, 12 * 4 + 1 do
    ---@class Key
    pianoKeys[i] = {
        char = keyChars:sub(i, i),
        pitch = 440 * 2 ^ ((i - 22) / 12),
        isBlack = keyIsBlack[i % 12],
        index = i,
        x = i + 1,
        y = keyIsBlack[i % 12] and 17 or 18
    }
end

local function drawPianoKey(i, active)
    local isBlack = pianoKeys[i].isBlack
    local x = pianoKeys[i].x
    local y = pianoKeys[i].y
    local bg = isBlack and colors.black or colors.white
    local fg = isBlack and colors.lightGray or colors.gray
    if active then
        bg = isBlack and colors.brown or colors.yellow
        fg = isBlack and colors.yellow or colors.brown
    end
    paintutils.drawFilledBox(x, 16, x, y, bg)
    drawText(pianoKeys[i].char, x, y, fg, bg)
end

-- Draw keyboard keys characters
for i = 1, #pianoKeys do drawPianoKey(i) end

-- Draw Meow Envelope text
drawText("Meow Envelope", 31, 2, colors.white, colors.lightBlue)

local keyboardKeys = {
    keys.z, keys.s, keys.x, keys.d, keys.c,
    keys.v, keys.g, keys.b, keys.h, keys.n, keys.j, keys.m,
    keys.comma, keys.l, keys.period, keys.semiColon or keys.semicolon, keys.slash,
    keys.q, keys.two, keys.w, keys.three, keys.e, keys.four, keys.r,
    keys.t, keys.six, keys.y, keys.seven, keys.u,
    keys.i, keys.nine, keys.o, keys.zero, keys.p, keys.minus, keys.leftBracket,
    keys.rightBracket,
}
local keyboardKeyToKeyIndex = {}
for i = 1, #keyboardKeys do
    keyboardKeyToKeyIndex[keyboardKeys[i]] = i
end

local activeKey
local function activateKey(key)
    if activeKey then drawPianoKey(activeKey.index, false) end
    activeKey = key
    drawPianoKey(key.index, true)
    synth.triggerNote(key.pitch)
end
local function deactivateKey(key)
    if activeKey == key then
        synth.releaseNote()
        drawPianoKey(activeKey.index, false)
        activeKey = nil
        blittle.drawBuffer(cats[1], cat_window)
    end
end

-- Create piano draggable
draggable.createDraggable(2, 50, 16, 18, function(x, y, type)
    if x < 2 or x > 50 then return end
    if type == "up" then
        deactivateKey(pianoKeys[x - 1])
    else
        activateKey(pianoKeys[x - 1])
    end
end)

-- Spaces to draw the slider with as text
local SLIDER_SPACES = "                  "

local ADSR = {0.25, 0.75, 0.01, 0.25}

-- Create ADSR slider draggable
for i = 1, 4 do
    local sy = 2 + 2 * i
    draggable.createDraggable(31, 49, sy, sy, function(x, y, type)
        local level = max(0, min(x - 31, 19))
        drawText(SLIDER_SPACES, 32, sy, nil, colors.black)
        drawText(SLIDER_SPACES:sub(1, level), 32, sy, nil, colors.yellow)
        local value = min(level / 19 + 0.001, 1)
        if i == 3 then -- Sustain level
            value = value ^ 3 + 0.0001
        else           -- Attack / Decay / Release
            value = value * 2
        end
        ADSR[i] = value
        synth.setEvelopeParams(ADSR[1], ADSR[2], ADSR[3], ADSR[4])
    end)

    -- Draw start position of sliders
    local level = ADSR[i]
    if i == 3 then -- Sustain level
        level = level ^ (1 / 3)
    else           -- Attack / Decay / Release
        level = level / 2
    end
    level = math.floor((level - 0.0001) * 19)
    drawText(SLIDER_SPACES, 32, sy, nil, colors.black)
    drawText(SLIDER_SPACES:sub(1, level), 32, sy, nil, colors.yellow)
end

local keysDown = {}
local function userInput()
    while true do
        local event, which, x, y = os.pullEventRaw()
        local keyIndex = keyboardKeyToKeyIndex[which]
        if event == "key" and not keysDown[which] and keyIndex then -- non-repeating key-down event
            activateKey(pianoKeys[keyIndex])
            keysDown[which] = true
        elseif event == "key_up" and keyIndex then
            deactivateKey(pianoKeys[keyIndex])
            keysDown[which] = nil
        elseif event == "mouse_click" then
            draggable.onMouseDown(x, y)
        elseif event == "mouse_up" then
            draggable.onMouseUp(x, y)
        elseif event == "mouse_drag" then
            draggable.onMouseDrag(x, y)
        elseif event == "terminate" then
            term.setBackgroundColor(colors.black)
            term.setTextColor(colors.white)
            term.clear()
            term.setCursorPos(1, 1)
            resetPalette()
            return
        end
    end
end

parallel.waitForAny(userInput, synth.processAudio)
