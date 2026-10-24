-- SPDX-License-Identifier: GPL-3.0-or-later
local F, R = frontline, frontline.rules
local function now() return core.get_us_time() / 1000000 end
F.now = now
local instance = 0
local function spec_for(stack)
    local key = stack:get_name():match("^frontline:(%w+)$")
    return R.weapons[key], key
end
F.spec_for = spec_for

function F.state(player)
    local name = player:get_player_name()
    if not F.states[name] then F.states[name] = {next_fire = 0, protected_until = 0} end
    return F.states[name]
end

function F.initialize_stack(stack, full)
    local spec = spec_for(stack)
    if not spec then return stack end
    local meta = stack:get_meta()
    if meta:get_string("frontline_id") == "" then
        instance = instance + 1
        meta:set_string("frontline_id", tostring(core.get_us_time()) .. ":" .. instance)
        meta:set_int("rounds", full and spec.magazine or 0)
    end
    local rounds = R.clamp_ammo(meta:get_int("rounds"), spec.magazine)
    meta:set_int("rounds", rounds)
    meta:set_string("description", spec.title .. "\n" .. rounds .. " / " .. spec.magazine)
    stack:set_wear(math.floor((1 - rounds / spec.magazine) * 65534))
    return stack
end

function F.reserve(player)
    local total = 0
    for _, item in ipairs(player:get_inventory():get_list("main") or {}) do
        if item:get_name() == "frontline:ammo" then total = total + item:get_count() end
    end
    return total
end

local function sound(name, player, gain)
    core.sound_play("frontline_" .. name, {pos = player:get_pos(), gain = gain or 0.6,
        max_hear_distance = 100}, true)
end

function F.set_aim(player, aimed)
    local state = F.state(player)
    if state.aimed == aimed then return end
    state.aimed = aimed
    if aimed then mcl_fovapi.apply_modifier(player, "frontline:aim")
    else mcl_fovapi.remove_modifier(player, "frontline:aim") end
end
mcl_fovapi.register_modifier({name = "frontline:aim", fov_factor = 0.65, time = 0.12})

function F.cancel_reload(player)
    F.state(player).reload = nil
end

function F.reload(player)
    if not player or player:get_hp() <= 0 then return false, "dead" end
    local state = F.state(player)
    local stack = F.initialize_stack(player:get_wielded_item())
    local spec = spec_for(stack)
    if not spec then return false, "no_weapon" end
    if state.reload then return false, "reloading" end
    local meta = stack:get_meta()
    if meta:get_int("rounds") >= spec.magazine then return false, "full" end
    if F.reserve(player) == 0 then return false, "no_ammo" end
    player:set_wielded_item(stack)
    state.reload = {slot = player:get_wield_index(), id = meta:get_string("frontline_id"),
        itemname = stack:get_name(), finish = now() + spec.reload, started = now()}
    F.set_aim(player, false)
    sound("reload", player, 0.45)
    return true
end

function F.finish_reload(player)
    local state = F.state(player)
    local pending = state.reload
    if not pending then return false end
    local stack = player:get_wielded_item()
    if player:get_hp() <= 0 or not R.reload_matches(pending, player:get_wield_index(),
            stack:get_meta():get_string("frontline_id"), stack:get_name()) then
        state.reload = nil
        return false
    end
    if now() < pending.finish then return false end
    local spec = spec_for(stack)
    local rounds = stack:get_meta():get_int("rounds")
    local amount = R.reload_amount(rounds, F.reserve(player), spec.magazine)
    local removed = player:get_inventory():remove_item("main", ItemStack("frontline:ammo " .. amount))
    stack:get_meta():set_int("rounds", rounds + removed:get_count())
    player:set_wielded_item(F.initialize_stack(stack))
    state.reload = nil
    return true
end

