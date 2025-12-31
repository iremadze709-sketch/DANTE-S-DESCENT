local Menu = {}
Menu.__index = Menu

function Menu:new()
    local obj = setmetatable({}, self)
    
    -- Menu state
    obj.currentScreen = "main"  -- "main", "options", or "tutorial"
    obj.selectedButton = 1
    
    -- Main menu buttons
    obj.mainButtons = {
        {text = "START GAME", action = "start"},
        {text = "TUTORIAL", action = "tutorial"},
        {text = "OPTIONS", action = "options"},
        {text = "QUIT", action = "quit"}
    }
    
    -- Tutorial content
    obj.tutorialPages = {
        {
            title = "MOVEMENT",
            controls = {
                {key = "W A S D", description = "Move Dante"},
                {key = "Arrow Keys", description = "Alternative movement"}
            },
            hint = "Navigate through the fiery depths of Hell"
        },
        {
            title = "COMBAT",
            controls = {
                {key = "SPACE", description = "Swing your sword"},
                {key = "C", description = "Raise shield to block"}
            },
            hint = "Defeat the demons that guard the tears"
        },
        {
            title = "OBJECTIVE",
            controls = {
                {key = "Collect 10 Tears", description = "Find Beatrice's tears"},
                {key = "Reach Beatrice", description = "Reunite with your beloved"}
            },
            hint = "Only then can you escape the Inferno together"
        }
    }
    obj.currentTutorialPage = 1
    
    -- Resolution options
    obj.resolutions = {
        {width = 1920, height = 1080, text = "1920 x 1080 (Full HD)"},
        {width = 1600, height = 900, text = "1600 x 900"},
        {width = 1366, height = 768, text = "1366 x 768"},
        {width = 1280, height = 720, text = "1280 x 720 (HD)"},
        {width = 1200, height = 700, text = "1200 x 700"}
    }
    
    -- Get current resolution index
    local currentWidth = love.graphics.getWidth()
    local currentHeight = love.graphics.getHeight()
    obj.selectedResolution = 1
    for i, res in ipairs(obj.resolutions) do
        if res.width == currentWidth and res.height == currentHeight then
            obj.selectedResolution = i
            break
        end
    end
    
    -- Options menu buttons
    obj.optionsButtons = {
        {text = "< RESOLUTION >", action = "resolution"},
        {text = "APPLY", action = "apply"},
        {text = "BACK", action = "back"}
    }
    
    -- Mouse hover state
    obj.hoveredButton = nil
    
    -- Load background image (optional - will use gradient if not found)
    local bgSuccess, bgImage = pcall(love.graphics.newImage, "assets/ui/menu_background.jpg")
    if bgSuccess then
        obj.backgroundImage = bgImage
        obj.backgroundImage:setFilter("linear", "linear")
        obj.usingBackground = true
    else
        obj.backgroundImage = nil
        obj.usingBackground = false
    end
    
    obj.titleScale = 1
    
    -- Fade effect
    obj.fadeAlpha = 1
    obj.fadeSpeed = 2
    obj.fadingOut = false
    
    -- Particle system for background
    local particleCanvas = love.graphics.newCanvas(8, 8)
    love.graphics.setCanvas(particleCanvas)
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", 4, 4, 3)
    love.graphics.setCanvas()
    love.graphics.setColor(1, 1, 1, 1)
    
    obj.emberParticles = love.graphics.newParticleSystem(particleCanvas, 200)
    obj.emberParticles:setParticleLifetime(3, 6)
    obj.emberParticles:setSizes(0.5, 0.8, 0.3)
    obj.emberParticles:setSpeed(10, 30)
    obj.emberParticles:setLinearAcceleration(-5, -50, 5, -20)
    obj.emberParticles:setColors(
        1.0, 0.6, 0.2, 0.8,
        1.0, 0.4, 0.1, 0.6,
        0.9, 0.2, 0.0, 0.4,
        0.6, 0.1, 0.0, 0
    )
    obj.emberParticles:setEmissionRate(30)
    obj.emberParticles:setPosition(love.graphics.getWidth() / 2, love.graphics.getHeight() + 50)
    obj.emberParticles:setEmissionArea("uniform", love.graphics.getWidth(), 0)
    obj.emberParticles:start()
    
    return obj
