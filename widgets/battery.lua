local wibox = require("wibox")
local awful = require("awful")
local naughty = require("naughty")
local watch = require("awful.widget.watch")
local helpers = require("lib.helpers")

local function factory(args)

    if args == nil then
        args = {}
    end

    local battery_widget = wibox.widget {
        {
            id = "icon",
            widget = wibox.widget.imagebox,
            resize = false
        },
        layout = wibox.container.margin(_, _, _, 3),
        set_image = function(self, path)
            self.icon.image = path
        end
    }

    local bat_dir = args.bat_dir or "/sys/class/power_supply/BAT0/"
    local ac_dir = args.bat_dir or "/sys/class/power_supply/ADP0/"

    if not helpers.file_exists(bat_dir .. "status") then return battery_widget end

    battery_widget._path_to_icons = args.path_to_icons or "/usr/share/icons/Adwaita/scalable/status/"

    function battery_widget:read(filename)
        return helpers.first_line(bat_dir .. filename)
    end

    function battery_widget:update_notification()
        if self._notification ~= nil then
            self:notify()
        end
    end

    function battery_widget:update()
        self._charge_full = tonumber(self:read("charge_full")) or 0
        self._charge_now = tonumber(self:read("charge_now")) or 0
        self._capacity = tonumber(self:read("capacity")) or 0
        self._current_now = tonumber(self:read("current_now")) or 1 -- avoid division by 0
        self._status = self:read("status")
        if (self._status == 'Unknown') and (1 == tonumber(helpers.first_line(ac_dir .. "online"))) then
            if self._capacity >= 95 then
                self._status = 'Full'
            else
                self._status = 'Charging'
            end
        end
        if self._status == "Discharging" then
            self._remaining_time = 3600 * self._charge_now / self._current_now
        elseif self._status == "Charging" then
            self._remaining_time = 3600 * (self._charge_full - self._charge_now) / self._current_now
        else
            self._remaining_time = nil
        end
        local charge = self._capacity
        local batteryType ="battery-empty%s-symbolic"
        if (charge < 15) then self:warn()
        elseif (charge >= 15 and charge < 40) then batteryType="battery-caution%s-symbolic"
        elseif (charge >= 40 and charge < 60) then batteryType="battery-low%s-symbolic"
        elseif (charge >= 60 and charge < 80) then batteryType="battery-good%s-symbolic"
        elseif (charge >= 80) then batteryType="battery-full%s-symbolic"
        end
        if self._status == 'Charging' or self._status == 'Full' then
            batteryType = string.format(batteryType,'-charging')
        else
            batteryType = string.format(batteryType,'')
        end
        self.image = battery_widget._path_to_icons .. batteryType .. ".svg"
        self:update_notification()
    end

    battery_widget:update()

    function battery_widget.update_cb()
        battery_widget:update()
    end

    function battery_widget.notification_destroyed_cb()
        battery_widget._notification = nil
    end

    function battery_widget:notify()
        local notif_text = ""
        notif_text = notif_text .. string.format(" %3d%%", self._capacity)
        if self._remaining_time then
            notif_text = notif_text .. string.format(" >> %dh%dm", math.floor(self._remaining_time / 3600), math.floor(self._remaining_time / 60) % 60)
        end
        local notify_args = {
            title = "Battery (" .. self._status .. ")",
            text = notif_text,
            timeout = 5,
            destroy = self.notification_destroyed_cb,
        }
        if self._notification ~= nil then
            notify_args.replaces_id = self._notification.id
        end
        self._notification = naughty.notify(notify_args)
    end

    function battery_widget:m_enter()
        self._mouse_over = true
        self:notify()
        self:update()
    end

    function battery_widget:m_leave()
        self._mouse_over = false
        if (self._notification ~= nil) then
            naughty.destroy(self._notification)
        end
    end

    helpers.newtimer("bat", 60, battery_widget.update_cb)

    battery_widget:connect_signal("mouse::enter", function() battery_widget:m_enter() end)
    battery_widget:connect_signal("mouse::leave", function() battery_widget:m_leave() end)

    --[[ Show warning notification ]]
    function battery_widget:warn()
        local notif_args = {
            icon = self._path_to_icons .. "battery-empty-symbolic.svg",
            icon_size=100,
            text = string.format("Battery below %d%%, plug AC adapter or save your work and shutdown", self._capacity),
            title = "Battery is dying",
            timeout = 10, hover_timeout = 1,
            position = "bottom_right",
            bg = "#F06060",
            fg = "#EEE9EF",
            width = 300,
            destroy = function () battery_widget._warning = nil end
        }
        if (self._warning) then
            notif_args.replaces_id = self._warning.id
        end
        self._warning = naughty.notify(notif_args)
    end

    return battery_widget
end

return factory
