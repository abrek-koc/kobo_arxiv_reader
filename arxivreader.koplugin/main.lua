local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local Menu = require("ui/widget/menu")
local TextViewer = require("ui/widget/textviewer")
local InputDialog = require("ui/widget/inputdialog")
local InfoMessage = require("ui/widget/infomessage")
local ConfirmBox = require("ui/widget/confirmbox")
local NetworkMgr = require("ui/network/manager")
local Trapper = require("ui/trapper")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local Device = require("device")
local lfs = require("libs/libkoreader-lfs")
local util = require("util")
local Core = dofile("plugins/arxivreader.koplugin/core.lua")
local App = WidgetContainer:extend{ name = "arxivreader", is_doc_only = false }
local ROOT = "/mnt/onboard/Articles"
local PAGE = 12
local subjects = {
    {"Artificial intelligence", "cs.AI"}, {"Machine learning", "cs.LG"},
    {"Computation and language", "cs.CL"}, {"Computer vision", "cs.CV"},
    {"Software engineering", "cs.SE"}, {"Computer science (all)", "cs"},
    {"Mathematics (all)", "math"}, {"Quantum physics", "quant-ph"},
    {"Astrophysics", "astro-ph"}, {"Condensed matter", "cond-mat"},
    {"Statistics", "stat"}, {"Electrical engineering", "eess"},
    {"Quantitative biology", "q-bio"}, {"Economics", "econ"},
}
function App:init()
    self.menus = {}
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/arxivreader.lua")
    self.papers = self.settings:readSetting("papers", {})
    self.cache = self.settings:readSetting("search_cache", {})
    self.ui.menu:registerToMainMenu(self)
    require("dispatcher"):registerAction("arxiv_reader", {
        category = "none", event = "ArxivReader", title = "arXiv Reader", general = true,
    })
end
function App:save()
    self.settings:saveSetting("papers", self.papers)
    self.settings:saveSetting("search_cache", self.cache)
    self.settings:flush()
end
function App:message(text)
    UIManager:show(InfoMessage:new{ text = text })
end
function App:addToMainMenu(items)
    items.arxiv_reader = { text = "arXiv Reader", sorting_hint = "more_tools",
        callback = function() self:onArxivReader() end }
end
function App:menu(title, items)
    local menu
    menu = Menu:new{ title = title, item_table = items, is_enable_shortcut = false,
        width = Device.screen:getWidth(), height = Device.screen:getHeight(),
        title_shrink_font_to_fit = true, items_per_page = 8, multilines_show_more_text = true,
        close_callback = function() self.menus[menu] = nil UIManager:close(menu) end,
    }
    self.menus[menu] = true
    UIManager:show(menu)
    return menu
end
function App:onArxivReader()
    self:menu("arXiv Reader", {
        {text = "Search papers", callback = function() self:searchDialog() end},
        {text = "Browse subjects", callback = function() self:browse() end},
        {text = "My library", callback = function() self:library() end},
        {text = "My notes", callback = function() self:library(true) end},
        {text = "Last search (offline)", callback = function()
            if self.cache.papers then self:results(self.cache) else self:message("Search once while connected to Wi-Fi.") end
        end},
        {text = "Reading help", callback = function()
            UIManager:show(TextViewer:new{title = "Reading with arXiv Reader", text =
                "Search by words, author, title, arXiv ID, or an arXiv abstract URL. Advanced arXiv queries such as au:Einstein AND ti:gravity also work.\n\nSave a paper to keep its abstract and notes offline. Download EPUB to create a scientific edition with a math font, section navigation, and full-resolution figures. Long-press a figure to zoom. Use landscape orientation for wide equations and tables. Keep embedded styles and fonts enabled. HTML is not available for every paper. Download PDF for the original layout.\n\nOpen a downloaded paper, long-press text, then choose Highlight or Add note. KOReader keeps these annotations and your reading position. Paper notes are a separate notebook in this app; export them as Markdown from the paper screen. Use KOReader's Export highlights tool for passage annotations.\n\nPapers and exported notes live in Articles/. Your saved library and paper notes live in KOReader settings/arxivreader.lua. Back up both folders, including document .sdr folders.\n\nHTML conversion and equation rendering can vary. Check the PDF if a formula or table looks wrong. The first download needs Wi-Fi; downloaded papers work offline.\n\nIndependent app; not affiliated with arXiv."})
        end},
    })
