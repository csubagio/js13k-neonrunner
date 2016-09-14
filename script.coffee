
for k in ['abs','sin','cos','min','max','PI', 'floor', 'random', 'pow', 'round', 'sign']
  window[k] = Math[k]

Array::nextLooped = (v, s) ->
  i = @indexOf v
  i ?= 0
  i = (i+s) % @length
  @[i]

Array::random = -> @[floor random()*@length*0.99]
Array::shuffle = ->
  for i in [1...@length]
    if random() > 0.5
      [@[i], @[0]] = [@[0], @[i]]
  return @


viewportWidth = 512

lerp = (a,b,v) -> a + (b-a) * v
clamp = (a,b,v) -> min(b,max(a,v))
worldClamp = (v) -> min(1,max(-1,v))


canvas = document.getElementById('b')
canvas.width=canvas.height=viewportWidth
gl = canvas.getContext 'webgl'


f32 = (arr) -> new Float32Array(arr)


compile = (source, type) ->
  shader = gl.createShader type
  gl.shaderSource shader, source
  gl.compileShader shader
  success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);
  unless success
    throw "could not compile shader:" + gl.getShaderInfoLog(shader)
  return shader

program = (vertSource, fragSource) ->
  vert = compile vertSource, gl.VERTEX_SHADER
  frag = compile fragSource, gl.FRAGMENT_SHADER
  prog = gl.createProgram()
  gl.attachShader prog, vert
  gl.attachShader prog, frag
  gl.linkProgram prog
  return prog


