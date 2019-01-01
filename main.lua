function match(val, fns)
  local f = fns[val[1]] or fns.default or error("Pattern matching not exhaustive: "..tostring(val[1]))
  return f(unpack(val))
end

-- PLEASE NO CYCLIC REFS...!
function dupe(t)
  if type(t) == "table" then
    local cpy = {}
    for k,v in pairs(t) do
      cpy[k] = dupe(v)
    end
  else
    return t
  end
end

local event
event = { -- PRODUCER-CONSUMER rel needed!
  _in = {},
  _out = {},
  
  push = function(ev)
    table.insert(event._in, ev)
  end,
  
  pull = function()
    if #event._out == 0 then
      for i=#event._in,1,-1 do
        local e = event._in[i]
        table.insert(event._out, e)
      end
      event._in = {}
    end
    return table.remove(event._out)
  end,
}

db = {
  _grid = {},
  
  _each_cell = function(choice, f)
    return match(choice, {
      atom = function(_,atom)
        return match(atom, {
          rgn = function(_,from,to,data)
            to = {to[1]+1, to[2]+1, to[3]+1}
            local d = {to[1]-from[1],to[2]-from[2],to[3]-from[3]}
            for i=0,d[1]*d[2]*d[3]-1 do
              local b = data[i+1]
              b = b == nil and true or b
              if b then
                -- d[1] cols per row
                -- d[2] rows per layer = d[1]*d[2] cols per layer
                -- d[3] layers = d[2]*d[3] rows = d[1]*d[2]*d[3] cols
                local col = from[1] + (i % d[1])
                local row = from[2] + (math.floor(i/d[1]) % d[2])
                local lyr = from[3] + (math.floor(i/d[1]*d[2]) % d[3])
                f{col,row,lyr}
              end
            end
          end,
        })
      end,
    })
  end,
  
  _set = function(cell, tile)
    local k = {}
    for i,n in ipairs(cell) do
      db.least[i] = math.min(db.least[i], n)
      db.most[i] = math.max(db.most[i], n)
      table.insert(k, tostring(n))
    end
    k = table.concat(k, ",")
    db._grid[k] = tile
  end,
  
  tile = function(cell) -- : Cell -> Tile
    local k = {}
    for i,n in ipairs(cell) do
      table.insert(k, tostring(n))
    end
    k = table.concat(k, ",")
    return db._grid[k] or "air"
  end,
  
  least = {1,1,1},
  most = {1,1,1},
  
  _fam = {
    air = {name="Air"},
    floor = {name="Floor", col={false,64,64,64}},
    hack = {name="Hack", col={true,0,255,255}, img={5,1}, attribs={move={2,2},size={1,4}}},
    sshot = {name="Slingshot", col={true,0,96,0}, img={7,1}, attribs={move={2,2},size={1,2}}},
    sentinel = {name="Sentinel", col={true,255,127,0}, img={4,2}, attribs={move={2,2},size={1,3}}},
    automaton = {name="Automaton", col={true,255,0,200}, img={6,2}, attribs={move={0,0},size={1,1}}},
    credit = {name="Credits", img={4,1}, attribs={amount=100}},
    warden_sh = {name="Warden#", col={true,255,0,0}, img={6,3}, attribs={move={4,4},size={1,8}}},
    tail = {name="Tail"}
  },

  name = function(t) -- : Tile -> Text
    if type(t) == "string" then
      return db._fam[t].name
    else
      return db.name(t.family)
    end
  end,
  
  attrib = function(t,k) -- : Tile -> Key -> Value
    local a = t.attribs
    
  end,
  
  colour = function(t) -- : Tile -> Colour
    if type(t) == "string" then
      return db._fam[t].col
    else
      return db.colour(t.family)
    end
  end,
  
  image = function(t) -- : Tile -> Img
    if type(t) == "string" then
      return db._fam[t].img
    else
      return db.image(t.family)
    end
  end,
  
  _fill = function(choice,ctor)
    db._each_cell(choice, function(cell)
      local t
      local f = db._fam[ctor]
      if f.attribs then
       t = {family = ctor, attribs=dupe(f.attribs)}
      else
       t = ctor
      end
      db._set(cell, t)
    end)
    event.push{"cell",choice,{"replace",ctor}}
  end,
  
  _handlers = {
  
    cell = function(_,cell)
      local from = db._state.from
      if (from) then
        db._set(cell,db.tile(from))
        db._set(from,"air")
        event.push{"cell",from,{"move",cell}}
        db._state.from = nil
      else
        db._state.from = cell
      end
    end,
    fill = function(_,choice,ctor)
      db._fill(choice,ctor)
    end,
  },
    
  _state = {},
  _options = {},
  _opt_cache = nil,
  
  _set_options = function(opts)
    db._opt_cache = {}
    for i,opt in ipairs(opts) do
      db._opt_cache[opt[1]] = true
    end
    db._options = opts
  end,
  
  take_input = function(input)
    if db._opt_cache[input[1]] then
      match(input, db._handlers)
      event.push{"input",db._options}
    else
      event.push{"error","Illegal input: "..input[1]}
    end
  end,
  
  init = function()
    db._set_options{{"cell",true,nil},{"fill"}}
  end,
}

