-- Draggable UI elements by Michiel
-- Listener will get x,y coordinates when element is dragged

---@type Draggable[]
local draggables = {}

---Create a draggable area
---@param x1 number screen coordinate (big 3x2 pixels)
---@param x2 number screen coordinate (big 3x2 pixels)
---@param y1 number screen coordinate (big 3x2 pixels)
---@param y2 number screen coordinate (big 3x2 pixels)
---@param listener fun(x: number, y: number, type: "down" | "up" | "drag")
---@return Draggable
local function createDraggable(x1, x2, y1, y2, listener)
    ---@class Draggable
    local draggable = {
        --- True if this draggable is currently being clicked
        active = false,
        ---Called on mouse_click event
        ---@param self Draggable
        ---@param x number
        ---@param y number
        onMouseDown = function(self, x, y)
            if x >= x1 and y >= y1 and x <= x2 and y <= y2 then
                self.active = true
                listener(x, y, "down")
            end
        end,
        ---Called on mouse_up event
        ---@param self Draggable
        ---@param x number
        ---@param y number
        onMouseUp = function(self, x, y)
            if self.active then
                self.active = false
                listener(x, y, "up")
            end
        end,
        ---Called on mouse_drag event
        ---@param self Draggable
        ---@param x number
        ---@param y number
        onMouseDrag = function(self, x, y)
            if self.active then
                listener(x, y, "drag")
            end
        end
    }
    draggables[#draggables + 1] = draggable
    return draggable
end

return {
    createDraggable = createDraggable,
    onMouseDown = function(x, y)
        for i = 1, #draggables do draggables[i]:onMouseDown(x, y) end
    end,
    onMouseUp = function(x, y)
        for i = 1, #draggables do draggables[i]:onMouseUp(x, y) end
    end,
    onMouseDrag = function(x, y)
        for i = 1, #draggables do draggables[i]:onMouseDrag(x, y) end
    end
}