generateSpriteProgram = (fragment) ->
  program "
      uniform vec3 x;
      uniform vec3 m;
      attribute vec3 p;
      varying vec4 u;
      varying vec4 q;
      void main() {
        vec3 t=p*0.5+x*2.0;
        float div=t.z*0.6+0.4;
        gl_Position=vec4(t.xy-m.xy*div,t.z / 100.0,div);
        u.xy=p.xy;
        u.zw=p.xy+x.xy;
        q.xy=m.xy;
        q.zw=x.xy;
      }
    ","
      precision mediump float;
      varying vec4 u;
      varying vec4 q;
      uniform float t;
      void main() { #{fragment} }
    "

ballProg = generateSpriteProgram "
    vec3 nrm = normalize(vec3(u.xy,1.0));
    vec3 lig = normalize(vec3(u.zw,1.0));
    float d=smoothstep(0.3, 0.95, dot(nrm,lig));
    gl_FragColor.rgb=mix(vec3(0.96,0.8,0.38),vec3(0.54,0.08,0.5),d);
    gl_FragColor.w=min(1.0,smoothstep(0.85,0.84,length(u.xy))+smoothstep(1.0,0.85,length(u.xy)));
    gl_FragColor.rgb*=gl_FragColor.w;
    if(gl_FragColor.a <= 0.0) {
      discard;
    }
  "

hoopProg = generateSpriteProgram "
    vec3 nrm = normalize(vec3(u.xy,1.0));
    vec3 lig = normalize(vec3(u.zw,1.0));
    float d=smoothstep(0.3, 0.95, dot(nrm,lig));
    gl_FragColor.rgb=mix(vec3(0.96,0.8,0.38),vec3(0.54,0.08,0.5),d);
    gl_FragColor.w=sin(smoothstep(0.5,1.0,length(u.xy))*3.14);
    gl_FragColor.rgb*=gl_FragColor.w;
    if(gl_FragColor.a <= 0.0) {
      discard;
    }
  "

portProg = generateSpriteProgram "
    vec2 p=u.xy;
    float d=1.0-length(p.xy);
    p+=(-q.xy+q.zw)*(1.0-length(p.xy));
    gl_FragColor.rgb=mix(vec3(1.2,0.3,0.5),vec3(0.54,0.08,0.5),pow(d,0.2));
    gl_FragColor.w=smoothstep(-0.5,-0.2,sin(length(p.xy)*3.14*4.0+t*2.0));
    gl_FragColor.w=min(1.0,gl_FragColor.w+smoothstep(0.75,0.76,1.0-d));
    gl_FragColor.w*=smoothstep(1.0,0.95,length(p.xy));
    gl_FragColor.rgb*=gl_FragColor.w;
    if(gl_FragColor.a <= 0.0) {
      discard;
    }
  "


lazerProg = program "
    uniform vec3 x;
    uniform vec3 m;
    attribute vec3 p;
    varying vec2 u;
    void main() {
      vec3 t;
      t.xy=p.x*normalize(x.yx*vec2(1,-1))*0.2;
      t.z=p.z*3.0;
      t+=x*2.0;
      float div=t.z*0.6+0.4;
      gl_Position=vec4(t.xy-m.xy*div,t.z / 100.0,div);
      u=p.xz;
    }
  ","
    precision mediump float;
    varying vec2 u;
    void main() {
      vec4 c;
      float f=cos(u.x*1.57);
      c.rgb=vec3(0.94,0.18,0.8)*smoothstep(0.0,0.4,f);
      c.rgb*=1.0+smoothstep(0.4,0.7,f);
      c.w=0.0;
      gl_FragColor=c;
    }
  "

presentProg = program "
    attribute vec4 p;
    varying vec4 u;
    void main() {
      gl_Position=p;
      u.xy=p.xy*0.5+0.5;
      u.y=1.0-u.y;
      u.zw=p.xy;
    }
  ","
    precision mediump float;
    uniform sampler2D s;
    uniform float t;
    varying vec4 u;
    void main() {
      gl_FragColor=texture2D(s,u.xy);
      gl_FragColor.rgb+=vec3(0.8,0.5,0.9)*smoothstep(0.98,1.0,sin(u.x-u.y*3.0-t*0.34));
      gl_FragColor.rgb*=gl_FragColor.a;
      float d=length(max(vec2(0.0),abs(u.zw)-vec2(0.8)))/0.2;
      d=smoothstep(0.9,1.0,d);
      float v=smoothstep(1.0,0.5,length(u.zw))+1.0;
      gl_FragColor.rgb+=mix(vec3(0.1,0.0,0.05),vec3(0.11,0.10,0.18),u.z+u.w)*v;
      gl_FragColor.rgb=mix(gl_FragColor.rgb,vec3(0.086,0.043,0.16),d);
      gl_FragColor.a+=d;
    }
  "

sunProg = program "
    attribute vec4 p;
    varying vec2 u;
    void main(){gl_Position=vec4(p.xy,1.0,1.0);u=p.xy;}
  ","
    precision mediump float;
    uniform float t;
    uniform vec3 m;
    varying vec2 u;
    void main() {
      vec2 s=u*2.0+m.xy*2.0;vec4 c;c.a=1.0;vec2 p=u+m.xy;
      float g=0.0;
      c.rgb=mix(vec3(0.8,0.22,0.6),vec3(0.96,0.8,0.38),s.y*0.5+0.5);
      float d=length(s);
      if(s.y<0.0){
        c.a=smoothstep(-s.y,1.0,0.5+0.5*sin(s.y*60.0+t));
      }
      p.y+=cos(p.x)*sign(p.y)*-0.05;
      g=pow(abs(sin(p.x/(-abs(p.y)*0.8-0.2)*20.0)),64.0);
      g+=pow(abs(sin(abs(p.y)*40.0-t*2.0)),64.0);
      g*=smoothstep(0.0,0.4,abs(p.y));
      c.a*=smoothstep(1.0,0.96,d);
      c.rgb=mix(
        mix( mix(vec3(0.54,0.08,0.5),vec3(0.08,0.04,0.16),length(s)*0.7),vec3(0.54,0.08,0.49),g ),
        c.rgb,
        c.a);
      c.a=1.0;
      c.rgb+=vec3(0.94,0.38,0.7)*pow(smoothstep(1.0-abs(s.x)*0.3,0.0,abs(s.y)),32.0);
      gl_FragColor=c;}
  "

starProg = program "
    attribute vec4 p;
    uniform vec3 m;
    uniform float t;
    varying vec2 u;
    void main(){
      vec2 x;
      float a = t/5000.0 * p.z;
      x.x = sin(a) * p.x + cos(a) * p.y;
      x.y = cos(a) * p.x - sin(a) * p.y;
      gl_Position=vec4(x-m.xy,1.0,1.0);
      u=p.xy;
      gl_PointSize = p.z * max(0.0,x.y) * sin(t*0.05*p.z+p.z);
    }
  ","
    precision mediump float;
    void main() {
      gl_FragColor=vec4(0.9,0.6,0.8,0.0)*pow(1.0-length(gl_PointCoord-0.5),8.0);
    }
  "


explodeProg = program "
    attribute vec4 p;
    uniform vec3 m, x;
    uniform vec2 t;
    varying vec4 u;
    void main(){
      vec3 l;
      float a=t.y*7.28;
      l.x=sin(a)*p.x+cos(a)*p.y*0.5;
      l.y=cos(a)*p.x-sin(a)*p.y*0.5;
      l.z=(p.z+0.2)*-15.0*pow(t.x,1.6);
      float s=sin(p.z*3.14);
      float d=pow(t.x,0.6)*pow(s,2.0)*7.0;
      l.xy*=d;
      l+=x*2.0;
      float div=l.z*0.6+0.4;
      gl_Position=vec4(l.xy-m.xy*div,l.z / 100.0,div);
      u.xy=l.xz;
      u.z=t.x;
      u.w=mod(p.z+t.x*2.3, 1.0);
      gl_PointSize=(0.2+s*s*s)*100.0/div;
    }
  ","
    precision mediump float;
    varying vec4 u;
    void main() {
      float a=smoothstep(0.1,0.2,u.y);
      vec2 x=gl_PointCoord.xy*2.0-1.0;
      if(u.w>0.5){x.y*=3.0+u.w-0.5;}
      else{x.x*=2.0+u.w;}
      float d=max(abs(x.x),abs(x.y));
      a*=smoothstep(1.0,1.0-u.z,d);
      gl_FragColor.rgb=mix(vec3(0.96,0.8,0.38),vec3(0.54,0.08,0.49),smoothstep(0.4,0.6,u.w))*a;
      gl_FragColor.w=a;
    }
  "

buffer = (verts) ->
  buf = gl.createBuffer()
  gl.bindBuffer gl.ARRAY_BUFFER, buf
  gl.bufferData gl.ARRAY_BUFFER, f32(verts), gl.STATIC_DRAW
  buf.count = verts.length / 3
  return buf

sunBuffer = buffer [
  -1,  1, 1,
   1,  1, 1,
  -1, -1, 1,
   1,  1, 1,
   1, -1, 1,
  -1, -1, 1,
]

quadBuffer = buffer [
  -1,  1, 0,
   1,  1, 0,
  -1, -1, 0,
   1,  1, 0,
   1, -1, 0,
  -1, -1, 0,
]

lazerBuffer = buffer [
  -1, 0, 0
   1, 0, 0
  -1, 0, 1
   1, 0, 0
   1, 0, 1
  -1, 0, 1
]

starBuffer = []
for i in [0...800]
  a = random() * PI * 2
  d = pow( 0.24 + random() * 1.8, 0.5 )
  starBuffer.push cos(a) * d
  starBuffer.push sin(a) * d
  starBuffer.push 2 + random() * 10

starBuffer = buffer starBuffer

explodeBuffer = []
for i in [0...100]
  a = random() * PI * 2
  d = pow( 0.1 + 0.9 * random(), 0.5 )
  explodeBuffer.push cos(a) * d
  explodeBuffer.push sin(a) * d
  explodeBuffer.push random()

explodeBuffer = buffer explodeBuffer


t = 0

playerX = 0
playerY = 1
playerZ = 0.8

cam = [0,0,0]
drawBuffer = (buf, prog, x, y, z, point) ->
  gl.bindBuffer gl.ARRAY_BUFFER, buf
  gl.enableVertexAttribArray 0
  gl.vertexAttribPointer 0, 3, gl.FLOAT, false, 0, 0
  gl.useProgram prog
  p = gl.getUniformLocation prog, 'm'
  gl.uniform3fv p, cam
  p = gl.getUniformLocation prog, 't'
  gl.uniform1f p, t
  p = gl.getUniformLocation prog, 'x'
  gl.uniform3f p, x, y, z
  p = gl.getUniformLocation prog, 's'
  gl.uniform1i p, 0
  gl.enable gl.BLEND
  gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
  if point
    gl.drawArrays gl.POINTS, 0, buf.count
  else
    gl.drawArrays gl.TRIANGLES, 0, buf.count


drawParticleBuffer = (buf, prog, x, y, z, age, seed) ->
  gl.bindBuffer gl.ARRAY_BUFFER, buf
  gl.enableVertexAttribArray 0
  gl.vertexAttribPointer 0, 3, gl.FLOAT, false, 0, 0
  gl.useProgram prog
  p = gl.getUniformLocation prog, 'm'
  gl.uniform3fv p, cam
  p = gl.getUniformLocation prog, 't'
  gl.uniform2f p, age, seed
  p = gl.getUniformLocation prog, 'x'
  gl.uniform3f p, x, y, z
  gl.enable gl.BLEND
  gl.blendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA);
  gl.drawArrays gl.POINTS, 0, buf.count



