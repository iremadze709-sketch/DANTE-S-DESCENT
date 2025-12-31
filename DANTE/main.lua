local sti = require("libraries.sti")
local Camera = require("libraries.camera")
local wf = require("libraries.windfield")

local Player = require("entities.player")
local Skeleton = require("entities.skeleton")
local Bat = require("entities.bat")
local Minotaur = require("entities.minotaur")
local Beatrice = require("entities.beatrice")
local UI = require("ui")
local Menu = require("menu")
local Audio = require("audio")
local Shaders = require("shaders")

-- Game state
local gameState = "menu"
local menu
local audio
local shaders

-- Store spawn positions from first game (to keep them consistent)
local savedSpawnPositions = nil

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    audio = Audio:new()
    _G.audio = audio
    
    shaders = Shaders:new()
    
    menu = Menu:new()
    
    audio:playMusic("menu")
    
    world = nil
    map = nil
    player = nil
    skeletons = nil
    minotaurs = nil
    bats = nil
    tears = nil
    beatrice = nil
    beatriceSpawned = false
    ui = nil
    camera = nil
    showDebug = false
    
    victoryTimer = 0
    victoryDuration = 5
end

function love.resize(w, h)
    if shaders then
        shaders = Shaders:new()
    end
    
    if gameState == "menu" and menu then
        menu.emberParticles:setPosition(w / 2, h + 50)
        menu.emberParticles:setEmissionArea("uniform", w, 0)
    end
end

function initGame()
    audio:playMusic("game")
    
    world = wf.newWorld(0, 0, true)
    
    world:addCollisionClass('Player')
    world:addCollisionClass('Enemy')
    world:addCollisionClass('Wall')

    map = sti("assets/maps/hell_map.lua")
    WORLD_WIDTH = map.width * map.tilewidth
    WORLD_HEIGHT = map.height * map.tileheight

    lands = {}
    if map.layers["land"] and map.layers["land"].objects then
        for _, obj in pairs(map.layers["land"].objects) do
            local land = world:newRectangleCollider(obj.x, obj.y, obj.width, obj.height)
            land:setType("static")
            land:setCollisionClass('Wall')
            table.insert(lands, land)
        end
    end

    player = Player:new(500, 400, world, audio)
    player.invulnerabilityTimer = 0
    player.invulnerabilityDuration = 1.0

    camera = Camera(player.x, player.y, 2.0)

    skeletons = {}
    minotaurs = {}
    bats = {}
    tears = {}
    beatrice = nil
    beatriceSpawned = false
    
   
    if savedSpawnPositions then
        print("Using saved spawn positions")
        restoreSpawnsFromSaved()
    else
        print("Generating new spawn positions (first run)")
        spawnTearsWithGuards(10)
        
        local numBats = 30 + math.random(4)
        for i = 1, numBats do
            local pos = findSafeSpawnPosition()
            if pos then
                table.insert(bats, Bat:new(pos.x, pos.y))
            end
        end
        
        -- Save these positions for future games
        saveCurrentSpawnPositions()
    end

    ui = UI:new()
    
    victoryTimer = 0
end