end

function Menu:update(dt)
    -- Update particles
    self.emberParticles:update(dt)
    
    -- Update particle emission position if resolution changed
    self.emberParticles:setPosition(love.graphics.getWidth() / 2, love.graphics.getHeight() + 50)
    self.emberParticles:setEmissionArea("uniform", love.graphics.getWidth(), 0)
    
    -- Update mouse hover detection
    local mx, my = love.mouse.getPosition()
    self.hoveredButton = self:getButtonAtPosition(mx, my)
    
    -- Update selected button based on hover
    if self.hoveredButton then
        self.selectedButton = self.hoveredButton
    end
    
    -- Fade animation
    if self.fadingOut then
        self.fadeAlpha = self.fadeAlpha + self.fadeSpeed * dt
        if self.fadeAlpha >= 1 then
            return "start_game"
        end
    else
        if self.fadeAlpha > 0 then
            self.fadeAlpha = math.max(0, self.fadeAlpha - self.fadeSpeed * dt)
        end
    end
    
    return nil
end

function Menu:getButtonAtPosition(mx, my)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local buttonStartY = height * 0.55
    local buttonSpacing = 80
    
    local buttons = self.currentScreen == "main" and self.mainButtons or self.optionsButtons
    
    for i, button in ipairs(buttons) do
        local y = buttonStartY + (i - 1) * buttonSpacing
        local buttonX = width / 2 - 250
        local buttonY = y - 5
        local buttonWidth = 500
        local buttonHeight = 60
        
        if mx >= buttonX and mx <= buttonX + buttonWidth and
           my >= buttonY and my <= buttonY + buttonHeight then
            return i
        end
    end
    
    return nil
end

function Menu:mousepressed(x, y, button, audio)
    if self.fadingOut then return end
    
    if button == 1 then
        local clickedButton = self:getButtonAtPosition(x, y)
        if clickedButton then
            self.selectedButton = clickedButton
            self:selectButton(audio)
        end
    end
end

function Menu:keypressed(key, audio)
    if self.fadingOut then return end
    
    if key == "w" or key == "up" then
        local buttons = self.currentScreen == "main" and self.mainButtons or self.optionsButtons
        self.selectedButton = self.selectedButton - 1
        if self.selectedButton < 1 then
            self.selectedButton = #buttons
        end
    elseif key == "s" or key == "down" then
        local buttons = self.currentScreen == "main" and self.mainButtons or self.optionsButtons
        self.selectedButton = self.selectedButton + 1
        if self.selectedButton > #buttons then
            self.selectedButton = 1
        end
    elseif key == "a" or key == "left" then
        -- Change resolution left or tutorial page
        if self.currentScreen == "options" and self.selectedButton == 1 then
            self.selectedResolution = self.selectedResolution - 1
            if self.selectedResolution < 1 then
                self.selectedResolution = #self.resolutions
            end
            if audio then
                audio:playSFX("button_select")
            end
        elseif self.currentScreen == "tutorial" then
            self.currentTutorialPage = self.currentTutorialPage - 1
            if self.currentTutorialPage < 1 then
                self.currentTutorialPage = #self.tutorialPages
            end
            if audio then
                audio:playSFX("button_select")
            end
        end
    elseif key == "d" or key == "right" then
        -- Change resolution right or tutorial page
        if self.currentScreen == "options" and self.selectedButton == 1 then
            self.selectedResolution = self.selectedResolution + 1
            if self.selectedResolution > #self.resolutions then
                self.selectedResolution = 1
            end
            if audio then
                audio:playSFX("button_select")
            end
        elseif self.currentScreen == "tutorial" then
            self.currentTutorialPage = self.currentTutorialPage + 1
            if self.currentTutorialPage > #self.tutorialPages then
                self.currentTutorialPage = 1
            end
            if audio then
                audio:playSFX("button_select")
            end
        end
    elseif key == "return" or key == "space" then
        return self:selectButton(audio)
    elseif key == "escape" then
        if self.currentScreen == "options" or self.currentScreen == "tutorial" then
            self.currentScreen = "main"
            self.selectedButton = 1
            self.currentTutorialPage = 1
            if audio then
                audio:playSFX("button_select")
            end
        end
    end
