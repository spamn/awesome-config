local awful = require("awful")
local wibox = require("wibox")
local spawn = require("awful.spawn")
local naughty = require("naughty")
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

    backlight_widget._path_to_icons = args.path_to_icons or "/usr/share/icons/Adwaita/scalable/status/"
    backlight_widget.image = backlight_widget._path_to_icons .. "display-brightness-symbolic.svg"
    backlight_widget.increase = 0
    backlight_widget._widget_update_pending = false
    backlight_widget._notification = nil
    backlight_widget._bar_char_count = args.bar_char_count or 20
    backlight_widget._value = 0
    backlight_widget._use_files = helpers.file_exists("/sys/class/backlight/intel_backlight/max_brightness") and helpers.file_exists("/sys/class/backlight/intel_backlight/actual_brightness")
    backlight_widget._increase = 0
    backlight_widget._last_update = 0

    function backlight_widget:_update_widget(stdout, _, _, _)
        local backlight = tonumber(stdout)
        local clock_now = os.clock()
        -- set are not immediate (there is a delay before the get is right), workaround that
        if (clock_now - backlight_widget._last_update > 0.1) then
            self._backlight = backlight or 0
        end

        backlight_widget._last_update = clock_now
        self._widget_update_pending = false

        if self._increase ~= 0 then
            backlight = self._backlight + self._increase
            self._increase = 0
            if backlight > 100 then
                backlight = 100
            elseif backlight < 0 then
                backlight = 0
            end
            awful.spawn("xbacklight =" .. math.floor(0.5 + backlight) .. "%", false)
            self._backlight = backlight
        end

        self:update_notification()
    end

    function backlight_widget:update_notification()
        if self._notification ~= nil then
            self:notify()
        end
    end

    function backlight_widget:update()
        local need_xbacklight_get = true
        if backlight_widget._use_files then
            local actual = tonumber(helpers.first_line("/sys/class/backlight/intel_backlight/actual_brightness"))
            local max = tonumber(helpers.first_line("/sys/class/backlight/intel_backlight/max_brightness"))
            if actual and max then
                need_xbacklight_get = false
                self:_update_widget(100 * actual / max)
            end
        end
        need_xbacklight_get = need_xbacklight_get and (not self._widget_update_pending)
        if (need_xbacklight_get) then
            self._widget_update_pending = true
            spawn.easy_async("xbacklight -get", function(stdout, stderr, exitreason, exitcode)
                self:_update_widget(stdout, stderr, exitreason, exitcode)
            end)
        end
    end

    function backlight_widget:notify()
        local printed_value = string.format(" %3d%%", math.floor(self._backlight + 0.5))
        local notif_text = ""
        local bar_count = math.floor(self._backlight * self._bar_char_count / 100 + 0.5)
        notif_text = string.rep("|", bar_count) .. string.rep(" ", self._bar_char_count - bar_count)
        local notify_args = {
            title = "Backlight",
            text = notif_text .. printed_value,
            timeout = 1,
            destroy = self.notification_destroyed_cb,
        }
        if self._notification ~= nil then
            notify_args.replaces_id = self._notification.id
        end
        self._notification = naughty.notify(notify_args)
    end

    function backlight_widget:increase_value(increment)
        local incr = tonumber(increment)
        if incr ~= nil then
            self._increase = self._increase + incr
        end
        self:update()
        self:notify()
    end

    backlight_widget:connect_signal("button::press", function(_,_,_,button,mods)
        local increment = 5;
        for i,mod in ipairs(mods) do
            if mod == "Shift" then
                increment = 1;
            end
        end
        if (button == 4)     then backlight_widget:increase_value(increment)
        elseif (button == 5) then backlight_widget:increase_value(-increment)
        elseif (button == 1) then backlight_widget:increase_value(50 - backlight_widget._backlight)
        end

    end)

    function backlight_widget:m_enter()
        self:notify()
        self:update()
    end

    function backlight_widget.notification_destroyed_cb()
        backlight_widget._notification = nil
    end

    function backlight_widget:m_leave()
        if (self._notification ~= nil) then
            naughty.destroy(self._notification)
        end
    end

    backlight_widget:connect_signal("mouse::enter", function() backlight_widget:m_enter() end)
    backlight_widget:connect_signal("mouse::leave", function() backlight_widget:m_leave() end)

    backlight_widget:update()
    helpers.newtimer("backlight", 60, function() backlight_widget:update() end)

    return backlight_widget
end

return factory
