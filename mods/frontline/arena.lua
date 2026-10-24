-- SPDX-License-Identifier: GPL-3.0-or-later
local F = frontline
local enabled = core.settings:get_bool("frontline_arena", true)
local storage = core.get_mod_storage()
local Y = 80
F.arena = {ready=false, y=Y, min={x=-33,y=Y-2,z=-25}, max={x=33,y=Y+15,z=25}}
local spawns = {{x=-27,y=Y+0.5,z=-16}, {x=27,y=Y+0.5,z=16},
    {x=-27,y=Y+0.5,z=16}, {x=27,y=Y+0.5,z=-16}}
local spawn_counter = 0

local materials = {
    concrete={"Concrete", "frontline_concrete.png"},
    asphalt={"Asphalt", "frontline_asphalt.png"},
    timber={"Timber cover", "frontline_timber.png"},
    steel={"Steel", "frontline_steel.png"},
    blue={"Blue container", "frontline_container_blue.png"},
    orange={"Orange container", "frontline_container_orange.png"},
    stripe={"Lane marking", "frontline_stripe.png"},
    blue_pad={"Blue spawn", "frontline_blue_pad.png"},
    orange_pad={"Orange spawn", "frontline_orange_pad.png"},
}
for name, mat in pairs(materials) do
    core.register_node("frontline:" .. name, {description=mat[1], tiles={mat[2]},
        groups={pickaxey=1, solid=1}, _mcl_hardness=3, _mcl_blast_resistance=1200,
        sounds=mcl_sounds.node_sound_stone_defaults()})
end
core.register_node("frontline:lamp", {description="Yard light", tiles={"frontline_light.png"},
    light_source=14, groups={pickaxey=1,solid=1}, _mcl_hardness=3})

local previous_protection = core.is_protected
core.is_protected = function(pos, name)
    if enabled and pos.x >= -33 and pos.x <= 33 and pos.z >= -25 and pos.z <= 25
            and pos.y >= Y-2 and pos.y <= Y+15
            and not core.check_player_privs(name, {protection_bypass=true}) then
        return true
    end
    return previous_protection(pos, name)
end

local function targets()
    for _, object in ipairs(core.get_objects_inside_radius({x=0,y=Y+1,z=0}, 60)) do
        local ent = object:get_luaentity()
        if ent and ent.name == "frontline:target" then object:remove() end
    end
    for _, z in ipairs({-19,19}) do
        core.add_entity({x=20,y=Y+1,z=z}, "frontline:target")
    end
end

core.register_entity("frontline:target", {
    initial_properties={physical=false, pointable=true, visual="cube",
        visual_size={x=0.8,y=1.8,z=0.22}, collisionbox={-0.4,-0.9,-0.11,0.4,0.9,0.11},
        textures={"frontline_target.png","frontline_target.png","frontline_target.png",
            "frontline_target.png","frontline_target.png","frontline_target.png"},
        hp_max=20, static_save=false},
    on_activate=function(self) self.object:set_armor_groups({fleshy=100}) end,
    on_death=function(self)
        local pos = self.object:get_pos()
        core.after(2, function() core.add_entity(pos, "frontline:target") end)
    end,
})

function F.equip(player)
    local inventory = player:get_inventory()
    -- Only clear our equipment. Other survival inventory is retained.
    for index, stack in ipairs(inventory:get_list("main") or {}) do
        if stack:get_name():find("^frontline:") then inventory:set_stack("main",index,"") end
    end
    for _, weapon in ipairs({"rifle", "pistol"}) do
        local leftover = inventory:add_item("main", F.initialize_stack(ItemStack("frontline:" .. weapon), true))
        if not leftover:is_empty() then
            core.chat_send_player(player:get_player_name(), "Inventory full. Make room and use /kit at spawn.")
        end
    end
    inventory:add_item("main", "frontline:ammo 240")
    F.cancel_reload(player)
    F.set_aim(player, false)
end

