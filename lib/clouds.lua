-- Controls for the stereo Clouds processor after Krill's Rings voice.
local clouds = {}
local controlspec = require "controlspec"

clouds.param_ids = {
  "clouds_enabled", "clouds_mix", "clouds_position", "clouds_size",
  "clouds_density", "clouds_texture", "clouds_pitch", "clouds_spread",
  "clouds_feedback", "clouds_reverb", "clouds_gain", "clouds_freeze",
  "clouds_mode", "clouds_lofi"
}

function clouds.add_params()
  params:add_group("clouds", "CLOUDS", #clouds.param_ids)

  local function option(id, name, choices, default)
    params:add_option(id, name, choices, default)
    params:set_action(id, function(value) engine[id](value - 1) end)
  end

  local function control(id, name, min, max, default, units, warp)
    params:add_control(id, name, controlspec.new(min, max, warp or "lin", 0, default, units or ""))
    params:set_action(id, function(value) engine[id](value) end)
  end

  option("clouds_enabled", "cld on", {"off", "on"}, 2)
  control("clouds_mix", "cld mix", 0, 1, 0.35)
  control("clouds_position", "cld pos", 0, 1, 0.5)
  control("clouds_size", "cld size", 0, 1, 0.25)
  control("clouds_density", "cld dens", 0, 1, 0.35)
  control("clouds_texture", "cld tex", 0, 1, 0.5)
  control("clouds_pitch", "cld pitch", -48, 48, 0, "st")
  control("clouds_spread", "cld spread", 0, 1, 0.5)
  control("clouds_feedback", "cld fb", 0, 1, 0.15)
  control("clouds_reverb", "cld rvb", 0, 1, 0.2)
  control("clouds_gain", "cld gain", 0.125, 8, 1, "x", "exp")
  option("clouds_freeze", "cld freeze", {"off", "on"}, 1)
  option("clouds_mode", "cld mode", {"grain", "stretch", "loop", "spectral"}, 1)
  option("clouds_lofi", "cld lofi", {"off", "on"}, 1)

  -- Krill does not bang all parameters at startup. Send this group's defaults
  -- explicitly, before the matrix and GUI wrap the parameter actions.
  for _, id in ipairs(clouds.param_ids) do
    params:lookup_param(id):bang()
  end
end

return clouds