end

function Menu:selectButton(audio)
    if self.currentScreen == "main" then
        local action = self.mainButtons[self.selectedButton].action
        
        if action == "start" then
            self.fadingOut = true
            if audio then
                audio:playSFX("button_select")
            end
        elseif action == "tutorial" then
            self.currentScreen = "tutorial"
            self.currentTutorialPage = 1
            if audio then
                audio:playSFX("button_select")
            end
        elseif action == "options" then
            self.currentScreen = "options"
            self.selectedButton = 1
            if audio then
                audio:playSFX("button_select")
            end
        elseif action == "quit" then
            if audio then
                audio:playSFX("button_select")
            end
            love.event.quit()
        end
    elseif self.currentScreen == "options" then
        local action = self.optionsButtons[self.selectedButton].action
        
        if action == "resolution" then
            -- Cycle through resolutions
            self.selectedResolution = self.selectedResolution + 1
            if self.selectedResolution > #self.resolutions then
                self.selectedResolution = 1
            end
            if audio then
                audio:playSFX("button_select")
            end
        elseif action == "apply" then
            -- Apply resolution
            local res = self.resolutions[self.selectedResolution]
            love.window.setMode(res.width, res.height)
            print("Resolution changed to " .. res.width .. "x" .. res.height)
            if audio then
                audio:playSFX("button_select")
            end
        elseif action == "back" then
            self.currentScreen = "main"
            self.selectedButton = 1
            if audio then
                audio:playSFX("button_select")
            end
        end
    elseif self.currentScreen == "tutorial" then
        -- Exit tutorial on any button press
        self.currentScreen = "main"
        self.selectedButton = 1
        self.currentTutorialPage = 1
        if audio then
            audio:playSFX("button_select")
        end
    end
end

function Menu:drawBackground()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    if self.usingBackground and self.backgroundImage then
        love.graphics.setColor(1, 1, 1, 1)
        local imgWidth = self.backgroundImage:getWidth()
        local imgHeight = self.backgroundImage:getHeight()
        
        local scaleX = width / imgWidth
        local scaleY = height / imgHeight
        local scale = math.max(scaleX, scaleY)
        
        local drawX = (width - imgWidth * scale) / 2
        local drawY = (height - imgHeight * scale) / 2
        
        love.graphics.draw(self.backgroundImage, drawX, drawY, 0, scale, scale)
        
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, width, height)
        love.graphics.setColor(1, 1, 1, 1)
    else
        for i = 0, height do
            local t = i / height
            love.graphics.setColor(0.05 + 0.02 * t, 0.01, 0.01, 1)
            love.graphics.rectangle("fill", 0, i, width, 1)
        end
    end
end

function Menu:drawMainMenu()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Draw title
    love.graphics.setColor(1, 1, 1, 1)
    local titleFont = love.graphics.newFont(80)
    love.graphics.setFont(titleFont)
    
    love.graphics.setColor(1, 0.8, 0.6, 1)
    love.graphics.printf("DANTE'S DESCENT", 0, height * 0.25, width, "center")
    
    love.graphics.setColor(0.8, 0.4, 0.2, 0.8)
    local subtitleFont = love.graphics.newFont(20)
    love.graphics.setFont(subtitleFont)
    love.graphics.printf("Journey Through the Inferno", 0, height * 0.25 + 80, width, "center")
    
    -- Draw buttons
    self:drawButtons(self.mainButtons)
    
    -- Controls hint
    love.graphics.setColor(0.5, 0.3, 0.2, 0.6)
    local hintFont = love.graphics.newFont(18)
    love.graphics.setFont(hintFont)
    love.graphics.printf(
        "W/S or <-/-> to navigate  |  ENTER, SPACE or CLICK to select",
        0, height - 40, width, "center"
    )
end

