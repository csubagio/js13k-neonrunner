http = require 'http'
pug = require 'pug'
fs = require 'fs'
coffee = require 'coffee-script'
UglifyJS = require 'uglify-js'
JSZip = require 'jszip'


hostname = '127.0.0.1'
port = 8081

server = http.createServer (req, res) ->
  unless req.url == '/'
    res.statusCode = 404
    return res.end ''

  res.statusCode = 200
  res.setHeader 'Content-Type', 'text/html'
  template = pug.compile fs.readFileSync './index.pug', 'utf8'

  data = { js: '' }
  try
    js = coffee.compile fs.readFileSync('./script.coffee', 'utf8'), {bare: true}
    if true
      ugly = UglifyJS.minify { "script.js": js }, { fromString: true, mangle: { toplevel: true } }
      data.js = ugly.code
    else
      data.js = js
  catch e
    console.error e.toString()

  html = template data
  res.end html

  zip = new JSZip();
  zip.file("neonrunner84.html", html, {compression: "DEFLATE", compressionOptions : {level:9}});
  zip
    .generateNodeStream({type:'nodebuffer',streamFiles:true})
    .pipe(fs.createWriteStream('neonrunner84.zip'))
    .on 'finish', ->
      zipFile = fs.openSync 'neonrunner84.zip', 'r'
      stat = fs.fstatSync zipFile
      fs.close zipFile
      console.log "zip file updated: #{stat.size}bytes, #{Math.floor stat.size/1024}kb"


server.listen port, hostname, ->
  console.log "Server running at http://#{hostname}:#{port}/"
