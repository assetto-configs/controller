-- A7-Assist v1.0.1 by Akeyroid7

local steerAngle = 0
local steerVelocity = 0

local dtSkip = 0 -- dtのテスト用。1回処理を行うごとにn回処理をスキップします。ステアリング以外の動作には影響しません。
local dtSkipCount = dtSkip

-- Options
local STOP_AUTO_CLUTCH = true -- 停車時に自動でクラッチを踏みます。trueで有効、falseで無効。
local HANDBRAKE_CLUTCH_LINK = true -- サイドブレーキを引いた時、クラッチを連動させます。trueで有効、falseで無効。
local VIBRATION_SLIP = 0.01 -- 振動エフェクトを前輪のスリップ量から生成します。値を大きくすると振動が強くなります。0でデフォルトの振動エフェクトを使用。

-- Gamepad Settings
local STICK_DEADZONE = 0.1
local STICK_GAMMA = 1
local GAS_DEADZONE = 0
local GAS_GAMMA = 1
local BRAKE_DEADZONE = 0
local BRAKE_GAMMA = 1

function script.update(dt)
  local data = ac.getJoypadState()
  local car = ac.getCar(0)

  local steerSelf = -data.ffb
  local steerForce = data.steerStickX
  local gyroSensor = data.localAngularVelocity.y
  local ndSlip = (data.ndSlipL + data.ndSlipR) / 2

  steerForce = math.sign(steerForce) * math.max(math.abs(steerForce) - STICK_DEADZONE, 0) / (1 - STICK_DEADZONE)
  steerForce = math.sign(steerForce) * math.abs(steerForce) ^ STICK_GAMMA

  local dtDebug = dt * (dtSkip + 1) -- これはdtDebugの動作に必要な処理です。
  if dtSkipCount < dtSkip then
    dtSkipCount = dtSkipCount + 1
    goto apply
  end
  dtSkipCount = 0

  -- 処理実行のたびに値を加減したい場合は、ここからapplyまでの間に記述し、その値にdtDebugを掛けてください。

  steerForce = steerForce * (2 - math.sign(steerForce) * steerSelf)
  steerForce = steerForce - steerForce * math.min(ndSlip / 5 * (1 + math.sign(steerForce) * steerAngle), 1)
  gyroSensor = gyroSensor + gyroSensor * math.abs(steerSelf)

  steerVelocity = steerForce + steerSelf + gyroSensor
  steerAngle = math.clamp(steerAngle + steerVelocity * 450 / data.steerLock * dtDebug, -1, 1)

  ::apply::

  data.steer = steerAngle

  data.gas = math.max(data.gas - GAS_DEADZONE, 0) / (1 - GAS_DEADZONE)
  data.gas = data.gas ^ GAS_GAMMA
  data.brake = math.max(data.brake - BRAKE_DEADZONE, 0) / (1 - BRAKE_DEADZONE)
  data.brake = data.brake ^ BRAKE_GAMMA

  if STOP_AUTO_CLUTCH then
    data.clutch = data.clutch * math.clamp((car.rpm - 1000) / 2000, 0, 1)
  end

  if HANDBRAKE_CLUTCH_LINK then
    data.clutch = math.min(data.clutch, 1 - data.handbrake)
  end

  if VIBRATION_SLIP ~= 0 then
    data.vibrationLeft = math.clamp(data.ndSlipL * VIBRATION_SLIP, 0, 1)
    data.vibrationRight = math.clamp(data.ndSlipR * VIBRATION_SLIP, 0, 1)
  end

  -- Debug:

  -- data = ac.getJoypadState()
  -- car = ac.getCar()

  ac.debug('car.rpm', car.rpm)
  ac.debug('data.ffb', data.ffb)
  ac.debug('data.gForces.x', data.gForces.x)
  ac.debug('data.localAngularVelocity.y', data.localAngularVelocity.y)
  ac.debug('data.localSpeedX', data.localSpeedX) -- sideways speed of front axle relative to car
  ac.debug('data.localVelocity.x', data.localVelocity.x) -- sideways speed of a car relative to car
  ac.debug('data.localVelocity.z', data.localVelocity.z) -- forwards/backwards speed of a car relative to car
  ac.debug('data.ndSlipL', data.ndSlipL) -- slipping for left front tyre
  ac.debug('data.ndSlipR', data.ndSlipR) -- slipping for right front tyre
  ac.debug('data.steer', data.steer)
  ac.debug('data.steerLock', data.steerLock)
  --ac.debug('data.steerStick', data.steerStick)
  ac.debug('data.steerStickX', data.steerStickX)
  ac.debug('data.steerStickY', data.steerStickY)
  ac.debug('dt', dt)
  ac.debug('dtDebug', dtDebug)
  ac.debug('steerVelocity', steerVelocity)

  -- 謎のバグ対策。何故かコレで直った。
  if data.steer ~= data.steer then
    steerAngle = 0
    data.steer = 0
  end
end