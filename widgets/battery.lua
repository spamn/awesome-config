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

    if not helpers.file_exists(bat_dir .. "status") then
        battery_widget.on_ac_cord = function(self, bool) end
        battery_widget.get_on_ac_power = function(self) return true end
        return battery_widget
    end

    local helper_args = {
        name = "battery",
        widget = battery_widget,
        -- disable control with mouse wheel when cursor is over the widget
        handle_mouse_wheel = false
    }
    setmetatable(helper_args, { __index = args })
    local w_helper = require('lib.widget_helper'):new(helper_args)

    local charge_full = 0
    local charge_now = 0
    local current_now = 1 -- avoid division by zero
    local status = "Unknown"
    local remaining_time = nil
    local warning_notif = nil

    --[[ Show warning notification ]]
    local function warn()
        local notif_args = {
            icon = self._path_to_icons .. "battery-empty-symbolic.svg",
            icon_size=100,
            text = string.format("Battery below %d%%, plug AC adapter or save your work and shutdown", capacity),
            title = "Battery is dying",
            timeout = 10, hover_timeout = 1,
            position = "bottom_right",
            bg = "#F06060",
            fg = "#EEE9EF",
            width = 300,
            destroy = function () warning_notif = nil end
        }
        if (warning_notif) then
            notif_args.replaces_id = warning_notif.id
        end
        warning_notif = naughty.notify(warning_notif)
    end

    function battery_widget:get_on_ac_power()
        return (1 == tonumber(helpers.first_line(ac_dir .. "online")))
    end

    local function read_from_bat_file(filename)
        return helpers.first_line(bat_dir .. filename)
    end

    function w_helper:update()
        charge_full = tonumber(read_from_bat_file("charge_full")) or 0
        charge_now = tonumber(read_from_bat_file("charge_now")) or 0
        local charge = tonumber(read_from_bat_file("capacity")) or 0
        w_helper:set_percentage(charge)
        current_now = tonumber(read_from_bat_file("current_now")) or 1 -- avoid division by 0
        status = read_from_bat_file("status")
        if (status == 'Unknown') and (1 == tonumber(helpers.first_line(ac_dir .. "online"))) then
            if capacity >= 95 then
                status = 'Full'
            else
                status = 'Charging'
            end
        end
        if status == "Discharging" then
            remaining_time = 3600 * charge_now / current_now
        elseif status == "Charging" then
            remaining_time = 3600 * (charge_full - charge_now) / current_now
        else
            remaining_time = nil
        end
        local batteryType ="battery-empty%s-symbolic"
        if (charge < 15) then warn()
        elseif (charge >= 15 and charge < 40) then batteryType="battery-caution%s-symbolic"
        elseif (charge >= 40 and charge < 60) then batteryType="battery-low%s-symbolic"
        elseif (charge >= 60 and charge < 80) then batteryType="battery-good%s-symbolic"
        elseif (charge >= 80) then batteryType="battery-full%s-symbolic"
        end
        if status == 'Charging' or status == 'Full' then
            batteryType = string.format(batteryType,'-charging')
        else
            batteryType = string.format(batteryType,'')
        end
        w_helper:set_image(batteryType .. ".svg")
        w_helper:update_notification()
    end

    w_helper:update()

    function w_helper:notify()
        local notif_text = ""
        notif_text = notif_text .. string.format(" %3d%%", self:get_percentage())
        if remaining_time then
            notif_text = notif_text .. string.format(" >> %dh%dm", math.floor(remaining_time / 3600), math.floor(remaining_time / 60) % 60)
        end
        local notify_args = {
            title = "Battery (" .. status .. ")",
            text = notif_text,
            timeout = 5,
        }
        w_helper:generate_notification(notify_args)
    end

    return battery_widget
end

return factory
