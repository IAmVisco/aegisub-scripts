--[[
Creates easy video clips from Aegisub.

Guide here:
https://idolactivities.github.io/vtuber-things/guides/clipper.html

]] --
---------------------
-- BASIC CONSTANTS --
---------------------
script_name = 'Clipper'
script_description = 'Encode a video clip based on the subtitles.'
script_version = '1.0.2'

clipboard = require('aegisub.clipboard')

ENCODE_PRESETS = {
    ['Test Encode (fast)'] = {
        options = '-c:v libx264 -preset ultrafast -tune zerolatency -c:a aac',
        extension = '.mp4'
    },
    ["Twitter Encode (quick and OK quality, MP4)"] = {
        options = "-c:v libx264 -preset slow -profile:v high -level 3.2 -tune film -c:a aac",
        extension = ".mp4"
    },
    ["YouTube Encode (quick and good quality, MP4)"] = {
        options = "-c:v libx264 -preset slow -profile:v high -level 4.2 -crf 20 -c:a aac",
        extension = ".mp4"
    },
    ["YouTube Encode (very slow but better quality/size, WebM)"] = {
        options = '-c:v libvpx-vp9 -row-mt 1 -cpu-used 2 -crf 20 -b:v 0 -c:a libopus',
        extension = ".webm"
    }
}

CONFIG_PATH = aegisub.decode_path('?user/clipper.conf')

global_config = {version = script_version}

-------------------
-- GENERAL UTILS --
-------------------

function file_exists(name)
    local f = io.open(name, 'r')
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end

function split_ext(fname) return string.match(fname, '(.-)%.([^%.]+)$') end

function table.keys(tb)
    local keys = {}
    for k, v in pairs(tb) do table.insert(keys, k) end
    return keys
end

function table.values(tb)
    local values = {}
    for k, v in pairs(tb) do table.insert(values, v) end
    return values
end

function table.update(t1, t2) for k, v in pairs(t2) do t1[k] = v end end

--------------------------
-- FIND FFMPEG BINARIES --
--------------------------

function find_bin_or_error(name)
    -- Check user directory
    -- This should take precedence, as it is recommended by the install instructions
    local file = aegisub.decode_path(
                     ('?user/automation/autoload/bin/%s'):format(name))
    if file_exists(file) then return file end

    -- If that fails, check install directory
    local file = aegisub.decode_path(
                     ('?data/automation/autoload/bin/%s'):format(name))
    if file_exists(file) then return file end

    -- If that fails, check for executable in path
    local path = os.getenv('PATH') or ''
    for prefix in path:gmatch('([^:]+):?') do
        local file = prefix .. '/' .. name
        if file_exists(file) then return name end
    end

    -- Else, error
    error(('Could not find %s.' ..
              'Make sure it is in Aegisub\'s "automation/autoload/bin" folder ' ..
              'or in your PATH.'):format(name))
end

FFMPEG = find_bin_or_error('ffmpeg.exe')
FFPROBE = find_bin_or_error('ffprobe.exe')

function filter_complex(subtitle_file)
    local vin_filter = {
        '[0:v]format=pix_fmts=rgb32,', -- convert input video to raw before hardsubbing
        ('ass=\'%s\'[v1];'):format(subtitle_file:gsub('\\', '\\\\'):gsub(':', '\\:')), -- apply ASS subtitle filter
        '[v1]format=pix_fmts=yuv420p'
    }
    return table.concat(vin_filter)
end

--------------------
-- ENCODING UTILS --
--------------------

function run_as_batch(cmd, callback, mode)
    local temp_file = aegisub.decode_path('?temp/clipper.bat')
    local fh = io.open(temp_file, 'w')
    fh:write('setlocal\r\n')
    fh:write(cmd .. '\r\n')
    fh:write('endlocal\r\n')
    fh:close()

    local res = nil
    -- If a callback is provided, run it on the process output
    if callback ~= nil then
        if mode == nil then mode = 'r' end
        local pipe = assert(io.popen('"' .. temp_file .. '"', 'r'))
        callback(pipe)
        res = {pipe:close()}
        res = res[1]
        -- Otherwise, just execute it
    else
        res = os.execute('"' .. temp_file .. '"')
    end

    -- Cleanup and return the exit code
    os.remove(temp_file)
    return res
end

