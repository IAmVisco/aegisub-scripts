--[[
README:

Trims leading and trailing spaces and newlines. Also trims spaces around \N tag. Useful for YouTube CCs.
]]


script_name="Trim spaces"
script_description="Trims spaces and newlines from all selected lines."
script_author="IAmVisco"
script_version="1.0"


function progress(msg) if aegisub.progress.is_cancelled() then aegisub.cancel() end aegisub.progress.title(msg) end

function trim(text)
    text = text:gsub("\\N*$", "")
    text = text:gsub("^\\N*", "")
    text = text:gsub("%s*$", "")
    text = text:gsub("^%s*", "")
    text = text:gsub("%s*\\N%s*", "\\N")

    return text
end

function trim_spaces(subs, sel, act)
    -- si is the index in sel, while ln is the line number in subs
    for si, ln in ipairs(sel) do
        progress("Fixing "..si.."/"..#sel)
        local line = subs[ln]
        -- Double pass in case of mixed spaces and new lines
        line.text = trim(trim(line.text))
        subs[ln] = line
    end

    aegisub.set_undo_point(script_name)
    return sel
end

aegisub.register_macro(script_name, script_description, trim_spaces)