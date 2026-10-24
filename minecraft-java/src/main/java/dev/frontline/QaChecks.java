package dev.frontline;

import com.google.gson.GsonBuilder;
import com.mojang.authlib.GameProfile;
import com.mojang.logging.LogUtils;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.function.Supplier;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.server.players.PlayerList;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.ai.memory.MemoryModuleType;
import net.minecraft.world.item.Items;
import net.minecraft.world.level.GameType;
import net.minecraftforge.common.util.FakePlayer;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.fml.util.ObfuscationReflectionHelper;

/** Only runs with -Dfrontline.qa=true in a disposable test server. */
final class QaChecks {
    private static final List<Map<String, Object>> checks = new ArrayList<>();
    private static TestPlayer a, b;
    private static Mob npc;
    private static int startedTick;
    private static int phase;
    private static boolean done;
    private static Object gunOperator;
    private static Class<?> operatorApi;
    private static float npcHealth;
    private static String shotResult;
    private static int targetRemovedTick;
    private static int modeCheckTick;

    private static final class TestPlayer extends FakePlayer {
        TestPlayer(ServerLevel level, String name) {
            super(level, new GameProfile(UUID.nameUUIDFromBytes(name.getBytes(StandardCharsets.UTF_8)), name));
            setGameMode(GameType.SURVIVAL);
            // FakePlayer.tick() is empty, so vanilla's login immunity never counts down.
            ObfuscationReflectionHelper.setPrivateValue(ServerPlayer.class, this, 0, "f_8921_");
        }
        @Override public boolean isInvulnerableTo(DamageSource source) { return false; }
        @Override public void teleportTo(ServerLevel destination, double x, double y, double z, float yaw, float pitch) {
            if (destination != serverLevel()) throw new IllegalStateException("QA fixture cannot change dimensions");
            // FakePlayer's network handler drops teleport packets and position updates.
            moveTo(x, y, z, yaw, pitch);
        }
    }

    static void begin(MinecraftServer server, Battlefield field) {
        try {
            startedTick = server.getTickCount();
            ServerLevel level = server.overworld();
            a = new TestPlayer(level, "FrontlineQA_A");
            b = new TestPlayer(level, "FrontlineQA_B");
            a.moveTo(-6, field.y + 1, -18, -90, 0);
            b.moveTo(-6, field.y + 1, -10, -90, 0);
            level.addNewPlayer(a); level.addNewPlayer(b);
            Equipment.issue(a); Equipment.issue(b);
            check("native_minecraft_blocks", ForgeRegistries.BLOCKS.getValue(new ResourceLocation("minecraft", "stone")) != null);
            check("two_distinct_simulated_players", a != b && !a.getUUID().equals(b.getUUID()));
            check("tacz_real_gun_class", a.getMainHandItem().getItem().getClass().getName().startsWith("com.tacz."));
            check("m4a1_loadout", a.getMainHandItem().getOrCreateTag().getString("GunId").equals("tacz:m4a1"));
            check("loaded_magazine", a.getMainHandItem().getOrCreateTag().getInt("GunCurrentAmmoCount") == 30);
            check("sidearm_loadout", a.getInventory().getItem(1).getOrCreateTag().getString("GunId").equals("tacz:glock_17"));
            check("native_interactive_handbook", a.getInventory().getItem(8).is(Items.WRITTEN_BOOK));
            a.getInventory().add(new net.minecraft.world.item.ItemStack(Items.DIAMOND));
            Equipment.issue(a); Equipment.issue(a);
            check("resupply_preserves_survival_items", a.getInventory().items.stream().anyMatch(stack -> stack.is(Items.DIAMOND)));
            check("resupply_does_not_duplicate_issued_guns", a.getInventory().items.stream().filter(stack -> stack.hasTag() && stack.getTag().contains("GunId")).count() == 2);
            var type = ForgeRegistries.ENTITY_TYPES.getValue(new ResourceLocation("tacz_npc", "bandit"));
            check("armed_npc_registered", type != null);
            Entity entity = type.create(level);
            check("armed_npc_is_native_mob", entity instanceof Mob);
            npc = (Mob) entity;
            npc.moveTo(6, field.y + 1, -18, 90, 0);
            npc.setPersistenceRequired();
            npc.setNoAi(true);
            npc.getAttribute(Attributes.MAX_HEALTH).setBaseValue(200);
            npc.setHealth(200);
            level.addFreshEntity(npc);
            npcHealth = npc.getHealth();
            operatorApi = Class.forName("com.tacz.guns.api.entity.IGunOperator");
            gunOperator = operatorApi.getMethod("fromLivingEntity", LivingEntity.class).invoke(null, a);
            operatorApi.getMethod("initialData").invoke(gunOperator);
            operatorApi.getMethod("draw", Supplier.class).invoke(gunOperator, (Supplier<net.minecraft.world.item.ItemStack>) a::getMainHandItem);
            operatorApi.getMethod("aim", boolean.class).invoke(gunOperator, true);
            phase = 1;
        } catch (Throwable error) { failure(server, error); }
    }