buttons =
  up: false
  down: false
  left: false
  right: false
  fire: false

bounced =
  fire: false

updatePaused = false
musicMuted = true

if /Chrome/.test(navigator.userAgent) && /Google Inc/.test(navigator.vendor)
  musicMuted = false

keys = (e, val) ->
  switch e.keyCode
    when 38 then buttons.up = val
    when 40 then buttons.down = val
    when 37 then buttons.left = val
    when 39 then buttons.right = val
    when 32
      if val and not buttons.fire
        bounced.fire = true
      buttons.fire = val   # s pace
    when 77 #m
      musicMuted = not musicMuted if val
    when 80 #p
      updatePaused = not updatePaused if val

document.onkeydown = (e) -> keys(e, true)
document.onkeyup = (e) -> keys(e, false)



textCanvas = document.createElement 'canvas'
textCanvas.width = textCanvas.height = viewportWidth
textContext = textCanvas.getContext '2d'

#document.body.insertBefore textCanvas, document.getElementById('b')

textTexture = gl.createTexture()
gl.activeTexture gl.TEXTURE0
gl.bindTexture gl.TEXTURE_2D, textTexture
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, textCanvas


textSize = floor viewportWidth/11

textGradient = textContext.createLinearGradient 0,5,0,textSize
inverseTextGradient = textContext.createLinearGradient 0,5,0,textSize

