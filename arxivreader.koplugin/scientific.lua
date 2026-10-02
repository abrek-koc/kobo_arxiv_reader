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
function S.prepare(html, paper, balance, absolute, decode)
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
            name = "images/figure-" .. (#assets+1)
            assets[#assets+1] = {name=name, url=address}
            by_url[address] = name
        end
        local id = attr(tag, "id")
        return '<img src="' .. name .. '" alt="' .. esc(decode(attr(tag,"alt") or "Figure"))
            .. '"' .. (id and (' id="' .. esc(decode(id)) .. '"') or "") .. '/>'
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
