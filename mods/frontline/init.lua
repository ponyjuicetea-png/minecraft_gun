-- SPDX-License-Identifier: GPL-3.0-or-later
frontline = {
    states = {}, scores = {}, last_hits = {},
    path = core.get_modpath(core.get_current_modname()),
}
frontline.rules = dofile(frontline.path .. "/rules.lua")
dofile(frontline.path .. "/weapons.lua")
dofile(frontline.path .. "/arena.lua")
