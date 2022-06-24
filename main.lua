#include helper.lua

local function ClosestTime(i, t)
	t = t or Time

	local tdist = math.huge
	local current = #i
	for k,v in ipairs(i) do
		if v.time > t then
			if tdist > dist(v.time, t) then
				tdist = dist(v.time, t)
				current = k
			end
		end
	end

	return current
end
	
local function hardreset()
	TrackedBodies = {}
	Time = 0
	Activated = false
	TapeRaised = 0
end

local function deleteAhead(body, t)
	for k,v in ipairs(TrackedBodies[body]) do
		if v.time > t then
			TrackedBodies[body][k] = nil
		end
	end
end

local function tablelength(T)
	local count = 0
	for _ in pairs(T) do count = count + 1 end
	return count
end

local function TimeMinMax()
	local min = math.huge
	local max = -math.huge
	for body in pairs(TrackedBodies) do
		local current = #TrackedBodies[body]
		local time = TrackedBodies[body][current].time
		if time > max then max = time end
		if time < min then min = time end
	end

	return min, max
end

local function Display(body)
	if TrackedBodies[body] == nil then
		return
	end
	
	local TB = TrackedBodies[body]
	
	local x, y = UiWorldToPixel(GetBodyWorldCOM(body))
	UiTooltip(#TB, .8, 'center', {x, y}, .75)
	UiTooltip(Round(GetTagValue(body,'initTime'), .1), .8, 'center', {x, y + 24}, .75)
	DrawBodyHighlight(body, .10)
	
	for k,v in ipairs(TrackedBodies[body]) do
		local speed = VecLength(v.motvel) / 10
		local rotspeed = VecLength(v.rotvel) / 10
		local t = logistic(dist(TB[k].time, Time), 2, 4, 1)
		DebugCross(v.pos, 1-t, t, 0, 1)
	end
end

local function GetPostProcSetting()
	return { sat = GetPostProcessingProperty("saturation"), bloom = GetPostProcessingProperty("bloom"), gamma = GetPostProcessingProperty("gamma"), brightness = GetPostProcessingProperty("brightness") }
end

local function ResetProcSettings()
	SetPostProcessingProperty("saturation", DefaultPostProc.sat)
	SetPostProcessingProperty("bloom", DefaultPostProc.bloom)
	SetPostProcessingProperty("brightness", DefaultPostProc.brightness)
	SetPostProcessingProperty("gamma", DefaultPostProc.gamma)
end

local function GetTrackData(body)
	local trans = GetBodyTransform(body)
	local com = GetBodyWorldCOM(body)
	
	return { time = Time, grabbed = (body == GetPlayerGrabBody()), pos = com, rot = trans.rot, motvel = GetBodyVelocity(body), rotvel = GetBodyAngularVelocity(body) }
end

local function ChangeTapeText(i)
	local r = math.random( 1, 1000 )
	if r < 750 then
		TapeDisplayedText = TapeToasts.Common[math.random(1, #TapeToasts.Common)]	
	elseif r < 900 then
		TapeDisplayedText = TapeToasts.Uncommon[math.random(1, #TapeToasts.Uncommon)]	
	elseif r < 950 then
		TapeDisplayedText = TapeToasts.Rare[math.random(1, #TapeToasts.Rare)]	
	else
		TapeDisplayedText = TapeToasts.Legendary[math.random(1, #TapeToasts.Legendary)]	
	end
	-- t = {"Chronomatic", "Chrono", "Chronography", "Time Splitter", "Rift Tearer", "Chaos Subverter", "Epoch Clock", "Era Corrupter", "Time Interpolator", "It's Rewind Time", "SPICY", "! ! ! ! ! ! ! !", "Manipulator", "Burn Me", "Updog", "Hot Stuff", "PRIDE", "Rick Astly", "Behind You"}
	-- TapeDisplayedText = t[iiii]
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

function init()
	iiii = 1
	ToolGroup = GetKeyWithDefault("int", "savegame.mod.group", 2) 

	RegisterTool("chrono", "Chrono Cassete Player", "", ToolGroup)
	SetBool("game.tool.chrono.enabled", true)

	sndTapeA = LoadSound('snd/TapeA.ogg')
	sndTapeB = LoadSound('snd/TapeB.ogg')
	sndTapeLoop = LoadLoop('snd/TapeLoop.ogg')
	sndTapeLoopReverse = LoadLoop('snd/TapeLoopReverse.ogg')
	sndTapeEject = LoadSound('snd/TapeEject.ogg')
	sndMusic = LoadLoop('snd/Theme.ogg')
	sndMusicRev = LoadLoop('snd/ThemeRev.ogg')
	
	Volume = GetKeyWithDefault("float", 'savegame.mod.volume', 0.75)
	VisualEffectsIntensity = GetKeyWithDefault("float", 'savegame.mod.visualeffects', 0.2)
	
	veczero = Vec(0,0,0)
	
	Activated = false
	ShowDebug = false
	
	-- The lower the more accurate
	Accuracy = (1 - GetKeyWithDefault("float", 'savegame.mod.accuracy', 0.8))
	AllowedDistance = GetKeyWithDefault("float", 'savegame.mod.maxdistance', 50)
	MaxStoredData = Round(AllowedDistance / Accuracy, 1)
	Interpolate = GetKeyWithDefault("bool", 'savegame.mod.interpolate', true)
	
	RewindKey = "usetool"
	AltRewindKey = "alt"
	PlaySpeedIncrement = GetKeyWithDefault("float", 'savegame.mod.playspeedincrement', 0.5)
	PlaySpeedMax = GetKeyWithDefault("float", 'savegame.mod.playspeedmax', 1)
	AltRewindSpeed = -GetKeyWithDefault("float", 'savegame.mod.altrewindspeed', 1)

	OnlyTrackVisible = GetKeyWithDefault("bool", 'savegame.mod.onlytrackvisible', false)
	
	PlaySpeed = 1
	Time = 0
	MaxTime = 0
	
	VisualEnabled = GetKeyWithDefault("bool", 'savegame.mod.showcassetteplayer', true)
	TapeRaised = 0
	TapeSide = 1
	TapeSway = Vec(0,0,0)
	TapeCycle = 0
	TapeToasts = {
		Common = {"Chronomatic", "Chrono"},
		Uncommon = {"Chronography", "Time Splitter", "Rift Tearer", "Chaos Subverter", "Epoch Clock", "Era Corrupter", "Time Interpolator" },
		Rare = {"It's Rewind Time", "SPICY", "! ! ! ! ! ! ! !", "Manipulator", "Burn Me"},
		Legendary = {"Updog", "Hot Stuff", "PRIDE", "Rick Astly", "Behind You"}
	}
	TapeDisplayedText = "Chronomatic"
	TapeSprites = {"gfx/0001.png", "gfx/0002.png", "gfx/0003.png"}

	DefaultPostProc = GetPostProcSetting()
	
	AlarmInitialTime = (HasKey('level.alarm') and HasKey('level.alarmtimer')) and GetFloat('level.alarmtimer') or -1
	
	AllBodies = {}
	TrackedBodies = {}
	GrabHighlight = {}

	DebugPointCount = 0
	DebugAllBodiesChecked = 0

	PlayingMusic = false
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

function tick(dt)
	local camera = GetCameraTransform()

	if InputPressed('t') then ShowDebug = not ShowDebug end
	if InputPressed('r') then iiii = iiii + 1 end

	if PauseMenuButton("Purge Tape") then
		hardreset()
		UiSound('snd/TapeEject.ogg', Volume)
	end

	
	if PlayingMusic then
		if PlaySpeed > 0 then
			PlayLoop(sndMusic, GetCameraTransform().pos, Volume * .75)
		elseif PlaySpeed < 0 then
			PlayLoop(sndMusicRev, GetCameraTransform().pos, Volume * .75)
		end
	end

	local InVehicle = GetPlayerVehicle() ~= 0

	if Activated and GetString("game.player.tool") == "chrono" then
		SetBool('game.input.locktool', true)

		if not InVehicle then
			local add = 0
			if not InputDown('shift') then
				if InputValue('mousewheel') ~= 0 then PlaySpeed = Round(PlaySpeed, PlaySpeedIncrement)
					if InputValue('mousewheel') > 0 then add = PlaySpeedIncrement end
					if InputValue('mousewheel') < 0 then add = -PlaySpeedIncrement end
				end
			else
				if InputValue('mousewheel') ~= 0 then PlaySpeed = Round(PlaySpeed, 1)
					if InputValue('mousewheel') > 0 then add = 1 end
					if InputValue('mousewheel') < 0 then add = -1 end
				end
			end
			PlaySpeed = PlaySpeed + add
			PlaySpeed = math.max(math.min(PlaySpeed, PlaySpeedMax), -PlaySpeedMax)
		end

		PlayLoop(PlaySpeed > 0 and sndTapeLoop or sndTapeLoopReverse,GetCameraTransform().pos, math.abs(PlaySpeed / PlaySpeedMax) * Volume * (Time ~= 0 and 1 or 0))
	end

	if GetString("game.player.tool") == "chrono" and not InVehicle then
		-- Holding Tool
		TapeSide = 1
		if InputPressed(RewindKey) and GetPlayerGrabBody() == 0 then
			if Activated then
				DeActivate()
			else
				Activate()
			end
		end

		-- if InputPressed(AltRewindKey) then
		-- 	if not Activated then
		-- 		TapeSide = 1
		-- 		Activate(-1)
		-- 	end
		-- end
		-- if InputReleased(AltRewindKey) then
		-- 	if Activated then
		-- 		TapeSide = 1
		-- 		DeActivate()
		-- 	end
		-- end

		if InputPressed(".") then
			PlayingMusic = not PlayingMusic
			UiSound('snd/TapeA.ogg', Volume)
		end
		
	else
		if InVehicle then TapeSide = -1 end
		-- Alternate
		if InputPressed(AltRewindKey) then
			if not Activated then
				TapeSide = -1
				Activate(AltRewindSpeed)
			end
		end
		if InputReleased(AltRewindKey) then
			if Activated then
				TapeSide = -1
				DeActivate()
			end
		end
	end

	local veldir = TransformToLocalVec(camera, GetPlayerVelocity())

	TapeSway = VecAdd(TapeSway, veldir)
	TapeSway = VecLerp(TapeSway, veczero, dt * 4)

	if TapeRaised <= 0 then
		ChangeTapeText()
	end
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

function update(dt)
	AllBodies = FindBodies(nil,true)
	GrabbedBody = GetPlayerGrabBody()
	DebugAllBodiesChecked = 0

-------------------------------------Adding Bodies to Track----------------------------------------------------------------------------
	for i in pairs(AllBodies) do
		local body = AllBodies[i]
		if not TrackedBodies[body] then
			if IsBodyActive(body) then
				if OnlyTrackVisible then
					if IsBodyVisible(body, 256) then
						TrackedBodies[body] = { GetTrackData(body), unbreakable = HasTag(body, 'unbreakable') }
					end
				else
					TrackedBodies[body] = { GetTrackData(body), unbreakable = HasTag(body, 'unbreakable') }
				end
			end
		end

		if not HasTag(body,'initTime') then
			SetTag(body,'initTime', Time)
		end

		DebugAllBodiesChecked = DebugAllBodiesChecked + 1
	end

	for body in pairs(TrackedBodies) do
		if body ~= nil and #GetBodyShapes(body) ~= 0 then
-------------------------------------Tracking Bodies----------------------------------------------------------------------------
			if not Activated then
				TrackedBodies[body].unbreakable = HasTag(body, 'unbreakable')

				local trans = GetBodyTransform(body)
				local com = GetBodyWorldCOM(body)
				
				local closest = ClosestTime(TrackedBodies[body])
				local index = nil
				local prevbody = nil
				
				if body == GrabbedBody and Activated then
					index = closest + 1
				else
					index = #TrackedBodies[body] + 1
				end

				prevbody = TrackedBodies[body][index - 1]
				
				local distancefromprev = math.huge
				if prevbody ~= nil then
					distancefromprev = VecDist(prevbody.pos, com)
					distancefromprev = distancefromprev + VecDist(prevbody.rot, trans.rot)
				end
				
				if distancefromprev > Accuracy then
					TrackedBodies[body][index] = GetTrackData(body) 
					prevbody = TrackedBodies[body][index]
					index = index + 1
				end
				
				while true do
					if #TrackedBodies[body] > MaxStoredData then
						table.remove(TrackedBodies[body], 1)
					else
						break
					end
				end

				-- Remove if
				if not IsBodyActive(body) and #TrackedBodies[body] <= 2 then
					TrackedBodies[body] = nil
				end
			end

-------------------------------------Constraining Bodies When Activated----------------------------------------------------------------------------
			if Activated then
				local nograv = VecScale(Vec(0, 1, 0), 10 * dt * 1)
			
				SetTag(body,'unbreakable')

				if TrackedBodies[body] then
					local current = ClosestTime(TrackedBodies[body])
					local TBdata = TrackedBodies[body][current]
					local pTBdata = TrackedBodies[body][current - 1]
					

					if TBdata then 
						local trans = GetBodyTransform(body)
						local com = GetBodyWorldCOM(body)

						local initTime = Round(GetTagValue(body,'initTime'), Accuracy/10)

						local InterpolatedPos = TBdata.pos
						local InterpolatedRot = TBdata.rot

						if pTBdata and Interpolate then
							local l = (Time - pTBdata.time) / (TBdata.time - pTBdata.time)
							l = math.max(0, math.min(1, l))
							InterpolatedPos = VecLerp(pTBdata.pos, TBdata.pos, l)
							InterpolatedRot = QuatSlerp(pTBdata.rot, TBdata.rot, l)
						end

						ConstrainPosition(body, 0, com, InterpolatedPos)
						ConstrainOrientation(body, 0, trans.rot, InterpolatedRot)

						-- SetBodyVelocity(body, TBdata.motvel)
						-- SetBodyAngularVelocity(body, TBdata.rotvel)
						
						ApplyBodyImpulse(body, com, VecScale(nograv, GetBodyMass(body)))

						if TBdata.grabbed then
							table.insert(GrabHighlight, body)
						end 
					else
						deleteAhead(body, Time)
					end
				end
			end
		else
			TrackedBodies[body] = nil
		end
	end
	
------------------------------------- When Activated, but not for each body ----------------------------------------------------------------------------
	if Activated then
		Time = math.max(Time + (dt * PlaySpeed), 0)
		Time = math.min(Time, MaxTime)
		if GrabbedBody ~= 0 then
			DeActivate()
		end

		-- Key stuff
		if GetBool('level.alarm') then
			local t = GetFloat('level.alarmtimer')
			t = t + dt
			t = t - (dt * PlaySpeed)
			if Round(t, 0.1) >= AlarmInitialTime then
				SetFloat('level.alarmtimer', AlarmInitialTime)
				SetBool('level.alarm', false)
				SetString('level.state', '')
			else
				SetFloat('level.alarmtimer', t)
			end
		end

		if HasKey('level.missiontime') then
			SetFloat('level.missiontime', Time)
		end
	else
		Time = Time + dt
		MaxTime = Time
	end
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

function Activate(playspeed)
	PlaySound(sndTapeA,GetCameraTransform().pos, Volume)
	
	DefaultPostProc = GetPostProcSetting()
	
	PlaySpeed = playspeed or 0
	MaxTime = Time
	Activated = true
end

function DeActivate()
	Activated = false
	PlaySpeed = 1
	
	for body in pairs(TrackedBodies) do
		if TrackedBodies[body].unbreakable then
			SetTag(body, 'unbreakable')
		else
			RemoveTag(body,'unbreakable')
		end

		if body ~= nil then
			local count = #TrackedBodies[body]
			local tdist = math.huge
			local current = math.huge

			local current = ClosestTime(TrackedBodies[body])
			local TB = TrackedBodies[body][current]
			
			if TB then
				SetBodyVelocity(body, TB.motvel)
				SetBodyAngularVelocity(body, TB.rotvel)
			end

			if count > 1 then deleteAhead(body, Time) end
		end
	end

	DefaultPostProc = ResetProcSettings()

	PlaySound(sndTapeB,GetCameraTransform().pos, Volume)
end

----------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

function draw(dt)
	local camera = GetCameraTransform()
	local vel = GetPlayerVelocity()

	
	------------Tool Sprite--------------------------------------------------------------------------------
	if VisualEnabled then
		if Activated or GetString("game.player.tool") == "chrono" then
			TapeRaised = Move(TapeRaised, 1, dt * 1.5)
		else
			TapeRaised = Move(TapeRaised, 0, dt * 4)
		end

		if TapeRaised > 0 then
			local trs = logistic(TapeRaised, 1, 10, 0)
			local offset = { x = 0.275 * TapeSide, y = 0.125 + trs }

			local TapeScale = .35
			
			local sprite = TapeSprites[Round(Time * 8, 1) % #TapeSprites + 1]

			UiPush()
				UiAlign('center middle')
				local scale = UiWidth()

				local velmag = VecLength(TapeSway)
				local vellog = logistic(velmag, 1, -4, 8)

				local sway = VecScale(TapeSway, vellog)
				
				UiScale(scale)
				UiTranslate(offset.x, offset.y)
				UiScale(1/scale)
				UiTranslate(UiCenter(), UiMiddle())

				UiScale(TapeScale * logistic(TapeRaised + .1, 1, -24, 0.30), TapeScale)
				UiTranslate(sway[1], sway[2])
				UiScale(1 + math.abs(sway[1] / 10000), 1 + math.abs(sway[2] / 4000))
				UiScale(1 + (-sway[3] / 2000), 1 + (-sway[3] / 2000))

				
				UiRotate((trs) * -720 * TapeSide)

				UiImage(sprite)

				UiPush()
					UiTranslate(0, -45)
					UiScale(1.2)
					UiFont("gfx/ostrich-sans-bold.ttf", 100)
					local text = string.format("%.2f", PlaySpeed);
					UiText(text)
				UiPop()

				UiPush()
					UiAlign('left middle')
					UiTranslate(-620, -285)
					UiScale(1.5)
					UiColor(0, 0, 0, 1)
					UiFont("gfx/ostrich-sans-bold.ttf", 100)
					local text = string.format("%.3f", Round(Time, .001));
					UiText(text)
				UiPop()

				UiPush()
					UiAlign('right middle')
					UiTranslate(620, -285)
					UiScale(1.25)
					UiColor(0, 0, 0, 1)
					UiFont("gfx/ostrich-sans-bold.ttf", 100)
					if TapeDisplayedText ~= "Rick Astly" then
						UiText(TapeDisplayedText)
					else
						local words = {"Never", "Gonna", "Give", "You", "Up", "Up", "Up", "Never", "Gonna", "Let", "You", "Down", "Down", "Down"}
						UiText(words[Round(Time * 4, 1) % #words + 1])
					end
				UiPop()
			UiPop() 
		end
	end
--------------------------------------------------------------------------------------------------

	if Activated then
		SetPostProcessingProperty("saturation", 1 + math.min(PlaySpeed / PlaySpeedMax, 0) * VisualEffectsIntensity)
		SetPostProcessingProperty("bloom", 1 + (PlaySpeed / PlaySpeedMax) * 10 * VisualEffectsIntensity)
		-- SetPostProcessingProperty("brightness", 1 + math.max(PlaySpeed / PlaySpeedMax, 0) * VisualEffectsIntensity * 1.5)
		-- SetPostProcessingProperty("gamma", 1 - (math.max(PlaySpeed / PlaySpeedMax, 0) / 2) * VisualEffectsIntensity * 0.5)

		for key,body in ipairs(GrabHighlight) do
			if body ~= nil then
				DrawBodyOutline(body, 0, 1, 0, 1)
				GrabHighlight[key] = nil
			else
				GrabHighlight[key] = nil
			end
		end
	end
	
	if ShowDebug then
		
		for body in pairs(TrackedBodies) do
			if IsBodyVisible(body,16,false) then
				Display(body)
			end

			DebugPointCount = DebugPointCount + #TrackedBodies[body]
		end

		UiPush()
			UiTranslate(32, 32)
			local container = UiSimpleContainer(320, 165)

			UiTranslate(0, UiSpacing().e)
			
			local abc = UiSimpleLabel("All Bodies Checked:".. DebugAllBodiesChecked)
			UiTranslate(0, abc.rect.h)

			local bp = UiSimpleLabel("Bodies:".. tablelength(TrackedBodies))
			UiTranslate(0, bp.rect.h)

			local tp = UiSimpleLabel("Tracked points:".. DebugPointCount)
			UiTranslate(0, tp.rect.h)

			local mt = UiSimpleLabel("Max Tracked points Per Body:".. MaxStoredData)
			UiTranslate(0, mt.rect.h)

			local mb = UiSimpleLabel("Megabytes:".. Round(collectgarbage("count")/1000, 5))
			UiTranslate(0, mb.rect.h)
		UiPop()

		DebugPointCount = 0
	end
end