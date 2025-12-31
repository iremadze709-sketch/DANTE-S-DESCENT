local anim8 = require("libraries.anim8")

local Player = {}
Player.__index = Player

function Player:new(x, y, world, audio)
    local obj = setmetatable({}, self)

   
    obj.audio = audio

    -- PHYSICS
    obj.collider = world:newCircleCollider(x, y, 20)
    obj.collider:setFixedRotation(true)
    obj.collider:setLinearDamping(10)
    obj.collider:setMass(1.5)
    obj.speed = 150

    -- SPRITES
    local runSheet = love.graphics.newImage("assets/sprites/KnightRun_strip.png")
    local idleSheet = love.graphics.newImage("assets/sprites/KnightIdle_strip.png")
    local shieldSheet = love.graphics.newImage("assets/sprites/KnightShield_strip.png")
    local attackSheet = love.graphics.newImage("assets/sprites/KnightAttack_strip.png")
    local deathSheet = love.graphics.newImage("assets/sprites/KnightDeath_strip.png")

    runSheet:setFilter("nearest", "nearest")
    idleSheet:setFilter("nearest", "nearest")
    shieldSheet:setFilter("nearest", "nearest")
    attackSheet:setFilter("nearest", "nearest")
    deathSheet:setFilter("nearest", "nearest")

    local runGrid = anim8.newGrid(96, 64, runSheet:getWidth(), runSheet:getHeight())
    local idleGrid = anim8.newGrid(64, 64, idleSheet:getWidth(), idleSheet:getHeight())
    local shieldGrid = anim8.newGrid(96, 64, shieldSheet:getWidth(), shieldSheet:getHeight())
    local attackGrid = anim8.newGrid(144, 64, attackSheet:getWidth(), attackSheet:getHeight())
    local deathGrid = anim8.newGrid(96, 64, deathSheet:getWidth(), deathSheet:getHeight())

    obj.anims = {
        run = {
            anim = anim8.newAnimation(runGrid("1-8", 1), 0.1),
            sheet = runSheet,
            offsetX = 48,
            offsetY = 32
        },
        idle = {
            anim = anim8.newAnimation(idleGrid("1-15", 1), 0.08),
            sheet = idleSheet,
            offsetX = 32,
            offsetY = 32
        },
        shield = {
            anim = anim8.newAnimation(shieldGrid("1-7", 1), 0.1),
            sheet = shieldSheet,
            offsetX = 48,
            offsetY = 32
        },
        attack = {
            anim = anim8.newAnimation(attackGrid("1-22", 1), 0.06),
            sheet = attackSheet,
            offsetX = 72,
            offsetY = 32
        },
        death = {
            anim = anim8.newAnimation(deathGrid("1-15", 1), 0.1, 'pauseAtEnd'),
            sheet = deathSheet,
            offsetX = 48,
            offsetY = 32
        }
    }

    obj.current = obj.anims.idle
    obj.state = "idle"
    obj.direction = 1

    -- SHIELD
    obj.shieldActive = false
    obj.shieldPlayed = false

    -- ATTACK
    obj.attackActive = false
    obj.attackTimer = 0
    obj.attackDuration = 22 * 0.06
    obj.attackCooldown = 0.3
    obj.attackCooldownTimer = 0
    obj.attackDamage = 1
    obj.attackRange = 80
    obj.hasDealtDamage = false
    obj.attackSoundPlayed = false

    -- DEATH
    obj.isDead = false
    obj.deathAnimationComplete = false

    -- RUNNING SOUND
    obj.isRunning = false  -- Track if currently running

    -- DUST
    local dustCanvas = love.graphics.newCanvas(8, 8)
    love.graphics.setCanvas(dustCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 4, 4, 3)
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    obj.dustSystem = love.graphics.newParticleSystem(dustCanvas, 64)
    obj.dustSystem:setParticleLifetime(0.2, 0.5)
    obj.dustSystem:setSizes(0.6, 0.2)
    obj.dustSystem:setSpeed(10, 30)
    obj.dustSystem:setSpread(math.pi)
    obj.dustSystem:setLinearAcceleration(0, -10, 0, 10)
    obj.dustSystem:setColors(
        0.6, 0.5, 0.4, 0.6,
        0.6, 0.5, 0.4, 0
    )

    return obj
end

function Player:die()
    if not self.isDead then
        self.isDead = true
        self.state = "death"
        self.current = self.anims.death
        self.anims.death.anim:gotoFrame(1)
        self.collider:setLinearVelocity(0, 0)
        
        -- Stop running sound when dying
        if self.audio and self.isRunning then
            print(" Stopping running sound (player died)")
            self.audio:stopLoopingSFX("running")
            self.isRunning = false
        end
        
        print("PLAYER DEATH ANIMATION STARTED")
    end
end

function Player:updateDeath(dt)
    self.dustSystem:update(dt)
    
    -- Update death animation
    if not self.deathAnimationComplete then
        self.current.anim:update(dt)
        
        -- Check if animation reached last frame
        if self.anims.death.anim.position == #self.anims.death.anim.frames then
            self.deathAnimationComplete = true
            print(" DEATH ANIMATION COMPLETE - LYING ON GROUND")
        end
    end
