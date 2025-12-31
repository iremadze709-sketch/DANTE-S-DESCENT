local UI = {}
UI.__index = UI

function UI:new()
    local obj = setmetatable({}, self)

  
    -- EMERALD COUNTER
 
    obj.emeraldSheet = love.graphics.newImage("assets/ui/emerald_counter-Sheet.png")
    obj.emeraldSheet:setFilter("nearest", "nearest")

    local emeraldSheetWidth  = obj.emeraldSheet:getWidth()
    local emeraldSheetHeight = obj.emeraldSheet:getHeight()

    obj.emeraldFrameWidth  = emeraldSheetWidth
    obj.emeraldFrameHeight = emeraldSheetHeight / 22  
    obj.emeraldTotalFrames = 22

    
    -- HEART COUNTER
   
    obj.heartSheet = love.graphics.newImage("assets/ui/heart_counter-Sheet.png")
    obj.heartSheet:setFilter("nearest", "nearest")

    local heartSheetWidth  = obj.heartSheet:getWidth()
    local heartSheetHeight = obj.heartSheet:getHeight()

    obj.heartFrameWidth  = heartSheetWidth / 8
    obj.heartFrameHeight = heartSheetHeight
    obj.heartTotalFrames = 8

   
    -- GAME STATE
   
    obj.emeralds  = 0
    obj.health    = 8
    obj.maxHealth = 8

   
    -- UI SETTINGS
    
    obj.padding = 20
    obj.scale   = 1.5

    return obj
end


-- EMERALDS

function UI:addEmerald()
    if self.emeralds < 10 then
        self.emeralds = self.emeralds + 1
    end
end

function UI:removeEmerald()
    if self.emeralds > 0 then
        self.emeralds = self.emeralds - 1
    end
end


-- HEALTH

function UI:takeDamage(amount)
    amount = amount or 1
    self.health = math.max(0, self.health - amount)
    return self.health <= 0
end

function UI:heal(amount)
    amount = amount or 1
    self.health = math.min(self.maxHealth, self.health + amount)
end

function UI:update(dt)
    -- UI is static
end

function UI:draw()
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setColor(1, 1, 1, 1)

    local screenWidth = love.graphics.getWidth()


    -- HEARTS (TOP-LEFT)
    
    local heartFrame = math.floor((self.maxHealth - self.health) * (7 / self.maxHealth))
    heartFrame = math.min(7, math.max(0, heartFrame))

    local heartQuad = love.graphics.newQuad(
        heartFrame * self.heartFrameWidth,
        0,
        self.heartFrameWidth,
        self.heartFrameHeight,
        self.heartSheet:getWidth(),
        self.heartSheet:getHeight()
    )

    love.graphics.draw(
        self.heartSheet,
        heartQuad,
        self.padding,
        self.padding,
        0,
        self.scale,
        self.scale
    )

    
    -- EMERALDS (TOP-RIGHT)
   
   
    local emeraldFrame = 21 - (self.emeralds * 2)
    emeraldFrame = math.min(21, math.max(0, emeraldFrame))

    local emeraldQuad = love.graphics.newQuad(
        0,
        emeraldFrame * self.emeraldFrameHeight,
        self.emeraldFrameWidth,
        self.emeraldFrameHeight,
        self.emeraldSheet:getWidth(),
        self.emeraldSheet:getHeight()
    )

    local emeraldX = screenWidth - (self.emeraldFrameWidth * self.scale) - self.padding

    love.graphics.draw(
        self.emeraldSheet,
        emeraldQuad,
        emeraldX,
        self.padding,
        0,
        self.scale,
        self.scale
    )

    love.graphics.setColor(r, g, b, a)
end

return UI