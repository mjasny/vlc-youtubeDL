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

  local file = assert(io.popen('youtube-dl -j '..url, 'r'))  --run youtube-dl in json mode
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
    
    if outurl then
      print("URL: "..outurl)
      print("NAME: "..json.title)
      print('ARTURL: '..json.thumbnail)
      
      local category = nil
      if json.categories then
        category = json.categories[0]
      end
      
      local year = nil
      if json.release_year then
        year = json.release_year
      elseif json.release_date then
        year = string.sub(json.release_date, 1, 4)
      elseif json.upload_date then
        year = string.sub(json.upload_date, 1, 4)
      end

      item = {
          path = outurl;
          name = json.title;
          title = json.fulltitle or json.alt_title;
          artist = json.artist or json.creator or json.uploader;
          genre = json.genre or category;
          copyright = json.license;
          album = json.album or json.series;
          tracknum = json.track_number or json.chapter_number or json.episode_number;
          description = json.description;
          rating = json.average_rating;
          date = year;
          url = json.webpage_url or url;
          arturl = json.thumbnail;
          trackid = json.track_id or json.episode_id or json.id;
          duration = json.duration;
          meta = json;
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