function F.spawn(player, refill)
    if not F.arena.ready then
        core.after(0.2, function()
            local current = core.get_player_by_name(player:get_player_name())
            if current then F.spawn(current, refill) end
        end)
        return
    end
    spawn_counter = spawn_counter + 1
    local spawn = spawns[(spawn_counter-1)%#spawns+1]
    player:set_pos(spawn)
    player:set_look_horizontal(spawn.x < 0 and -math.pi/2 or math.pi/2)
    player:set_look_vertical(0)
    player:set_hp(player:get_properties().hp_max or 20)
    F.last_hits[player:get_player_name()] = nil
    F.state(player).protected_until = F.now() + tonumber(core.settings:get("frontline_spawn_protection") or 3)
    F.cancel_reload(player)
    F.set_aim(player, false)
    if refill then F.equip(player) end
end

local function hud(player)
    local state = F.state(player)
    state.hud = {
        title=player:hud_add({type="text",position={x=0,y=0},offset={x=30,y=110},
            alignment={x=1,y=1},number=0xF3C678,text="FRONTLINE  /  THE YARD",style=1}),
        score=player:hud_add({type="text",position={x=1,y=0},offset={x=-30,y=30},
            alignment={x=-1,y=1},number=0xE8EDF2,text=""}),
        ammo=player:hud_add({type="text",position={x=1,y=1},offset={x=-30,y=-125},
            alignment={x=-1,y=-1},number=0xF3C678,text=""}),
        help=player:hud_add({type="text",position={x=0,y=1},offset={x=30,y=-100},
            alignment={x=1,y=-1},number=0xCBD3DB,
            text="LMB  FIRE   |   HOLD RMB  AIM\nR  RELOAD   |   1 / 2  WEAPON   |   /arena  RETURN"}),
        crosshair=player:hud_add({type="image",position={x=0.5,y=0.5},
            scale={x=1,y=1},text="frontline_crosshair.png"}),
        shield=player:hud_add({type="text",position={x=0.5,y=0.16},
            number=0x8ED6F2,text=""}),
    }
end

function F.update_scores()
    local rows = {}
    for _, player in ipairs(core.get_connected_players()) do
        local name = player:get_player_name()
        local score = F.scores[name] or {kills=0,deaths=0}
        rows[#rows+1] = {name=name,kills=score.kills,deaths=score.deaths}
    end
    table.sort(rows, function(a,b) return a.kills == b.kills and a.name < b.name or a.kills > b.kills end)
    local lines = {"DEATHMATCH  /  FIRST TO " .. (core.settings:get("frontline_score_limit") or "10")}
    for _, row in ipairs(rows) do
        lines[#lines+1] = string.format("%s   %02d K  /  %02d D",row.name,row.kills,row.deaths)
    end
    for _, player in ipairs(core.get_connected_players()) do
        local state = F.state(player)
        if state.hud then player:hud_change(state.hud.score,"text",table.concat(lines,"\n")) end
    end
end

core.register_on_joinplayer(function(player)
    local name = player:get_player_name()
    F.scores[name] = F.scores[name] or {kills=0,deaths=0}
    if enabled then
        hud(player)
        core.after(0.5,function()
            local connected = core.get_player_by_name(name)
            if connected then
                F.spawn(connected,true)
                connected:set_lighting({shadows={intensity=0.65},bloom={intensity=0.08},volumetric_light={strength=0.15}})
                F.update_scores()
            end
        end)
        core.chat_send_player(name,"Welcome to FRONTLINE. LMB fire / hold RMB aim / R reload. Try the targets or invite a friend. /guns for help.")
    end
end)
core.register_on_leaveplayer(function(player)
    local name = player:get_player_name()
    F.states[name], F.last_hits[name] = nil, nil
    core.after(0,F.update_scores)
end)

local round_ending = false
function F.reset_round()
    round_ending = false
    for name in pairs(F.scores) do F.scores[name] = {kills=0,deaths=0} end
    if enabled then
        for _, player in ipairs(core.get_connected_players()) do
            if player:get_hp() <= 0 then player:respawn() else F.spawn(player,true) end
        end
    end
    F.update_scores()
    core.chat_send_all("FRONTLINE / New round. First to " .. (core.settings:get("frontline_score_limit") or "10") .. " kills.")
end

core.register_on_dieplayer(function(player)
    local name = player:get_player_name()
    local score = F.scores[name] or {kills=0,deaths=0}
    F.scores[name] = score
    score.deaths = score.deaths + 1
    F.cancel_reload(player)
    F.set_aim(player,false)
    local last = F.last_hits[name]
    if last and F.now()-last.time <= 5 and last.attacker ~= name then
        local killer = F.scores[last.attacker]
        if killer then
            killer.kills = killer.kills + 1
            core.chat_send_all(last.attacker .. "  >  " .. name)
            if not round_ending and killer.kills >= tonumber(core.settings:get("frontline_score_limit") or 10) then
                round_ending = true
                core.chat_send_all(last.attacker .. " wins! New round in 7 seconds.")
                core.after(7, F.reset_round)
            end
        end
    end
    F.last_hits[name] = nil
    F.update_scores()
    if enabled and core.settings:get_bool("frontline_auto_respawn",true) then
        core.after(2,function()
            local connected = core.get_player_by_name(name)
            if connected and connected:get_hp() <= 0 then connected:respawn() end
        end)
    end
end)
core.register_on_respawnplayer(function(player)
    if not enabled then return end
    -- VoxeLibre's earlier spawn callback also runs. Move after all callbacks.
    core.after(0, function()
        local current = core.get_player_by_name(player:get_player_name())
        if current then F.spawn(current,true) end
    end)
    return true
end)

local function in_combat(player)
    return F.now() - (F.state(player).last_combat or -100) < 10
end
core.register_chatcommand("arena", {description="Return to the arena (10s out of combat)",func=function(name)
    local player = core.get_player_by_name(name)
    if not enabled then return false,"Arena is disabled on this server." end
    if not player or player:get_hp() <= 0 then return false,"Respawn first." end
    if in_combat(player) then return false,"Wait 10 seconds after combat." end
    F.spawn(player,true)
    return true,"Returned to the yard."
end})
core.register_chatcommand("kit", {description="Refill your equipment at spawn",func=function(name)
    local player = core.get_player_by_name(name)
    if not player or player:get_hp() <= 0 or in_combat(player) then return false,"Wait until out of combat." end
    for _, spawn in ipairs(spawns) do
        if vector.distance(player:get_pos(),spawn)<6 then F.equip(player); return true,"Equipment refilled." end
    end
    return false,"Use /kit at a spawn pad."
end})
core.register_chatcommand("roundreset", {privs={server=true}, description="Reset the deathmatch round",func=function()
    F.reset_round(); return true,"Round reset."
end})
core.register_chatcommand("guns", {description="Firearms controls",func=function()
    return true,"LMB: fire (rifle automatic, pistol semi-auto). Hold RMB: aim. R (Aux1): reload; alternatively sneak+RMB or /reload. 1/2: switch. /arena: return. /kit: refill at spawn. /score: scores."
end})
core.register_chatcommand("score", {description="Show match scores",func=function()
    local lines={}
    for name, score in pairs(F.scores) do lines[#lines+1]=name .. ": " .. score.kills .. " kills / " .. score.deaths .. " deaths" end
    table.sort(lines)
    return true,table.concat(lines,"\n")
end})

local function build_arena()
    local vm = VoxelManip()
    local lower, upper = vm:read_from_map(F.arena.min,F.arena.max)
    local area = VoxelArea:new({MinEdge=lower,MaxEdge=upper})
    local data = vm:get_data()
    local function box(x1,y1,z1,x2,y2,z2,node)
        local id = core.get_content_id(node)
        for z=z1,z2 do for y=y1,y2 do for x=x1,x2 do data[area:index(x,y,z)]=id end end end
    end
    box(-32,Y,-24,32,Y+14,24,"air")
    box(-33,Y-2,-25,33,Y-1,25,"frontline:concrete")
    box(-32,Y-1,-24,32,Y-1,24,"frontline:asphalt")
    for _, z in ipairs({-25,25}) do box(-33,Y,z,33,Y+3,z,"frontline:concrete") end
    for _, x in ipairs({-33,33}) do box(x,Y,-25,x,Y+3,25,"frontline:concrete") end
    for _, z in ipairs({-11,11}) do box(-31,Y-1,z,31,Y-1,z,"frontline:stripe") end
    -- Offset containers, solid cover, and open outer lanes.
    box(-13,Y,-5,-4,Y+2,-1,"frontline:blue")
    box(4,Y,1,13,Y+2,5,"frontline:orange")
    box(-2,Y,-13,2,Y+2,-9,"frontline:concrete")
    box(-2,Y,9,2,Y+2,13,"frontline:concrete")
    for _, x in ipairs({-20,19}) do
        box(x,Y,-8,x+2,Y+1,-6,"frontline:timber")
        box(-x-2,Y,6,-x,Y+1,8,"frontline:timber")
    end
    for index, spawn in ipairs(spawns) do
        box(spawn.x-2,Y-1,spawn.z-2,spawn.x+2,Y-1,spawn.z+2,
            index%2==1 and "frontline:blue_pad" or "frontline:orange_pad")
    end
    for _, x in ipairs({-30,0,30}) do for _, z in ipairs({-23,23}) do
        box(x,Y,z,x,Y+5,z,"frontline:steel")
        box(x-1,Y+6,z,x+1,Y+6,z,"frontline:lamp")
    end end
    vm:set_data(data)
    vm:write_to_map(true)
    storage:set_int("arena_version",1)
    F.arena.ready = true
    targets()
    core.log("action","[frontline] Arena ready at (0,80,0)")
end

if enabled then
    core.register_on_mods_loaded(function()
        core.after(0,function()
            core.emerge_area(F.arena.min,F.arena.max,function(_,_,remaining)
                if remaining == 0 then
                    core.after(0,function()
                        if storage:get_int("arena_version") < 1 then build_arena()
                        else F.arena.ready=true; targets(); core.log("action","[frontline] Arena ready (existing map)") end
                    end)
                end
            end)
            core.set_timeofday(0.34)
        end)
    end)
    local timer = 0
    core.register_globalstep(function(dt)
        timer = timer + dt
        if timer < 1 then return end
        timer = 0
        local stop_path = core.get_worldpath() .. "/frontline-stop-request"
        local request = io.open(stop_path,"r")
        if request then
            request:close()
            os.remove(stop_path)
            core.request_shutdown("Frontline server saved and stopped.",false,0)
        end
        for _, player in ipairs(core.get_connected_players()) do
            local pos = player:get_pos()
            if player:get_hp()>0 and math.abs(pos.x)<35 and math.abs(pos.z)<27 and pos.y<Y-5 then F.spawn(player,false) end
        end
    end)
end
