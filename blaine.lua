--[[
17 SEPTEMBER 2015

NIGHTFALL - THE THROWAWAY EDITION
=================================
Let's face up to the truth: two summers of intense research has produced very little in the way of a tangible, functioning version of Nightfall.

Now, with less than ten days to go before you're back at Uni, the sense of desperation is very real.
What's been holding you back? A desire for good design. Future-proofing. Modularity. Etc.
Thus, with those eliminated, maybe you can get somewhere.

-> Eschew modularity - one file should be enough.
-> Forget design - do the simplest thing that could possibly work.
-> We care about the immediate present; not the future.
-> Screw reuse - code copying and duplication isn't just tolerated; it's encouraged.
-> Code readability doesn't matter; no-one else needs to read it.
-> Refactor mercilessly; even then, only as a final resort.

In the real world, after all, shipping is a product's most important feature.

Your objective is simple: Create a working prototype of Nightfall, whatever it takes.
You have 7 days.
]]--


local root_viewport
local img

local families = {
  hack = {
    name="Hack", srect={5*32, 32, 32, 32}, col={0,255,255}, move=2, maxs=3, commands={
      {name="Slice", rng=1, dmg=2},
    }
  },
  slingshot = {
    name="Slingshot", srect={7*32, 32, 32, 32}, col={32,127,32}, move=2, maxs=2, commands={
      {name="Stone", rng=3, dmg=1},
    }
  },
  sentinel = {
    name="Sentinel", srect={4*32, 2*32, 32, 32}, col={255,127,0}, move=1, maxs=3, commands={
      {name="Cut", rng=1, dmg=2}
    }
  },
  floor = {
    name="Floor", col={64,64,64}
  },
  air = {
    name="Air",
  }
}

local grid
do
  local flr = "floor"
  local air = "air"
  local hck = "hack"
  local sst = "slingshot"
  local snt = "sentinel"
  
  grid = {
    {
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
      {air,air,air,air,flr,flr,flr,flr,flr,flr,},
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
      {flr,flr,flr,air,flr,flr,flr,flr,flr,flr,},
    },
    {
      {air,air,air,air,air,air,air,air,air,air,},
      {air,air,air,air,air,air,air,air,air,air,},
      {air,air,air,air,air,air,hck,air,air,air,},
      {air,air,air,air,air,air,sst,air,air,air,},
      {air,air,air,air,air,air,air,air,air,air,},
      {air,air,air,air,air,air,air,air,air,air,},
      {air,air,air,air,air,air,air,air,snt,air,},
      {air,air,air,air,air,air,air,air,air,air,},
      {air,air,air,air,air,air,air,air,air,air,},
    }
  }
end

local function prep_grid()
  for layer=1,2 do
    for row=1,8 do
      for col=1,10 do
        local f = grid[layer][row][col]
        grid[layer][row][col] = {
          family = families[f],
          move = {f.move, f.move},
          size = {1, f.maxs},
        }
      end
    end
  end
end

local function tile(col, row, layer)
  if 0 < col and col < 10 then
    if 0 < row and row < 8 then
      layer = layer or 2
      return grid[layer][row][col]
    end
  end
  return nil
end

function love.load()
  love.window.setMode(800, 600, {resizable=true})
  love.window.setTitle("Nightfall, the cursed project")
  love.graphics.setLineStyle("rough")
  love.graphics.setLineJoin("miter")
  love.graphics.setDefaultFilter("nearest", "nearest")
  
  img = {
    tiles = love.graphics.newImage("progs.png")
  }
  
  prep_grid()
end

function love.mousereleased(x, y, bn)
  local row = math.floor((y-48)/34) + 1
  local col = math.floor((x-48)/34) + 1
  
  local t = tile(col,row)
  if t then 
    
  end
end

function draw_grid()
  love.graphics.translate(48, 48)
  for layer=1,2 do
  love.graphics.push()
    for row=1,8 do
      love.graphics.push()
      for col=1,10 do
        local t = grid[layer][row][col]
        local f = t.family
        if (f.col) then
          local r,g,b = unpack(f.col)
          love.graphics.setColor(r/2,g/2,b/2)
          love.graphics.rectangle("fill", 0, 0, 32, 32)
          love.graphics.setColor(r,g,b)
          love.graphics.rectangle("fill", 0, 0, 29, 29)
        end
        if (f.srect) then
          local x, y, w, h = unpack(f.srect)
          local q = love.graphics.newQuad(x,y,w,h, img.tiles:getDimensions())
          love.graphics.setColor(255,255,255)
          love.graphics.draw(img.tiles, q, 0, 0)
        end
        love.graphics.translate(34, 0)
      end
      love.graphics.pop()
      love.graphics.translate(0, 34)
    end
    love.graphics.pop()
  end
end

function love.draw()
  draw_grid()
end