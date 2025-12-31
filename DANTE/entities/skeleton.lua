local anim8 = require("libraries.anim8")

local Skeleton = {}
Skeleton.__index = Skeleton

function Skeleton:new(x, y, world, player, audio)
    local obj = setmetatable({}, self)
    obj.player = player
    obj.audio = audio  -- Store audio reference

    -- SENSOR collider
    obj.collider = world:newCircleCollider(x, y, 18)
    obj.collider:setSensor(true)
    obj.collider:setFixedRotation(true)

    obj.x, obj.y = x, y
    obj.speed = 55

    -- AI params
    obj.visionRange = 150
    obj.attackRange = 30
    obj.attackCooldown = 1.2
    obj.attackTimer = 0
    obj.attackAnimTimer = 0
    obj.attackDuration = 18 * 0.07
    obj.state = "idle"
    obj.direction = 1
    
    -- Damage system
    obj.damage = 1
    obj.hasDealtDamage = false
    obj.isAttacking = false

    -- React state
    obj.hasReacted = false
    obj.reactTimer = 0
    obj.reactDuration = 0.6

    -- Sprites
    local idleImg = love.graphics.newImage("assets/sprites/skeleton/SkeletonIdle.png")
    local walkImg = love.graphics.newImage("assets/sprites/skeleton/SkeletonWalk.png")
    local reactImg = love.graphics.newImage("assets/sprites/skeleton/SkeletonReact.png")
    local attackImg = love.graphics.newImage("assets/sprites/skeleton/SkeletonAttack.png")
    local hitImg = love.graphics.newImage("assets/sprites/skeleton/SkeletonHit.png")
    local deadImg = love.graphics.newImage("assets/sprites/skeleton/Skeleton_Dead.png")

    idleImg:setFilter("nearest", "nearest")
    walkImg:setFilter("nearest", "nearest")
    reactImg:setFilter("nearest", "nearest")
    attackImg:setFilter("nearest", "nearest")
    hitImg:setFilter("nearest", "nearest")
    deadImg:setFilter("nearest", "nearest")

    obj.anims = {
        idle = {
            sheet = idleImg,
            anim = anim8.newAnimation(anim8.newGrid(24,32,idleImg:getWidth(),idleImg:getHeight())("1-11",1), 0.12),
            ox = 12, oy = 16
        },
        walk = {
            sheet = walkImg,
            anim = anim8.newAnimation(anim8.newGrid(22,33,walkImg:getWidth(),walkImg:getHeight())("1-13",1), 0.1),
            ox = 11, oy = 16
        },
        react = {
            sheet = reactImg,
            anim = anim8.newAnimation(anim8.newGrid(22,32,reactImg:getWidth(),reactImg:getHeight())("1-4",1), 0.15),
            ox = 11, oy = 16
        },
        attack = {
            sheet = attackImg,
            anim = anim8.newAnimation(anim8.newGrid(43,37,attackImg:getWidth(),attackImg:getHeight())("1-18",1), 0.07),
            ox = 21, oy = 18
        },
        hit = {
            sheet = hitImg,
            anim = anim8.newAnimation(anim8.newGrid(30,32,hitImg:getWidth(),hitImg:getHeight())("1-8",1), 0.08),
            ox = 15, oy = 16
        },
        dead = {
            sheet = deadImg,
            anim = anim8.newAnimation(anim8.newGrid(33,32,deadImg:getWidth(),deadImg:getHeight())("1-15",1), 0.1, 'pauseAtEnd'),
            ox = 16, oy = 16
        }
    }

    obj.current = obj.anims.idle

    -- Health system
    obj.health = 2
    obj.maxHealth = 2
    obj.isDead = false
    obj.isHit = false
    obj.hitTimer = 0
    obj.hitDuration = 8 * 0.08

    -- PARTICLE SYSTEMS
    local bloodCanvas = love.graphics.newCanvas(4, 4)
    love.graphics.setCanvas(bloodCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 2, 2, 2)
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    obj.bloodParticles = love.graphics.newParticleSystem(bloodCanvas, 20)
    obj.bloodParticles:setParticleLifetime(0.3, 0.6)
    obj.bloodParticles:setSizes(1.0, 0.5, 0.2)
    obj.bloodParticles:setSpeed(40, 100)
    obj.bloodParticles:setSpread(math.pi * 0.5)
    obj.bloodParticles:setLinearAcceleration(-20, 50, 20, 150)
    obj.bloodParticles:setColors(
        0.8, 0.1, 0.1, 1,
        0.6, 0.05, 0.05, 0.8,
        0.4, 0.0, 0.0, 0
    )

    local sparkCanvas = love.graphics.newCanvas(6, 6)
    love.graphics.setCanvas(sparkCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 3, 3, 2)
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)

    obj.sparkParticles = love.graphics.newParticleSystem(sparkCanvas, 30)
    obj.sparkParticles:setParticleLifetime(0.2, 0.5)
    obj.sparkParticles:setSizes(1.2, 0.8, 0.3, 0)
    obj.sparkParticles:setSpeed(60, 150)
    obj.sparkParticles:setSpread(math.pi * 0.6)
    obj.sparkParticles:setLinearAcceleration(-30, -80, 30, 100)
    obj.sparkParticles:setColors(
        1.0, 0.8, 0.3, 1,
        1.0, 0.5, 0.1, 0.9,
        0.9, 0.3, 0.0, 0.6,
        0.6, 0.2, 0.0, 0
    )

    return obj
end

local function distance(x1, y1, x2, y2)
    return ((x2 - x1)^2 + (y2 - y1)^2)^0.5