    static void tick(MinecraftServer server) {
        if (done || phase == 0) return;
        try {
            if (a != null && !a.isRemoved() && a.isAlive()) a.doTick();
            if (b != null && !b.isRemoved() && b.isAlive()) b.doTick();
            int elapsed = server.getTickCount() - startedTick;
            if (phase == 1 && elapsed >= 60) {
                // NPCs equip their constructor loot during normal entity ticks.
                check("npc_has_real_tacz_firearm", npc.getMainHandItem().getItem().getClass().getName().startsWith("com.tacz."));
                a.setYRot(-90); a.setXRot(0);
                shotResult = String.valueOf(operatorApi.getMethod("shoot", Supplier.class, Supplier.class)
                    .invoke(gunOperator, (Supplier<Float>) () -> 0F, (Supplier<Float>) () -> -90F));
                check("tacz_server_shoot_operator", shotResult.equals("SUCCESS"));
                phase = 2;
            }
            if (phase == 2 && elapsed >= 80) {
                check("tacz_shot_consumes_magazine", a.getMainHandItem().getOrCreateTag().getInt("GunCurrentAmmoCount") < 30);
                check("tacz_projectile_damages_humanoid_npc", npc.getHealth() < npcHealth);
                a.setItemSlot(EquipmentSlot.HEAD, net.minecraft.world.item.ItemStack.EMPTY);
                a.setItemSlot(EquipmentSlot.CHEST, net.minecraft.world.item.ItemStack.EMPTY);
                a.getAttribute(Attributes.MAX_HEALTH).setBaseValue(200);
                a.setHealth(200);
                check("simulated_player_can_receive_normal_damage", a.hurt(server.overworld().damageSources().generic(), 1));
                a.setHealth(200); a.invulnerableTime = 0;
                npc.setNoAi(false);
                npc.setTarget(a);
                Class.forName("net.tslat.smartbrainlib.util.BrainUtils")
                    .getMethod("setTargetOfEntity", LivingEntity.class, LivingEntity.class).invoke(null, npc, a);
                phase = 3;
            }
            if (phase == 3 && elapsed % 100 == 0) {
                LogUtils.getLogger().info("FRONTLINE_QA_NPC gun={} target={} sees={} remembered={} playerHealth={} npcPosition={} shots={}",
                    npc.getMainHandItem().getTag(), npc.getTarget() == null ? "null" : npc.getTarget().getScoreboardName(),
                    npc.hasLineOfSight(a), npc.getBrain().getMemory(MemoryModuleType.NEAREST_VISIBLE_LIVING_ENTITIES)
                        .map(entities -> entities.contains(a)).orElse(false), a.getHealth(), npc.position(),
                    npc.getClass().getField("collectiveShots").getInt(npc));
            }
            if (phase == 3 && a.getHealth() < 200) {
                DamageSource damage = a.getLastDamageSource();
                String direct = damage != null && damage.getDirectEntity() != null
                    ? String.valueOf(ForgeRegistries.ENTITY_TYPES.getKey(damage.getDirectEntity().getType())) : "";
                check("armed_npc_ai_returns_fire", damage != null && (damage.getMsgId().contains("bullet") || direct.startsWith("tacz:")));
                check("victim_survives_test_shot", a.isAlive());
                // Regression: removing a locked target must not crash the NPC AI.
                a.discard();
                targetRemovedTick = server.getTickCount();
                phase = 4;
            }
            if (phase == 4 && server.getTickCount() >= targetRemovedTick + 60) {
                check("npc_target_removal_does_not_crash_server", npc.isAlive());
                npc.discard(); b.discard();
                beginModeChecks(server);
            }
            if (phase == 5 && server.getTickCount() >= modeCheckTick + 100) {
                var wave = waveEnemies(server);
                check("two_player_coop_spawns_six_armed_enemies", wave.size() == 6
                    && wave.stream().allMatch(entity -> entity.getMainHandItem().getItem().getClass().getName().startsWith("com.tacz.")));
                for (Mob enemy : wave) enemy.hurt(server.overworld().damageSources().playerAttack(b), 1000);
                int score = server.getScoreboard().getOrCreatePlayerScore(b.getScoreboardName(), server.getScoreboard().getObjective("frontline")).getScore();
                check("npc_kills_increment_score", score == 6);
                check("npc_deaths_leave_lootable_corpses", wave.stream().allMatch(LivingEntity::isDeadOrDying));
                modeCheckTick = server.getTickCount(); phase = 6;
            }
            if (phase == 6 && server.getTickCount() >= modeCheckTick + 140) {
                check("coop_advances_after_corpses_to_eight_enemy_wave", waveEnemies(server).size() == 8);
                command(server, a, "frontline stop");
                check("stop_removes_all_wave_enemies_and_corpses", waveEntities(server).isEmpty());
                finish(server, true, null);
            }
            if (phase == 3 && elapsed > 600) throw new IllegalStateException("NPC did not return fire within 30 seconds");
            if (elapsed > 1200) throw new IllegalStateException("Native integration checks timed out; phase=" + phase);
        } catch (Throwable error) { failure(server, error); }
    }