local function tracer(origin, destination)
    local direction = vector.subtract(destination, origin)
    local distance = vector.length(direction)
    if distance < 0.1 then return end
    local velocity = vector.multiply(direction, 1 / 0.055)
    core.add_particle({pos = origin, velocity = velocity, expirationtime = 0.055,
        size = 1.4, texture = "frontline_tracer.png", glow = 14, collisiondetection = false})
    core.add_particlespawner({amount = 4, time = 0.02, minpos = destination, maxpos = destination,
        minvel = {x=-0.6,y=0.1,z=-0.6}, maxvel = {x=0.6,y=1,z=0.6},
        minexptime=0.1, maxexptime=0.22, minsize=0.5, maxsize=1.5,
        texture="frontline_tracer.png", glow=9})
end

function F.fire(player)
    if not player or player:get_hp() <= 0 then return false, "dead" end
    if not core.check_player_privs(player, {interact=true}) then return false, "privilege" end
    local state, time = F.state(player), now()
    local stack = F.initialize_stack(player:get_wielded_item())
    local spec, key = spec_for(stack)
    if not spec then return false, "no_weapon" end
    player:set_wielded_item(stack)
    local allowed, reason = R.can_fire(state, time, stack:get_meta():get_int("rounds"))
    if not allowed then
        if reason == "empty" and time >= (state.dry_until or 0) then
            sound("empty", player, 0.25)
            state.dry_until = time + 0.5
        end
        return false, reason
    end
    state.protected_until = 0 -- Firing voluntarily ends your own spawn shield.
    state.next_fire, state.last_combat = time + spec.cooldown, time
    stack:get_meta():set_int("rounds", stack:get_meta():get_int("rounds") - 1)
    player:set_wielded_item(F.initialize_stack(stack))
    local origin = vector.add(player:get_pos(), {x=0, y=player:get_properties().eye_height or 1.625, z=0})
    local direction = player:get_look_dir()
    local spread = state.aimed and spec.aimed_spread or spec.spread
    if core.settings:get_bool("frontline_test_mode", false) then spread = 0 end
    direction = vector.normalize(vector.add(direction, {x=(math.random()-0.5)*spread,
        y=(math.random()-0.5)*spread, z=(math.random()-0.5)*spread}))
    local destination = vector.add(origin, vector.multiply(direction, spec.range))
    local hit_name
    for hit in core.raycast(origin, destination, true, false) do
        if hit.type == "node" then
            local node = core.get_node_or_nil(hit.under)
            local def = node and core.registered_nodes[node.name]
            if not def or def.walkable then
                destination = hit.intersection_point
                break
            end
        elseif hit.type == "object" and hit.ref ~= player then
            local target = hit.ref
            local entity = target:get_luaentity()
            if target:is_player() or (entity and (entity.is_mob or entity.name == "frontline:target")) then
                destination = hit.intersection_point
                if not target:is_player() or (core.settings:get_bool("enable_pvp", true)
                        and now() >= F.state(target).protected_until) then
                    local damage = spec.damage
                    if target:is_player() then
                        local height = target:get_properties().eye_height or 1.625
                        if destination.y - target:get_pos().y > height * 0.8 then
                            damage = math.floor(damage * spec.headshot)
                        end
                        hit_name = target:get_player_name()
                        F.last_hits[hit_name] = {attacker=player:get_player_name(), time=time}
                        F.state(target).last_combat = time
                    end
                    if target:is_player() then
                        -- VoxeLibre's melee hook rejects hits beyond melee reach.
                        -- Use its projectile damage path, preserving armor/death hooks.
                        mcl_util.deal_damage(target, damage, {type="arrow",source=player,direct=player})
                    else
                        target:punch(player, 1, {full_punch_interval=0, damage_groups={fleshy=damage}}, direction)
                    end
                    state.hit_until = time + 0.18
                end
                break
            end
        end
    end
    tracer(vector.add(origin, vector.multiply(direction, 0.6)), destination)
    sound(key == "rifle" and "rifle" or "pistol", player)
    player:set_look_vertical(math.max(-math.pi/2, player:get_look_vertical() - spec.recoil * (state.aimed and 0.6 or 1)))
    return true, hit_name