function Menu:drawTutorialScreen()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    local page = self.tutorialPages[self.currentTutorialPage]
    
    -- Draw title
    love.graphics.setColor(1, 0.8, 0.6, 1)
    local titleFont = love.graphics.newFont(70)
    love.graphics.setFont(titleFont)
    love.graphics.printf(page.title, 0, height * 0.15, width, "center")
    
    -- Draw control items
    local startY = height * 0.35
    local spacing = 100
    
    local keyFont = love.graphics.newFont(36)
    local descFont = love.graphics.newFont(28)
    
    for i, control in ipairs(page.controls) do
        local y = startY + (i - 1) * spacing
        
        -- Key background box
        love.graphics.setColor(0.8, 0.3, 0.1, 0.4)
        love.graphics.rectangle("fill", width / 2 - 350, y - 15, 300, 70, 10, 10)
        
        love.graphics.setColor(1, 0.5, 0.2, 0.8)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", width / 2 - 350, y - 15, 300, 70, 10, 10)
        
        -- Key text
        love.graphics.setFont(keyFont)
        love.graphics.setColor(1, 0.9, 0.7, 1)
        love.graphics.printf(control.key, width / 2 - 350, y, 300, "center")
        
        -- Arrow
        love.graphics.setFont(descFont)
        love.graphics.setColor(1, 0.6, 0.2, 1)
        love.graphics.printf("→", width / 2 - 20, y + 5, 40, "center")
        
        -- Description
        love.graphics.setColor(0.9, 0.8, 0.9, 1)
        love.graphics.printf(control.description, width / 2 + 50, y + 5, 400, "left")
    end
    
    -- Hint text at bottom
    love.graphics.setColor(0.8, 0.4, 0.2, 0.9)
    local hintFont = love.graphics.newFont(24)
    love.graphics.setFont(hintFont)
    love.graphics.printf(page.hint, 0, height * 0.75, width, "center")
    
    -- Page indicator
    love.graphics.setColor(0.6, 0.4, 0.3, 0.8)
    local pageFont = love.graphics.newFont(20)
    love.graphics.setFont(pageFont)
    love.graphics.printf(
        "Page " .. self.currentTutorialPage .. " of " .. #self.tutorialPages,
        0, height * 0.85, width, "center"
    )
    
    -- Navigation hint
    love.graphics.setColor(0.5, 0.3, 0.2, 0.6)
    local navFont = love.graphics.newFont(18)
    love.graphics.setFont(navFont)
    
    local navText = "A/D or <-/-> to change page  |  ESC, ENTER or SPACE to return"
    if self.currentTutorialPage == #self.tutorialPages then
        navText = "Press ESC, ENTER or SPACE to return to menu"
    end
    
    love.graphics.printf(navText, 0, height - 40, width, "center")
    
    -- Draw arrows if there are multiple pages
    if #self.tutorialPages > 1 then
        love.graphics.setColor(1, 0.6, 0.2, 0.8)
        local arrowFont = love.graphics.newFont(50)
        love.graphics.setFont(arrowFont)
        
        if self.currentTutorialPage > 1 then
            local leftPulse = math.sin(love.timer.getTime() * 3) * 10
            love.graphics.printf("<-", 50 - leftPulse, height / 2 - 25, 100, "left")
        end
        
        if self.currentTutorialPage < #self.tutorialPages then
            local rightPulse = math.sin(love.timer.getTime() * 3) * 10
            love.graphics.printf("->", width - 150 + rightPulse, height / 2 - 25, 100, "right")
        end
    end
end

