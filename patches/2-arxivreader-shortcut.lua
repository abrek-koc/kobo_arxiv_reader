-- Optional KOReader home-folder shortcut. No Rakuyomi dependency.
local FileChooser = require("ui/widget/filechooser")
local filemanagerutil = require("apps/filemanager/filemanagerutil")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local sentinel = "\0arxivreader-shortcut"
local function samePath(a, b)
    return a and b and a:gsub("/+$", "") == b:gsub("/+$", "")
end
local generate = FileChooser.genItemTable
function FileChooser:genItemTable(dirs, files, path)
    local items = generate(self, dirs, files, path)
    if self.name ~= "filemanager" or not samePath(path or self.path, filemanagerutil.getHomeFolder()) then
        return items
    end
    for _, item in ipairs(items) do
        if item.path == sentinel then return items end
    end
    table.insert(items, 1, {text = "arXiv Reader", path = sentinel, bold = true})
    return items
end
local select = FileChooser.onMenuSelect
function FileChooser:onMenuSelect(item)
    if not item or item.path ~= sentinel then return select(self, item) end
    local plugin = self.ui and self.ui.arxivreader
    if plugin and type(plugin.onArxivReader) == "function" then
        plugin:onArxivReader()
    else
        UIManager:show(InfoMessage:new{text = "arXiv Reader is unavailable. Install and enable the plugin, then restart KOReader."})
    end
    return true
end
local hold = FileChooser.onMenuHold
function FileChooser:onMenuHold(item)
    if item and item.path == sentinel then return true end
    return hold(self, item)
end
