--[[ Unified Cover Titles: Patch to add centered series/title overlays with alpha transparency ]]
--
local Font = require("ui/font")
local AlphaContainer = require("ui/widget/container/alphacontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local TextBoxWidget = require("ui/widget/textboxwidget")
local userpatch = require("userpatch")
local Screen = require("device").screen
local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")

-- stylua: ignore start
--========================== [[Edit your preferences here]] ================================
local font_size = 17                                       
local border_thickness = 3                                 -- Matched to Folder Size.border.thick
local border_corner_radius = 2                             
local background_alpha = 0.75                              -- Matched from Folder code
local text_color = Blitbuffer.colorFromString("#000000")   
local border_color = Blitbuffer.colorFromString("#000000") 
local background_color = Blitbuffer.COLOR_WHITE            
--==========================================================================================
-- stylua: ignore end

local function patchAddSeriesIndicator(plugin)
    local MosaicMenu = require("mosaicmenu")
    local MosaicMenuItem = userpatch.getUpValue(MosaicMenu._updateItemsBuildUI, "MosaicMenuItem")
    local BookInfoManager = require("bookinfomanager")

    if not MosaicMenuItem or MosaicMenuItem.patched_series_badge then
        return
    end
    MosaicMenuItem.patched_series_badge = true
	
    local orig_MosaicMenuItem_init = MosaicMenuItem.init
    local orig_MosaicMenuItem_paint = MosaicMenuItem.paintTo
    local orig_MosaicMenuItem_free = MosaicMenuItem.free

    function MosaicMenuItem:init()
        orig_MosaicMenuItem_init(self)

        if self.is_directory or self.file_deleted then
            return
        end

		local bookinfo = BookInfoManager:getBookInfo(self.filepath, false)
		if bookinfo then
            local display_text = bookinfo.title or "Unknown Title"
            if bookinfo.series_index then
                display_text = display_text .. " (#" .. bookinfo.series_index .. ")"
            end
			
			self.has_series_badge = true
            self.display_text = display_text
        end
    end

    function MosaicMenuItem:paintTo(bb, x, y)
        orig_MosaicMenuItem_paint(self, bb, x, y)

        if self.has_series_badge then
            -- Find the cover image target within the menu item
            local target = self[1][1][1]
            if not target or not target.dimen then
                return
            end

            if not self.series_badge then
                -- Width logic: Matches the full width of the cover image minus borders
                local target_w = target.dimen.w - (2 * border_thickness)
                
                local series_text = TextBoxWidget:new{
                    text = self.display_text,
                    face = Font:getFace("cfont", font_size),
                    bold = true,
                    fgcolor = text_color,
                    width = target_w, 
                    alignment = "center",
                }
                
                self.series_badge = FrameContainer:new{
                    linesize = Screen:scaleBySize(2),
                    radius = Screen:scaleBySize(border_corner_radius),
                    color = border_color,
                    bordersize = border_thickness,
                    padding = 0, 
                    AlphaContainer:new{
                        alpha = background_alpha,
                        background = background_color, -- Tinted background logic
                        padding = Screen:scaleBySize(4),
                        series_text,
                    }
                }
                self._series_text = series_text
            end

			local badge_size = self.series_badge:getSize()

            -- Perfectly centered horizontally and vertically over the cover image
            local badge_x = target.dimen.x + (target.dimen.w - badge_size.w) / 2
			local badge_y = target.dimen.y + (target.dimen.h - badge_size.h) / 2

            self.series_badge:paintTo(bb, badge_x, badge_y)
        end
    end
	
	if orig_MosaicMenuItem_free then
		function MosaicMenuItem:free()
			if self._series_text then
				self._series_text:free(true)
				self._series_text = nil
			end
			if self.series_badge then
				self.series_badge:free(true)
				self.series_badge = nil
			end
			orig_MosaicMenuItem_free(self)
		end
	end
end

userpatch.registerPatchPluginFunc("coverbrowser", patchAddSeriesIndicator)