function saveCurrentSpawnPositions()
    savedSpawnPositions = {
        tears = {},
        skeletons = {},
        minotaurs = {},
        bats = {}
    }
    
    -- Save tear positions
    for _, tear in ipairs(tears) do
        table.insert(savedSpawnPositions.tears, {x = tear.x, y = tear.y})
    end
    
    -- Save skeleton positions
    for _, skeleton in ipairs(skeletons) do
        table.insert(savedSpawnPositions.skeletons, {x = skeleton.x, y = skeleton.y})
    end
    
    -- Save minotaur positions
    for _, minotaur in ipairs(minotaurs) do
        table.insert(savedSpawnPositions.minotaurs, {x = minotaur.x, y = minotaur.y})
    end
    
    -- Save bat positions
    for _, bat in ipairs(bats) do
        table.insert(savedSpawnPositions.bats, {x = bat.x, y = bat.y})
    end
    
    print("Saved positions: " .. #savedSpawnPositions.tears .. " tears, " .. 
          #savedSpawnPositions.skeletons .. " skeletons, " .. 
          #savedSpawnPositions.minotaurs .. " minotaurs, " .. 
          #savedSpawnPositions.bats .. " bats")
end

function restoreSpawnsFromSaved()
    -- Restore tears
    for _, pos in ipairs(savedSpawnPositions.tears) do
        spawnTear(pos.x, pos.y)
    end
    
    -- Restore skeletons
    for _, pos in ipairs(savedSpawnPositions.skeletons) do
        table.insert(skeletons, Skeleton:new(pos.x, pos.y, world, player, audio))
    end
    
    -- Restore minotaurs
    for _, pos in ipairs(savedSpawnPositions.minotaurs) do
        table.insert(minotaurs, Minotaur:new(pos.x, pos.y, world, player, audio))
    end
    
    -- Restore bats
    for _, pos in ipairs(savedSpawnPositions.bats) do
        table.insert(bats, Bat:new(pos.x, pos.y))
    end
    
    print("Restored positions: " .. #tears .. " tears, " .. 
          #skeletons .. " skeletons, " .. 
          #minotaurs .. " minotaurs, " .. 
          #bats .. " bats")
end

function spawnBeatrice()
    if beatriceSpawned or not player then
        return
    end
    
    local spawnDistance = 200
    local angle = math.random() * math.pi * 2
    local spawnX = player.x + math.cos(angle) * spawnDistance
    local spawnY = player.y + math.sin(angle) * spawnDistance
    
    spawnX = math.max(100, math.min(spawnX, WORLD_WIDTH - 100))
    spawnY = math.max(100, math.min(spawnY, WORLD_HEIGHT - 100))
    
    beatrice = Beatrice:new(spawnX, spawnY, player)
    beatriceSpawned = true
end

function spawnTear(x, y)
    local tearSheet = love.graphics.newImage("assets/ui/tear.png")
    tearSheet:setFilter("nearest", "nearest")
    
    local tear = {
        x = x,
        y = y,
        sprite = tearSheet,
        frameWidth = 16,
        frameHeight = 16,
        currentFrame = 0,
        frameTimer = 0,
        frameDelay = 0.15,
        totalFrames = 4,
        collected = false,
        scale = 1.5,
        pickupRadius = 25,
        floatOffset = 0,
        floatSpeed = 2,
        floatAmplitude = 5
    }
    
    table.insert(tears, tear)
end

function isOnLava(x, y)
    if not map or not map.layers["lava"] then
        return false
    end
    
    local lavaLayer = map.layers["lava"]
    
    local tileX = math.floor(x / map.tilewidth) + 1
    local tileY = math.floor(y / map.tileheight) + 1
    
    if tileX < 1 or tileX > map.width or tileY < 1 or tileY > map.height then
        return true
    end
    
    if lavaLayer.data then
        local tileIndex = (tileY - 1) * map.width + tileX
        if lavaLayer.data[tileIndex] and lavaLayer.data[tileIndex].id > 0 then
            return true
        end
    end
    
    return false
end

function findSafeSpawnPosition(existingPositions, minDistance)
    existingPositions = existingPositions or {}
    minDistance = minDistance or 100
    
    local maxAttempts = 50
    local padding = 100
    
    for attempt = 1, maxAttempts do
        local x = padding + math.random() * (WORLD_WIDTH - padding * 2)
        local y = padding + math.random() * (WORLD_HEIGHT - padding * 2)
        
        if not isOnLava(x, y) then
            local tooClose = false
            for _, pos in ipairs(existingPositions) do
                local dx = pos.x - x
                local dy = pos.y - y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < minDistance then
                    tooClose = true
                    break
                end
            end
            
            if not tooClose then
                return {x = x, y = y}
            end
        end
    end
    
    return {x = 500, y = 400}
end

function spawnTearsWithGuards(numTears)
    local tearPositions = {}
    
    for i = 1, numTears do
        local pos = findSafeSpawnPosition(tearPositions, 150)
        table.insert(tearPositions, pos)
        
        spawnTear(pos.x, pos.y)
        
        local guardRoll = math.random()
        
        if guardRoll < 0.3 then
            
            local angle1 = math.random() * math.pi * 4
            local angle2 = angle1 + math.pi
            local guardDist = 60
            
            local s1x = pos.x + math.cos(angle1) * guardDist
            local s1y = pos.y + math.sin(angle1) * guardDist
            local s2x = pos.x + math.cos(angle2) * guardDist
            local s2y = pos.y + math.sin(angle2) * guardDist
            
            table.insert(skeletons, Skeleton:new(s1x, s1y, world, player, audio))
            table.insert(skeletons, Skeleton:new(s2x, s2y, world, player, audio))
            
        elseif guardRoll < 0.5 then
            
            local angle = math.random() * math.pi * 4
            local guardDist = 70
            
            local mx = pos.x + math.cos(angle) * guardDist
            local my = pos.y + math.sin(angle) * guardDist
            
            table.insert(minotaurs, Minotaur:new(mx, my, world, player, audio))
        end
    end
end

function updateTears(dt)
    for i = #tears, 1, -1 do
        local tear = tears[i]
        
        if not tear.collected then
            tear.frameTimer = tear.frameTimer + dt
            if tear.frameTimer >= tear.frameDelay then
                tear.frameTimer = 0
                tear.currentFrame = (tear.currentFrame + 1) % tear.totalFrames
            end
            
            tear.floatOffset = math.sin(love.timer.getTime() * tear.floatSpeed) * tear.floatAmplitude
            
            local dx = player.x - tear.x
            local dy = player.y - tear.y
            local dist = math.sqrt(dx * dx + dy * dy)
            
            if dist <= tear.pickupRadius then
                tear.collected = true
                ui:addEmerald()
                audio:playSFX("tear_pickup")
                table.remove(tears, i)
                
                if ui.emeralds >= 10 and not beatriceSpawned then
                    spawnBeatrice()
                end
            end
        end
    end
end

function drawTears()
    for _, tear in ipairs(tears) do
        if not tear.collected then
            local quad = love.graphics.newQuad(
                tear.currentFrame * tear.frameWidth,
                0,
                tear.frameWidth,
                tear.frameHeight,
                tear.sprite:getWidth(),
                tear.sprite:getHeight()
            )
            
            shaders:applyEntityGlow(tear, {0.3, 0.8, 1.0}, 0.5)
            
            love.graphics.draw(
                tear.sprite,
                quad,
                tear.x,
                tear.y + tear.floatOffset,
                0,
                tear.scale,
                tear.scale,
                tear.frameWidth / 2,
                tear.frameHeight / 2
            )
            
            shaders:clearShader()
        end
    end
end

function love.update(dt)
    audio:update(dt)
    
    shaders:update(dt)
    
    if gameState == "menu" then
        local result = menu:update(dt)
        if result == "start_game" then
            gameState = "playing"
            initGame()
        end
    elseif gameState == "victory" then
        victoryTimer = victoryTimer + dt
        if victoryTimer >= victoryDuration then
            gameState = "menu"
            menu = Menu:new()
            audio:stopAllLoopingSFX()
            audio:playMusic("menu")
        end
    elseif gameState == "playing" then
        world:update(dt)

        if ui.health > 0 then
            player:update(dt)
            
            local allEnemies = {}
            for _, s in ipairs(skeletons) do
                table.insert(allEnemies, s)
            end
            for _, m in ipairs(minotaurs) do
                table.insert(allEnemies, m)
            end
            player:checkAttackHit(allEnemies)
            
            updateTears(dt)
            
            if beatrice then
                local reunion = beatrice:update(dt)
                if reunion then
                    print("REUNION! Dante and Beatrice are together again!")
                    audio:stopAllLoopingSFX()
                    gameState = "victory"
                    victoryTimer = 0
                end
            end
        else
            player:updateDeath(dt)
        end
        
        ui:update(dt)
        
        if player.invulnerabilityTimer > 0 then
            player.invulnerabilityTimer = player.invulnerabilityTimer - dt
        end

        for _, s in ipairs(skeletons) do
            s:update(dt, ui, player)
        end

        for _, m in ipairs(minotaurs) do
            m:update(dt, ui, player)
        end

        for _, bat in ipairs(bats) do
            bat:update(dt, WORLD_WIDTH, WORLD_HEIGHT)
        end

        camera:lookAt(player.x, player.y)

        local w = love.graphics.getWidth() / camera.scale
        local h = love.graphics.getHeight() / camera.scale

        camera.x = math.max(w / 2, math.min(camera.x, WORLD_WIDTH - w / 2))
        camera.y = math.max(h / 2, math.min(camera.y, WORLD_HEIGHT - h / 2))
    end
end

function love.draw()
    if gameState == "menu" then
        menu:draw()
    elseif gameState == "victory" then
        love.graphics.setColor(0, 0, 0, 0.9)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
        
        love.graphics.setColor(1, 0.9, 0.7, 1)
        local titleFont = love.graphics.newFont(70)
        love.graphics.setFont(titleFont)
        love.graphics.printf(
            "BEATRICE RESCUED!",
            0,
            love.graphics.getHeight() / 2 - 120,
            love.graphics.getWidth(),
            "center"
        )
        
        love.graphics.setColor(0.9, 0.8, 0.9, 1)
        local messageFont = love.graphics.newFont(32)
        love.graphics.setFont(messageFont)
        love.graphics.printf(
            "The lovers are together again.\nDante's journey through the Inferno is complete.",
            0,
            love.graphics.getHeight() / 2 - 20,
            love.graphics.getWidth(),
            "center"
        )
        
        love.graphics.setColor(0.6, 0.5, 0.6, 0.8)
        local hintFont = love.graphics.newFont(20)
        love.graphics.setFont(hintFont)
        love.graphics.printf(
            "Returning to menu...",
            0,
            love.graphics.getHeight() / 2 + 120,
            love.graphics.getWidth(),
            "center"
        )
        
        love.graphics.setColor(1, 1, 1, 1)
    elseif gameState == "playing" then
        shaders:beginDraw()
        
        camera:attach()

        love.graphics.setColor(0.05, 0.02, 0.02, 1)
        love.graphics.rectangle("fill", 0, 0, WORLD_WIDTH, WORLD_HEIGHT)
        love.graphics.setColor(1, 1, 1, 1)

        local lavaLayer = map.layers["lava"]
        if lavaLayer then
            shaders:applyLavaPulse(1.0)
            
            if lavaLayer.type == "tilelayer" and lavaLayer.tiles then
                for _, tile in ipairs(lavaLayer.tiles) do
                    local t = tile.y / WORLD_HEIGHT
                    love.graphics.setColor(1, 0.3 + 0.3 * (1 - t), 0.1 * (1 - t), 1)
                    tile:draw()
                end
                love.graphics.setColor(1, 1, 1, 1)
            else
                map:drawLayer(lavaLayer)
            end
            
            shaders:clearShader()
        end

        if map.layers["main_land"] then
            map:drawLayer(map.layers["main_land"])
        end
        if map.layers["island_base"] then
            map:drawLayer(map.layers["island_base"])
        end

        drawTears()

        for i = #skeletons, 1, -1 do
            local s = skeletons[i]
            if s.isDead then
                s:draw()
            end
        end

        for i = #minotaurs, 1, -1 do
            local m = minotaurs[i]
            if m.isDead then
                m:draw()
            end
        end

        if ui.health > 0 then
            if player.invulnerabilityTimer > 0 then
                if math.floor(player.invulnerabilityTimer * 10) % 2 == 0 then
                    love.graphics.setColor(1, 0.3, 0.3, 0.7)
                end
            end
            player:draw()
            love.graphics.setColor(1, 1, 1, 1)
        else
            player:draw()
        end
        
        if beatrice then
            beatrice:draw(shaders)
        end
        
        for i = #skeletons, 1, -1 do
            local s = skeletons[i]
            if not s.isDead then
                shaders:applyEntityGlow(s, {0.7, 0.8, 0.9}, 0.15)
                s:draw()
                shaders:clearShader()
            end
        end

        for i = #minotaurs, 1, -1 do
            local m = minotaurs[i]
            if not m.isDead then
                shaders:applyEntityGlow(m, {0.8, 0.5, 0.3}, 0.2)
                m:draw()
                shaders:clearShader()
            end
        end

        for _, bat in ipairs(bats) do
            bat:draw()
        end

        if map.layers["island_top"] then
            map:drawLayer(map.layers["island_top"])
        end

        if showDebug then
            love.graphics.setColor(0, 1, 0, 0.5)
            world:draw()
            love.graphics.setColor(1, 1, 1, 1)
        end

        camera:detach()
        
        shaders:endDraw()

        ui:draw()
        
        if ui.health <= 0 and player.isDead and player.deathAnimationComplete then
            love.graphics.setColor(0, 0, 0, 0.85)
            love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
            
            love.graphics.setColor(0.8, 0, 0, 1)
            local font = love.graphics.newFont(60)
            love.graphics.setFont(font)
            love.graphics.printf("GAME OVER", 0, love.graphics.getHeight() / 2 - 80, love.graphics.getWidth(), "center")
            
            love.graphics.setColor(0.9, 0.9, 0.9, 1)
            local smallFont = love.graphics.newFont(24)
            love.graphics.setFont(smallFont)
            love.graphics.printf("Press R to Restart", 0, love.graphics.getHeight() / 2 + 40, love.graphics.getWidth(), "center")
            
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end

function love.keypressed(key)
    if gameState == "menu" then
        menu:keypressed(key, audio)
    elseif gameState == "victory" then
        if key == "return" or key == "space" or key == "escape" then
            audio:stopAllLoopingSFX()
            gameState = "menu"
            menu = Menu:new()
            audio:playMusic("menu")
        end
    elseif gameState == "playing" then
        if key == "r" and ui and ui.health <= 0 and player and player.isDead and player.deathAnimationComplete then
            audio:stopMusic(true)
            audio:stopAllLoopingSFX()
            initGame()
            print("Game restarted!")
        end
        
        if key == "escape" then
            audio:stopAllLoopingSFX()
            audio:stopMusic(true)
            gameState = "menu"
            menu = Menu:new()
            audio:playMusic("menu")
        end
    end
end

function love.mousepressed(x, y, button)
    if gameState == "menu" then
        menu:mousepressed(x, y, button, audio)
    end
end