for s in [['#000853', 0.1],['#4a50b9', 0.3],['#cae2fa',0.53],['#120d13',0.55],['#241128',0.6],['#612958',0.75],['#ac28be',0.85],['#cea8d4',1.0]]
  textGradient.addColorStop s[1],s[0]

for s in [['#18161c',1], ['#424281',0.5], ['#a2b2d6',0]]
  inverseTextGradient.addColorStop s[1],s[0]

fireCooldown = 0

bullets = for i in [0..20]
  { on: false, x: 0, y: 0, z: 0 }

print = (x, y, alpha, text) ->
  textContext.save()
  textContext.translate x, y
  textContext.scale 1.1, 0.85
  textContext.globalAlpha = alpha
  textContext.textAlign = 'center'
  textContext.font = "#{textSize}px futura, 'Bauhaus 93', 'Trebuchet MS', Arial, sans-serif"
  textContext.textBaseline = "top"

  textContext.strokeStyle = '#a40690'
  textContext.lineWidth = floor textSize/4
  textContext.strokeText text, 0, 0

  textContext.strokeStyle = inverseTextGradient
  textContext.lineWidth = floor textSize/8
  textContext.strokeText text, 0, 0

  textContext.fillStyle = textGradient
  textContext.fillText text, 0, 0
  textContext.restore()




generateReverb = (length, decay) ->
  bufferSize = length * audioContext.sampleRate
  noiseBuffer = audioContext.createBuffer(2, bufferSize, audioContext.sampleRate)
  outputL = noiseBuffer.getChannelData(0)
  outputR = noiseBuffer.getChannelData(1)
  for i in [0...bufferSize]
    outputL[i] = (random() * 2 - 1) * pow( 1 - i / bufferSize, decay )
    outputR[i] = (random() * 2 - 1) * pow( 1 - i / bufferSize, decay )
  convolver = audioContext.createConvolver()
  convolver.buffer = noiseBuffer
  return convolver

audioContext = new (window.AudioContext || window.webkitAudioContext)()

masterGain = audioContext.createGain()
masterGain.connect audioContext.destination
masterGain.gain.value = 1

compressor = audioContext.createDynamicsCompressor();
compressor.threshold.value = -50
compressor.knee.value = 20
compressor.ratio.value = 12
compressor.reduction.value = -20
compressor.attack.value = 0.2
compressor.release.value = 0.9
compressor.connect masterGain

gain = audioContext.createGain()
gain.connect compressor
gain.gain.value = 0.06

reverbGain = audioContext.createGain()
reverbGain.connect compressor
reverbGain.gain.value = 0.04

reverbNode = generateReverb 6, 40
reverbNode.connect reverbGain

