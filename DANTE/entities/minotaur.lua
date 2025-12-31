local anim8 = require("libraries.anim8")

local Minotaur = {}
Minotaur.__index = Minotaur

function Minotaur:new(x, y, world, player, audio)
    local obj = setmetatable({}, self)
    obj.player = player
    obj.audio = audio

    -- SENSOR collider
    obj.collider = world:newCircleCollider(x, y, 25)
    obj.collider:setSensor(true)
    obj.collider:setFixedRotation(true)

    obj.x, obj.y = x, y
    obj.speed = 45

    -- AI params
    obj.visionRange = 180
    obj.attackRange = 35
    obj.attackCooldown = 1.5
    obj.attackTimer = 0
    obj.attackAnimTimer = 0
    obj.attackDuration = 5 * 0.1  
    obj.state = "idle"
    obj.direction = 1
    
    -- Damage system
    obj.damage = 2  -- Minotaur deals more damage
    obj.hasDealtDamage = false
    obj.isAttacking = false

    -- React state
    obj.hasReacted = false
    obj.reactTimer = 0
    obj.reactDuration = 0.5

    -- PATROL SYSTEM
    obj.patrolState = "idle"  -- "idle" or "walking"
    obj.patrolTimer = 0
    obj.patrolIdleTime = 2 + math.random() * 3  -- Stand idle 2-5 seconds
    obj.patrolWalkTime = 3 + math.random() * 4  -- Walk 3-7 seconds
    obj.patrolDirection = math.random(0, 3) * (math.pi / 2)  -- 0, 90, 180, 270 (cardinal directions)

    -- Sprites 
    local idleImg = love.graphics.newImage("assets/sprites/minotaur/Idle.png")
    local walkImg = love.graphics.newImage("assets/sprites/minotaur/Walk.png")
    local attackImg = love.graphics.newImage("assets/sprites/minotaur/Attack.png")
    local hurtImg = love.graphics.newImage("assets/sprites/minotaur/Hurt.png")
    local deadImg = love.graphics.newImage("assets/sprites/minotaur/Dead.png")

    idleImg:setFilter("nearest", "nearest")
    walkImg:setFilter("nearest", "nearest")
    attackImg:setFilter("nearest", "nearest")
    hurtImg:setFilter("nearest", "nearest")
    deadImg:setFilter("nearest", "nearest")

    obj.anims = {
        idle = {
            sheet = idleImg,
            anim = anim8.newAnimation(anim8.newGrid(128, 128, idleImg:getWidth(), idleImg:getHeight())("1-10", 1), 0.1),
            ox = 64, oy = 64
        },
        walk = {
            sheet = walkImg,
            anim = anim8.newAnimation(anim8.newGrid(128, 128, walkImg:getWidth(), walkImg:getHeight())("1-12", 1), 0.08),
            ox = 64, oy = 64
        },
        attack = {
            sheet = attackImg,
            anim = anim8.newAnimation(anim8.newGrid(128, 128, attackImg:getWidth(), attackImg:getHeight())("1-5", 1), 0.1),  
            ox = 64, oy = 64
        },
        hurt = {
            sheet = hurtImg,
            anim = anim8.newAnimation(anim8.newGrid(128, 128, hurtImg:getWidth(), hurtImg:getHeight())("1-3", 1), 0.1),
            ox = 64, oy = 64
        },
        dead = {
            sheet = deadImg,
            anim = anim8.newAnimation(anim8.newGrid(128, 128, deadImg:getWidth(), deadImg:getHeight())("1-5", 1), 0.15, 'pauseAtEnd'),
            ox = 64, oy = 64
        }
    }

    obj.current = obj.anims.idle

    -- Health system (stronger than skeleton)
    obj.health = 4
    obj.maxHealth = 4
    obj.isDead = false
    obj.isHurt = false
    obj.hurtTimer = 0
    obj.hurtDuration = 3 * 0.1

    -- PARTICLE SYSTEMS
    local bloodCanvas = love.graphics.newCanvas(4, 4)
    love.graphics.setCanvas(bloodCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 2, 2, 2)
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    obj.bloodParticles = love.graphics.newParticleSystem(bloodCanvas, 25)
    obj.bloodParticles:setParticleLifetime(0.4, 0.7)
    obj.bloodParticles:setSizes(1.2, 0.6, 0.2)
    obj.bloodParticles:setSpeed(50, 120)
    obj.bloodParticles:setSpread(math.pi * 0.5)
    obj.bloodParticles:setLinearAcceleration(-20, 50, 20, 150)
    obj.bloodParticles:setColors(
        0.9, 0.1, 0.1, 1,
        0.7, 0.05, 0.05, 0.8,
        0.5, 0.0, 0.0, 0
    )

    local sparkCanvas = love.graphics.newCanvas(6, 6)
    love.graphics.setCanvas(sparkCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 3, 3, 2)
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    obj.sparkParticles = love.graphics.newParticleSystem(sparkCanvas, 35)
    obj.sparkParticles:setParticleLifetime(0.2, 0.5)
    obj.sparkParticles:setSizes(1.4, 1.0, 0.4, 0)
    obj.sparkParticles:setSpeed(70, 160)
    obj.sparkParticles:setSpread(math.pi * 0.6)
    obj.sparkParticles:setLinearAcceleration(-30, -80, 30, 100)
    obj.sparkParticles:setColors(
        1.0, 0.9, 0.4, 1,
        1.0, 0.6, 0.2, 0.9,
        0.9, 0.4, 0.0, 0.6,
        0.7, 0.2, 0.0, 0
    )

    return obj
