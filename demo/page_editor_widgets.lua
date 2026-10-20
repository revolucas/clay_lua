local function C(color) return color.r, color.g, color.b, color.a end

local selectedNodeKey = "terrain"
local selectedAssetKey = "grass"
local expandedNodes = { world = true, terrain = true }
local selectedNode
local roughness = 0.42
local assetEnabled = true

local scene = {
  {
    key = "world", text = "World", icon = "◉", type = "Scene",
    children = {
      {
        key = "terrain", text = "Terrain", icon = "▧", type = "Terrain",
        children = {
          { key = "north-field", text = "North Field", icon = "▱", type = "Tile region" },
          { key = "river-bank", text = "River Bank", icon = "▱", type = "Tile region" },
        },
      },
      { key = "outpost", text = "Outpost", icon = "⌂", type = "Prefab" },
      { key = "camera", text = "Editor Camera", icon = "◎", type = "Camera" },
    },
  },
  {
    key = "materials", text = "Materials", icon = "▦", type = "Folder",
    children = {
      { key = "grass-material", text = "Grass", icon = "▧", type = "Material" },
      { key = "rock-material", text = "Rock", icon = "▧", type = "Material" },
    },
  },
}

local assets = {
  { key = "grass", name = "Grass", category = "Texture", path = "textures/grass.dds",
    description = "Ground cover for temperate terrain.", tags = { "terrain", "green" },
    color = { r = 85, g = 126, b = 76, a = 255 }, icon = "▦" },
  { key = "dirt", name = "Dirt", category = "Texture", path = "textures/dirt.dds",
    description = "Packed soil with a warm brown palette.", tags = { "terrain", "ground" },
    color = { r = 135, g = 100, b = 69, a = 255 }, icon = "▦" },
  { key = "stone", name = "Stone", category = "Texture", path = "textures/stone.dds",
    description = "Weathered stone surface.", tags = { "rock", "grey" },
    color = { r = 119, g = 126, b = 132, a = 255 }, icon = "▦" },
  { key = "water", name = "Water", category = "Material", path = "materials/water.lua",
    description = "Shallow water material with a soft blue tint.", tags = { "liquid", "blue" },
    color = { r = 59, g = 130, b = 170, a = 255 }, icon = "≈" },
  { key = "pine", name = "Pine", category = "Model", path = "models/pine.ogf",
    description = "Tall evergreen tree mesh.", tags = { "vegetation", "tree" },
    color = { r = 48, g = 97, b = 70, a = 255 }, icon = "♠" },
  { key = "rock", name = "Rock", category = "Model", path = "models/rock.ogf",
    description = "Small environment rock mesh.", tags = { "environment", "stone" },
    color = { r = 104, g = 105, b = 100, a = 255 }, icon = "◆" },
}

selectedNode = scene[1].children[1]

local function draw_panel_title(title, subtitle)
  clay.element()
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIT)
    :childGap(3)
    :open()
  clay.text(title)
    :fontId(1)
    :fontSize(theme.type.body)
    :textColor(C(theme.colors.textStrong))
    :done()
  clay.text(subtitle)
    :fontId(1)
    :fontSize(theme.type.small)
    :textColor(C(theme.colors.textMuted))
    :done()
  clay.close()
end

local function draw_tree_panel()
  clay.element("EditorSceneTreePanel")
    :layoutDirection(clay.TOP_TO_BOTTOM)
    :width(clay.SIZING_FIXED, 210)
    :height(clay.SIZING_FIXED, 320)
    :padding(10)
    :childGap(8)
    :backgroundColor(C(theme.colors.surface))
    :borderColor(C(theme.colors.border))
    :borderWidth(1)
    :open()
  draw_panel_title("Scene", "World hierarchy")

  clay.element("EditorSceneTreeViewport")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_GROW)
    :clip(false, true)
    :open()
  clay.element("EditorSceneTreeContent")
    :width(clay.SIZING_GROW)
    :height(clay.SIZING_FIT)
    :open()
  selectedNodeKey, expandedNodes = clay.treeview(
    clay.id("EditorSceneTree"), scene)
    :rowHeight(26)
    :indent(16)
    :fontSize(theme.type.small)
    :viewport(clay.id("EditorSceneTreeViewport"))
    :getIcon(function(item) return item.icon end)
    :expanded(expandedNodes)
    :selectedKey(selectedNodeKey)
    :onSelect(function(key, item)
      selectedNodeKey = key
      selectedNode = item
    end)
    :multiSelect(false)
    :draw()
  clay.close() -- tree content
  clay.scrollbar(clay.id("EditorSceneTreeViewport"),
    clay.id("EditorSceneTreeContent"), device.scroll and device.scroll.y or 0, nil)
  clay.close() -- tree viewport
  clay.close() -- tree panel
end

local function draw_asset_panel()
  local _, selectedAsset = clay.asset_browser(clay.id("EditorAssetBrowser"), assets)
    :width(340)
    :height(320)
    :columns(2)
    :tileSize(148, 104)
    :selectedKey(selectedAssetKey)
    :onSelect(function(key) selectedAssetKey = key end)
    :onActivate(function(key, item)
      print("Open asset:", key, item.path)
    end)
    :draw()
  return selectedAsset
end

function layout()
  local description = device.isWeb
    and "Scene hierarchy and property editing components."
    or "Reusable building blocks for scene editing, asset selection, and property editing."
  clay.text("Editor Widgets")
    :fontId(1)
    :fontSize(theme.type.heading)
    :textColor(C(theme.colors.textStrong))
    :done()
  clay.text(description)
    :fontId(1)
    :fontSize(theme.type.small)
    :textColor(C(theme.colors.textMuted))
    :done()

  local selectedAsset
  clay.element("EditorWidgetBrowserRow")
    :layoutDirection(clay.LEFT_TO_RIGHT)
    :width(clay.SIZING_FIT)
    :height(clay.SIZING_FIT)
    :childGap(10)
    :open()
  draw_tree_panel()
  if not device.isWeb then selectedAsset = draw_asset_panel() end
  clay.close()

  clay.inspector(clay.id("EditorSelectionInspector"), function(ui)
    ui:section("Selection")
      :value("Scene item", selectedNode and selectedNode.text or "Nothing selected")
      :value("Type", selectedNode and selectedNode.type or "—")
      :value("Asset", selectedAsset and selectedAsset.name or "—")
      :value("Path", selectedAsset and selectedAsset.path or "—")

    ui:section("Material")
      :row("Roughness", function()
        roughness = clay.slider(clay.id("EditorRoughness"), roughness)
          :range(0, 1)
          :step(0.01)
          :width(160)
          :height(24)
          :draw()
      end)
      :row("Enabled", function()
        assetEnabled = clay.checkbox(clay.id("EditorAssetEnabled"), "On", assetEnabled)
          :draw()
      end)
      :note(selectedAsset and selectedAsset.description
        or "Choose an asset to inspect its metadata.")
  end)
    :width(560)
    :rowHeight(30)
    :labelWidth(112)
    :sectionGap(6)
    :draw()
end
