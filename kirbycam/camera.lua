--------
-- KirbyCam chase cam v1.0b-public 2021.10.20
-- Some parts of code from "base" camera by x4fab
--------

--------------------------------------------------
--USER VARIABLES: Change these values depending on your preferences
local OPT_baseFOV = 65 --base vertical FOV
local OPT_dynamicFOV = false --enable speed-based FOV increase (arcade-like)
--------------------------------------------------

--local velocitySmooth = 8
local carVelocity = smoothing(vec3(),8) --general smoothing and camera looseness relative to vehicle. Higher = looser
--local carVelocityY = smoothing(0,velocitySmooth) --cursed Y component smoothing
--local carVelocityZ = smoothing(0,velocitySmooth) --cursed Y component smoothing
local carVelocityRaw = vec3(0,0,0)
local carAccel = vec3(0,0,0) --smoothing of longitudinal/lateral g-force effects
local carAccelFx = vec3(0,0,0) --smoothing of g-force derived vibrations
local carAccelFy = vec3(0,0,0) --smoothing of large vertical movements
local camPitch = 0
local camDirLowSpeed = vec3()
local carSpeedSmooth = smoothing(0, 32)
local lookDirection = 0
local lookPitch = 0
local calculateVelocityHere = true
local lastCarPos = vec3()
local wheelbase = 0
local cgHeight = 0
local rollAdd = 0
local flag = false
local wheelCenter = vec3(0,0,0)
local wheelCenterFlat = vec3()
local wheelCenterOffset = 0

--[[ Springy camera values
local stiffness = 4800
local damping = 520 --smooth 8, damp 250
local mass = 10
local springPosOffset = 0
local springVelocity = 0
]]

