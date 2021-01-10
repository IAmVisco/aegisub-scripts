--[[
README:

Replaced all occurrences of "@" symbol with newline and prepends height mod to all selected lines.
Height mod is constant as of now (for my font) and is equal to -0.0015.
]]


script_name="Fix line height"
script_description="Fixes line height distance in double lines. Useful if your font has weird spacing."
script_author="IAmVisco"
script_version="1.0"


function progress(msg) if aegisub.progress.is_cancelled() then aegisub.cancel() end aegisub.progress.title(msg) end
function show_dialog(msg) aegisub.dialog.display({{class="label", label=msg}}, {"OK"}, {ok='OK'}) end

function fix_line_height(subs, sel, act)
    local height_mod = -0.0015
    local show_warning = false
    local newline_pattern = "%{\\r%}\\N"
    -- si is the index in sel, while ln is the line number in subs
    for si, ln in ipairs(sel) do
        progress("Fixing "..si.."/"..#sel)
        line = subs[ln]
        text = line.text

        if not text:match("@") then
            show_warning = true;
        else
            text="{\\org(-2000000,0)\\fr"..height_mod.."}"..text:gsub("%s*@%s*", newline_pattern)
        end

        line.text = text
        subs[ln] = line
    end

    if show_warning then
        show_dialog("Not all lines were affected.")
    end

    aegisub.set_undo_point(script_name)
    return sel
end

aegisub.register_macro(script_name, script_description, fix_line_height)