local grid_spec = {
  {{1,1,1},{16,8,1},"floor"},
  {{3,3,1},{5,5,1},"air"},
  {{10,1,1},{11,8,1},"air"},
  {{1,1,2},{1,1,2},"hack"},
  {{8,1,2},{8,1,2},"sshot"},
  {{8,8,2},{8,8,2},"sentinel"},
  {{15,1,2},{16,8,2},"credit"},
  {{6,7,2},{6,7,2},"automaton"},
  {{7,6,2},{7,6,2},"automaton"},
  {{1,8,2},{1,8,2},"warden_sh"},
  {{13,4,2},{13,4,2},"warden_sh"},
  {{13,5,2},{13,5,2},"automaton"},
}

function setup_grid(i)
  local entry = grid_spec[i]
  if entry == nil then error("No more setup available.")
  else
    db.take_input{"fill",{"atom",{"rgn",entry[1],entry[2],{}}},entry[3]}
  end
end

function love.load()
  love.window.setMode(800, 600, {resizable=true})
  love.window.setTitle("Nightfall, the cursed project")
  love.graphics.setLineStyle("rough")
  love.graphics.setLineJoin("miter")
  love.graphics.setDefaultFilter("nearest", "nearest")
  love.keyboard.setKeyRepeat(true)
  
  gfx.tiles = love.graphics.newImage("progs.png")
  db.init()
  
  for i=1,#grid_spec do setup_grid(i) end
end

local ui = {}

function ui.handle(ev)
  return match(ev, {
    input = function(_,options)
      gfx.console.print("These are your options:")
      for i,opt in ipairs(options) do
        gfx.console.print{i,") ",opt}
      end
    end,
    default = function() gfx.console.print{"Event: ", ev} end,
  })
end

function love.update(dt)
  while true do
    local ev = event.pull()
    if ev == nil then
      break
    else
      ui.handle(ev)
    end
  end
end

function love.mousepressed(x, y, button)
  local size = gfx.size + gfx.skip
  local col = math.floor(x / size)+1
  local row = math.floor(y / size)+1
  
  local str = string.format("%d,%d,2",col,row)
  for i=1,#str do
    love.textinput(str:sub(i,i))
  end
end

function love.keypressed(k)
  if k == "f3" then
    gfx.console.on = not gfx.console.on
  elseif k == "backspace" then
    table.remove(gfx.console.entry)
  elseif k == "return" then
    local str = table.concat(gfx.console.entry)
    gfx.console.print(str)
    gfx.console.accept(str)
    gfx.console.entry = {}
  end
end

function love.textinput(t)
  table.insert(gfx.console.entry, t)
