JSON = require "dkjson" -- load additional json routines

-- Probe function.
function probe()
    if vlc.access == "http" or vlc.access == "https" then
        peeklen = 9
        s = ""
        while string.len(s) < 9 do
            s = string.lower(string.gsub(vlc.peek(peeklen), "%s", ""))
            peeklen = peeklen + 1
        end
        return s == "<!doctype"
    else
        return false
    end
end

function _get_format_url(format)
    -- prefer streaming formats
    if format.manifest_url then
        return format.manifest_url
    else
        return format.url
    end
end

-- Parse function.
function parse()
    local url = vlc.access .. "://" .. vlc.path -- get full url

    -- Function to execute command and return file handle or nil on failure
    local function execute_command(command)
        local file = io.popen(command, 'r')
        if file then
            local output = file:read("*a")    -- Attempt to read something to check if command worked
            if output == "" then              -- If nothing was read, assume command failed (like command not found)
                file:close()                  -- Important to close to avoid resource leaks
                return nil                    -- Indicate failure
            else
                file:close()                  -- Close and reopen for actual usage
                return io.popen(command, 'r') -- Reopen since we consumed the initial read
            end
        else
            return nil -- Command execution failed
        end
    end

    -- Try executing youtube-dl command
    local file = execute_command('youtube-dl -j --flat-playlist "' .. url .. '"')
    if not file then
        -- If youtube-dl fails, try yt-dlp as a fallback
        file = assert(execute_command('yt-dlp -j --flat-playlist "' .. url .. '"'),
            "Both youtube-dl and yt-dlp failed to execute.")
    end


    local tracks = {}
    while true do
        local output = file:read('*l')

        if not output then
            break
        end

        local json = JSON.decode(output) -- decode the json-output from youtube-dl

        if not json then
            break
        end

        local outurl = json.url
        local out_includes_audio = true
        local audiourl = nil
        if not outurl then
            if json.requested_formats then
                for key, format in pairs(json.requested_formats) do
                    if format.vcodec ~= (nil or "none") then
                        outurl = _get_format_url(format)
                        out_includes_audio = format.acodec ~= (nil or "none")
                    end

                    if format.acodec ~= (nil or "none") then
                        audiourl = _get_format_url(format)
                    end
                end
            else
                -- choose best
                for key, format in pairs(json.formats) do
                    outurl = _get_format_url(format)
                end
                -- prefer audio and video
                for key, format in pairs(json.formats) do
                    if format.vcodec ~= (nil or "none") and format.acodec ~= (nil or "none") then
                        outurl = _get_format_url(format)
                    end
                end
            end
        end

        if outurl then
            if (json._type == "url" or json._type == "url_transparent") and json.ie_key == "Youtube" then
                outurl = "https://www.youtube.com/watch?v=" .. outurl
            end

            local category = nil
            if json.categories then
                category = json.categories[1]
            end

            local year = nil
            if json.release_year then
                year = json.release_year
            elseif json.release_date then
                year = string.sub(json.release_date, 1, 4)
            elseif json.upload_date then
                year = string.sub(json.upload_date, 1, 4)
            end

            local thumbnail = nil
            if json.thumbnails then
                thumbnail = json.thumbnails[#json.thumbnails].url
            end

            jsoncopy = {}
            for k in pairs(json) do
                jsoncopy[k] = tostring(json[k])
            end

            json = jsoncopy

            item = {
                path        = outurl,
                name        = json.title,
                duration    = json.duration,

                -- for a list of these check vlc/modules/lua/libs/sd.c
                title       = json.track or json.title,
                artist      = json.artist or json.creator or json.uploader or json.playlist_uploader,
                genre       = json.genre or category,
                copyright   = json.license,
                album       = json.album or json.playlist_title or json.playlist,
                tracknum    = json.track_number or json.playlist_index,
                description = json.description,
                rating      = json.average_rating,
                date        = year,
                --setting
                url         = json.webpage_url or url,
                --language
                --nowplaying
                --publisher
                --encodedby
                arturl      = json.thumbnail or thumbnail,
                trackid     = json.track_id or json.episode_id or json.id,
                tracktotal  = json.n_entries,
                --director
                season      = json.season or json.season_number or json.season_id,
                episode     = json.episode or json.episode_number,
                show_name   = json.series,
                --actors

                meta        = json,
                options     = { "start-time=" .. (json.start_time or 0) },
            }

            if not out_includes_audio and audiourl and outurl ~= audiourl then
                item['options'][':input-slave'] = ":input-slave=" .. audiourl;
            end

            table.insert(tracks, item)
        end
    end
    file:close()
    return tracks
end
