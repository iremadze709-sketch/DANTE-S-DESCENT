local Audio = {}
Audio.__index = Audio

function Audio:new()
    local obj = setmetatable({}, self)
    
    -- Volume settings 
    obj.masterVolume = 0.5
    obj.musicVolume = 0.5
    obj.sfxVolume = 0.6
    
    -- Individual SFX volume overrides (multipliers)
    obj.sfxVolumeOverrides = {
        shield_block = 0.4,
        player_attack = 0.4,  
        skeleton_attack = 0.7,
        skeleton_hit = 0.8,
        skeleton_death = 0.8,
        player_hit = 0.9,
        running = 0.25,  
    }
    
    -- Music tracks
    obj.music = {}
    obj.currentMusic = nil
    obj.nextMusic = nil
    
    -- Fade settings
    obj.isFading = false
    obj.fadeOutSpeed = 1.5
    obj.fadeInSpeed = 1.5
    obj.fadeVolume = 1.0
    obj.fadeState = "none"
    
    -- Sound effects
    obj.sfx = {}
    
    -- Looping sound effects (for running, etc.)
    obj.loopingSounds = {}
    
    -- Load music
    obj:loadMusic("menu", "assets/sounds/music/menu_music.mp3")
    obj:loadMusic("game", "assets/sounds/music/game_music.mp3")
    
    -- Load sound effects
    obj:loadSFX("player_attack", "assets/sounds/sfx/player_attack.mp3")
    obj:loadSFX("player_hit", "assets/sounds/sfx/player_hit.mp3")
    obj:loadSFX("skeleton_hit", "assets/sounds/sfx/skeleton_hit.mp3")
    obj:loadSFX("skeleton_death", "assets/sounds/sfx/skeleton_death.mp3")
    obj:loadSFX("skeleton_attack", "assets/sounds/sfx/skeleton_attack.mp3")
    obj:loadSFX("shield_block", "assets/sounds/sfx/shield_block.mp3")
    obj:loadSFX("tear_pickup", "assets/sounds/sfx/tear_pickup.mp3")
    obj:loadSFX("button_select", "assets/sounds/sfx/button_select.mp3")
    
    -- Try to load running sound (optional - won't crash if missing)
    local runningLoaded = obj:loadSFX("running", "assets/sounds/sfx/running.mp3")
    
    
    return obj
end

-- Update function 
function Audio:update(dt)
    if self.fadeState == "fading_out" then
        self.fadeVolume = self.fadeVolume - self.fadeOutSpeed * dt
        
        if self.fadeVolume <= 0 then
            self.fadeVolume = 0
            
            if self.currentMusic then
                self.currentMusic:stop()
            end
            
            if self.nextMusic then
                self.currentMusic = self.nextMusic
                self.currentMusic:setVolume(0)
                self.currentMusic:play()
                self.fadeState = "fading_in"
                self.nextMusic = nil
            else
                self.fadeState = "none"
            end
        end
        
        if self.currentMusic then
            self.currentMusic:setVolume(self.fadeVolume * self.musicVolume * self.masterVolume)
        end
        
    elseif self.fadeState == "fading_in" then
        self.fadeVolume = self.fadeVolume + self.fadeInSpeed * dt
        
        if self.fadeVolume >= 1 then
            self.fadeVolume = 1
            self.fadeState = "none"
        end
        
        if self.currentMusic then
            self.currentMusic:setVolume(self.fadeVolume * self.musicVolume * self.masterVolume)
        end
    end
end

-- Load music 
function Audio:loadMusic(name, filepath)
    local success, music = pcall(love.audio.newSource, filepath, "stream")
    if success then
        music:setLooping(true)
        music:setVolume(self.musicVolume * self.masterVolume)
        self.music[name] = music
      
        return true
    else
        
        return false
    end
end

-- Load sound effect (loads into memory, good for short sounds)
function Audio:loadSFX(name, filepath)
    local success, sfx = pcall(love.audio.newSource, filepath, "static")
    if success then
        sfx:setVolume(self.sfxVolume * self.masterVolume)
        self.sfx[name] = sfx
      
        return true
    else
      
        return false
    end
end

-- Play music with fade
function Audio:playMusic(name, immediate)
    if not self.music[name] then
      
        return
    end
    
    local targetMusic = self.music[name]
    
    if self.currentMusic == targetMusic and self.currentMusic:isPlaying() then
        return
    end
    
    if immediate then
        if self.currentMusic then
            self.currentMusic:stop()
        end
        self.currentMusic = targetMusic
        self.fadeVolume = 1.0
        self.fadeState = "none"
        self.currentMusic:setVolume(self.musicVolume * self.masterVolume)
        self.currentMusic:play()
       
    else
        if self.currentMusic and self.currentMusic:isPlaying() then
            self.nextMusic = targetMusic
            self.fadeState = "fading_out"
           
        else
            self.currentMusic = targetMusic
            self.fadeVolume = 0
            self.fadeState = "fading_in"
            self.currentMusic:setVolume(0)
            self.currentMusic:play()
           
        end
    end
end

-- Stop music with fade
function Audio:stopMusic(immediate)
    if not self.currentMusic then
        return
    end
    
    if immediate then
        self.currentMusic:stop()
        self.fadeState = "none"
        self.fadeVolume = 1.0
        self.currentMusic = nil
    else
        self.nextMusic = nil
        self.fadeState = "fading_out"
    end
end

-- Play sound effect
function Audio:playSFX(name)
    if not self.sfx[name] then
      
        return
    end
    
    -- Clone the sound so multiple instances can play at once
    local sound = self.sfx[name]:clone()
    
    -- Apply volume with any overrides
    local volumeMultiplier = self.sfxVolumeOverrides[name] or 1.0
    local finalVolume = self.sfxVolume * self.masterVolume * volumeMultiplier
    sound:setVolume(finalVolume)
    
    sound:play()
end

-- Play looping sound effect (for running, ambient sounds, etc.)
function Audio:playLoopingSFX(name)
    if not self.sfx[name] then
        -- Don't print warning for optional sounds
        return
    end
    
    -- Check if already playing
    if self.loopingSounds[name] and self.loopingSounds[name]:isPlaying() then
        return
    end
    
    -- Create a looping instance
    local sound = self.sfx[name]:clone()
    sound:setLooping(true)
    
    -- Apply volume with any overrides
    local volumeMultiplier = self.sfxVolumeOverrides[name] or 1.0
    local finalVolume = self.sfxVolume * self.masterVolume * volumeMultiplier
    sound:setVolume(finalVolume)
    
    sound:play()
    self.loopingSounds[name] = sound
end

-- Stop looping sound effect
function Audio:stopLoopingSFX(name)
    if self.loopingSounds[name] then
        self.loopingSounds[name]:stop()
        self.loopingSounds[name] = nil
    end
end

-- Stop all looping sounds
function Audio:stopAllLoopingSFX()
    for name, sound in pairs(self.loopingSounds) do
        sound:stop()
    end
    self.loopingSounds = {}
end

-- Set master volume (0.0 to 1.0)
function Audio:setMasterVolume(volume)
    self.masterVolume = math.max(0, math.min(1, volume))
    self:updateAllVolumes()
end

-- Set music volume (0.0 to 1.0)
function Audio:setMusicVolume(volume)
    self.musicVolume = math.max(0, math.min(1, volume))
    self:updateAllVolumes()
end

-- Set SFX volume (0.0 to 1.0)
function Audio:setSFXVolume(volume)
    self.sfxVolume = math.max(0, math.min(1, volume))
    self:updateAllVolumes()
end

-- Update all volumes
function Audio:updateAllVolumes()
    if self.currentMusic then
        self.currentMusic:setVolume(self.fadeVolume * self.musicVolume * self.masterVolume)
    end
    
    for _, sfx in pairs(self.sfx) do
        sfx:setVolume(self.sfxVolume * self.masterVolume)
    end
    
    -- Update looping sounds volumes
    for name, sound in pairs(self.loopingSounds) do
        local volumeMultiplier = self.sfxVolumeOverrides[name] or 1.0
        local finalVolume = self.sfxVolume * self.masterVolume * volumeMultiplier
        sound:setVolume(finalVolume)
    end
end

return Audio