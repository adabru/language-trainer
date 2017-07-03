#!/usr/bin/env lsc

# return (require './absh').absh {req}

require! [http, fs, util]
print = (s) -> console.log util.inspect s, {+colors, depth:0}


server = http.createServer (req, res) ->
  switch
    case req.url is '/'
      res.writeHead 200, {'Content-Type': 'text/html; charset=utf-8'}
      s = """
        <head>
          <script src=\"/frontend.js\"></script>
          <link rel="stylesheet" type="text/css" href="style.css" />
        </head>
        <div id='app'></div>
        <script>
          frontend.render(document.querySelector("\#app"))
        </script>"""
      res.end s
    default
      p = ".#{req.url}"
      fs.access p, fs.constants.R_OK, (err) ->
        if err?
          res.writeHead 404 ; res.end!
        else
          res.writeHead 200
          _=fs.createReadStream p ; _.pipe res ; _.on 'error', (err) -> (res.end! ; console.log err)

server.listen 2017, "127.0.0.1", -> console.log "Server running at http://127.0.0.1:2017/"