function id_colorspace(video)
    local values = {}

    local cmd = ('"%s" -show_streams -select_streams v "%s"'):format(FFPROBE,
                                                                     video)

    local res = run_as_batch(cmd, function(pipe)
        for line in pipe:lines() do
            if line:match('^color') then
                local key, value = line:match('^([%w_]+)=(%w+)$')
                if key then values[key] = value end
            end
        end
    end)

    -- https://kdenlive.org/en/project/color-hell-ffmpeg-transcoding-and-preserving-bt-601/
    if values['color_space'] == 'bt470bg' then
        return 'bt470bg', 'gamma28', 'bt470bg'
    else
        if values['color_space'] == 'smpte170m' then
            return 'smpte170m', 'smpte170m', 'smpte170m'
        else
            return values['color_space'], values['color_transfer'],
                   values['color_primaries']
        end
    end
end

function encode_cmd(video, options, filter, output, logfile_path)
    local command = {
        ('"%s"'):format(FFMPEG),
        ('-i "%s"'):format(video), options,
        ('-filter_complex "%s"'):format(filter),
        ('-color_primaries %s -color_trc %s -colorspace %s'):format(id_colorspace(video)), ('"%s"'):format(output)
    }

    local set_env = ('set "FFREPORT=file=%s:level=32"\r\n'):format(
                        logfile_path:gsub('\\', '\\\\'):gsub(':', '\\:'))

    return set_env .. table.concat(command, ' ')
end

-----------------------------
-- CONFIG/DIALOG FUNCTIONS --
-----------------------------

