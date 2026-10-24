-- SPDX-License-Identifier: GPL-3.0-or-later
-- Pure rules shared by runtime and tests. All ammo values are bounded integers.
local R = {}
R.weapons = {
    rifle = {title = "AR-30 / CARBINE", magazine = 30, cooldown = 0.11,
        reload = 2.0, damage = 5, headshot = 1.8, range = 160,
        spread = 0.013, aimed_spread = 0.0025, recoil = 0.012, automatic = true},
    pistol = {title = "P-12 / SIDEARM", magazine = 12, cooldown = 0.25,
        reload = 1.35, damage = 4, headshot = 1.75, range = 90,
        spread = 0.009, aimed_spread = 0.002, recoil = 0.018, automatic = false},
}
function R.clamp_ammo(value, magazine)
    return math.max(0, math.min(magazine, math.floor(tonumber(value) or 0)))
end
function R.reload_amount(rounds, reserve, magazine)
    return math.min(magazine - R.clamp_ammo(rounds, magazine), math.max(0, math.floor(reserve)))
end
function R.can_fire(state, now, rounds)
    if state.reload then return false, "reloading" end
    if now < (state.next_fire or 0) then return false, "cooldown" end
    if rounds <= 0 then return false, "empty" end
    return true
end
function R.reload_matches(reload, slot, id, itemname)
    return reload and reload.slot == slot and reload.id == id and reload.itemname == itemname
end
return R
