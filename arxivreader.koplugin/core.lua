local Core = {}
function Core.id(value)
    local id = (value or ""):gsub("^https?://[^/]+/abs/", ""):gsub("^https?://[^/]+/html/", ""):gsub("^https?://[^/]+/pdf/", ""):gsub("%.pdf$", "")
    local base = id:gsub("v[1-9]%d*$", "")
    if base:match("^%d%d%d%d%.%d%d%d%d%d?$") or base:match("^[%a][%w%.%-]+/%d%d%d%d%d%d%d$") then return id end
end
function Core.filename(id)
    assert(Core.id(id) == id, "Invalid arXiv identifier")
    return id:gsub("/", "_")
end
function Core.escape(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
function Core.parse(xml, decode)
    if not xml:find("<feed[%s>]") then return nil, "arXiv returned an invalid feed. Please try again later." end
    local papers = {}
    local function field(body, tag)
        return decode((body:match("<" .. tag .. "[^>]*>(.-)</" .. tag .. ">") or ""):gsub("<!%[CDATA%[(.-)%]%]>", "%1")):gsub("%s+", " "):match("^%s*(.-)%s*$")
    end
    for entry in xml:gmatch("<entry[^>]*>(.-)</entry>") do
        local rawid = field(entry, "id")
        if rawid:find("/api/errors", 1, true) then return nil, field(entry, "summary") end
        local id = Core.id(rawid)
        if id then
            local authors = {}
            for author in entry:gmatch("<author[^>]*>(.-)</author>") do authors[#authors+1] = field(author, "name") end
            papers[#papers+1] = {
                id = id, title = field(entry, "title"), abstract = field(entry, "summary"),
                authors = table.concat(authors, ", "), published = field(entry, "published"):sub(1,10),
            }
        end
    end
    return papers, tonumber(xml:match("<opensearch:totalResults[^>]*>(%d+)")) or #papers
end
function Core.html(html, paper)
    local article = html:match("<article[^>]*>(.-)</article>")
    if not article then return nil, "No readable HTML article was returned. Try Download PDF." end
    article = article:gsub("<script[^>]*>.-</script>", ""):gsub("<style[^>]*>.-</style>", "")
    -- Preserve MathML, figures, section IDs, and references for KOReader's engine.
    return '<!DOCTYPE html><html><head><meta charset="utf-8"/><title>' .. Core.escape(paper.title)
        .. '</title></head><body><p>arXiv:' .. Core.escape(paper.id) .. ' | <a href="https://arxiv.org/abs/'
        .. paper.id .. '">Original paper</a></p>' .. article .. '</body></html>'
end
function Core.markdown(paper)
    return "# " .. paper.title .. "\n\n" .. paper.authors .. "\n\narXiv: " .. paper.id
        .. "\nhttps://arxiv.org/abs/" .. paper.id .. "\n\nStatus: " .. (paper.status or "To read")
        .. "\n\n## Notes\n\n" .. (paper.notes or "") .. "\n"
end
return Core
