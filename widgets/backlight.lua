local awful = require("awful")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local helpers = require("lib.helpers")

local function factory(args)

    if args == nil then
        args = {}
        --see https://stackoverflow.com/questions/6022519/define-default-values-for-function-arguments for adding default arguments
    end

    local backlight_widget = wibox.widget {
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
        name = "backlight",
        widget = backlight_widget,
        -- control with mouse wheel when cursor is over the widget
        handle_mouse_wheel = true
    }
    setmetatable(helper_args, { __index = args })
    local w_helper = require('lib.widget_helper'):new(helper_args)

    w_helper:set_image("display-brightness-symbolic.svg")

    local widget_update_pending = false
    local last_update = 0
    local current_backlight = 0

    function w_helper:set_percentage(percentage)
        awful.spawn(string.format("xbacklight =%d", percentage), false)
        current_backlight = percentage
    end

    local function get_percentage(self)
        return current_backlight
    end

    local function get_dummy_percentage(self)
        return 50
    end

    w_helper.get_percentage = get_percentage

    function backlight_widget:_update_widget(stdout, stderr, _, _)
        local backlight = tonumber(stdout)
        local clock_now = os.clock()
        -- set are not immediate (there is a delay before the get is right), workaround that
        if (clock_now - last_update > 0.1) then
            if (backlight == nil) then
                w_helper.get_percentage = get_dummy_percentage
            else
                w_helper.get_percentage = get_percentage
            end
            last_update = clock_now
        end

        widget_update_pending = false

        w_helper:handle_increment()
        w_helper:update_notification()
    end

    function w_helper:update()
        local need_xbacklight_get = true
        need_xbacklight_get = need_xbacklight_get and (not widget_update_pending)
        if (need_xbacklight_get) then
            widget_update_pending = true
            spawn.easy_async("xbacklight -get", function(stdout, stderr, exitreason, exitcode)
                backlight_widget:_update_widget(stdout, stderr, exitreason, exitcode)
            end)
        end
    end

    function w_helper:notify()
        local notify_args = {
            title = "Backlight",
            text = w_helper:make_progress_bar(),
            timeout = 1,
        }
        w_helper:generate_notification(notify_args)
    end

    function backlight_widget:increase_value(increment)
        w_helper.increase_perct(increment)
    end

    backlight_widget:connect_signal("button::press", function(_,_,_,button,mods)
        if (button == 1) then
            w_helper:increase_perct(50 - w_helper:get_percentage())
        end

    end)

    w_helper:update()

    return backlight_widget
end

return factory