createInstrument = (wave, lfowave, lfoamp, lfofreq) ->
  ret = {}
  ret.gain = audioContext.createGain()
  ret.gain.connect reverbNode
  ret.gain.connect gain
  ret.gain.gain.value = 0

  ret.osc = osc = audioContext.createOscillator()
  osc.type = wave
  osc.frequency.value = 500
  osc.detune = random() * 10
  osc.start audioContext.currentTime + 0.01
  osc.connect ret.gain

  ret.lfogain = audioContext.createGain()
  ret.lfogain.connect osc.frequency
  ret.lfogain.gain.value = lfoamp

  ret.lfo = lfo = audioContext.createOscillator()
  lfo.frequency.value = lfofreq
  lfo.type = lfowave
  lfo.start audioContext.currentTime + 0.01
  lfo.connect ret.lfogain

  return ret

whiteNoise = ->
  bufferSize = 2 * audioContext.sampleRate
  noiseBuffer = audioContext.createBuffer(1, bufferSize, audioContext.sampleRate)
  output = noiseBuffer.getChannelData(0)
  for i in [0...bufferSize]
    output[i] = random() * 2 - 1
  noise = audioContext.createBufferSource()
  noise.buffer = noiseBuffer
  noise.loop = true
  noise.start()
  noise


zootInstrument = createInstrument 'sawtooth', 'triangle', 10, 5
engineInstrument = createInstrument 'sawtooth', 'triangle', 100, 80
waahInstruments = for i in [0..3]
  w = createInstrument 'sawtooth', 'triangle', i + 2, 2
  w.gcurve = f32 [0.01, 0.1, 0.07, 0.05]
  w

kickInstrument = createInstrument 'sine', 'triangle', 100, 100
kickInstrument.fcurve = f32 [100, 40, 100, 30, 7]
kickInstrument.gcurve = f32 [0.0, 1.0, 0.1, 0.03, 0.02, 0.02, 0]

snareInstrument = createInstrument 'triangle', 'triangle', 100, 20
snareInstrument.fcurve = f32 [300, 100, 40, 20, 10, 7]
snareInstrument.gcurve = f32 [0,0.5, 0.1, 0.03, 0.01, 0]

cymbalInstrument = createInstrument 'sine', 'sine', 0, 0
cymbalInstrument.fcurve = f32 [1]
cymbalInstrument.gcurve = f32 [0, 0.3, 0.2, 0.1, 0.1, 0, 0, 0, 0, 0]
cymbalInstrument.noise = whiteNoise()
cymbalInstrument.noise.connect cymbalInstrument.gain

playerPewInstrument = createInstrument 'triangle', 'sawtooth', 100, 30
pewFrequency = f32 [1200, 500, 150, 100, 50]
pewGain = f32 [0.2, 0.1, 0.05, 0.02, 0.0001]

explodeInstrument = createInstrument 'sawtooth', 'square', 100, 15
explodeInstrument.fcurve = f32 [1000, 400, 150, 100, 50, 30]
explodeInstrument.gcurve = f32 [0,0.55, 0.1, 0.03, 0.03, 0.03, 0.03, 0.01, 0]

noteTimer = 1000
bar = []

notes = {
  a: 440
  'a#': 466.16
  b: 493.88
  c: 523.25
  'c#': 554.37
  d: 587.33
  'd#': 622.25
  e: 659.25
  f: 698.46
  'f#': 739.99
  g: 783.99
  'g#': 830.61
  '.': null
}

noteOrder = ['c', 'd', 'e', 'f', 'g', 'a', 'b']


introDialog = [
  "8675309, what are you doing there? That isn't your interface!"
  "Hmm... there must have been an authorization GLITCH during the intrusion"
  "Never mind, we've had a firewall breach and you're the only one in there"
  "I need you to find the malicious software and neutralize it"
  "This is not an optional job. I'm firing up calibration protocol 9"
]



beat = [1, 1, 3, 2, 1, 1, 3, 2, 1, 1, 3, 2, 1, 3, 3, 3]
nextNote = 0
noteCount = 0
beatDuration = 14

targets = []


gameStates =
  pressStart: 0
  intro: 1
  freePlay: 2
  tutorial: 3

gameState = gameStates.pressStart
newState = true
stateData = {}

setState = (index) ->
  newState = 2
  gameState = index
  stateData = {}




dialogLine = 0
dialogChar = 0
dialogDiv = document.getElementById 'c'
dialog = null

resetDialog = (data) ->
  dialog = data
  dialogLine = 0
  dialogChar = 0

runDialog = ->
  if dialog?
    line = dialog[dialogLine]
    if line?
      if dialogChar < line.length
        dialogChar += 1
        if buttons.fire
          dialogChar += 2
        dialogDiv.innerHTML = line[0..dialogChar] + "<span class='f'>█</span>"
      else
        if bounced.fire
          dialogLine += 1
          dialogChar = 0
    else
      dialogDiv.innerHTML = ''
      return true
  return false