function Menu:drawOptionsMenu()
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    
    -- Draw title
    love.graphics.setColor(1, 0.8, 0.6, 1)
    local titleFont = love.graphics.newFont(60)
    love.graphics.setFont(titleFont)
    love.graphics.printf("OPTIONS", 0, height * 0.25, width, "center")
    
    -- Draw resolution selection
    local buttonFont = love.graphics.newFont(40)
    love.graphics.setFont(buttonFont)
    
    local buttonStartY = height * 0.55
    local buttonSpacing = 80
    
    for i, button in ipairs(self.optionsButtons) do
        local y = buttonStartY + (i - 1) * buttonSpacing
        local isSelected = (i == self.selectedButton)
        
        -- Button background
        if isSelected then
            local boxPulse = math.sin(love.timer.getTime() * 5) * 5
            love.graphics.setColor(0.8, 0.3, 0.1, 0.3)
            love.graphics.rectangle("fill", width / 2 - 250 - boxPulse, y - 5, 500 + boxPulse * 2, 60)
            
            love.graphics.setColor(1, 0.5, 0.2, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", width / 2 - 250 - boxPulse, y - 5, 500 + boxPulse * 2, 60)
        end
        
        -- Button text
        if button.action == "resolution" then
            -- Show current resolution
            local resText = self.resolutions[self.selectedResolution].text
            if isSelected then
                love.graphics.setColor(1, 0.9, 0.7, 1)
            else
                love.graphics.setColor(0.6, 0.4, 0.3, 0.8)
            end
            love.graphics.printf(resText, 0, y, width, "center")
            
            -- Draw arrows if selected
            if isSelected then
                love.graphics.setColor(1, 0.6, 0.2, 1)
                local arrowOffset = math.sin(love.timer.getTime() * 4) * 10
                love.graphics.printf("<-", -300 - arrowOffset, y, width, "center")
                love.graphics.printf("->", 300 + arrowOffset, y, width, "center")
            end
        else
            if isSelected then
                love.graphics.setColor(1, 0.9, 0.7, 1)
            else
                love.graphics.setColor(0.6, 0.4, 0.3, 0.8)
            end
            love.graphics.printf(button.text, 0, y, width, "center")
            
            if isSelected and button.action ~= "resolution" then
                love.graphics.setColor(1, 0.6, 0.2, 1)
                local arrowOffset = math.sin(love.timer.getTime() * 4) * 10
                love.graphics.printf("->", -250 - arrowOffset, y, width, "center")
                love.graphics.printf("<-", 250 + arrowOffset, y, width, "center")
            end
        end
    end
    
    -- Controls hint
    love.graphics.setColor(0.5, 0.3, 0.2, 0.6)
    local hintFont = love.graphics.newFont(18)
    love.graphics.setFont(hintFont)
    love.graphics.printf(
        "W/S or <-/-> to navigate  |  A/D or <-/-> to change  |  ENTER to apply  |  ESC to go back",
        0, height - 40, width, "center"
    )
end

function Menu:drawButtons(buttons)
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()
    local buttonFont = love.graphics.newFont(40)
    love.graphics.setFont(buttonFont)
    
    local buttonStartY = height * 0.55
    local buttonSpacing = 80
    
    for i, button in ipairs(buttons) do
        local y = buttonStartY + (i - 1) * buttonSpacing
        local isSelected = (i == self.selectedButton)
        
        if isSelected then
            local boxPulse = math.sin(love.timer.getTime() * 5) * 5
            love.graphics.setColor(0.8, 0.3, 0.1, 0.3)
            love.graphics.rectangle("fill", width / 2 - 200 - boxPulse, y - 5, 400 + boxPulse * 2, 60)
            
            love.graphics.setColor(1, 0.5, 0.2, 0.8)
            love.graphics.setLineWidth(3)
            love.graphics.rectangle("line", width / 2 - 200 - boxPulse, y - 5, 400 + boxPulse * 2, 60)
        end
        
        if isSelected then
            love.graphics.setColor(1, 0.9, 0.7, 1)
        else
            love.graphics.setColor(0.6, 0.4, 0.3, 0.8)
        end
        
        love.graphics.printf(button.text, 0, y, width, "center")
        
        if isSelected then
            love.graphics.setColor(1, 0.6, 0.2, 1)
            local arrowOffset = math.sin(love.timer.getTime() * 4) * 10
            love.graphics.printf("→", -250 - arrowOffset, y, width, "center")
            love.graphics.printf("←", 250 + arrowOffset, y, width, "center")
        end
    end
end

function Menu:draw()
    self:drawBackground()
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.emberParticles)
    
    if self.currentScreen == "main" then
        self:drawMainMenu()
    elseif self.currentScreen == "options" then
        self:drawOptionsMenu()
    elseif self.currentScreen == "tutorial" then
        self:drawTutorialScreen()
    end
    
    -- Fade overlay
    if self.fadeAlpha > 0 then
        love.graphics.setColor(0, 0, 0, self.fadeAlpha)
        love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

return Menu