end

local function distance(x1, y1, x2, y2)
    return ((x2 - x1)^2 + (y2 - y1)^2)^0.5
end

function Minotaur:takeDamage(amount)
    if self.isDead then
        return false
    end
    
    amount = amount or 1
    self.health = self.health - amount
    
    print(" Minotaur hit! Health: " .. self.health .. "/" .. self.maxHealth)
    
    if self.health <= 0 then
        if self.audio then
            self.audio:playSFX("skeleton_death")
        end
        self:die()
        return true
    else
        if self.audio then
            self.audio:playSFX("skeleton_hit")
        end
        self:playHurtAnimation()
        return false
    end
end

function Minotaur:playHurtAnimation()
    self.isHurt = true
    self.hurtTimer = self.hurtDuration
    self.state = "hurt"
    self.current = self.anims.hurt
    self.anims.hurt.anim:gotoFrame(1)
    self.isAttacking = false
    self.attackAnimTimer = 0
    self.hasDealtDamage = false
end

function Minotaur:die()
    if not self.isDead then
        self.isDead = true
        self.state = "dead"
        self.current = self.anims.dead
        self.anims.dead.anim:gotoFrame(1)
        self.collider:destroy()
        print(" MINOTAUR DIED!")
    end
end

function Minotaur:updatePatrol(dt)
    self.patrolTimer = self.patrolTimer + dt
    
    if self.patrolState == "idle" then
        if self.patrolTimer >= self.patrolIdleTime then
            self.patrolState = "walking"
            self.patrolTimer = 0
            self.patrolWalkTime = 3 + math.random() * 4
            self.patrolDirection = math.random(0, 3) * (math.pi / 2)
            self.state = "walk"
            self.current = self.anims.walk
        end
    elseif self.patrolState == "walking" then
        if self.patrolTimer >= self.patrolWalkTime then
            self.patrolState = "idle"
            self.patrolTimer = 0
            self.patrolIdleTime = 2 + math.random() * 3
            self.state = "idle"
            self.current = self.anims.idle
        else
            local dx = math.cos(self.patrolDirection) * self.speed * dt
            local dy = math.sin(self.patrolDirection) * self.speed * dt
            
            self.x = self.x + dx
            self.y = self.y + dy
            self.collider:setPosition(self.x, self.y)
            
            if dx < 0 then
                self.direction = -1
            elseif dx > 0 then
                self.direction = 1
            end
        end
    end
end