movePlayer = ->
  speed = 0.05
  playerX += speed if buttons.right
  playerX -= speed if buttons.left
  playerY += speed if buttons.up
  playerY -= speed if buttons.down
  playerX = worldClamp playerX
  playerY = worldClamp playerY


fireDelay = 20

fireWeapons = ->
  if fireCooldown > 0
    fireCooldown -= 1

  if buttons.fire and fireCooldown <= 0
    for i in bullets when not i.on
      i.on = true
      i.x = playerX
      i.y = playerY
      i.z = playerZ + 0.2
      fireCooldown = fireDelay
      try
        playerPewInstrument.osc.frequency.cancelScheduledValues audioContext.currentTime
        playerPewInstrument.osc.frequency.setValueCurveAtTime pewFrequency, audioContext.currentTime, 0.5
        playerPewInstrument.gain.gain.cancelScheduledValues audioContext.currentTime
        playerPewInstrument.gain.gain.setValueCurveAtTime pewGain, audioContext.currentTime, 0.5
      break


updateTargets = ->
  for tg in targets
    tg.time ?= 0
    tg.time += 0.016
    tg.tick.call tg if tg.tick?
    dx = tg.px - tg.x
    dy = tg.py - tg.y
    dz = tg.pz - tg.z
    tg.x += 0.1 * dx
    tg.y += 0.1 * dy
    tg.z += 0.1 * dz
    drawBuffer quadBuffer, ballProg, tg.x, tg.y, tg.z
    for bl in bullets
      dx = bl.x - tg.x
      dy = bl.y - tg.y
      dz = tg.z - bl.z
      if abs(dx) < 0.25 and abs(dy) < 0.25 and dz > 0 and dz <= 3
        tg.dead = true
        particle tg.x, tg.y, tg.z, 0.7, explodeProg
        tg.die.call tg if tg.die?

        try
          explodeInstrument.osc.frequency.cancelScheduledValues audioContext.currentTime
          explodeInstrument.osc.frequency.setValueCurveAtTime explodeInstrument.fcurve, audioContext.currentTime, 3
          explodeInstrument.gain.gain.cancelScheduledValues audioContext.currentTime
          explodeInstrument.gain.gain.setValueCurveAtTime explodeInstrument.gcurve, audioContext.currentTime, 3
        break


  targets = (tg for tg in targets when not tg.dead)


drawGame = ->
  gl.depthMask false
  for i in bullets when i.on
    if i.z > 10
      i.on = false
    else
      drawBuffer lazerBuffer, lazerProg, i.x, i.y, i.z
    i.z += 1
  gl.depthMask true

  drawBuffer quadBuffer, ballProg, playerX, playerY, playerZ

particles = []

particle = (x, y, z, duration, program) ->
  particles.push {duration: duration, age: 0, program:program, x:x, y:y, z:z, seed:random()}

