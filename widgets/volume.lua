local awful = require("awful")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local helpers = require("lib.helpers")

local request_command = 'amixer -D pulse sget Master'

local function factory(args)

    if args == nil then
        args = {}
        --see https://stackoverflow.com/questions/6022519/define-default-values-for-function-arguments for adding default arguments
    end

    local volume_widget = wibox.widget {
        {
            id = "icon",
            resize = false,
            widget = wibox.widget.imagebox,
        },
        layout = wibox.container.margin(_, _, _, 3),
        set_image = function(self, path)
            self.icon.image = path
        end
    }

    local helper_args = {
        name = "volume",
        widget = volume_widget,
        -- control with mouse wheel when cursor is over the widget
        handle_mouse_wheel = true
    }
    setmetatable(helper_args, { __index = args })
    local w_helper = require('lib.widget_helper'):new(helper_args)

    local toggle_mute = false
    local increase = 0
    local widget_update_pending = false
    local bar_char_count = args.bar_char_count or 20
    local mute_state = false
    local current_volume = 0

    local function _update_widget(stdout, _, _, _)
        local volume = string.match(stdout, "(%d?%d?%d)%%")
        local mute = string.match(stdout, "%[(o%D%D?)%]")
        mute_state = mute == "off"
        current_volume = tonumber(string.format("% 3d", volume))

        widget_update_pending = false

        w_helper:handle_increment()

        if toggle_mute then
            toggle_mute = false
            awful.spawn("amixer -D pulse sset Master toggle", false)
            mute_state = not mute_state
        end

        local volume_icon_name
        if mute_state then volume_icon_name="audio-volume-muted-symbolic"
        elseif (current_volume == 0) then volume_icon_name="audio-volume-muted-symbolic"
        elseif (current_volume < 33) then volume_icon_name="audio-volume-low-symbolic"
        elseif (current_volume < 67) then volume_icon_name="audio-volume-medium-symbolic"
        elseif (current_volume <= 100) then volume_icon_name="audio-volume-high-symbolic"
        end

        w_helper:set_image(volume_icon_name .. ".svg")
        w_helper:update_notification()
    end

    function w_helper:update()
        if (not widget_update_pending) then
            widget_update_pending = true
            spawn.easy_async(request_command, function(stdout, stderr, exitreason, exitcode)
                _update_widget(stdout, stderr, exitreason, exitcode)
            end)
        end
    end

    function w_helper:notify()
        local notify_args = {
            title = "Volume",
            text = w_helper:make_progress_bar(),
            timeout = 1,
        }
        if mute_state then
            -- notify_args.fg = '#ff0000' not working, awesome bug? https://github.com/awesomeWM/awesome/issues/2040
            notify_args.title = notify_args.title .. " (muted)"
        end
        w_helper:generate_notification(notify_args)
    end

    function w_helper:set_percentage(percentage)
        awful.spawn("amixer -D pulse sset Master " .. percentage .. "%", false)
        current_volume = percentage
    end

    function w_helper:get_percentage()
        return current_volume
    end

    function volume_widget:increase_volume(value)
        w_helper:increase_perct(value)
    end

    function volume_widget:toggle_mute()
        toggle_mute = not toggle_mute
        w_helper:notify()
        w_helper:update()
    end

    --[[ allows control volume level by: - clicking on the widget to mute/unmute ]]
    volume_widget:connect_signal("button::press", function(_,_,_,button,mods)
        if (button == 1) then volume_widget:toggle_mute() end
    end)

    w_helper:update()

    return volume_widget
end

return factory
