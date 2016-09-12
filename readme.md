# Neon Runner '84

This is a game made for the gamejam over at http://2016.js13kgames.com Compressed in the zip file, the whole thing comes in at just under 13 kilobytes of data!

It was built primarily in coffee-script, using WebGL and WebAudio in the browser. There's a minimal server in the package whose job is to build the project. When run, you can navigate to the root of localhost:8081, and you'll find the game running in a debuggable state, while the packed and minified html and zip files have been refreshed on disk.

WebGL is basically a dream to work with: pretty much everything worked as I'd imagine it would right out of the box. Performance is still variable, but given the stability of the ES2 standard, the browser meisters can work behind the scenes to keep improving while us devs get to work making content.

Graphics for this game were largely generated in pixel shaders, using what amounts to layers of plotting functions.

WebAudio, on the other hand, is still an unpredictable, nightmarish mess. Case in point? Back here in September of 2016, In Firefox you can't fade gain to 0... because 0 isn't a positive number. Uh huh. *Sigh*

If you're lucky, Chrome will still playback the sound in this game the way I authored it back in Chrome v52. Whether it'll continue to work in the future is seriously anybody's guess. If it sounds like a cat being strangled by a tardis, then hit M in digust to disable sound all together.

Otherwise though, this was a *TON* of fun, and I'd recommend the jam to anyone who's into game development. Here's to JS13k 2017!