frame = ->
  if updatePaused
    masterGain.gain.value = 0
    return requestAnimationFrame frame

  if musicMuted
    masterGain.gain.value = 0
  else
    masterGain.gain.value = 1

  t += 0.16

  if noteTimer >= (beat.length * beatDuration)
    bar = [
        ['f', 'a', 'c', '.']
        ['d', 'c', '.', 'e']
        ['d', 'c', 'e', 'd', 'c', 'e', 'd', 'c', 'e']
        ['a', 'g', '.', 'f']
        ['g', 'e', 'c', 'b', 'd', 'e']
        ['d', 'c', 'e', 'a', 'c', 'a', 'd', 'c', 'e']
        ['d', 'c', 'g', 'a', 'g', 'a', 'd', 'g', 'e']
    ].random().shuffle()
    noteTimer = 0
    noteCount = 0
    nextNote = 0
  else
    noteTimer += 1

  if noteTimer == nextNote
    noteCount += 1
    nextNote += beatDuration + round(random()) * beatDuration
    noteName = bar[noteCount]
    if noteName == '.'
      for i in waahInstruments
        try
          i.gain.gain.linearRampToValueAtTime 0.001, audioContext.currentTime + 0.01, 0.1
    else if noteName?
      res = []
      for i in [0...4]
        inst = waahInstruments[i]
        note = notes[noteName]
        res.push noteName
        if note?
          octave = [(if bar.length == 4 then 0.5 else 1.0), 0.25, 0.125, 0.125/2.0][i]
          try
            inst.gain.gain.setValueCurveAtTime inst.gcurve, audioContext.currentTime + 0.01, 0.1
            inst.osc.frequency.linearRampToValueAtTime note * octave, audioContext.currentTime + 0.05
        noteName = noteOrder.nextLooped noteName[0], round(random()) *  2

  if ( noteTimer % beatDuration ) == 0
    tick = floor noteTimer / beatDuration
    drum = [null, kickInstrument, snareInstrument, cymbalInstrument][beat[tick%beat.length]]
    if drum
      try
        drum.osc.frequency.setValueCurveAtTime drum.fcurve, audioContext.currentTime + 0.01, 0.2
        drum.gain.gain.setValueCurveAtTime drum.gcurve, audioContext.currentTime + 0.01, 0.2


  cam = [playerX/3, playerY/2, 0]

  gl.viewport 0, 0, viewportWidth, viewportWidth
  gl.clearColor 0.08, 0.04, 0.16, 1.0
  gl.depthFunc gl.LEQUAL
  gl.disable gl.CULL_FACE
  gl.clear gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT

  gl.disable gl.DEPTH_TEST
  drawBuffer sunBuffer, sunProg, 0, 0, 0
  drawBuffer starBuffer, starProg, 0, 0, 0, true

  gl.enable gl.DEPTH_TEST

  textContext.clearRect 0, 0, viewportWidth, viewportWidth
  switch gameState
    when gameStates.pressStart
      if newState
        t = 0

      playerX = lerp playerX, -0.1, 0.1
      playerY = lerp playerY, 0.6, 0.1
      print viewportWidth/2, viewportWidth-textSize*2.2, min(1,pow(abs(sin(t*0.32)),4)*2), "PRESS SPACE"
      print viewportWidth/2 + sin(t*0.06)*20, viewportWidth*0.16 + sin(t*0.12)*10, 1, "NEON"
      print viewportWidth/2 + sin(t*0.06+0.7)*20, viewportWidth*0.16 + textSize*0.8 + sin(t*0.12+0.5)*10, 1, "RUNNER '84"
      if bounced.fire
        setState gameStates.intro

      for i in [0..12]
        drawBuffer quadBuffer, ballProg, 0 + sin(t*0.1+i), -1 + abs(sin(t*0.1+i*0.5)), 12.4-i
        drawBuffer quadBuffer, ballProg, 0 - sin(t*0.1+i), -1, 12.4-i

      drawBuffer quadBuffer, ballProg, 0, 0.7, 0.4

    when gameStates.intro
      if newState
        resetDialog introDialog

      if runDialog()
        setState gameStates.tutorial

      playerX = lerp playerX, 0, 0.1
      playerY = lerp playerY, -0.3, 0.1

    when gameStates.tutorial
      if newState
        stateData.step = 0
        stateData.count = 0
        stateData.time = 0
        resetDialog [ "use arrow keys" ]

      doneDialog = runDialog()
      stateData.time += 1

      switch stateData.step
        when 0
          if doneDialog and stateData.time > 200
            stateData.time = 0
            resetDialog [ "use the damned arrow keys" ]
          if buttons.up or buttons.down or buttons.left or buttons.right
            stateData.count += 1
            stateData.time = 0
            if stateData.count > 120
              stateData.step = 1
              stateData.time = 0
              resetDialog [ "very good" ]
        when 1
          if stateData.time > 100
            resetDialog ["now test bandwidth by moving to all extents"]
            stateData.step = 2
            stateData.time = 0
            stateData.count = 0
        when 2
          if stateData.time > 400
            resetDialog ["move your avatar into the corners, 8675309"]
            stateData.time = 0
          for corner, index in [[-1,-1],[1,-1],[-1,1],[1,1]]
            if abs(playerX-corner[0]) + abs(playerY-corner[1]) < 0.2
              stateData.count |= 1 << index
              stateData.time = 0
          if stateData.count == 15
            resetDialog ["hmm, a little tight. You'll manage"]
            stateData.step = 3
            stateData.time = 0
            stateData.count = 0
        when 3
          if doneDialog or stateData.time > 300
            resetDialog ["now test your data stream with the spacebar"]
            stateData.step = 4
            stateData.time = 0
        when 4
          if stateData.time > 200
            resetDialog ["hold the spacebar, genius"]
            stateData.time = 0
          if buttons.fire
            stateData.count += 1
            stateData.time = 0
            if stateData.count > 200
              resetDialog ["you're kidding, right? You'll need to upgrade that
                if you're going to stand a chance", "sigh",
                "I'm going to inject some benign nodes. Synchronize with them" ]
              stateData.step = 5
        when 5
          if doneDialog
            targets.push { x: -30, y: -10, z:30, px: 0, py: 0.5, pz: 4 }
            stateData.step = 6
        when 6
          if targets.length == 0
            resetDialog ["good. Keep going"]
            stateData.step = 7
            stateData.count = 0
        when 7
          if targets.length == 0
            if stateData.count > 5
              resetDialog ["fine, good enough",
                "I'm plotting a course to a server that has the upgrades you'll need",
                "synchronize with the jump port to engage"]
              stateData.step = 8
            else
              stateData.count += 1
              for i in [0...stateData.count]
                targets.push { x: -30, y: -10, z:30, px: -1 + 2 * random(), py: -1 + 2 * random(), pz: 4 }
        when 8
          #if stateData.jumpReady then setState gameStates.freePlay
          setState gameStates.freePlay

      movePlayer()
      if stateData.step >= 4
        fireWeapons()
      updateTargets()
      drawGame()

    when gameStates.freePlay
      if newState
        stateData.score = 0
        stateData.time = 300
        stateData.wave = 0

      doneDialog = runDialog()

      stateData.time += 1
      if stateData.time >= 300
        resetDialog [ "jam end, freeplay mode" ]
        stateData.time = 0

      if targets.length == 0
        stateData.wave += 1
        switch
          when stateData.wave < 5
            targets.push { x: -30, y: -10, z:30, px: 0, py: 0.5, pz: 4, die: -> stateData.score += 5 }
          when stateData.wave < 15
            for i in [0...3]
              targets.push {
                x: -30, y: -10, z:30,
                px: 0, py: 0, pz: 4, d: 0.3 + random() * 0.7, a: random() * 3.14, s: 0.5 + 2.0 * random()
                die: -> stateData.score += 10
                tick: ->
                  a = @time * @s + @a
                  @px = ( sin(a) + cos(a) ) * @d
                  @py = ( cos(a) - sin(a) ) * @d
              }
          when stateData.wave < 25
            fireDelay = 10
            for i in [0...3]
              targets.push {
                x: -30, y: -10, z:30,
                px: 0, py: 0, pz: 4, d: 0.3 + random() * 0.7, a: random() * 3.14, s: 0.5 + 2.0 * random()
                die: -> stateData.score += 10
                tick: ->
                  a = @time * @s + @a
                  @px = ( sin(a) + cos(a) ) * @d
                  @py = sin(a)
              }
          else
            fireDelay = 5
            for i in [0...5]
              targets.push {
                x: -30, y: -10, z:30,
                px: 0, py: 0, pz: 4, d: 0.7 + random() * 0.3, a: random() * 3.14, s: 1 + 3.0 * random() * sign(random()-0.5)
                q: random(), r: -1 + 2 * random(), h: random(), i: random()
                die: -> stateData.score += 10
                tick: ->
                  a = @time * @s + @a
                  @px = ( sin(a) * @q + cos(a) ) * @d
                  a *= @h
                  @py = ( cos(a) - sin(a) ) * @d * @i
                  @py = worldClamp @py + @r;

              }

      movePlayer()
      fireWeapons()
      updateTargets()
      drawGame()

      print viewportWidth/2, viewportWidth*0.02, 1, "" + stateData.score

  ###
  if particles.length == 0
    particle random() - 0.5, random() - 0.5, 8, 0.5 + 0.5 * random(), explodeProg
  ###

  gl.depthMask false
  for part in particles
    part.age += 0.016
    if part.age >= part.duration
      part.done = true
    else
      drawParticleBuffer explodeBuffer, part.program, part.x, part.y, part.z, part.age/part.duration, part.seed
  particles = (p for p in particles when not p.done)
  gl.depthMask true

  gl.disable gl.DEPTH_TEST
  gl.activeTexture gl.TEXTURE0
  gl.bindTexture gl.TEXTURE_2D, textTexture
  gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, textCanvas
  drawBuffer sunBuffer, presentProg

  if newState > 0
    newState -= 1
  bounced[k] = false for k of bounced

  requestAnimationFrame frame

  ###
  document.getElementById('debug').innerHTML =
      "#{playerX.toFixed(3)} #{playerY.toFixed(3)} #{(tg.x.toFixed(2) for tg in targets).join '.'} #{JSON.stringify stateData}"
  ###

frame()
