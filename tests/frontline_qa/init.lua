-- Runs in a disposable world with two real network clients.
local F = frontline
local results = {}
local done = false
local function check(name, condition, detail)
    results[#results+1] = {name=name, passed=not not condition, detail=detail or ""}
    core.log("action", "[frontline-qa] " .. (condition and "PASS " or "FAIL ") .. name .. " " .. tostring(detail or ""))
    if not condition then error("QA failed: " .. name .. " " .. tostring(detail or "")) end
end
local function finish(ok, message)
    if done then return end
    done = true
    local report={passed=ok,checks=results,error=message,clients=#core.get_connected_players()}
    core.safe_file_write(core.get_worldpath() .. "/qa-results.json",core.write_json(report,true))
    core.log("action","[frontline-qa] COMPLETE " .. tostring(ok))
    core.after(6,function() core.request_shutdown("QA complete",false,0) end)
end
local function safely(fn)
    return function()
        if done then return end
        local ok, err = xpcall(fn,debug.traceback)
        if not ok then finish(false,err) end
    end
end
local function later(delay, fn) core.after(delay,safely(fn)) end

local a,b
local function weapon(player,key,rounds)
    local stack=F.initialize_stack(ItemStack("frontline:" .. key),true)
    if rounds then stack:get_meta():set_int("rounds",rounds) end
    player:set_wielded_item(stack)
    F.state(player).next_fire=0
    F.state(player).reload=nil
end
local function position_players()
    a:set_pos({x=-5,y=79.5,z=-18})
    b:set_pos({x=5,y=79.5,z=-18})
    b:set_hp(20)
    F.state(b).protected_until=0
end
local function aim_at(shooter,pos)
    local origin=vector.add(shooter:get_pos(),{x=0,y=shooter:get_properties().eye_height,z=0})
    local dir=vector.normalize(vector.subtract(pos,origin))
    shooter:set_look_horizontal(core.dir_to_yaw(dir))
    shooter:set_look_vertical(-math.asin(dir.y))
end
local function aim_body()
    aim_at(a,vector.add(b:get_pos(),{x=0,y=0.85,z=0}))
end
local function rounds(player) return player:get_wielded_item():get_meta():get_int("rounds") end

local function run()
    check("two real authenticated network clients",#core.get_connected_players()==2)
    check("arena floor generated",core.get_node({x=0,y=79,z=-18}).name=="frontline:asphalt")
    check("arena map protected",core.is_protected({x=0,y=79,z=0},a:get_player_name()))
    F.equip(a); F.equip(b)
    check("spawn kit contains 3D rifle",a:get_wielded_item():get_name()=="frontline:rifle")
    check("rifle starts with 30 rounds",rounds(a)==30)
    check("reserve ammunition provisioned",F.reserve(a)==240)
    position_players()
    aim_body()
    for y=80,82 do core.set_node({x=0,y=y,z=-18},{name="frontline:concrete"}) end
    F.state(a).next_fire=0
    local fired=F.fire(a)
    check("shot consumes server magazine",fired and rounds(a)==29)
    check("solid wall blocks player damage",b:get_hp()==20,b:get_hp())
    local again,reason=F.fire(a)
    check("fire rate cannot be bypassed",not again and reason=="cooldown" and rounds(a)==29)
    for y=80,82 do core.set_node({x=0,y=y,z=-18},{name="air"}) end
    later(0.3,function()
        aim_body()
        local before=b:get_hp()
        check("unobstructed shot fired",F.fire(a))
        check("ranged projectile damages player",b:get_hp()==before-5,"HP="..b:get_hp())
        later(0.3,function()
            aim_at(a,vector.add(b:get_pos(),{x=0,y=b:get_properties().eye_height,z=0}))
            local hp=b:get_hp()
            F.fire(a)
            check("headshot multiplier",hp-b:get_hp()==9,"damage="..(hp-b:get_hp()))
            b:set_hp(20)
            F.state(b).protected_until=F.now()+3
            later(0.3,function()
                aim_body(); F.fire(a)
                check("spawn shield blocks incoming bullets",b:get_hp()==20)
                F.state(b).protected_until=0
                core.settings:set_bool("enable_pvp",false)
                later(0.3,function()
                    aim_body(); F.fire(a)
                    check("disabled PvP is respected",b:get_hp()==20)
                    core.settings:set_bool("enable_pvp",true)
                    F.state(a).protected_until=F.now()+3
                    later(0.3,function()
                        aim_body(); F.fire(a)
                        check("shooting ends own spawn shield",F.state(a).protected_until==0)
                        -- Partial reload must consume only the available reserve.
                        a:get_inventory():remove_item("main","frontline:ammo 999")
                        a:get_inventory():add_item("main","frontline:ammo 7")
                        weapon(a,"rifle",5)
                        check("reload begins",F.reload(a))
                        local blocked,why=F.fire(a)
                        check("cannot shoot during reload",not blocked and why=="reloading")
                        later(2.2,function()
                            F.finish_reload(a)
                            check("partial reload conserves ammunition",rounds(a)==12 and F.reserve(a)==0,
                                "rounds="..rounds(a).." reserve="..F.reserve(a))
                            weapon(a,"rifle",0)
                            local empty,empty_reason=F.fire(a)
                            check("empty gun cannot fire",not empty and empty_reason=="empty")
                            check("reload without reserve refused",not F.reload(a))
                            a:get_inventory():add_item("main","frontline:ammo 30")
                            weapon(a,"rifle",2); F.reload(a)
                            weapon(a,"pistol",2)
                            -- Recreate the pending record to exercise switch cancellation,
                            -- since weapon() deliberately clears fixture state.
                            weapon(a,"rifle",2); F.reload(a)
                            local pending=F.state(a).reload
                            a:set_wielded_item(F.initialize_stack(ItemStack("frontline:pistol"),true))
                            F.finish_reload(a)
                            check("weapon switching cancels reload without consuming reserve",
                                pending~=nil and F.state(a).reload==nil and F.reserve(a)==30)
                            weapon(a,"rifle",2); F.reload(a)
                            a:set_wielded_item(F.initialize_stack(ItemStack("frontline:rifle"),true))
                            F.finish_reload(a)
                            check("same-type weapon replacement cannot steal reload",F.state(a).reload==nil and F.reserve(a)==30)
                            F.set_aim(a,true)
                            local fov=a:get_fov()
                            check("aim changes FOV",math.abs(fov-0.65)<0.001,fov)
                            F.set_aim(a,false)
                            check("aim reset restores FOV",a:get_fov()==0)
                            position_players(); b:set_hp(4)
                            weapon(a,"rifle",30); aim_body()
                            local kills=F.scores[a:get_player_name()].kills
                            local deaths=F.scores[b:get_player_name()].deaths
                            check("lethal shot fired",F.fire(a))
                            check("kill/death attributed once",F.scores[a:get_player_name()].kills==kills+1
                                and F.scores[b:get_player_name()].deaths==deaths+1)
                            later(2.5,function()
                                check("dead player automatically respawns",b:get_hp()>0)
                                check("respawn grants fresh equipment",b:get_inventory():contains_item("main","frontline:rifle") and F.reserve(b)==240)
                                check("respawn restores spawn shield",F.state(b).protected_until>F.now())
                                F.reset_round()
                                check("round reset clears scoreboard",F.scores[a:get_player_name()].kills==0 and F.scores[b:get_player_name()].deaths==0)
                                -- Leave both clients in an ordinary playable scene for capture.
                                a:set_pos({x=-22,y=79.5,z=-16})
                                b:set_pos({x=-5,y=79.5,z=-16})
                                aim_at(a,{x=6,y=81,z=0})
                                finish(true)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end

local waiting=0
local started=false
core.register_globalstep(function(dt)
    if started or done then return end
    waiting=waiting+dt
    if waiting>90 then finish(false,"Timed out waiting for two clients and map generation"); return end
    a=core.get_player_by_name("QAAlpha"); b=core.get_player_by_name("QABravo")
    if a and b and F.arena.ready and waiting>5 then
        started=true
        later(2,run)
    end
end)
