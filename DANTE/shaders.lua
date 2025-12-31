local Shaders = {}
Shaders.__index = Shaders

function Shaders:new()
    local obj = setmetatable({}, self)
    
   
    obj.gameCanvas = love.graphics.newCanvas()
    
    -- Glow effect for entities 
    obj.entityGlowShader = love.graphics.newShader([[
        extern number time;
        extern vec3 glowColor;
        extern number glowIntensity;
        
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            vec4 pixel = Texel(texture, texture_coords);
            
            if (pixel.a > 0.1) {
                // Very subtle pulsing glow
                float pulse = sin(time * 2.0) * 0.3 + 0.7;
                vec3 glow = glowColor * glowIntensity * pulse;
                pixel.rgb += glow * pixel.a;
            }
            
            return pixel * color;
        }
    ]])
    
    -- Lava pulse shader (subtle)
    obj.lavaPulseShader = love.graphics.newShader([[
        extern number time;
        extern number intensity;
        
        vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
            vec4 pixel = Texel(texture, texture_coords);
            
            // Gentle pulsing brightness
            float pulse = sin(time * 1.5) * 0.1 + 0.9;
            
            // Add subtle orange/red glow
            pixel.r = pixel.r * (1.0 + intensity * pulse * 0.15);
            pixel.g = pixel.g * (1.0 + intensity * pulse * 0.08);
            
            // Very subtle color shift
            float shift = sin(time * 1.0 + texture_coords.y * 8.0) * 0.05;
            pixel.r += shift * intensity;
            
            return pixel * color;
        }
    ]])
    
    -- Settings
    obj.time = 0
    obj.glowIntensity = 0.2
    
    -- Effect toggles
    obj.enableEntityGlow = true
    obj.enableLavaPulse = true
    
    
    return obj
end

function Shaders:update(dt)
    self.time = self.time + dt
end

function Shaders:beginDraw()
    -- Start drawing to canvas
    love.graphics.setCanvas(self.gameCanvas)
    love.graphics.clear()
end

function Shaders:applyEntityGlow(entity, glowColor, intensity)
    if not self.enableEntityGlow then
        return
    end
    
    love.graphics.setShader(self.entityGlowShader)
    self.entityGlowShader:send("time", self.time)
    self.entityGlowShader:send("glowColor", glowColor or {1.0, 0.6, 0.2})
    self.entityGlowShader:send("glowIntensity", intensity or self.glowIntensity)
end

function Shaders:applyLavaPulse(intensity)
    if not self.enableLavaPulse then
        return
    end
    
    love.graphics.setShader(self.lavaPulseShader)
    self.lavaPulseShader:send("time", self.time)
    self.lavaPulseShader:send("intensity", intensity or 0.8)
end

function Shaders:clearShader()
    love.graphics.setShader()
end

function Shaders:endDraw()
    love.graphics.setCanvas()
    
    -- Draw final result (no heat distortion)
    love.graphics.setShader()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.gameCanvas, 0, 0)
end

-- Convenience methods for toggling effects
function Shaders:toggleEntityGlow()
    self.enableEntityGlow = not self.enableEntityGlow
    print(" Entity Glow: " .. (self.enableEntityGlow and "ON" or "OFF"))
end

function Shaders:toggleLavaPulse()
    self.enableLavaPulse = not self.enableLavaPulse
    print("Lava Pulse: " .. (self.enableLavaPulse and "ON" or "OFF"))
end

return Shaders