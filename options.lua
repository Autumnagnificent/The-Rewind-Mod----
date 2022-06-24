#include helper.lua

local function Reset()
	SetString("savegame.mod.mode", "rewind")
	SetFloat('savegame.mod.volume', 0.2)
	SetFloat('savegame.mod.visualeffects', 0.0)
	SetInt('savegame.mod.group', 6)

	SetFloat('savegame.mod.playspeedincrement', 1)
	SetFloat('savegame.mod.playspeedmax', 1)
	SetFloat('savegame.mod.altrewindspeed', 1)
	SetBool('savegame.mod.showcassetteplayer', true)
	SetBool('savegame.mod.onlytrackvisible', false)

	SetFloat('savegame.mod.accuracy', 0.8)
	SetFloat('savegame.mod.maxdistance', 50)
	SetBool('savegame.mod.interpolate', true)
	
	UiSound("snd/TapeEject.ogg", GetFloat('savegame.mod.volume'))
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

function init()
	x0, y0, x1, y1 = UiSafeMargins()

	campos = GetCameraTransform().pos
	sndTapeLoop = LoadLoop('snd/TapeLoop.ogg')
	sndTheme = LoadLoop('snd/Theme.ogg')
	
	lerpvol = 0
	MasterBlur = 1
	SetValue("MasterBlur", 0, "easeout", 0.25)
	
	tooltips = {}
	ShowDangerZone = false
	
	num = .4
	
	MaxPoints = function () return Round(GetKeyWithDefault("float", 'savegame.mod.maxdistance', 50) / (1 - GetKeyWithDefault("float", 'savegame.mod.accuracy', 0.9)), 1) end
end

function tick(dt)
	local UiVolume = GetKeyWithDefault('float', 'savegame.mod.volume', 0.75)
	lerpvol = Lerp(lerpvol, UiVolume, dt * 3.5)
	-- MasterBlur = Move(MasterBlur, 0, dt * 4.75)
	 PlayLoop(sndTheme, campos, math.max(0, UiVolume * 0.5))

	if InputPressed('lmb') then UiSound('snd/TapeA.ogg', UiVolume) lerpvol = 0 end
	if InputDown('lmb') then PlayLoop(sndTapeLoop, campos, lerpvol) end
	if InputReleased('lmb') then UiSound('snd/TapeB.ogg', UiVolume) end
end

