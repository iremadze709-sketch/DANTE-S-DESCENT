local anim8 = require("libraries.anim8")

local Beatrice = {}
Beatrice.__index = Beatrice

function Beatrice:new(x, y, player)
    local obj = setmetatable({}, self)
    
    obj.player = player
    obj.x = x
    obj.y = y
    obj.speed = 80  
    obj.direction = 1
    obj.scale = 0.6 
    
    -- Load sprites
    local idleSheet = love.graphics.newImage("assets/sprites/beatrice/Idle.png")
    local walkSheet = love.graphics.newImage("assets/sprites/beatrice/Run.png")
    
    idleSheet:setFilter("nearest", "nearest")
    walkSheet:setFilter("nearest", "nearest")
    
   
    -- Idle
    local idleGrid = anim8.newGrid(128, 128, idleSheet:getWidth(), idleSheet:getHeight())
    -- Run
    local walkGrid = anim8.newGrid(128, 128, walkSheet:getWidth(), walkSheet:getHeight())
    
    obj.anims = {
        idle = {
            sheet = idleSheet,
            anim = anim8.newAnimation(idleGrid("1-5", 1), 0.15),
            ox = 64,
            oy = 64
        },
        walk = {
            sheet = walkSheet,
            anim = anim8.newAnimation(walkGrid("1-6", 1), 0.1),
            ox = 64,
            oy = 64
        }
    }
    
    obj.current = obj.anims.idle
    obj.state = "idle"
    
    -- Collision detection
    obj.collisionRadius = 50
    
    -- Glow effect for magical appearance
    obj.glowIntensity = 0
    obj.glowSpeed = 2
    
    -- Particle system for magical entrance
    local particleCanvas = love.graphics.newCanvas(8, 8)
    love.graphics.setCanvas(particleCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 4, 4, 3)
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    
    obj.magicParticles = love.graphics.newParticleSystem(particleCanvas, 100)
    obj.magicParticles:setParticleLifetime(1, 2)
    obj.magicParticles:setSizes(0.8, 1.2, 0.5, 0)
    obj.magicParticles:setSpeed(20, 50)
    obj.magicParticles:setSpread(math.pi * 2)
    obj.magicParticles:setLinearAcceleration(-10, -30, 10, -10)
    obj.magicParticles:setColors(
        1.0, 0.9, 0.7, 1,
        0.9, 0.8, 0.9, 0.8,
        0.8, 0.7, 1.0, 0.6,
        0.7, 0.6, 0.9, 0
    )
    obj.magicParticles:setEmissionRate(20)
    obj.magicParticles:setPosition(x, y)
    
    -- Spawn effect
    obj.spawnTimer = 0
    obj.spawnDuration = 1.5
    obj.isSpawning = true
    obj.magicParticles:emit(50)
    
    
    
    return obj
end

function Beatrice:update(dt)
    -- Update animations
    self.current.anim:update(dt)
    
    -- Update particles
    self.magicParticles:setPosition(self.x, self.y - 10)
    self.magicParticles:update(dt)
    
    -- Handle spawn animation
    if self.isSpawning then
        self.spawnTimer = self.spawnTimer + dt
        self.glowIntensity = math.min(1, self.spawnTimer / self.spawnDuration)
        
        if self.spawnTimer >= self.spawnDuration then
            self.isSpawning = false
            self.magicParticles:setEmissionRate(5)  -- Reduce to gentle aura
        end
        return
    end
    
    -- Pulsing glow effect
    self.glowIntensity = 0.7 + math.sin(love.timer.getTime() * self.glowSpeed) * 0.3
    
    -- Calculate distance to player
    local dx = self.player.x - self.x
    local dy = self.player.y - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    
    -- Follow player if far enough
    local followDistance = 50
    if dist > followDistance then
        local angle = math.atan2(dy, dx)
        self.x = self.x + math.cos(angle) * self.speed * dt
        self.y = self.y + math.sin(angle) * self.speed * dt
        
        -- Update direction based on movement
        if dx < 0 then
            self.direction = -1
        else
            self.direction = 1
        end
        
        self.state = "walk"
        self.current = self.anims.walk
    else
        self.state = "idle"
        self.current = self.anims.idle
    end
    
    -- Check collision with player
    if dist <= self.collisionRadius then
        -- Stop player's running sound when reunion happens
        if self.player.audio and self.player.isRunning then
            
            self.player.audio:stopLoopingSFX("running")
            self.player.isRunning = false
        end
        return true  -- Signal reunion!
    end
    
    return false
end

function Beatrice:draw(shaders)
    -- Draw magical particles
    love.graphics.draw(self.magicParticles)
    
    -- Apply glow shader if available
    if shaders and not self.isSpawning then
        shaders:applyEntityGlow(self, {1.0, 0.9, 0.7}, self.glowIntensity * 0.3)
    end
    
    -- Draw Beatrice with fade-in during spawn
    local alpha = self.isSpawning and self.glowIntensity or 1
    love.graphics.setColor(1, 1, 1, alpha)
    
    self.current.anim:draw(
        self.current.sheet,
        self.x,
        self.y,
        0,
        self.direction * self.scale,
        self.scale,
        self.current.ox,
        self.current.oy
    )
    
    love.graphics.setColor(1, 1, 1, 1)
    
    if shaders then
        shaders:clearShader()
    end
end

return Beatrice