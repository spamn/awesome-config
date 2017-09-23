--[[

     Licensed under GNU General Public License v2

--]]

--[[
    Common object to put some functionality in common between widget
    - Handle having a single notification that appears when mouse is over widget
    - Set a periodical update for the widget data
    - etc ...

    This object has been created because I had too much duplicated code
--]]

local naughty = require("naughty")
local helpers = require("lib.helpers")
local factory = {}


function factory:new(args)
    local base = {}
    if not args or not args.widget then
        return nil
    end

    local widget = args.widget
    -- hf high frequency
    -- lf low frequency
    local hf_period = args.hf_period or 10
    local lf_period = args.lf_period or 300
    local path_to_icons = args.path_to_icons or "/usr/share/icons/Adwaita/scalable/status/"
    local notification = nil
    local hf_timer
    local mouse_over = false
    local percentage = 0
    local increment = 0
    local handle_mouse_wheel = args.handle_mouse_wheel or false -- call increase_perct on mouse wheel
    local min_notify_char_count = args.min_notify_char_count or 25

    function base:make_progress_bar(_char_width)
        local char_width = _char_width or min_notify_char_count
        local ret = ""
        local perct = self:get_percentage()
        local max_bar_count = char_width - 5
        if (max_bar_count > 0) then
            local bar_count = math.floor(perct * max_bar_count / 100 + 0.5)
            ret = string.rep("|", bar_count) .. string.rep(" ", max_bar_count - bar_count)
        end
        ret = ret .. string.format(" %3d%%", perct)
        return ret
    end

    base.update = function(self)
        -- function to override, called periodically and when entering widget with mouse and a few other events
    end

    base.notify = function (self)
        local notif_args = { title = "Override me", text = "Please"}
        self:generate_notification(notif_args);
    end

    -- Call this function when you want the stacked increments to take effect
    base.handle_increment = function(self)
        if increment ~= 0 then
            local new_percentage = self:get_percentage() + increment
            if new_percentage > 100 then
                new_percentage = 100
            elseif new_percentage < 0 then
                new_percentage = 0
            end
            if new_percentage ~= self:get_percentage() then
                self:set_percentage(new_percentage)
            end
        end
        increment = 0
    end

    base.increase_perct = function(self, value)
        increment = increment + (tonumber(value) or 0)
        self:update()
        self:notify()
    end

    base.set_percentage = function(self, perc)
        -- function to override if needed
        percentage = perc
    end

    base.get_percentage = function(self)
        -- function to override if needed
        return percentage
    end

    base.set_image = function(self, name)
        if (widget) then
            widget.icon.image = path_to_icons .. name;
        end
    end

    base.generate_notification = function(self, notif_args)
        if notification ~= nil then
            notif_args.replaces_id = notification.id
        end
        if (#notif_args.title < min_notify_char_count) then
            notif_args.title = notif_args.title .. string.rep(" ", min_notify_char_count - #notif_args.title)
        end
        notif_args.destroy = function() notification = nil end
        notification = naughty.notify(notif_args)
    end

    base.update_notification = function(self)
        if notification ~= nil then
            self:notify()
        end
    end

    base.m_enter = function(self)
        mouse_over = true
        self:notify()
        self:update()
    end

    base.m_leave = function(self)
        mouse_over = false
        if (notification ~= nil) then
            naughty.destroy(notification)
        end
    end

    local widget_helper = { }
    setmetatable(widget_helper, { __index = base })

    widget:connect_signal("mouse::enter", function() widget_helper:m_enter() end)
    widget:connect_signal("mouse::leave", function() widget_helper:m_leave() end)

    hf_timer = helpers.newtimer(args.name or "timer_with_no_name", hf_period, function() widget_helper:update() end, true, true)
    hf_timer:stop()
    helpers.newtimer(args.name or "timer_with_no_name", lf_period, function() widget_helper:update() end)

    -- allow control when cursor is over the widget and using mouse wheel
    if (handle_mouse_wheel) then
        widget:connect_signal("button::press", function(_,_,_,button,mods)
            local incr = 5;
            for i,mod in ipairs(mods) do
                if mod == "Shift" then
                    incr = 1;
                end
            end
            if (button == 4)     then widget_helper:increase_perct(incr)
            elseif (button == 5) then widget_helper:increase_perct(-incr)
            end
        end)
    end

    local is_on_ac_cord = false

    base.on_ac_cord = function(self, bool)
        if bool ~= is_on_ac_cord then
            is_on_ac_cord = bool
            if bool then
                hf_timer:again()
            else
                hf_timer:stop()
            end
            self:update()
        end
    end

    -- widget.helper = widget_helper
    widget.on_ac_cord = function(self, bool) widget_helper:on_ac_cord(bool)  end

    return widget_helper
end

return factory