function update(dt, cameraIndex)
  local cameraParameters = ac.getCameraParameters(cameraIndex)
  local height = cameraParameters.height
  local pitchAngle = -cameraParameters.pitch

  local gForce = ac.getCarGForces()

  if ac.isInReplayMode() then 
	gForce = vec3(gForce.x, -gForce.y, gForce.z) --hmmmmmm
  end
  
  carAccel:set(math.lerp(carAccel, gForce, dt*2))
  carAccelFx:set(math.lerp(carAccelFx, gForce, dt*30))
  carAccelFy:set(math.lerp(carAccelFy, gForce, dt*2))
  local carUp = ac.getCarUp()
  local carPos = ac.getCarPosition()
  if (not flag) or (wheelbase == 0) then
    local tyreFLPos = carPos - ac.getTyrePosition(1)
    local tyreRLPos = carPos - ac.getTyrePosition(3)
	wheelbase = (tyreFLPos-tyreRLPos):length()/2
	for i=1,4 do
		wheelCenter = wheelCenter + ac.getTyrePosition(i)
	end
	wheelCenter = wheelCenter/4
	wheelCenter = carPos - wheelCenter
	wheelCenterFlat = vec3(wheelCenter.x, 0, wheelCenter.z)
	local centerDir = ac.getCarDirection():dot(wheelCenter:normalize())
	wheelCenterOffset = wheelCenterFlat:length()*math.sign(-centerDir)
	cgHeight = ac.getCGHeight()
	flag = true
  end
  
  local carDir = vec3()
  carDir:set(ac.getCarDirection())
  carPos = carPos - cgHeight*carUp + wheelCenterOffset*carDir
  local carDirFlat = vec3(carDir.x, 0, carDir.z):normalize()
  local carDirProj = vec3(carDir.x, 0, carDir.z)
  local carRight = math.cross(carDir, carUp):normalize()
  local carRightFlat = vec3(carRight.x, 0, carRight.z):normalize()
  local carUpProj = vec3(0,carDir.y,0)
  local carAngle = math.atan2(carDir.z, carDir.x)
  
  local distance = cameraParameters.distance + (wheelbase) --scale distance by wheelbase to compensate for different cars

  local carPitch = math.asin(-carDir.y)
  --local carPitch = math.acos(carDir:dot(carDirFlat))
  
  if calculateVelocityHere then
    if lastCarPos ~= carPos then
      local delta = lastCarPos - carPos
      local deltaLength = #delta
      if deltaLength > 5 then delta = delta / deltaLength * 5 end
	  carVelocityRaw = (-delta / dt)
      carVelocity:update(carVelocityRaw)
	  --carVelocityY:update(carVelocityRaw.y)
	  --carVelocityZ:update(carVelocityRaw.z)
      lastCarPos = carPos
	  local carSpeed = carVelocityRaw:length()
      carSpeedSmooth:update(carSpeed)
    end
  else
    carVelocity:updateIfNew(ac.getCarVelocity())
  end

  local cameraDir = vec3(carVelocity.val.x, carVelocity.val.y, carVelocity.val.z):normalize()
  local cameraDirProj = vec3(cameraDir.x, 0, cameraDir.z):normalize()
  local cameraUpProj = vec3(0, cameraDir.y, 0):normalize()
    --ac.debug('velocityPitch',math.deg(cameraDirProj:angle(cameraDir)))
  --camPitch = math.lerp(camPitch, math.lerp(carPitch, -math.atan2(math.cross(cameraDir, cameraDirProj):dot(carRight),cameraDir:dot(cameraDirProj)),math.saturate(carSpeedSmooth.val-1)), dt*2)
  camPitch = math.lerp(camPitch, math.lerp(carPitch, math.asin(cameraDir.y),math.saturate(carSpeedSmooth.val-1)), dt*2)
  camDirLowSpeed:set( math.lerp(camDirLowSpeed, math.lerp(carDir*math.max(1,carVelocityRaw:length()), vec3(carVelocity.val.x, 0, carVelocity.val.z), math.saturate(carSpeedSmooth.val-1)), dt))
  cameraDir:set(camDirLowSpeed:normalize())
  local cameraUp = carUp - math.project(carUp, carRightFlat)
  cameraDir:rotate(quat.fromAngleAxis(math.lerp(0,camPitch,math.saturate(carSpeedSmooth.val-1)), math.cross(cameraDir, cameraUp):normalize()))
  local cameraRight = math.cross(cameraDir, cameraUp):normalize()
  --cameraDir:rotate(quat.fromAngleAxis(math.radians(pitchAngle), cameraRight))
  
  local joystickLook = ac.getJoystickLook()
  lookDirection = math.lerp(lookDirection,
    (ac.looksLeft() and ac.looksRight() or ac.looksBehind()) and -2 or
    ac.looksLeft() and 1 or
    ac.looksRight() and -1 or
	joystickLook ~= nil and joystickLook.y < -0.5 and -2 or
    joystickLook ~= nil and -joystickLook.x or 0, dt*10)
	
  lookPitch = math.lerp(lookPitch,
	(joystickLook ~= nil and joystickLook.y > -0.5 and -joystickLook.y or 0) * math.pi/4, dt*10)
	
  cameraDir:rotate(quat.fromAngleAxis(lookDirection * math.pi/2, vec3(0,1,0))) 
  cameraDir:rotate(quat.fromAngleAxis(lookPitch, cameraRight)) 
  --ac.debug('joystickLook', joystickLook.y)
  
  --cameraDirProj = vec3(cameraDir.x, 0, cameraDir.z):normalize()
  --cameraUpProj = vec3(0, cameraDir.y, 0):normalize()
  
  local velocityAngle = math.atan2(cameraDir.z, cameraDir.x)
  --local cameraDirProj = vec3(cameraDir.x, 0, cameraDir.z)
  --local velocityAngle = math.acos(cameraDir:dot(cameraDirProj)/(1*cameraDirProj:length()))
  local velocityPitch = math.asin(-cameraDir.y)
  local diffAngle = velocityAngle - carAngle
  local fovAdd = (OPT_dynamicFOV and (30*math.sin(math.atan((carSpeedSmooth.val)/50))) or 0)
  local fxDistance = distance + ((math.sin(math.atan(1.5*carAccel.z-.258))+.25)*0.35) - fovAdd*.03 --limit to (-1,1) with gradual falloff
  height = height + fxDistance*math.tan(math.radians(pitchAngle)) --cancel out added height by pitch angle
  
  local vertFx = math.sin(math.atan(-carAccelFy.y))*.54 + math.sin(math.atan(-carAccelFx.y))*.1*(carSpeedSmooth.val/100)
  local rollAngle = -math.atan2(math.cross(carRight, carRightFlat):dot(carDir),carRight:dot(carRightFlat))
  local rollClamped = math.clamp( math.abs(rollAngle), 0, 0.785 ) --pi/4 or 45 degrees. no track has more than this right? :)
  local rollRange = rollClamped/0.785
  rollAdd = (math.lerp(rollAdd, (height*0.65)*math.tan(math.smootherstep(rollRange)*.785), dt))
  
  --[[springy camera stuff
  local stretch = springPosOffset - -gForce.y
  local force = -stiffness * stretch - damping * springVelocity
  local acceleration = force / mass
  springVelocity = springVelocity + acceleration * dt
  springPosOffset = springPosOffset + springVelocity * dt
  ac.debug('springVelocity', springVelocity)
  ac.debug('springPosOffset', springPosOffset)
  --springy camera end]]
  
  -- Set camera parameters:
  --local springFx = math.sin(1*math.atan(springPosOffset*0.5))*0.1
  
  ac.Camera.position = carPos
	+ math.sin(diffAngle)*math.cos(velocityPitch)*carRightFlat*-fxDistance
	+ math.cos(diffAngle)*math.cos(velocityPitch)*carDirFlat*-fxDistance
	+ math.sin(velocityPitch)*vec3(0,1,0)*fxDistance
	+ cameraUp*(height+cgHeight)
	+ carUp * rollAdd
	+ carRight*math.sin(math.atan(carAccel.x))*-(wheelbase/8) --*variation.val --limit to (-1,1) with gradual falloff so it won't go crazy during crashes
	+ carUp * (vertFx)

  cameraDir:rotate(quat.fromAngleAxis((-math.atan((vertFx)/(fxDistance+wheelbase))), cameraRight))
  cameraDir:rotate(quat.fromAngleAxis(math.radians(pitchAngle), cameraRight))
  ac.Camera.direction = cameraDir
  local whatsUp = vec3(0,1,0)
  whatsUp:rotate(quat.fromAngleAxis(math.radians(math.sin(math.atan(2*carAccel.x)))*-1, carDirFlat))
  ac.Camera.up = whatsUp
  ac.Camera.fov = OPT_baseFOV + fovAdd
end