    private static int command(MinecraftServer server, ServerPlayer player, String command) {
        return server.getCommands().performPrefixedCommand(player.createCommandSourceStack(), command);
    }

    private static List<Mob> waveEntities(MinecraftServer server) {
        List<Mob> result = new ArrayList<>();
        for (Entity entity : server.overworld().getAllEntities()) {
            if (entity instanceof Mob mob && entity.getTags().contains("frontline_enemy")) result.add(mob);
        }
        return result;
    }

    private static List<Mob> waveEnemies(MinecraftServer server) {
        return waveEntities(server).stream().filter(entity -> !entity.isDeadOrDying()).toList();
    }

    private static List<ServerPlayer> fixtureRoster(MinecraftServer server) {
        // getPlayers() is an unmodifiable view. Modify the pinned-version backing roster only in QA.
        return ObfuscationReflectionHelper.getPrivateValue(PlayerList.class, server.getPlayerList(), "f_11196_");
    }

    private static void beginModeChecks(MinecraftServer server) {
        ServerLevel level = server.overworld();
        a = new TestPlayer(level, "FrontlineQA_C"); b = new TestPlayer(level, "FrontlineQA_D");
        level.addNewPlayer(a); level.addNewPlayer(b);
        // Internal test fixtures only. They have no authenticated network connections.
        fixtureRoster(server).add(a);
        check("pvp_requires_at_least_two_players", command(server, a, "frontline pvp") == 0);
        fixtureRoster(server).add(b);
        check("pvp_accepts_two_simulated_players", command(server, a, "frontline pvp") == 1);
        check("pvp_players_spawn_on_opposite_sides", a.getX() * b.getX() < 0);
        check("pvp_issues_tacz_weapon_to_both_players", a.getMainHandItem().getOrCreateTag().contains("GunId")
            && b.getMainHandItem().getOrCreateTag().contains("GunId"));
        command(server, a, "frontline start");
        check("coop_groups_players_without_friendly_fire", a.getTeam() != null && a.getTeam() == b.getTeam() && !a.getTeam().isAllowFriendlyFire());
        // Keep the round-control fixtures stationary and outside the NPC target set.
        a.setGameMode(GameType.CREATIVE); b.setGameMode(GameType.CREATIVE);
        modeCheckTick = server.getTickCount(); phase = 5;
    }

    private static void check(String name, boolean passed) {
        Map<String, Object> row = new LinkedHashMap<>(); row.put("name", name); row.put("passed", passed); checks.add(row);
        LogUtils.getLogger().info("FRONTLINE_QA {} {}", passed ? "PASS" : "FAIL", name);
        if (!passed) throw new IllegalStateException(name);
    }

    private static void failure(MinecraftServer server, Throwable error) {
        LogUtils.getLogger().error("Frontline QA failed", error);
        finish(server, false, error.toString());
    }

    private static void finish(MinecraftServer server, boolean passed, String error) {
        if (done) return; done = true;
        try {
            if (npc != null) npc.discard();
            fixtureRoster(server).remove(a);
            fixtureRoster(server).remove(b);
            if (a != null) a.discard();
            if (b != null) b.discard();
        } catch (Exception cleanupError) {
            passed = false; error = "Fixture cleanup failed: " + cleanupError;
        }
        try {
            Map<String, Object> report = new LinkedHashMap<>();
            report.put("passed", passed); report.put("checks", checks); report.put("error", error);
            report.put("players", "Two Forge FakePlayer fixtures; not two authenticated network clients");
            report.put("shotResult", shotResult);
            Files.writeString(server.getServerDirectory().toPath().resolve("qa-results.json"), new GsonBuilder().setPrettyPrinting().create().toJson(report));
        } catch (Exception writeError) { LogUtils.getLogger().error("Cannot write QA report", writeError); }
        server.halt(false);
    }
}