end
function App:searchDialog()
    local dialog
    dialog = InputDialog:new{ title = "Search arXiv", input = self.settings:readSetting("last_query", ""),
        input_hint = "Words, arXiv ID, or au:author AND ti:title",
        buttons = {{
            {text = "Cancel", callback = function() UIManager:close(dialog) end},
            {text = "Search", is_enter_default = true, callback = function()
                local q = util.trim(dialog:getInputText())
                if q == "" then return end
                UIManager:close(dialog)
                self.settings:saveSetting("last_query", q)
                self:search(q, 0, "relevance")
            end},
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end
function App:browse()
    local rows = {}
    for _, subject in ipairs(subjects) do
        local title, category = subject[1], subject[2]
        rows[#rows+1] = {text = title, callback = function()
            local query = "cat:" .. category
            if not category:find("%.") and category ~= "quant-ph" then query = query .. ".*" end
            self:search(query, 0, "submittedDate")
        end}
    end
    self:menu("Browse subjects - newest first", rows)
end
-- All foreground fetches are cancellable, bounded, and use one connection.
function App:fetch(address, limit, progress_text)
    local socket = require("socket")
    local wait = math.max(0, 3 - (socket.gettime() - (self.last_request or 0)))
    self.last_request = socket.gettime() + wait
    local progress = InfoMessage:new{ text = (progress_text or "Connecting to arXiv...") .. "\nTap to cancel." }
    UIManager:show(progress)
    UIManager:forceRePaint()
    local completed, body, err = Trapper:dismissableRunInSubprocess(function()
        socket.sleep(wait)
        local socketutil = require("socketutil")
        socketutil:set_timeout(15, 90)
        local parts, size = {}, 0
        local started = os.time()
        local ok, _, code = pcall(require("socket.http").request, {
            url = address, headers = {["User-Agent"] = socketutil.USER_AGENT .. " arxivreader/0.1"},
            sink = function(chunk)
                if os.time() - started > 90 then return nil, "Download timed out" end
                if chunk then
                    size = size + #chunk
                    if size > limit then return nil, "Paper exceeds download size limit" end
                    parts[#parts+1] = chunk
                end
                return 1
            end,
        })
        socketutil:reset_timeout()
        if not ok then return nil, "Connection failed. Check Wi-Fi and try again." end
        if tonumber(code) ~= 200 then return nil, "arXiv response: " .. tostring(code) .. ". Try again later or choose PDF." end
        return table.concat(parts)
    end, progress)
    if completed then UIManager:close(progress) end
    if not completed then return nil, "Cancelled." end
    self.last_request = socket.gettime()
    return body, err
end
function App:online(task)
    if self.busy then return self:message("An arXiv operation is already running.") end
    NetworkMgr:runWhenConnected(function()
        if self.busy then return end
        self.busy = true
        Trapper:wrap(function()
            local ok, err = pcall(task)
            Trapper:clear()
            self.busy = false
            if not ok then self:message("Could not finish this operation:\n" .. tostring(err)) end
        end)
    end)
end
function App:search(query, start, sort)
    self:online(function()
        local id = Core.id(query)
        local url = "https://export.arxiv.org/api/query?"
        if id then url = url .. "id_list=" .. require("socket.url").escape(id)
        else
            local q = query:find(":") and query or "all:" .. query
            url = url .. "search_query=" .. require("socket.url").escape(q)
        end
        url = url .. "&start=" .. start .. "&max_results=" .. PAGE .. "&sortBy=" .. sort .. "&sortOrder=descending"
        local xml, err = self:fetch(url, 2 * 1024 * 1024)
        if not xml then return self:message(err) end
        local papers, total = Core.parse(xml, util.htmlEntitiesToUtf8)
        if not papers then return self:message(total) end
        self.cache = {papers = papers, total = total, query = query, start = start, sort = sort}
        self:save()
        self:results(self.cache)
    end)
end
function App:results(result)
    if #result.papers == 0 then return self:message("No papers found. Try different words or an author name.") end
    local rows = {}
    local menu
    for _, item in ipairs(result.papers) do
        local paper = item
        rows[#rows+1] = {text = paper.title, mandatory = paper.published,
            callback = function() self:detail(self.papers[paper.id] or paper) end}
    end
    if result.start > 0 then rows[#rows+1] = {text = "Previous results", callback = function()
        UIManager:close(menu)
        self:search(result.query, math.max(0, result.start - PAGE), result.sort)
    end} end
    if result.start + #result.papers < result.total then rows[#rows+1] = {text = "Next results", callback = function()
        UIManager:close(menu)
        self:search(result.query, result.start + PAGE, result.sort)
    end} end
    menu = self:menu("arXiv: " .. (result.start + 1) .. "-" .. (result.start + #result.papers) .. " / " .. result.total, rows)
end
function App:remember(paper)
    if not self.papers[paper.id] then
        paper.status = paper.status or "To read"
        paper.saved = os.time()
        self.papers[paper.id] = paper
    end
    self:save()
end
function App:library(notes_only)
    local sorted, rows = {}, {}
    for _, p in pairs(self.papers) do
        if not notes_only or (p.notes and p.notes ~= "") then sorted[#sorted+1] = p end
    end
    table.sort(sorted, function(a,b) return (a.saved or 0) > (b.saved or 0) end)
    for _, p in ipairs(sorted) do
        local paper = p
        rows[#rows+1] = {text = paper.title, mandatory = paper.status or "To read",
            callback = function() self:detail(paper) end}
    end
    if #rows == 0 then return self:message(notes_only and "No paper notes yet. Open a paper and choose Paper notes." or "Your library is empty. Search or browse a subject, then save a paper.") end
    self:menu(notes_only and "My notes" or "My library", rows)
end
function App:detail(paper)
    local viewer
    local function close() UIManager:close(viewer) end
    viewer = TextViewer:new{
        title = paper.title, title_multilines = true,
        text = paper.authors .. "\n\n" .. paper.published .. " | arXiv:" .. paper.id
            .. "\nhttps://arxiv.org/abs/" .. paper.id .. "\n\n" .. paper.abstract
            .. "\n\nStatus: " .. (paper.status or "Not saved") .. "\n\n" .. (paper.notes or ""),
        buttons_table = {
            {{text = self.papers[paper.id] and "Saved" or "Save to library", callback = function()
                self:remember(paper) close() self:detail(paper)
            end}},
            {{text = "Read EPUB", callback = function() close() self:read(paper, "epub") end},
             {text = "Read PDF", callback = function() close() self:read(paper, "pdf") end}},
            {{text = "Download EPUB", callback = function() close() self:download(paper, "epub") end},
             {text = "Download PDF", callback = function() close() self:download(paper, "pdf") end}},
            {{text = "Paper notes", callback = function() close() self:notes(paper) end},
             {text = "Reading status", callback = function() close() self:status(paper) end}},
            {{text = "Export notes", callback = function() self:export(paper) end},
             {text = "Remove from library", enabled = self.papers[paper.id] ~= nil, callback = function()
                UIManager:show(ConfirmBox:new{text = "Remove this saved entry and its paper notes? Downloaded files and KOReader highlights will be kept.",
                    ok_callback = function() self.papers[paper.id] = nil self:save() close() end})
             end}},
            {{text = "Close", callback = close}},
        },
    }
    UIManager:show(viewer)
end
function App:notes(paper)
    local dialog
    dialog = InputDialog:new{title = "Paper notes", input = paper.notes or "",
        input_type = "text", allow_newline = true, fullscreen = true,
        buttons = {{
            {text = "Cancel", callback = function() UIManager:close(dialog) end},
            {text = "Save", callback = function()
                paper.notes = dialog:getInputText()
                self:remember(paper)
                UIManager:close(dialog)
                self:detail(paper)
            end},
        }},
    }
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end
function App:status(paper)
    local rows, menu = {}
    for _, value in ipairs({"To read", "Reading", "Finished"}) do
        local status = value
        rows[#rows+1] = {text = status, callback = function()
            paper.status = status self:remember(paper)
            UIManager:close(menu) self:detail(paper)
        end}
    end
    menu = self:menu("Reading status", rows)
end
-- PluginLoader reserves self.path for the plugin directory.
function App:paperFilePath(paper, format)
    return ROOT .. "/" .. Core.filename(paper.id) .. (format == "epub" and ".science-v3.epub" or "." .. format)
end
function App:read(paper, format)
    local path = self:paperFilePath(paper, format)
    if format == "epub" and not lfs.attributes(path) then
        path = ROOT .. "/" .. Core.filename(paper.id) .. ".science.epub"
        if not lfs.attributes(path) then
            path = ROOT .. "/" .. Core.filename(paper.id) .. ".epub" -- Retain older annotations.
        end
    end
    if not lfs.attributes(path) then return self:message("Download the " .. format:upper() .. " first from the paper screen.") end
    paper.status = "Reading" self:remember(paper)
    for menu in pairs(self.menus) do UIManager:close(menu) end
    self.menus = {}
    require("apps/reader/readerui"):showReader(path)
end
function App:download(paper, format)
    local path = self:paperFilePath(paper, format)
    if lfs.attributes(path) then return self:message("Already downloaded. Choose Read " .. format:upper() .. ".") end
    self:online(function()
        util.makePath(ROOT)
        if format == "pdf" then
            local body, err = self:fetch("https://arxiv.org/pdf/" .. paper.id, 40 * 1024 * 1024)
            if not body then return self:message(err) end
            if body:sub(1,5) ~= "%PDF-" then return self:message("arXiv did not return a PDF. Please try again later.") end
            local file, open_err = io.open(path .. ".part", "wb")
            if not file then return self:message(tostring(open_err)) end
            local written, write_err = file:write(body)
            local closed, close_err = file:close()
            if not written or not closed then os.remove(path .. ".part") return self:message(tostring(write_err or close_err)) end
            local moved, move_err = os.rename(path .. ".part", path)
            if not moved then return self:message(tostring(move_err)) end
        else
            local url = "https://arxiv.org/html/" .. paper.id
            local body, err = self:fetch(url, 15 * 1024 * 1024)
            if not body then return self:message(err) end
            local html, html_err = Core.html(body, paper)
            if not html then return self:message(html_err) end
            local backend = dofile(self.path .. "/scientific.lua")
            local success, build_err = backend.create(path, html, paper, url, self.path, function(address, limit, index, count)
                return self:fetch(address, limit, "Downloading figure " .. index .. " of " .. count)
            end)
            Trapper:clear()
            if not success or not lfs.attributes(path) then return self:message(build_err or "EPUB was not saved. You can retry or download PDF.") end
        end
        self:remember(paper)
        UIManager:show(ConfirmBox:new{text = format:upper() .. " saved for offline reading. Read it now?",
            ok_text = "Read", ok_callback = function() self:read(paper, format) end})
    end)
end
function App:export(paper)
    util.makePath(ROOT .. "/Notes")
    local path = ROOT .. "/Notes/" .. Core.filename(paper.id) .. ".md"
    local file, err = io.open(path .. ".part", "wb")
    if not file then return self:message(tostring(err)) end
    local written, write_err = file:write(Core.markdown(paper))
    local closed, close_err = file:close()
    if not written or not closed then os.remove(path .. ".part") return self:message(tostring(write_err or close_err)) end
    local moved, move_err = os.rename(path .. ".part", path)
    if not moved then return self:message(tostring(move_err)) end
    self:message("Notes exported to:\n" .. path)
end
return App