function Minotaur:update(dt, ui, player)
    self.bloodParticles:update(dt)
    self.sparkParticles:update(dt)

    if self.isDead then
        self.current.anim:update(dt)
        return
    end
    
    if player.isDead then
        self.state = "idle"
        self.current = self.anims.idle
        self.isAttacking = false
        self.current.anim:update(dt)
        return
    end
    
    if self.isHurt then
        self.hurtTimer = self.hurtTimer - dt
        if self.hurtTimer <= 0 then
            self.isHurt = false
            self.state = "idle"
        end
        self.current.anim:update(dt)
        return
    end
    
    self.attackTimer = math.max(0, self.attackTimer - dt)
    self.reactTimer = math.max(0, self.reactTimer - dt)
    
    if self.isAttacking then
        self.attackAnimTimer = self.attackAnimTimer + dt
    end

    local px, py = self.player.x, self.player.y
    local dx = px - self.x
    local dy = py - self.y
    local dist = distance(self.x, self.y, px, py)

    self.direction = (px < self.x) and -1 or 1

    -- STATE MACHINE
    if dist <= self.visionRange and not self.hasReacted then
        self.hasReacted = true
        self.reactTimer = self.reactDuration
        self.patrolState = "idle"
        print("MINOTAUR SPOTTED PLAYER!")
    end

    if self.hasReacted then
        if dist <= self.attackRange then
            self.state = "attack"
            self.current = self.anims.attack
            
            if self.attackTimer <= 0 and not self.isAttacking then
                print(" MINOTAUR ATTACKS! Distance: " .. math.floor(dist))
                self.attackTimer = self.attackCooldown
                self.attackAnimTimer = 0
                self.hasDealtDamage = false
                self.isAttacking = true
                self.anims.attack.anim:gotoFrame(1)
            end
            
            if self.isAttacking then
                local attackProgress = self.attackAnimTimer / self.attackDuration
                
                -- FIXED: Changed timing window to be tighter and earlier (60-75% of animation)
                if attackProgress >= 0.60 and attackProgress <= 0.75 and not self.hasDealtDamage then
                    if self.player.invulnerabilityTimer <= 0 and dist <= self.attackRange then
                        if self.player.shieldActive then
                            local minotaurDirection = (self.x < px) and -1 or 1
                            if minotaurDirection == self.player.direction then
                                print(" MINOTAUR ATTACK BLOCKED!")
                                self.hasDealtDamage = true
                                
                                if self.audio then
                                    self.audio:playSFX("shield_block")
                                end
                                
                                self.sparkParticles:setPosition(px, py - 10)
                                self.sparkParticles:setDirection(math.atan2(self.y - py, self.x - px))
                                self.sparkParticles:emit(30)
                            else
                                local isDead = ui:takeDamage(self.damage)
                                self.hasDealtDamage = true
                                self.player.invulnerabilityTimer = self.player.invulnerabilityDuration
                                
                                if self.audio then
                                    self.audio:playSFX("player_hit")
                                end
                                
                                self.bloodParticles:setPosition(px, py - 10)
                                self.bloodParticles:setDirection(math.atan2(self.y - py, self.x - px))
                                self.bloodParticles:emit(20)
                                
                                print("  MINOTAUR DAMAGE DEALT! Health: " .. ui.health .. "/8")
                                
                                if isDead then
                                    print(" PLAYER DIED!")
                                    self.player:die()
                                end
                            end
                        else
                            local isDead = ui:takeDamage(self.damage)
                            self.hasDealtDamage = true
                            self.player.invulnerabilityTimer = self.player.invulnerabilityDuration
                            
                            if self.audio then
                                self.audio:playSFX("player_hit")
                            end
                            
                            self.bloodParticles:setPosition(px, py - 10)
                            self.bloodParticles:setDirection(math.atan2(self.y - py, self.x - px))
                            self.bloodParticles:emit(20)
                            
                            print("  MINOTAUR DAMAGE DEALT! Health: " .. ui.health .. "/8")
                            
                            if isDead then
                                print(" PLAYER DIED!")
                                self.player:die()
                            end
                        end
                    end
                end
                
                -- FIXED: End attack immediately when animation finishes
                if self.attackAnimTimer >= self.attackDuration then
                    self.isAttacking = false
                    self.attackAnimTimer = 0
                    self.state = "idle"  -- Return to idle immediately
                end
            end
            
        elseif dist <= self.visionRange then
            self.state = "walk"
            self.current = self.anims.walk
            local angle = math.atan2(dy, dx)
            self.x = self.x + math.cos(angle) * self.speed * dt
            self.y = self.y + math.sin(angle) * self.speed * dt
            self.collider:setPosition(self.x, self.y)
        else
            self.hasReacted = false
            self:updatePatrol(dt)
        end
    else
        self:updatePatrol(dt)
    end

    self.current.anim:update(dt)
end

function Minotaur:draw()
    love.graphics.draw(self.bloodParticles)
    love.graphics.draw(self.sparkParticles)
    
    love.graphics.setColor(0.85, 0.75, 0.7, 1)
    self.current.anim:draw(
        self.current.sheet,
        self.x, self.y,
        0,
        self.direction * 1.3,
        1.3,
        self.current.ox, self.current.oy
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return Minotaur