function draw(dt)
	UiColorFilter(1,1,1,1 - MasterBlur)

	if MasterBlur ~= 0 then
		UiDisableInput()
	end

	tooltips = {}

	UiPush()
		UiImage('gfx/OptionMenu.png')
		UiBlur(.3)
	UiPop()

	local data = {}
	
	-- Window 1
	UiPush()
		UiTranslate(x0 + UiSpacing().a, y0 + UiSpacing().a)
		UiSimpleContainer(350, 300)

		UiTranslate(0, UiSpacing().b)
		-- Reset
		data.reset = UiSimpleButton(nil, "Reset To Default")
		if data.reset.value then Reset() end
		UiTranslate(0, UiSpacing().d + data.reset.rect.h)

		-- Volume
		data.volume = UiSimpleSlider('savegame.mod.volume', "Volume", 0.75, 0, 1, 0.05)
		UiTranslate(0, UiSpacing().d + data.volume.rect.h)

		-- Visual Effects
		data.visualeffects = UiSimpleSlider('savegame.mod.visualeffects', "Visual Effects Intensity", 0.2, 0 , 1, 0.1)
		UiTranslate(0, UiSpacing().d + data.visualeffects.rect.h)

		-- Tool Group
		data.toolgroup = UiSimpleSlider('savegame.mod.group', "Tool Group", 6, 1, 6, 1)
		UiTranslate(0, UiSpacing().d + data.toolgroup.rect.h)
	UiPop()

	-- Window 2
	UiPush()
		UiTranslate(x0 + UiSpacing().a + UiSpacing().b + 350, y0 + UiSpacing().a)
		UiSimpleContainer(300, 450)

		UiTranslate(0, UiSpacing().b)

		-- Play Speeds
		data.playspeedincrement = UiSimpleSlider('savegame.mod.playspeedincrement', "Play Speed Increment", 1, 0.01, 1, 0.1)
		UiTranslate(0, UiSpacing().d + data.playspeedincrement.rect.h)
		
		data.playspeedmax = UiSimpleSlider('savegame.mod.playspeedmax', "Play Speed Max", 1, 1, 4, 0.5)
		UiTranslate(0, UiSpacing().d + data.playspeedmax.rect.h)
		
		data.altrewindspeed = UiSimpleSlider('savegame.mod.altrewindspeed', "Alt Rewind Speed", 1, data.playspeedincrement.value, 4, math.max(0.1, data.playspeedincrement.value))
		UiTranslate(0, UiSpacing().d + data.altrewindspeed.rect.h)

		-- Show Cassette Player
		data.showcassetteplayer = UiSimpleTrueFalse("savegame.mod.showcassetteplayer", "Show Cassette Player", false)
		UiTranslate(0, UiSpacing().d + data.showcassetteplayer.rect.h)
		
		-- OnlyTrackVisible
		data.onlytrackvisible = UiSimpleTrueFalse("savegame.mod.onlytrackvisible", "Only Track Visible", false)
		UiTranslate(0, UiSpacing().d + data.onlytrackvisible.rect.h)
		
	UiPop()
	
	-- Window 3
	UiPush()
		UiTranslate(x1 - UiSpacing().a - 300, y0 + UiSpacing().a)
		data.dangerzone = UiSimpleContainer(300, 300)

		if not ShowDangerZone then
			UiTranslate(0, UiSpacing().b)
			data.showdangerzone = UiSimpleButton(nil, "Show Danger Zone")
			if data.showdangerzone.value then ShowDangerZone = true end
		else
			UiTranslate(0, UiSpacing().b)
		end

		data.accuracy = {}
		data.maxdistance = {}
		data.maxpoints = {}
		data.interpolate = {}
		if ShowDangerZone then
			-- Accuracy
			data.accuracy = UiSimpleSlider('savegame.mod.accuracy', "Accuracy", 0.9, 0, 0.99, 0.025)
			UiTranslate(0, UiSpacing().d + data.accuracy.rect.h)

			-- Max Distance
			data.maxdistance = UiSimpleSlider('savegame.mod.maxdistance', "Max Distance", 50, 10, 1000, 5)
			UiTranslate(0, UiSpacing().d + data.maxdistance.rect.h)

			-- Max Points
			data.maxpoints = UiSimpleLabel("Max Points Per Body: "..MaxPoints())
			UiTranslate(0, UiSpacing().d + data.maxpoints.rect.h)

			-- Interpolate
			data.interpolate = UiSimpleTrueFalse("savegame.mod.interpolate", "Interpolate Points", true)
			UiTranslate(0, UiSpacing().d + data.interpolate.rect.h)
		end
	UiPop()
	
	-- Tooltips
	UiPush()
		if data.reset.hover then UiTooltip("Resets all settings to their default values") end
		if data.volume.hover then UiTooltip("The Volume of all Sound Effects. A volume of 0.5 is half volume") end
		if data.volume.slider then UiTooltip(data.volume.value) end
		if data.visualeffects.hover then UiTooltip("The Intensity of all Visual Effects. A value of 0.5 is half intensity") end
		if data.visualeffects.slider then UiTooltip(data.visualeffects.value) end
		if data.toolgroup.hover then UiTooltip("Which Group the Tool will be in. A value of 1 is with the sledgehammer, and a value of 6 is with the modded tools") end
		if data.toolgroup.slider then UiTooltip("Group "..data.toolgroup.value) end

		if data.playspeedincrement.hover then UiTooltip("The amount that the speed will change everytime the player \"ticks\" the scroll wheel") end
		if data.playspeedincrement.slider then UiTooltip(data.playspeedincrement.value) end
		if data.playspeedmax.hover then UiTooltip("The Maximum Speed at which the Tape will play. A value of 1 is normal speed") end
		if data.playspeedmax.slider then UiTooltip( data.playspeedmax.value) end
		if data.altrewindspeed.hover then UiTooltip("The Speed at which the Tape will rewind at when the player presses the \"Alt\" key.") end
		if data.altrewindspeed.slider then UiTooltip(data.altrewindspeed.value.."x") end
		if data.showcassetteplayer.hover then UiTooltip("Whether or not the Tape Player will be shown, use this to hide the visual and make cool cinimatic stuff") end
		if data.onlytrackvisible.hover then UiTooltip("Only allow a body to be recorded if it was first in Visible to the camera. Performance optimization") end

		if (data.dangerzone.hover and not ShowDangerZone) then UiTooltip("These are setting that can cause problems if set to certain values, don't change these unless you understand what they do. You can always reset them, to the defualt values when need be") end
		if data.accuracy.hover then UiTooltip("How Accurate the tracking is, Tracks are only updated when there is a change in position or rotation, Basically, the closer accuracy is to 1, the smaller the movements that can be tracked. An Accuracy of "..data.accuracy.value.." allows movements of "..(1 - data.accuracy.value).." to be tracked.") end
		if data.accuracy.slider then UiTooltip(data.accuracy.value) end
		if data.maxdistance.hover then UiTooltip("The Maximum Distance that an object can be recorded. This distance includes changes to the rotation. Not counting rotation, a value of "..data.maxdistance.value.." is worth "..(data.maxdistance.value*10).." voxels") end
		if data.maxdistance.slider then UiTooltip(data.maxdistance.value) end
		if data.maxpoints.hover then UiTooltip("The Maximum number of points that an object can store. Low Maximum Points = Low Memory Ussage, High Maximum = Points = High Memory Ussage. I recommend High Accuracy paired with a Low Max Distance for the best looking effect, or a Low Accuracy with a Higher Distance for things like driving cars or long cimematic scenes") end
		if data.interpolate.hover then UiTooltip("Enabling Interpolation will make things look buttery smooth even with a low accuracy, at the cost of a very very slight performance hit. I recommend it especially if you are using a Play Speed Increment at less than 1, but if you need to you can disable it") end

	UiPop()

	if MasterBlur > 0 then UiBlur(MasterBlur) end
end