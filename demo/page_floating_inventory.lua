local window = require("window")

local function C(c) return c.r, c.g, c.b, c.a end

local draggingItem = nil
local dragStartX, dragStartY = 0, 0
local dragSource = nil        -- "inventory" or "slot:<key>"
local dragStarted = false
local dragThreshold = 5
local lastMouseDown = false

local inventoryItems = {
  "10mm Pistol",
  "Laser Rifle",
  "Combat Armor",
  "Leather Jacket",
  "Stimpack",
  "Bottlecap",
  "Super Sledge",
  "Power Armor",
  "Plasma Grenade",
}

local equipped = {
  head = nil,
  chest = nil,
  legs = nil,
  leftHand = nil,
  rightHand = nil,
}

-------------------------------------------------
-- Inventory item component
-------------------------------------------------
local function InventoryItem(i, label, mouse_down)
  local elid = clay.id("InventoryItem", i)
  local hovered = clay.pointerOver(elid)

  clay.element(elid)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIXED, 36)
    :padding(8)
    :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(hovered and theme.colors.surfaceHover or theme.colors.surfaceRaised))
    :borderColor(255, 255, 255, 20)
    :borderWidth(0, 1, 0, 1) -- l,t,r,b
    :open()
  clay.text(label)
    :fontId(1):fontSize(16)
    :textColor(C(COLOR_WHITE))
    :done()

  if hovered and mouse_down and not draggingItem then
    dragStartX, dragStartY = window.mousePosition()
    draggingItem = label
    dragSource = "inventory"
    dragStarted = false
  end
  clay.close()
end

-------------------------------------------------
-- Equipment slot component
-------------------------------------------------
local function EquipmentSlot(i, name, key, mouse_down)
  local elid = clay.id("EquipSlot", i)
  local item = equipped[key]
  local hovered = clay.pointerOver(elid)

  clay.element(elid)
    :width(clay.SIZING_FIXED, 140)
    :height(clay.SIZING_FIXED, 40)
    :childAlignment(clay.ALIGN_X_CENTER, clay.ALIGN_Y_CENTER)
    :backgroundColor(C(hovered and theme.colors.surfaceHover or theme.colors.surface))
    :borderColor(200, 200, 255, 60)
    :borderWidth(1)
    :open()
  clay.text(name .. ": " .. (item or "[empty]"))
    :fontId(1):fontSize(14)
    :textColor(C(COLOR_WHITE))
    :done()

  -- start drag from slot
  if hovered and mouse_down and not draggingItem and item then
    dragStartX, dragStartY = window.mousePosition()
    draggingItem = item
    dragSource = "slot:" .. key
    dragStarted = false
  end

  -- drop from inventory onto slot
  if hovered and not mouse_down and draggingItem and dragStarted then
    if dragSource == "inventory" then
      for j = #inventoryItems, 1, -1 do
        if inventoryItems[j] == draggingItem then
          table.remove(inventoryItems, j)
          break
        end
      end
    elseif dragSource and dragSource:match("^slot:") then
      local oldKey = dragSource:match("slot:(.+)")
      equipped[oldKey] = nil
    end

    equipped[key] = draggingItem
    draggingItem = nil
    dragStarted = false
  end
  clay.close()
end

function layout(dt)
  local mx, my = window.mousePosition()
  local mouse_down = window.mouseButtonDown(window.MOUSE_BUTTON_LEFT)

  -- detect drag start
  if draggingItem and not dragStarted and mouse_down then
    local dx = mx - dragStartX
    local dy = my - dragStartY
    if math.sqrt(dx*dx + dy*dy) > dragThreshold then
      dragStarted = true
    end
  end

  clay.element("InventoryRoot")
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_GROW)
    :childGap(12)
    :open()

  -- Left inventory
  clay.element("InventoryScroll")
    :width(clay.SIZING_FIXED, 240)
    :height(clay.SIZING_GROW)
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :padding(8)
    :childGap(8)
    :clip(false, true) -- vertical scroll; childOffset defaults to Clay_GetScrollOffset() if omitted
    :backgroundColor(C(theme.colors.surface))
    :borderColor(C(COLOR_WHITE_24))
    :borderWidth(0, 0, 1, 0) -- right border only
    :open()
  for i, item in ipairs(inventoryItems) do
    InventoryItem(i, item, mouse_down)
  end

  -- drop from slot back to inventory
  if clay.hovered() and not mouse_down and draggingItem and dragStarted then
    if dragSource and dragSource:match("^slot:") then
      local oldKey = dragSource:match("slot:(.+)")
      equipped[oldKey] = nil
      table.insert(inventoryItems, draggingItem)
    end
    draggingItem = nil
    dragStarted = false
  end
  clay.close() -- InventoryScroll

  -- Right paper doll
  clay.element("EquipPanel")
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_GROW)
    :childGap(12)
    :padding(16)
    :backgroundColor(C(theme.colors.surfaceRaised))
    :open()
  clay.text("Paper Doll (mock)")
    :fontId(1):fontSize(18)
    :textColor(C(COLOR_WHITE))
    :done()
  EquipmentSlot(1, "Head", "head", mouse_down)
  EquipmentSlot(2, "Chest", "chest", mouse_down)
  EquipmentSlot(3, "Legs", "legs", mouse_down)
  EquipmentSlot(4, "Left Hand", "leftHand", mouse_down)
  EquipmentSlot(5, "Right Hand", "rightHand", mouse_down)
  clay.close() -- EquipPanel
  clay.close() -- InventoryRoot

  -- floating ghost follows mouse while dragging
  if draggingItem and dragStarted then
    clay.element("FloatingItem")
      :floating()
        :root()
        :attach("lt", "lt")
        :offset(mx + 8, my + 8)
        :zIndex(1000)
        :pointerCaptureMode(clay.POINTER_CAPTURE_MODE_PASSTHROUGH)
        :clipTo(clay.CLIP_TO_NONE)
        :done()
      :width(clay.SIZING_FIXED, 160)
      :height(clay.SIZING_FIXED, 32)
      :childAlignment(clay.ALIGN_X_LEFT, clay.ALIGN_Y_CENTER)
      :backgroundColor(C(theme.colors.borderSubtle))
      :borderColor(C(COLOR_WHITE_45))
      :borderWidth(1)
      :open()
    clay.text(draggingItem)
      :fontId(1):fontSize(14)
      :textColor(C(COLOR_WHITE))
      :done()
    clay.close()
  end

  -- mouse release cleanup
  if not mouse_down and lastMouseDown and draggingItem then
    if dragStarted then
      -- release in void → revert
      if dragSource == "inventory" then
        -- back to inventory (already there)
      elseif dragSource and dragSource:match("^slot:") then
        local oldKey = dragSource:match("slot:(.+)")
        equipped[oldKey] = draggingItem
      end
    end
    draggingItem = nil
    dragStarted = false
    dragSource = nil
  end

  lastMouseDown = mouse_down
end