end

local function fmt_table(t)
  local u = {}
  for i,v in ipairs(t) do
    if type(v) == "table" then
      table.insert(u, "(")
      for _,item in ipairs(fmt_table(v)) do
        table.insert(u, item)
      end
      table.insert(u, ")")
    else
      table.insert(u, tostring(v))
    end
  end
  return u
end

function console_print(t)
  local buf = gfx.console.buf
  if type(t) == "string" then
    table.insert(buf, t)
    if #buf > gfx.console.max_lines-1 then
      table.remove(buf,1)
    end
    print(t)
  elseif type(t) == "table" then
    local s = table.concat(fmt_table(t), " ")
    return console_print(s)
  else
    return console_print(tostring(s))
  end
end

gfx = {
  size=32,
  skip=3,
  bevel=3,
  k_shadow=0.5,
  console = {
    on = false,
    buf = {"*** Nightfall-demo by Joel Jakubovic, 2015 ***",
           "**********************************************"},
    entry = {},
    prompt = "> ",
    max_lines = 30,
    accept = function(str)
      local f, e = loadstring(str)
      if f then
        local ok,aux = pcall(f)
        gfx.console.print(aux)
      else
        gfx.console.print(e)
      end
    end,
    print = console_print,
  },
}

local function draw_console()
  local w,h = love.graphics.getDimensions()
  local font = love.graphics.getFont()
  local buf = gfx.console.buf
  local fh = font:getHeight()
  local start_x = 0
  
  love.graphics.translate(start_x, h)
  local full_height = fh*gfx.console.max_lines
  love.graphics.setColor(32,32,32,200)
  love.graphics.rectangle("fill", 0, -full_height, w-start_x, full_height)
  love.graphics.translate(0, -fh)
  love.graphics.setColor(255,255,255)
  -- text entry line
  love.graphics.push()
    love.graphics.print(gfx.console.prompt, 0, 0)
    love.graphics.translate(font:getWidth(gfx.console.prompt), 0)
    for i,seg in ipairs(gfx.console.entry) do
      local adv = font:getWidth(seg)
      love.graphics.print(seg, 0, 0)
      love.graphics.translate(adv, 0)
    end
  love.graphics.pop()
  
  -- the rest
  for i=#buf,1,-1 do
    local line = buf[i]
    love.graphics.translate(0,-fh)
    love.graphics.print(line, 0, 0)
  end
end

local function draw_grid()
  local from, to = db.least, db.most
  for lyr=from[3],to[3] do
    love.graphics.push()
    for row=from[2],to[2] do
      love.graphics.push()
      for col=from[1],to[1] do
        local tile = db.tile{col,row,lyr}
        local col = db.colour(tile)
        local img = db.image(tile)
        if col then
          local bevel,r,g,b,a = unpack(col)
          local size = gfx.size
          local pos = 0
          if bevel then
            love.graphics.setColor(r*gfx.k_shadow,g*gfx.k_shadow,b*gfx.k_shadow,a)
            love.graphics.rectangle("fill", 0, 0, size, size)
            size = size - gfx.bevel
          end
          love.graphics.setColor(r,g,b,a)
          love.graphics.rectangle("fill", pos, pos, size, size)
        end
        if img then
          local w, h = gfx.tiles:getDimensions()
          local q = love.graphics.newQuad(img[1]*32,img[2]*32,32,32,w,h)
          love.graphics.setColor(255,255,255)
          love.graphics.draw(gfx.tiles, q, 0, 0, 0, gfx.size/32, gfx.size/32)
        end
        love.graphics.translate(gfx.size+gfx.skip, 0)
      end
      love.graphics.pop()
      love.graphics.translate(0,gfx.size+gfx.skip)
    end
    love.graphics.pop()
  end
end

function love.draw()
  love.graphics.push()
    draw_grid()
  love.graphics.pop()
  if gfx.console.on then
    draw_console()
  end
end