function show_info(message, extra)
    local buttons = {'OK'}
    local button_ids = {ok = 'OK'}

    -- This is only used internally, so just lazy match links
    local link = message:match('http[s]://%S+')
    if link then buttons = {'Copy link', 'OK'} end

    dialog = {
        -- Top left margin
        {class = 'label', label = '    ', x = 0, y = 0, width = 1, height = 1},
        {class = 'label', label = message, x = 1, y = 1, width = 1, height = 1}
    }

    if extra ~= nil and type(extra) == 'table' then
        for _, control in ipairs(extra) do table.insert(dialog, control) end
    end

    -- Bottom right margin
    table.insert(dialog, {
        class = 'label',
        label = '    ',
        x = 2,
        y = dialog[#dialog].y + 1,
        width = 1,
        height = 1
    })

    local is_okay = nil
    while is_okay ~= 'OK' do
        is_okay, results = aegisub.dialog.display(dialog, buttons, button_ids)

        if is_okay == 'Copy link' then clipboard.set(link) end
    end
    return results
end

function show_help(key, message, show_hide_confirmation)
    if global_config['skip_help'][key] ~= nil then return end

    if show_hide_confirmation == nil then show_hide_confirmation = true end

    local extras = nil
    if show_hide_confirmation then
        extras = {
            {
                class = 'checkbox',
                label = 'Don\'t show this message again',
                name = 'skip',
                value = false,
                x = 1,
                y = 3,
                width = 1,
                height = 1
            }
        }
    end

    results = show_info(message, extras)

    if results['skip'] then global_config['skip_help'][key] = true end
end

function init_config()
    global_config['preset'] = table.keys(ENCODE_PRESETS)[1]
    global_config['skip_help'] = {}

    show_help('welcome', 'Welcome to Clipper! If this is your first time\n' ..
                  'using Clipper, please read the guide here:\n\n' ..
                  'https://idolactivities.github.io/vtuber-things/guides/clipper.html#usage',
              false)

    save_config()
end

function update_config_version(conf)
    -- To be written if a future update changes the configuration format
    return conf
end

function save_config()
    conf_fp = io.open(CONFIG_PATH, 'w')

    global_config['clipname'] = nil

    for k, v in pairs(global_config) do
        -- Lists always end in a comma
        if type(v) == 'table' then
            -- But they are stored as keys to a table
            v = table.concat(table.keys(v), ',') .. ','
        end
        conf_fp:write(('%s = %s\n'):format(k, v))
    end

    conf_fp:close()
end

function load_config()
    if not file_exists(CONFIG_PATH) then return init_config() end

    conf = {}
    conf_fp = io.open(CONFIG_PATH, 'r')

    for line in conf_fp:lines() do
        -- Strip leading whitespace
        line = line:match('%s*(.+)')

        -- Skip empty lines and comments
        if line and line:sub(1, 1) ~= '#' and line:sub(1, 1) ~= ';' then
            option, value = line:match('(%S+)%s*[=:]%s*(.*)')

            -- Lists always end in a comma
            if value:sub(-1) == ',' then
                values = {}
                -- But we store them as keys for easy indexing
                for k in value:gmatch('%s*([^,]+),') do
                    values[k] = true
                end
                conf[option] = values
            else
                conf[option] = value
            end
        end
    end

    if conf['version'] ~= script_version then
        conf = update_config_version(conf)
    end

    table.update(global_config, conf)

    conf_fp:close()
end

function find_unused_clipname(output_dir, basename)
    -- build a set of extensions that our presets may have
    local extensions = {}
    for k, v in pairs(ENCODE_PRESETS) do extensions[v['extension']] = true end

    local suffix = 2
    local clipname = basename
    -- check if our clipname exists with any of the preset extensions and bump
    -- the clipname with a suffix until one doesn't exist
    while (true) do
        local exists = false
        for ext, _ in pairs(extensions) do
            exists = file_exists(output_dir .. clipname .. ext)
            if exists then break end
        end
        if exists then
            clipname = basename .. '-' .. suffix
            suffix = suffix + 1
        else
            break
        end
    end

    return clipname
end

function confirm_overwrite(filename)
    local config = {
        {
            class = 'label',
            label = ('Are you sure you want to overwrite %s?'):format(filename),
            x = 0,
            y = 0,
            width = 4,
            height = 2
        }
    }
    local buttons = {'Yes', 'Cancel'}
    local button_ids = {ok = 'Yes', cancel = 'Cancel'}
    local button, _ = aegisub.dialog.display(config, buttons, button_ids)
    if button == false then aegisub.cancel() end
end

function select_clip_options(clipname)
    local config = {
        {class = 'label', label = 'Preset', x = 0, y = 0, width = 1, height = 1},
        {
            class = 'dropdown',
            name = 'preset',
            items = table.keys(ENCODE_PRESETS),
            value = global_config['preset'],
            x = 2,
            y = 0,
            width = 2,
            height = 1
        },
        {
            class = 'label',
            label = 'Clip Name',
            x = 0,
            y = 1,
            width = 1,
            height = 1
        }, {
            class = 'edit',
            name = 'clipname',
            value = clipname,
            x = 2,
            y = 1,
            width = 2,
            height = 1
        }
    }
    local buttons = {'OK', 'Cancel'}
    local button_ids = {ok = 'OK', cancel = 'Cancel'}
    local button, results = aegisub.dialog.display(config, buttons, button_ids)
    if button == false then aegisub.cancel() end

    table.update(global_config, results)
    save_config()

    return results
end

---------------------------
-- MAIN CLIPPER FUNCTION --
---------------------------

function clipper(sub, _, _)
    -- path of video
    local video_path = aegisub.project_properties().video_file
    -- path/filename of subtitle script
    local work_dir = aegisub.decode_path('?script') .. package.config:sub(1, 1)
    local ass_fname = aegisub.file_name()
    local ass_path = work_dir .. ass_fname

    load_config()

    local clipname = find_unused_clipname(work_dir, split_ext(ass_fname))
    local results = select_clip_options(clipname)
    local output_path = work_dir .. results['clipname'] .. ENCODE_PRESETS[results['preset']]['extension']
    local options = ENCODE_PRESETS[results['preset']]['options']

    if file_exists(output_path) then
        if output_path == video_path then
            show_info(('The specified output file (%s) is the same as\n' ..
                          'the input file, which isn\'t allowed. Specify\n' ..
                          'a different clip name instead.'):format(output_path))
            aegisub.cancel()
        end
        confirm_overwrite(output_path)
        options = options .. ' -y'
    end

    local logfile_path = work_dir .. clipname .. '_encode.log'

    -- Generate a ffmpeg filter of selects for the line segments
    local filter = filter_complex(ass_path)
    local cmd = encode_cmd(video_path, options, filter, output_path, logfile_path)

    aegisub.progress.task('Encoding your video...')
    res = run_as_batch(cmd)


    if res == nil then
        show_info(('FFmpeg failed to complete! Try the troubleshooting\n' ..
                      'here to figure out what\'s wrong:\n\n' ..
                      'https://idolactivities.github.io/vtuber-things/guides/clipper.html#troubleshooting\n\n' ..
                      'Detailed information saved to:\n\n%s'):format(
                      logfile_path))
        aegisub.cancel()
    end

    -- The user doesn't need to see the log file unless the encoding fails
    os.remove(logfile_path)
end

function validate_clipper(sub, sel, _)
    if aegisub.decode_path('?script') == '?script' or
        aegisub.decode_path('?video') == '?video' then return false end
    return true
end

aegisub.register_macro(script_name, script_description, clipper, validate_clipper)
