-- Run from the repository: lua test/controls.lua /path/to/norns
local norns_path = assert(arg[1], "provide the Norns source directory")
package.path = norns_path .. "/lua/?.lua;" .. norns_path .. "/lua/core/?.lua;" .. norns_path .. "/lua/lib/?.lua;" .. package.path
util = require "util"
MusicUtil = require "musicutil"
controlspec = require "controlspec"
local ParamSet = require "paramset"
norns = {pmap = {data = {}}, state = {data = "/tmp/krill-clouds-test/"}, menu = {status = function() return true end}}
screen = {peek = function() return "" end}
clock = {run = function() end}
function include(path) return dofile(path .. ".lua") end
dofile("lib/globals.lua")

local sent = {}
engine = setmetatable({}, {__index = function(_, id)
  return function(value) sent[id] = value end
end})
params = ParamSet.new("clouds-test")
clouds = include("lib/clouds")
clouds.add_params()
assert(params.group == 0, "Clouds group size is incorrect")

local function near(a, b) assert(math.abs(a-b) < 1e-8, tostring(a) .. " != " .. tostring(b)) end
near(sent.clouds_mix, 0.35)
assert(sent.clouds_enabled == 1 and sent.clouds_freeze == 0 and sent.clouds_mode == 0)
for _, id in ipairs(clouds.param_ids) do assert(sent[id] ~= nil, id .. " default not sent") end
params:set("clouds_mode", 4)
assert(sent.clouds_mode == 3)
params:set("clouds_freeze", 2)
assert(sent.clouds_freeze == 1)
params:set("clouds_enabled", 1)
assert(sent.clouds_enabled == 0)
params:set("clouds_lofi", 2)
assert(sent.clouds_lofi == 1)
params:set("clouds_pitch", -12)
near(sent.clouds_pitch, -12)
params:set("clouds_pitch", -100)
near(sent.clouds_pitch, -48)
params:set("clouds_gain", 100)
near(sent.clouds_gain, 8)
params:set("clouds_mix", -1)
near(sent.clouds_mix, 0)
params:set("clouds_mix", 2)
near(sent.clouds_mix, 1)

-- Exercise Norns' real PSET writer/reader, including zero-indexed engine options.
local snapshot = {}
for _, id in ipairs(clouds.param_ids) do snapshot[id] = params:get(id) end
local preset = os.tmpname()
params:write(preset)
for _, id in ipairs(clouds.param_ids) do params:lookup_param(id):set_default() end
params:read(preset)
os.remove(preset)
for id, value in pairs(snapshot) do near(params:get(id), value) end
assert(sent.clouds_mode == 3 and sent.clouds_freeze == 1)

-- Exercise actual Krill matrix action wrapping and a modulation patch.
params:add_control("test_source", "source", controlspec.new(0, 1, "lin", 0, 0))
mod_matrix = include("lib/mod_matrix")
mod_matrix:enrich_param_actions()
local indices = {}
for i, item in ipairs(mod_matrix.lookup) do if item.id then indices[item.id] = i end end
for _, id in ipairs(clouds.param_ids) do assert(indices[id], id .. " missing from matrix") end
mod_matrix.inputs[1] = indices.test_source
mod_matrix.outputs[1] = indices.clouds_position
local unity, zero
for i, value in ipairs(mod_matrix.level_options) do
  if value == 1 then unity = i end
  if value == 0 then zero = i end
end
mod_matrix.patch_points[1] = {{enabled = 2, level = unity, level_range = zero, crow_enabled = 1, midi_cc_enabled = 1}}
params:set("test_source", 0.8)
near(sent.clouds_position, 0.8)

-- The GUI must expose all controls in both sequencing modes and preserve actions.
lorenz = {boundary = {}}
gui = include("lib/gui")
local original_lookup = params.lookup_param
function params:lookup_param(id)
  if not self.lookup[id] then self:add_number(id, id, 0, 10, 1) end
  return original_lookup(self, id)
end
params:add_number("vuja_de_num_divs", "divisions", 1, 6, 3)
gui.init()
assert(menu_map[6] == "cld" and active_sub_menu[6] == 1)
for _, mode in ipairs({1, 2}) do
  sequencing_mode = mode
  gui.setup_menu_maps()
  assert(sub_menu_map[6] == clouds.param_ids)
  params:set("clouds_freeze", 1)
  params:set("clouds_freeze", 2)
  assert(sent.clouds_freeze == 1, "GUI wrapper lost engine action")
end
print("PASS: defaults, bounds, options, PSET round-trip, modulation and both GUI modes")

-- Register the whole script's parameters to catch group nesting and ID conflicts.
params = ParamSet.new("full-krill-test")
params:add_option("clock_crow_out", "crow clock", {"off", "on"}, 1)
cs = controlspec
midi_helper = {get_midi_devices = function() end}
w_slash = include("lib/w_slash")
parameters = include("lib/parameters")
parameters.init()
assert(params:lookup_param("clouds").t == params.tGROUP)
assert(params.group == 0)
for _, id in ipairs(clouds.param_ids) do assert(params.lookup[id]) end
gui.init()
assert(sub_menu_map[6] == clouds.param_ids)
print("PASS: full script parameter registration and Clouds page")
