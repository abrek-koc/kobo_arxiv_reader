-- Scientific EPUB 3 packaging. Keeps source mathematics and full-size artwork.
local S = {}
local function esc(s)
    return (s:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end
local function attr(tag, name)
    return tag:match("%s" .. name .. '%s*=%s*"([^"]*)"')
        or tag:match("%s" .. name .. "%s*=%s*'([^']*)'")
end
S.css = [[
@font-face { font-family: "STIX Two Math"; src: url("fonts/STIXTwoMath-Regular.otf"); }
body { margin: 0; color: #000; background: #fff; line-height: 1.3; }
p { text-align: left; margin: .45em 0; }
h1,h2,h3,h4,h5,h6 { text-align: left; page-break-after: avoid; }
math { font-family: "STIX Two Math"; }
math[display="block"] { display: block; margin: .7em 0; text-align: center; }
figure { display: block; margin: 1em 0; padding: 0; }
img { max-width: 100%; height: auto; }
figure img, .ltx_graphics { display: block; margin: .5em auto; max-width: 100%; height: auto; }
.ltx_figure_panel { display: block; margin: .7em 0; }
.reader-narrow-table { width: 100%; font-size: .9em; }
.reader-table-label { font-weight: bold; page-break-after: avoid; }
.reader-original-tables { page-break-before: always; }
.ltx_font_bold { font-weight: bold; }
.ltx_border_t, .ltx_border_tt { border-top: 1px solid #000; }
.ltx_border_b, .ltx_border_bb { border-bottom: 1px solid #000; }
.ltx_align_right { text-align: right; }
.ltx_align_center { text-align: center; }
img.reader-inline-icon { display: inline; width: 1.3em; height: auto; vertical-align: middle; }
figcaption { display: block; text-align: left; font-size: .9em; }
table { border-collapse: collapse; max-width: 100%; margin: .6em 0; font-size: .85em; }
th,td { padding: .25em; vertical-align: top; }
th { border-bottom: 1px solid #000; }
.ltx_equation, .ltx_equationgroup { display: block; margin: .6em 0; }
.ltx_equation tr, .ltx_equation td { display: block; text-align: center; border: none; }
.ltx_eqn_eqno { text-align: right; font-size: .8em; }
.ltx_eqn_pad { display: none; }
.ltx_ref { color: #000; text-decoration: underline; }
pre { white-space: pre-wrap; font-size: .85em; }
.reader-hint { font-size: .85em; border-bottom: 1px solid #000; padding-bottom: .5em; }
]]
-- Expand merged cells before splitting wide data tables. Original markup is
-- retained in an appendix; copied cell IDs are removed to keep anchors unique.
function S.readableTables(html)
    local originals, serial = {}, 0
    local function withoutIDs(s)
        return s:gsub('%s+id%s*=%s*"[^"]*"', ""):gsub("%s+id%s*=%s*'[^']*'", "")
    end
    html = html:gsub("(<table%s[^>]*>)(.-)</table>", function(open, inside)
        local original = open .. inside .. "</table>"
        if inside:find("<table[%s>]") or not (attr(open,"class") or ""):find("ltx_tabular",1,true) then return original end
        local rows, grid, width = {}, {}, 0
        for tr in inside:gmatch("<tr[%s>].-</tr>") do
            local row = {}
            for tag, attrs, content in tr:gmatch("<(t[dh])([^>]*)>(.-)</t[dh]>") do
                local cs = tonumber(attr(" " .. attrs,"colspan") or "1")
                local rs = tonumber(attr(" " .. attrs,"rowspan") or "1")
                if not cs or not rs or cs < 1 or rs < 1 or cs > 48 or rs > 400 then return original end
                row[#row+1] = {html=withoutIDs(content), colspan=cs, rowspan=rs, tag=tag,
                    class=attr(" " .. attrs,"class")}
            end
            rows[#rows+1] = row
        end
        if #rows > 400 then return original end
        for r, row in ipairs(rows) do
            grid[r] = grid[r] or {}
            local col = 1
            for _, cell in ipairs(row) do
                while grid[r][col] do col=col+1 end
                if col+cell.colspan-1>48 or r+cell.rowspan-1>#rows then return original end
                for y=r,r+cell.rowspan-1 do
                    grid[y] = grid[y] or {}
                    for x=col,col+cell.colspan-1 do
                        if grid[y][x] then return original end
                        grid[y][x] = cell
                    end
                end
                col=col+cell.colspan
            end
            width=math.max(width,col-1)
        end
        if width <= 5 then return original end
        local header_count=0
        local head=inside:match("<thead[^>]*>(.-)</thead>")
        if head then for _ in head:gmatch("<tr[%s>]") do header_count=header_count+1 end end
        local context=1
        if header_count==0 and rows[1] and rows[2] and rows[3]
                and #rows[3]==1 and rows[3][1].colspan==width then
            -- Explicit full-width section separator after a grouped header.
            local grouped=false
            for _,cell in ipairs(rows[1]) do if cell.colspan>1 then grouped=true end end
            if grouped and #rows[2]==width then
                header_count=2
                context=0
                for _,cell in ipairs(rows[1]) do
                    if cell.html:match("^%s*$") and cell.colspan==1 then context=context+1 else break end
                end
                context=math.max(1,math.min(2,context))
            end
        end
        if header_count==0 or header_count>=#rows then return original end
        for r=1,#rows do for c=1,width do if not grid[r][c] then return original end end end
        serial=serial+1
        local base="arxiv-wide-table-"..serial
        while html:find(base,1,true) do base=base.."x" end
        local id=attr(open,"id")
        local source_id=base.."-original"
        local appendix_open=withoutIDs(open):gsub(">$",' id="'..source_id..'">')
        originals[#originals+1]='<section><h2 id="'..base..'-reference">Original table layout '..serial
            ..'</h2><p><a href="#'..base..'">Back to readable column groups</a></p>'
            ..appendix_open..inside..'</table></section>'
        local out={'<div class="reader-table-groups" id="'..base..'">'}
        if id then out[#out+1]='<a id="'..esc(id)..'"></a>' end
        out[#out+1]='<p class="reader-hint">Wide table: column groups below repeat the row labels. '
            ..'<a href="#'..source_id..'">Original layout</a></p>'
        local capacity=4-context
        for first=context+1,width,capacity do
            local last=math.min(width,first+capacity-1)
            local cols={}
            for c=1,context do cols[#cols+1]=c end
            for c=first,last do cols[#cols+1]=c end
            out[#out+1]='<p class="reader-table-label">Columns '..first..'&#8211;'..last..' of '..width..'</p><table class="reader-narrow-table">'
            for r=1,#rows do
                if r==1 then out[#out+1]="<thead>" elseif r==header_count+1 then out[#out+1]="</thead><tbody>" end
                out[#out+1]="<tr>"
                local i=1
                while i<=#cols do
                    local cell=grid[r][cols[i]]
                    local span=1
                    while i+span<=#cols and grid[r][cols[i+span]]==cell do span=span+1 end
                    local tag=r<=header_count and "th" or "td"
                    out[#out+1]='<'..tag..' colspan="'..span..'"'
                        ..(cell.class and (' class="'..esc(cell.class)..'"') or "")..'>'
                        ..cell.html..'</'..tag..'>'
                    i=i+span
                end
                out[#out+1]="</tr>"
            end
            out[#out+1]="</tbody></table>"
        end
        out[#out+1]="</div>"
        return table.concat(out)
    end)
    if #originals>0 then
        html=html:gsub("</body>",function()return '<section class="reader-original-tables"><h1>Original table layouts</h1>'
            ..table.concat(originals)..'</section></body>' end,1)
    end
    return html, #originals
end

function S.prepare(html, paper, balance, absolute, decode)
    html = S.readableTables(html)
    -- arXiv uses <object data="...svg"> for many converted PDF figures.
    -- Normalize before asset discovery; retain reference targets and alt text.
    html = html:gsub("<object%s([^>]*)>(.-)</object>", function(attrs, fallback)
        local tag = "<object " .. attrs .. ">"
        local mime, src = attr(tag,"type"), attr(tag,"data")
        if not src or (mime and not mime:match("^image/")) then
            error("Unsupported embedded figure; EPUB not saved. Use the PDF.")
        end
        local id, alt = attr(tag,"id"), attr(tag,"aria-label") or attr(tag,"title")
        return '<img src="'..esc(decode(src))..'" alt="'..esc(decode(alt or "Refer to caption"))..'"'
            ..(id and (' id="'..esc(decode(id))..'"') or "")..'/>'
    end)

    local assets, by_url, protected = {}, {}, {}
    local token = "ARXIVPROTECTED"
    while html:find(token, 1, true) do token = token .. "X" end
    local function protect(fragment)
        local key = token .. tostring(#protected + 1) .. "END"
        protected[#protected+1] = {key, fragment}
        return key
    end
    -- Never pass MathML through the HTML balancer: keep its semantics and namespace.
    html = html:gsub("<math[%s>].-</math>", function(math)
        if not math:match("^<math[^>]*%sxmlns%s*=") then
            math = math:gsub("^<math", '<math xmlns="http://www.w3.org/1998/Math/MathML"', 1)
        end
        return protect(math)
    end)
    -- Extract vector artwork so KOReader's image viewer can zoom it.
    html = html:gsub("<svg[%s>].-</svg>", function(svg)
        if not svg:match("^<svg[^>]*%sxmlns%s*=") then
            svg = svg:gsub("^<svg", '<svg xmlns="http://www.w3.org/2000/svg"', 1)
        end
        local name = "images/inline-" .. (#assets+1) .. ".svg"
        assets[#assets+1] = {name=name, mime="image/svg+xml", content=svg}
        return '<img src="' .. name .. '" alt="Vector figure"/>'
    end)
    html = html:gsub("<img%s[^>]*>", function(tag)
        local src = attr(tag, "src")
        if not src then error("A figure has no source. Use the PDF for this paper.") end
        -- Already packaged inline SVG.
        if src:match("^images/inline%-%d+%.svg$") then return tag end
        src = decode(src)
        local address = absolute(src)
        if not address or not address:match("^https://arxiv%.org/") then
            error("Unsupported figure source: " .. src .. ". Use the PDF for this paper.")
        end
        local name = by_url[address]
        if not name then
            local ext = address:match("%.([%a%d]+)[?#]?[^/]*$")
            local supported = {svg=true, png=true, jpg=true, jpeg=true, gif=true}
            name = "images/figure-" .. (#assets+1) .. (ext and supported[ext:lower()] and ("." .. ext:lower()) or "")
            assets[#assets+1] = {name=name, url=address}
            by_url[address] = name
        end
        local id = attr(tag, "id")
        local width, height = tonumber(attr(tag,"width")), tonumber(attr(tag,"height"))
        local icon = width and height and width <= 64 and height <= 64
        return '<img src="' .. name .. '" alt="' .. esc(decode(attr(tag,"alt") or "Figure"))
            .. '"' .. (icon and ' class="reader-inline-icon"' or "") .. (id and (' id="' .. esc(decode(id)) .. '"') or "") .. '/>'
    end)
    -- Strip fixed browser layouts outside protected math; retain class semantics.
    html = html:gsub("%sstyle%s*=%s*\"[^\"]*\"", ""):gsub("%sstyle%s*=%s*'[^']*'", "")
    html = balance(html)
    assert(type(html)=="string" and html:find("<body"), "HTML conversion failed")
    for _, entry in ipairs(protected) do
        local count
        html, count = html:gsub(entry[1], function() return entry[2] end)
        assert(count == 1, "Equation was lost during conversion")
    end
    local body = html:match("<body[^>]*>(.-)</body>")
    assert(body, "Converted article has no body")
    local toc, heading_number = {}, 0
    body = body:gsub("<h([1-6])([^>]*)>(.-)</h%1>", function(level, attrs, title)
        heading_number = heading_number+1
        local id = attr(" " .. attrs, "id")
        if not id then id = token .. "heading" .. heading_number attrs = attrs .. ' id="' .. id .. '"' end
        -- Math or markup in a heading should not leak into navigation XML.
        local label = decode(title:gsub("<[^>]+>", ""):gsub("%s+", " "))
        toc[#toc+1] = {id=decode(id), title=label}
        return "<h" .. level .. attrs .. ">" .. title .. "</h" .. level .. ">"
    end)
    local hint = '<p class="reader-hint">Scientific edition. Long-press a figure to zoom. '
        .. 'For wide tables or equations, try landscape orientation or a smaller text size. '
        .. 'Keep embedded styles and fonts enabled.</p>'
    local content = '<?xml version="1.0" encoding="utf-8"?>'
        .. '<html xmlns="http://www.w3.org/1999/xhtml"><head><title>' .. esc(paper.title)
        .. '</title><link rel="stylesheet" type="text/css" href="science.css"/></head><body>'
        .. hint .. body .. '</body></html>'
    return {content=content, assets=assets, toc=toc}
end
function S.imageType(bytes)
    if bytes:sub(1,8) == "\137PNG\r\n\26\n" then return "image/png" end
    if bytes:sub(1,3) == "\255\216\255" then return "image/jpeg" end
    if bytes:sub(1,6) == "GIF87a" or bytes:sub(1,6) == "GIF89a" then return "image/gif" end
    if bytes:sub(1,1000):find("<svg[%s>]") then return "image/svg+xml" end
    return nil
end
function S.package(plan, paper, font, license, add, fetch)
    add("mimetype", "application/epub+zip", true)
    add("META-INF/container.xml", '<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/package.opf" media-type="application/oebps-package+xml"/></rootfiles></container>')
    add("OEBPS/science.css", S.css)
    add("OEBPS/fonts/STIXTwoMath-Regular.otf", font)
    add("OEBPS/fonts/OFL.txt", license)
    local manifest, nav, ncx = {}, {}, {}
    local total = 0
    for i, asset in ipairs(plan.assets) do
        local bytes, err = asset.content
        if not bytes then bytes, err = fetch(asset.url, 20*1024*1024, i, #plan.assets) end
        assert(bytes, err or "Figure download cancelled")
        total = total + #bytes
        assert(total <= 100*1024*1024, "Figures exceed the 100 MiB limit")
        local mime = asset.mime or S.imageType(bytes)
        assert(mime, "An unsupported or invalid figure was returned; EPUB not saved. Use PDF.")
        add("OEBPS/" .. asset.name, bytes)
        manifest[#manifest+1] = '<item id="fig' .. i .. '" href="' .. asset.name .. '" media-type="' .. mime .. '"/>'
    end
    for i, section in ipairs(plan.toc) do
        local href = "article.xhtml#" .. esc(section.id)
        nav[#nav+1] = '<li><a href="' .. href .. '">' .. esc(section.title) .. '</a></li>'
        ncx[#ncx+1] = '<navPoint id="n' .. i .. '" playOrder="' .. i .. '"><navLabel><text>'
            .. esc(section.title) .. '</text></navLabel><content src="' .. href .. '"/></navPoint>'
    end
    if #nav == 0 then nav[1] = '<li><a href="article.xhtml">Article</a></li>' end
    local uid = "https://arxiv.org/abs/" .. paper.id
    local properties = plan.content:find("<math[%s>]") and ' properties="mathml"' or ""
    add("OEBPS/article.xhtml", plan.content)
    add("OEBPS/nav.xhtml", '<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>Contents</title></head><body><nav epub:type="toc"><h1>Contents</h1><ol>' .. table.concat(nav) .. '</ol></nav></body></html>')
    add("OEBPS/toc.ncx", '<?xml version="1.0"?><ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1"><head><meta name="dtb:uid" content="' .. esc(uid) .. '"/></head><docTitle><text>' .. esc(paper.title) .. '</text></docTitle><navMap>' .. table.concat(ncx) .. '</navMap></ncx>')
    add("OEBPS/package.opf", '<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="paper"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="paper">'
        .. esc(uid) .. '</dc:identifier><dc:title>' .. esc(paper.title) .. '</dc:title><dc:creator>'
        .. esc(paper.authors or "") .. '</dc:creator><dc:language>en</dc:language><meta property="dcterms:modified">'
        .. os.date("!%Y-%m-%dT%H:%M:%SZ") .. '</meta></metadata><manifest>'
        .. '<item id="article" href="article.xhtml" media-type="application/xhtml+xml"' .. properties .. '/>'
        .. '<item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>'
        .. '<item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml"/>'
        .. '<item id="css" href="science.css" media-type="text/css"/>'
        .. '<item id="font" href="fonts/STIXTwoMath-Regular.otf" media-type="font/otf"/>'
        .. '<item id="license" href="fonts/OFL.txt" media-type="text/plain"/>'
        .. table.concat(manifest) .. '</manifest><spine toc="ncx"><itemref idref="article"/></spine></package>')
end
function S.create(path, html, paper, url, plugin_dir, fetch)
    local function read(name)
        local f = assert(io.open(plugin_dir .. "/assets/" .. name, "rb"))
        local data = f:read("*a") f:close() return data
    end
    local plan = S.prepare(html, paper,
        function(source) return require("libs/libkoreader-cre").getBalancedHTML(source, 0) end,
        function(src) return require("socket.url").absolute(url, src) end,
        require("util").htmlEntitiesToUtf8)
    local font, license = read("STIXTwoMath-Regular.otf"), read("OFL.txt")
    local writer = require("ffi/archiver").Writer:new()
    local temp = path .. ".part"
    if not writer:open(temp, "epub") then return nil, writer.err or "Cannot create EPUB" end
    local ok, err = pcall(function()
        S.package(plan, paper, font, license, function(name, content, uncompressed)
            assert(writer:setZipCompression(uncompressed and "store" or "deflate"), writer.err)
            assert(writer:addFileFromMemory(name, content), writer.err)
        end, fetch)
    end)
    writer:close()
    if not ok then os.remove(temp) return nil, tostring(err) end
    local renamed, rename_err = os.rename(temp, path)
    if not renamed then os.remove(temp) return nil, rename_err end
    return true
end
return S
