JSON = require "dkjson" -- load additional json routines

-- Probe function.
function probe()
  return ( vlc.access == "http" or vlc.access == "https" )
    -- better checks needed ??
end

-- Parse function.
function parse()
  local url = vlc.access.."://"..vlc.path -- get full url
  print( "Using youtube-dl for: "..url )

  --checks if youtube-dl exists, else download the right file or update it

  local file = assert(io.popen('youtube-dl -j --flat-playlist '..url, 'r'))  --run youtube-dl in json mode
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
    if not outurl then
      -- choose best
      for key, format in pairs(json.formats) do
        outurl = format.url
      end
    end
    
    if (json._type == "url" or json._type == "url_transparent") and json.ie_key == "Youtube" then
      outurl = "https://www.youtube.com/watch?v="..outurl
    end
    
    if outurl then
      print("URL: "..outurl)
      print("NAME: "..json.title)
      
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

      item = {
        path         = outurl;
        name         = json.title;
        duration     = json.duration;
        
        title        = json.track or json.title;
        artist       = json.artist or json.creator or json.uploader;
        genre        = json.genre or category;
        copyright    = json.license;
        album        = json.album;
        tracknum     = json.track_number;
        description  = json.description;
        rating       = json.average_rating;
        date         = year;
        --setting
        url          = json.webpage_url or url;
        --language
        --nowplaying
        --publisher
        --encodedby
        arturl       = json.thumbnail or thumbnail;
        trackid      = json.track_id or json.episode_id or json.id;
        --director
        season       = json.season or json.season_number or json.season_id;
        episode      = json.episode or json.episode_number;
        show_name    = json.series;
        --actors
        
        meta         = json;
      }
      table.insert(tracks, item)
    end
  end
  file:close()
  return tracks
end

function trim1(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end