end

function Skeleton:takeDamage(amount)
    if self.isDead then
        return false
    end
    
    amount = amount or 1
    self.health = self.health - amount
    
    print(" Skeleton hit! Health: " .. self.health .. "/" .. self.maxHealth)
    
    if self.health <= 0 then
        -- Play death sound
        if self.audio then
            self.audio:playSFX("skeleton_death")
        end
        self:die()
        return true
    else
        -- Play hit sound
        if self.audio then
            self.audio:playSFX("skeleton_hit")
        end
        self:playHitAnimation()
        return false
    end
end

function Skeleton:playHitAnimation()
    self.isHit = true
    self.hitTimer = self.hitDuration
    self.state = "hit"
    self.current = self.anims.hit
    self.anims.hit.anim:gotoFrame(1)
    self.isAttacking = false
    self.attackAnimTimer = 0
    self.hasDealtDamage = false  
end

function Skeleton:die()
    if not self.isDead then
        self.isDead = true
        self.state = "dead"
        self.current = self.anims.dead
        self.anims.dead.anim:gotoFrame(1)
        self.collider:destroy()
        print("SKELETON DIED!")
    end
end

function Skeleton:update(dt, ui, player)
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
    
    if self.isHit then
        self.hitTimer = self.hitTimer - dt
        if self.hitTimer <= 0 then
            self.isHit = false
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
    if self.reactTimer > 0 then
        self.state = "react"
        self.current = self.anims.react
        self.isAttacking = false
    elseif dist <= self.visionRange and not self.hasReacted then
        self.state = "react"
        self.hasReacted = true
        self.reactTimer = self.reactDuration
        self.current = self.anims.react
        self.anims.react.anim:gotoFrame(1)
        self.isAttacking = false
    elseif dist <= self.attackRange then
        self.state = "attack"
        self.current = self.anims.attack
        
        if self.attackTimer <= 0 and not self.isAttacking then
            print("SKELETON STARTS ATTACK! Distance: " .. math.floor(dist))
            self.attackTimer = self.attackCooldown
            self.attackAnimTimer = 0
            self.hasDealtDamage = false
            self.isAttacking = true
            self.anims.attack.anim:gotoFrame(1)
        end
        
        if self.isAttacking then
            local attackProgress = self.attackAnimTimer / self.attackDuration
            
            if attackProgress >= 0.48 and attackProgress <= 0.55 and not self.hasDealtDamage then
                if self.player.invulnerabilityTimer <= 0 and dist <= self.attackRange then
                    if self.player.shieldActive then
                        local skeletonDirection = (self.x < px) and -1 or 1
                        if skeletonDirection == self.player.direction then
                            -- Attack blocked
                            print(" ATTACK BLOCKED BY SHIELD!")
                            self.hasDealtDamage = true
                            
                            -- Play shield block sound
                            if self.audio then
                                self.audio:playSFX("shield_block")
                            end
                            
                            self.sparkParticles:setPosition(px, py - 10)
                            self.sparkParticles:setDirection(math.atan2(self.y - py, self.x - px))
                            self.sparkParticles:emit(25)
                        else
                            -- Shield wrong direction - take damage
                            local isDead = ui:takeDamage(self.damage)
                            self.hasDealtDamage = true
                            self.player.invulnerabilityTimer = self.player.invulnerabilityDuration
                            
                            -- Play player hit sound
                            if self.audio then
                                self.audio:playSFX("player_hit")
                            end
                            
                            self.bloodParticles:setPosition(px, py - 10)
                            self.bloodParticles:setDirection(math.atan2(self.y - py, self.x - px))
                            self.bloodParticles:emit(15)
                            
                            print(" DAMAGE DEALT! (shield wrong direction) Health: " .. ui.health .. "/8")
                            
                            if isDead then
                                print(" PLAYER DIED!")
                                self.player:die()
                            end
                        end
                    else
                        -- Not blocking - take damage
                        local isDead = ui:takeDamage(self.damage)
                        self.hasDealtDamage = true
                        self.player.invulnerabilityTimer = self.player.invulnerabilityDuration
                        
                        -- Play player hit sound
                        if self.audio then
                            self.audio:playSFX("player_hit")
                        end
                        
                        self.bloodParticles:setPosition(px, py - 10)
                        self.bloodParticles:setDirection(math.atan2(self.y - py, self.x - px))
                        self.bloodParticles:emit(15)
                        
                        print("  DAMAGE DEALT! Health: " .. ui.health .. "/8")
                        
                        if isDead then
                            print(" PLAYER DIED!")
                            self.player:die()
                        end
                    end
                end
            end
            
            if self.attackAnimTimer >= self.attackDuration then
                self.isAttacking = false
                self.attackAnimTimer = 0
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
        self.state = "idle"
        self.current = self.anims.idle
        self.hasReacted = false
    end

    self.current.anim:update(dt)
end

function Skeleton:stopAttacking()
    if self.state == "attack" then
        self.state = "idle"
        self.current = self.anims.idle
        self.isAttacking = false
        self.attackAnimTimer = 0
    end
end

function Skeleton:draw()
    love.graphics.draw(self.bloodParticles)
    love.graphics.draw(self.sparkParticles)
    
    love.graphics.setColor(0.78, 0.8, 0.85, 1)
    self.current.anim:draw(
        self.current.sheet,
        self.x, self.y,
        0,
        self.direction * 1.2,
        1.2,
        self.current.ox, self.current.oy
    )
    love.graphics.setColor(1, 1, 1, 1)
end

return Skeleton