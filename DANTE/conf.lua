function love.conf(t)
    t.identity = "DantesInferno"
    t.version = "11.4"
    t.console = false

    t.window.title = "Dante's Descent"
    t.window.width = 1920   
    t.window.height = 1080
    t.window.icon = "icon.png"

    t.window.resizable = false
    t.window.vsync = 1

    t.modules.joystick = false
    t.modules.physics = true
end