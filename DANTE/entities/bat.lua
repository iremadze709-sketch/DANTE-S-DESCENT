local anim8 = require("libraries.anim8")

local Bat = {}
Bat.__index = Bat

function Bat:new(x, y)
    local obj = setmetatable({}, self)
    
    obj.x = x
    obj.y = y
    obj.speed = 60 + math.random() * 40  -- Random speed between 60-100
    
    -- Load bat sprite
    local batSheet = love.graphics.newImage("assets/sprites/bat.png")
    batSheet:setFilter("nearest", "nearest")
    
    -- Create animation grid 
    local batGrid = anim8.newGrid(64, 64, batSheet:getWidth(), batSheet:getHeight())
    
    obj.sheet = batSheet
    obj.anim = anim8.newAnimation(batGrid("1-4", 1), 0.1)
    obj.offsetX = 32
    obj.offsetY = 32
    obj.scale = 0.6  
    
    -- Random flying direction
    obj.angle = math.random() * math.pi * 2
    obj.direction = math.random() > 0.5 and 1 or -1  -- Face left or right
    
    -- AI behavior
    obj.changeDirectionTimer = 0
    obj.changeDirectionInterval = 2 + math.random() * 3  -- Change direction every 2-5 seconds
    
    -- Flight pattern 
    obj.waveOffset = math.random() * math.pi * 2
    obj.waveSpeed = 2 + math.random() * 2
    obj.waveAmplitude = 15 + math.random() * 15
    
 
    obj.baseY = y
    
    return obj
end

function Bat:update(dt, worldWidth, worldHeight)
    -- Update animation
    self.anim:update(dt)
    
    -- Update direction change timer
    self.changeDirectionTimer = self.changeDirectionTimer + dt
    if self.changeDirectionTimer >= self.changeDirectionInterval then
        self.changeDirectionTimer = 0
        self.changeDirectionInterval = 2 + math.random() * 3
        
        -- Change direction randomly
        self.angle = self.angle + (math.random() - 0.5) * math.pi
    end
    
    -- Move bat
    local dx = math.cos(self.angle) * self.speed * dt
    local dy = math.sin(self.angle) * self.speed * dt
    
    self.x = self.x + dx
    self.baseY = self.baseY + dy
    
    -- Add wave movement for flying effect
    self.waveOffset = self.waveOffset + self.waveSpeed * dt
    self.y = self.baseY + math.sin(self.waveOffset) * self.waveAmplitude
    
    -- Update facing direction based on movement
    if dx < 0 then
        self.direction = -1
    elseif dx > 0 then
        self.direction = 1
    end
    
    -- Bounce off world boundaries
    local margin = 50
    if self.x < margin then
        self.x = margin
        self.angle = math.pi - self.angle
    elseif self.x > worldWidth - margin then
        self.x = worldWidth - margin
        self.angle = math.pi - self.angle
    end
    
    if self.baseY < margin then
        self.baseY = margin
        self.angle = -self.angle
    elseif self.baseY > worldHeight - margin then
        self.baseY = worldHeight - margin
        self.angle = -self.angle
    end
end

function Bat:draw()
    love.graphics.setColor(1, 1, 1, 0.9)  
    self.anim:draw(
        self.sheet,
        self.x,
        self.y,
        0,
        self.direction * self.scale,
        self.scale,
        self.offsetX,
        self.offsetY
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return Bat