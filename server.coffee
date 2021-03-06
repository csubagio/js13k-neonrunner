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
    data.js = coffee.compile fs.readFileSync('./script.coffee', 'utf8'), {bare: true}
    ugly = UglifyJS.minify { "script.js": data.js }, { fromString: true, mangle: { toplevel: true } }
    data.ugly = ugly.code
  catch e
    console.error e.toString()

  serveUgly = false
  if serveUgly
    data.js = data.ugly

  html = template data
  res.end html

  data.js = data.ugly
  html = template data
  fs.writeFileSync 'neonrunner84.html', html, 'utf8'
  fs.writeFileSync 'index.html', html, 'utf8'

  htmlFile = fs.openSync 'neonrunner84.html', 'r'
  stat = fs.fstatSync htmlFile
  fs.close htmlFile
  console.log "html file updated: #{stat.size}bytes, #{Math.floor stat.size/1024}kb"

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
