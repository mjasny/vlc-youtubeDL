JSON = (loadfile "JSON.lua")() -- load additional json routines

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
  local output = trim1(file:read('*all'))
  file:close()

  local json = JSON:decode(output) -- decode the json-output from youtube-dl

  if json then
    print("URL: "..json.url)
    print("NAME: "..json.title)
    print('ARTURL: '..json.thumbnail)

    return { { path = json.url; name = json.title; arturl = json.thumbnail;} }
  end
  print("youtube-dl is not supporting this site.")
  return { {} }
end

function trim1(s)
  return (s:gsub("^%s*(.-)%s*$", "%1"))
end