end

core.register_craftitem("frontline:ammo", {description="Frontline ammunition", inventory_image="frontline_ammo.png", stack_max=999})
for key, spec in pairs(R.weapons) do
    -- A mesh node is used as a wieldable item: it renders a real 3D weapon without
    -- requiring a patched client. Both use callbacks suppress placing/melee hits.
    core.register_node("frontline:" .. key, {
        description=spec.title, drawtype="mesh", mesh="frontline_" .. key .. ".obj",
        tiles={"frontline_gun.png"}, inventory_image="frontline_" .. key .. "_icon.png",
        paramtype="light", sunlight_propagates=true, walkable=false,
        selection_box={type="fixed", fixed={-0.15,-0.2,-0.5,0.15,0.2,0.5}},
        groups={not_in_creative_inventory=1}, stack_max=1, wield_scale={x=1,y=1,z=1},
        node_placement_prediction="", node_dig_prediction="",
        on_use=function(stack) return stack end,
        on_place=function(stack) return stack end,
        on_secondary_use=function(stack) return stack end,
    })
end

local function update_hud(player, spec, stack, state)
    if not state.hud then return end
    local armed = spec ~= nil and player:get_hp() > 0
    if state.armed ~= armed then
        player:hud_set_flags({crosshair=not armed})
        state.armed = armed
    end
    local ammo = ""
    if armed then
        if state.reload then
            ammo = string.format("RELOADING  %.1fs", math.max(0, state.reload.finish-now()))
        else
            ammo = string.format("%02d / %02d    |    %03d", stack:get_meta():get_int("rounds"), spec.magazine, F.reserve(player))
        end
        ammo = spec.title .. "\n" .. ammo
    end
    local crosshair = armed and ((state.hit_until or 0) > now() and "frontline_hit.png" or "frontline_crosshair.png") or "frontline_blank.png"
    if state.last_ammo ~= ammo then player:hud_change(state.hud.ammo, "text", ammo); state.last_ammo = ammo end
    if state.last_crosshair ~= crosshair then player:hud_change(state.hud.crosshair,"text",crosshair); state.last_crosshair=crosshair end
    local shield = state.protected_until > now() and "SPAWN SHIELD  |  FIRE TO ENGAGE" or ""
    if shield ~= state.last_shield then player:hud_change(state.hud.shield,"text",shield); state.last_shield=shield end
end
F.update_hud = update_hud

core.register_globalstep(function(dtime)
    for _, player in ipairs(core.get_connected_players()) do
        local state = F.state(player)
        local stack = player:get_wielded_item()
        local spec = spec_for(stack)
        local controls = player:get_player_control()
        if player:get_hp() > 0 and spec then
            if stack:get_meta():get_string("frontline_id") == "" then
                stack = F.initialize_stack(stack); player:set_wielded_item(stack)
            end
            F.finish_reload(player)
            if controls.aux1 and not state.aux_down then F.reload(player) end
            if controls.sneak and controls.place and not state.place_down then F.reload(player) end
            F.set_aim(player, controls.place and not controls.sneak and not state.reload or false)
            if controls.dig and (spec.automatic or not state.dig_down) then F.fire(player) end
        else
            F.cancel_reload(player)
            F.set_aim(player, false)
        end
        state.dig_down, state.aux_down, state.place_down = controls.dig, controls.aux1, controls.place
        state.hud_timer = (state.hud_timer or 0) + dtime
        if state.hud_timer >= 0.1 then
            state.hud_timer = 0
            update_hud(player, spec, player:get_wielded_item(), state)
        end
    end
end)
core.register_chatcommand("reload", {description="Reload your held firearm", func=function(name)
    local ok, reason = F.reload(core.get_player_by_name(name))
    return ok, ok and "Reloading..." or "Cannot reload: " .. reason
end})