end

function Player:update(dt)
    self.x, self.y = self.collider:getPosition()

    local dx, dy = 0, 0
    local moving = false
    local cDown = love.keyboard.isDown("c")
    local spaceDown = love.keyboard.isDown("space")

    self.dustSystem:update(dt)
    self.attackCooldownTimer = math.max(0, self.attackCooldownTimer - dt)

    if self.attackActive then
        self.attackTimer = self.attackTimer - dt
        self.state = "attack"
        self.current = self.anims.attack
        self.collider:setLinearVelocity(0, 0)
        self.current.anim:update(dt)
        
        -- Stop running sound when attacking
        if self.audio and self.isRunning then
            print("Stopping running sound (attacking)")
            self.audio:stopLoopingSFX("running")
            self.isRunning = false
        end
        
        -- Play attack sound at 25% of animation (delayed for sword swing visual)
        local attackElapsed = self.attackDuration - self.attackTimer
        local attackProgress = attackElapsed / self.attackDuration
        
        if attackProgress >= 0.25 and not self.attackSoundPlayed then
            if self.audio then
                self.audio:playSFX("player_attack")
            end
            self.attackSoundPlayed = true
        end

        if self.attackTimer <= 0 then
            self.attackActive = false
            self.anims.attack.anim:gotoFrame(1)
        end

    elseif cDown then
        self.state = "shield"
        self.current = self.anims.shield
        self.collider:setLinearVelocity(0, 0)
        
        -- Stop running sound when shielding
        if self.audio and self.isRunning then
            print("Stopping running sound (shielding)")
            self.audio:stopLoopingSFX("running")
            self.isRunning = false
        end

        if not self.shieldActive then
            self.shieldActive = true
            self.shieldPlayed = false
            self.current.anim:gotoFrame(1)
        end

        if not self.shieldPlayed then
            self.current.anim:update(dt)
            if self.current.anim.position == #self.current.anim.frames then
                self.shieldPlayed = true
            end
        end

    else
        if self.shieldActive then
            self.shieldActive = false
            self.shieldPlayed = false
            self.anims.shield.anim:gotoFrame(1)
        end

        if spaceDown and self.attackCooldownTimer <= 0 then
            self.attackActive = true
            self.attackTimer = self.attackDuration
            self.attackCooldownTimer = self.attackCooldown
            self.hasDealtDamage = false
            self.attackSoundPlayed = false
            self.anims.attack.anim:gotoFrame(1)
        end

        if love.keyboard.isDown("d") then dx = 1 self.direction = 1 moving = true end
        if love.keyboard.isDown("a") then dx = -1 self.direction = -1 moving = true end
        if love.keyboard.isDown("w") then dy = -1 moving = true end
        if love.keyboard.isDown("s") then dy = 1 moving = true end

        if moving then
            self.state = "run"
            self.current = self.anims.run
            local a = math.atan2(dy, dx)
            self.collider:setLinearVelocity(
                math.cos(a) * self.speed,
                math.sin(a) * self.speed
            )

            local footX = self.x - (self.direction * 6)
            local footY = self.y + 10
            self.dustSystem:setPosition(footX, footY)
            self.dustSystem:emit(1)
            
            -- Start running sound if not already playing
            if self.audio and not self.isRunning then
                print("Starting running sound")
                self.audio:playLoopingSFX("running")
                self.isRunning = true
            end
        else
            self.state = "idle"
            self.current = self.anims.idle
            self.collider:setLinearVelocity(0, 0)
            
            -- Stop running sound when idle
            if self.audio and self.isRunning then
                print(" Stopping running sound (idle)")
                self.audio:stopLoopingSFX("running")
                self.isRunning = false
            end
        end

        self.current.anim:update(dt)
    end
end

function Player:checkAttackHit(skeletons)
    if not self.attackActive or self.hasDealtDamage then
        return
    end
    
    local attackElapsed = self.attackDuration - self.attackTimer
    local attackProgress = attackElapsed / self.attackDuration
    
    if attackProgress >= 0.40 and attackProgress <= 0.65 then
        local attackX = self.x + (self.direction * 40)
        local attackY = self.y
        
        for _, skeleton in ipairs(skeletons) do
            if not skeleton.isDead and not skeleton.isHit then
                local dx = skeleton.x - attackX
                local dy = skeleton.y - attackY
                local dist = math.sqrt(dx * dx + dy * dy)
                
                if dist <= self.attackRange then
                    skeleton:takeDamage(self.attackDamage)
                    self.hasDealtDamage = true
                    break
                end
            end
        end
    end
end

function Player:draw()
    love.graphics.draw(self.dustSystem)
    self.current.anim:draw(
        self.current.sheet,
        self.x,
        self.y,
        0,
        self.direction * 1.2,
        1.2,
        self.current.offsetX,
        self.current.offsetY
    )
end

return Player