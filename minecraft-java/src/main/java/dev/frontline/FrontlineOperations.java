package dev.frontline;

import com.mojang.logging.LogUtils;
import java.nio.file.Files;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import net.minecraft.commands.Commands;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.ClickEvent;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerBossEvent;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.BossEvent;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.level.GameType;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.scores.Objective;
import net.minecraft.world.scores.PlayerTeam;
import net.minecraft.world.scores.criteria.ObjectiveCriteria;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.event.entity.living.LivingDeathEvent;
import net.minecraftforge.event.entity.living.LivingHurtEvent;
import net.minecraftforge.event.entity.player.PlayerEvent;
import net.minecraftforge.event.level.BlockEvent;
import net.minecraftforge.event.server.ServerStartedEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.registries.ForgeRegistries;
import org.slf4j.Logger;

@Mod(FrontlineOperations.MODID)
public final class FrontlineOperations {
    public static final String MODID = "frontline_ops";
    private static final Logger LOG = LogUtils.getLogger();
    private static final String ENEMY_TAG = "frontline_enemy";
    private final Set<UUID> enemies = new HashSet<>();
    private final ServerBossEvent bar = new ServerBossEvent(Component.literal("前線作戰 / 準備就緒"), BossEvent.BossBarColor.BLUE, BossEvent.BossBarOverlay.PROGRESS);
    private MinecraftServer server;
    private Battlefield field;
    private String mode = "READY";
    private int wave;
    private int waveSize;
    private int nextWaveTick;
    private int roundResetTick;
    private int spawnIndex;

    public FrontlineOperations() { MinecraftForge.EVENT_BUS.register(this); }

    @SubscribeEvent public void started(ServerStartedEvent event) {
        server = event.getServer();
        field = Battlefield.get(server);
        field.ensure(server);
        clearEnemies();
        mode = "READY"; wave = 0; nextWaveTick = 0; roundResetTick = 0; spawnIndex = 0;
        var scoreboard = server.getScoreboard();
        if (scoreboard.getObjective("frontline") == null) scoreboard.addObjective("frontline", ObjectiveCriteria.DUMMY,
            Component.literal("前線作戰 / 擊殺數"), ObjectiveCriteria.RenderType.INTEGER);
        scoreboard.setDisplayObjective(1, scoreboard.getObjective("frontline"));
        PlayerTeam team = scoreboard.getPlayerTeam("frontline_coop");
        if (team == null) team = scoreboard.addPlayerTeam("frontline_coop");
        team.setAllowFriendlyFire(false);
        team.setDisplayName(Component.literal("前線合作隊"));
        bar.setVisible(false);
        LOG.info("FRONTLINE_READY Minecraft Java + TaCZ; native battlefield y={}", field.y);
        if (Boolean.getBoolean("frontline.qa")) QaChecks.begin(server, field);
    }

    @SubscribeEvent public void commands(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("frontline")
            .executes(context -> {
                context.getSource().sendSuccess(() -> Component.literal("前線作戰：/frontline start 合作波次；/frontline pvp 玩家對戰；/frontline kit 補給；/frontline arena 基地；/frontline explore 探索。"), false);
                return 1;
            })
            .then(Commands.literal("start").executes(context -> { startCoop(); return 1; }))
            .then(Commands.literal("pvp").executes(context -> { return startPvp(); }))
            .then(Commands.literal("stop").executes(context -> { stop(); return 1; }))
            .then(Commands.literal("status").executes(context -> {
                context.getSource().sendSuccess(() -> Component.literal("FRONTLINE_STATUS mode=" + mode + " wave=" + wave + " enemies=" + enemies.size() + " players=" + server.getPlayerCount()), false);
                return enemies.size();
            }))
            .then(Commands.literal("arena").executes(context -> {
                ServerPlayer player = context.getSource().getPlayerOrException();
                if (recentCombat(player)) { player.sendSystemMessage(Component.literal("離開戰鬥 10 秒後才能返回。")); return 0; }
                toSpawn(player, false); return 1;
            }))
            .then(Commands.literal("explore").executes(context -> {
                ServerPlayer player = context.getSource().getPlayerOrException();
                if (recentCombat(player)) return 0;
                ServerLevel level = server.overworld();
                int y = level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, 120, 0);
                player.getPersistentData().putBoolean("FrontlineExplore", true);
                player.teleportTo(level, 120.5, y + 1, 0.5, -90, 0);
                player.sendSystemMessage(Component.literal("已進入原版世界。/frontline arena 可回基地。")); return 1;
            }))
            .then(Commands.literal("kit").executes(context -> {
                ServerPlayer player = context.getSource().getPlayerOrException();
                if (recentCombat(player) || !nearBase(player)) {
                    player.sendSystemMessage(Component.literal("請在基地出生點附近、離開戰鬥 10 秒後補給。")); return 0;
                }
                Equipment.issue(player); player.sendSystemMessage(Component.literal("M4A1、Glock 17、彈藥與作戰手冊已補給。")); return 1;
            })));
    }

    @SubscribeEvent public void joined(PlayerEvent.PlayerLoggedInEvent event) {
        if (!(event.getEntity() instanceof ServerPlayer player) || field == null) return;
        var data = player.getPersistentData();
        if (!data.getBoolean("FrontlineOnboarded")) {
            data.putBoolean("FrontlineOnboarded", true);
            player.setGameMode(GameType.SURVIVAL);
            toSpawn(player, true);
        }
        if (mode.equals("COOP")) server.getScoreboard().addPlayerToTeam(player.getScoreboardName(), server.getScoreboard().getPlayerTeam("frontline_coop"));
        player.sendSystemMessage(Component.literal("原版 Minecraft + TaCZ 已就緒。按 9 選擇作戰手冊，右鍵開啟。\n")
            .append(Component.literal("[點此開始與武裝 NPC 作戰]").withStyle(style -> style.withColor(0x6ED9A8)
                .withClickEvent(new ClickEvent(ClickEvent.Action.RUN_COMMAND, "/frontline start")))));
    }

    @SubscribeEvent public void cloned(PlayerEvent.Clone event) {
        for (String key : List.of("FrontlineOnboarded", "FrontlineExplore")) event.getEntity().getPersistentData().putBoolean(key, event.getOriginal().getPersistentData().getBoolean(key));
    }

    @SubscribeEvent public void respawned(PlayerEvent.PlayerRespawnEvent event) {
        if (event.getEntity() instanceof ServerPlayer player && field != null) {
            if (!player.getPersistentData().getBoolean("FrontlineExplore")) server.execute(() -> toSpawn(player, true));
        }
    }

    @SubscribeEvent public void hurt(LivingHurtEvent event) {
        if (event.getEntity() instanceof ServerPlayer target) {
            long time = target.serverLevel().getGameTime();
            if (target.getPersistentData().getLong("FrontlineShieldUntil") > time) { event.setCanceled(true); return; }
            target.getPersistentData().putLong("FrontlineCombatUntil", time + 200);
        }
        if (event.getSource().getEntity() instanceof ServerPlayer shooter) {
            shooter.getPersistentData().putLong("FrontlineShieldUntil", 0);
            shooter.getPersistentData().putLong("FrontlineCombatUntil", shooter.serverLevel().getGameTime() + 200);
        }
    }

    @SubscribeEvent public void died(LivingDeathEvent event) {
        Entity victim = event.getEntity();
        boolean enemy = enemies.remove(victim.getUUID());
        if ((enemy || (mode.equals("PVP") && victim instanceof ServerPlayer))
            && event.getSource().getEntity() instanceof ServerPlayer shooter && shooter != victim) {
            Objective objective = server.getScoreboard().getObjective("frontline");
            if (objective != null) {
                var score = server.getScoreboard().getOrCreatePlayerScore(shooter.getScoreboardName(), objective);
                score.add(1);
                if (mode.equals("PVP") && score.getScore() >= 10 && roundResetTick == 0) {
                    announce(shooter.getGameProfile().getName() + " 贏得槍戰！7 秒後返回準備區。");
                    roundResetTick = server.getTickCount() + 140;
                }
            }
        }
    }

    @SubscribeEvent public void breaking(BlockEvent.BreakEvent event) {
        if (field != null && event.getLevel() instanceof ServerLevel level && level.dimension() == Level.OVERWORLD
            && field.contains(event.getPos()) && !event.getPlayer().hasPermissions(2)) event.setCanceled(true);
    }

    @SubscribeEvent public void tick(TickEvent.ServerTickEvent event) {
        if (event.phase != TickEvent.Phase.END || server == null) return;
        if (Boolean.getBoolean("frontline.qa")) QaChecks.tick(server);
        int tick = server.getTickCount();
        if (tick % 20 != 0) return;
        var stopRequest = server.getServerDirectory().toPath().resolve("frontline-stop-request");
        if (Files.exists(stopRequest)) {
            try { Files.delete(stopRequest); } catch (Exception error) { LOG.warn("Cannot remove stop request", error); }
            server.halt(false); return;
        }
        if (roundResetTick > 0 && tick >= roundResetTick) { stop(); return; }
        List<ServerPlayer> fighters = fighters();
        for (ServerPlayer player : server.getPlayerList().getPlayers()) {
            if (!mode.equals("READY") && fighters.contains(player)) bar.addPlayer(player); else bar.removePlayer(player);
        }
        if (mode.equals("COOP")) {
            // Upstream keeps lootable NPC corpses alive as containers; they no longer count as fighters.
            enemies.removeIf(id -> !(server.overworld().getEntity(id) instanceof LivingEntity living)
                || !living.isAlive() || living.isDeadOrDying());
            if (fighters.isEmpty()) {
                bar.setName(Component.literal("合作作戰暫停 / 回到基地繼續"));
                nextWaveTick = tick + 100;
                return;
            }
            if (enemies.isEmpty() && nextWaveTick == 0) {
                nextWaveTick = tick + 100;
                announce("第 " + wave + " 波完成，5 秒後增援抵達。");
            }
            if (enemies.isEmpty() && nextWaveTick > 0 && tick >= nextWaveTick) spawnWave(fighters.size());
            bar.setName(Component.literal("合作作戰 / 第 " + wave + " 波 / 敵人 " + enemies.size()));
            bar.setProgress(waveSize == 0 ? 1 : Math.min(1, (float) enemies.size() / waveSize));
        }
        if (mode.equals("PVP")) bar.setName(Component.literal("玩家槍戰 / 先達 10 殺獲勝"));
    }

    private void startCoop() {
        if (server.getPlayerCount() == 0) return;
        stop(); mode = "COOP"; wave = 0; nextWaveTick = server.getTickCount() + 60;
        resetScores();
        for (ServerPlayer player : server.getPlayerList().getPlayers()) {
            server.getScoreboard().addPlayerToTeam(player.getScoreboardName(), server.getScoreboard().getPlayerTeam("frontline_coop"));
            toSpawn(player, true);
        }
        bar.setVisible(true);
        announce("合作作戰開始！敵方持槍 NPC 將從貨場另一側進攻。");
    }

    private int startPvp() {
        if (server.getPlayerCount() < 2) { announce("玩家槍戰至少需要兩名玩家。現在可先玩合作 NPC 作戰。"); return 0; }
        stop(); mode = "PVP"; resetScores();
        int index = 0;
        for (ServerPlayer player : server.getPlayerList().getPlayers()) {
            server.getScoreboard().removePlayerFromTeam(player.getScoreboardName());
            player.getPersistentData().putBoolean("FrontlineExplore", false);
            Equipment.issue(player);
            player.teleportTo(server.overworld(), index++ % 2 == 0 ? -33.5 : 33.5, field.y + 1, 0.5, index % 2 == 1 ? -90 : 90, 0);
            protect(player);
        }
        bar.setVisible(true); bar.setProgress(1);
        announce("玩家槍戰開始，先達 10 殺獲勝。");
        return 1;
    }

    private void spawnWave(int players) {
        wave++;
        waveSize = Math.min(16, 2 + wave * 2 + Math.max(0, players - 1) * 2);
        var type = ForgeRegistries.ENTITY_TYPES.getValue(new ResourceLocation("tacz_npc", "bandit"));
        if (type == null) { announce("NPC 模組未載入，合作作戰已停止。"); stop(); return; }
        for (int index = 0; index < waveSize; index++) {
            Entity entity = type.create(server.overworld());
            if (!(entity instanceof Mob mob)) continue;
            int x = index < 10 ? 12 + index % 5 * 5 : 28 + (index - 10) % 2 * 5;
            int z = index < 10 ? -18 + index / 5 * 5 : 14 + (index - 10) / 2 * 4;
            mob.moveTo(x + 0.5, field.y + 1, z + 0.5, 90, 0);
            mob.addTag(ENEMY_TAG);
            mob.setPersistenceRequired();
            if (mob.getAttribute(Attributes.FOLLOW_RANGE) != null) mob.getAttribute(Attributes.FOLLOW_RANGE).setBaseValue(64);
            if (mob.getAttribute(Attributes.MAX_HEALTH) != null) mob.getAttribute(Attributes.MAX_HEALTH).setBaseValue(20 + Math.min(wave, 10) * 2);
            mob.setHealth(mob.getMaxHealth());
            if (server.overworld().addFreshEntity(mob)) enemies.add(mob.getUUID());
        }
        nextWaveTick = 0;
        announce("第 " + wave + " 波：" + enemies.size() + " 名武裝敵人。");
        LOG.info("FRONTLINE_WAVE wave={} enemies={}", wave, enemies.size());
    }

    private void stop() {
        clearEnemies(); mode = "READY"; nextWaveTick = 0; roundResetTick = 0;
        bar.setVisible(false); bar.removeAllPlayers();
        if (server != null) for (ServerPlayer player : server.getPlayerList().getPlayers()) server.getScoreboard().removePlayerFromTeam(player.getScoreboardName());
    }

    private void clearEnemies() {
        if (server == null || field == null) return;
        List<Entity> removed = new ArrayList<>();
        for (Entity entity : server.overworld().getAllEntities()) if (entity.getTags().contains(ENEMY_TAG)) removed.add(entity);
        for (Entity entity : removed) entity.discard();
        enemies.clear();
    }

    private void resetScores() {
        Objective objective = server.getScoreboard().getObjective("frontline");
        for (ServerPlayer player : server.getPlayerList().getPlayers()) server.getScoreboard().getOrCreatePlayerScore(player.getScoreboardName(), objective).setScore(0);
    }

    private List<ServerPlayer> fighters() {
        List<ServerPlayer> result = new ArrayList<>();
        for (ServerPlayer player : server.getPlayerList().getPlayers()) if (!player.isSpectator() && player.level().dimension() == Level.OVERWORLD
            && player.position().distanceToSqr(0, field.y, 0) < 100 * 100) result.add(player);
        return result;
    }

    private void toSpawn(ServerPlayer player, boolean issue) {
        BlockPos spawn = field.spawn();
        boolean east = mode.equals("PVP") && spawnIndex++ % 2 == 1;
        player.teleportTo(server.overworld(), east ? 33.5 : spawn.getX() + 0.5, spawn.getY(), spawn.getZ() + 0.5, east ? 90 : -90, 0);
        player.getPersistentData().putBoolean("FrontlineExplore", false);
        player.setRespawnPosition(Level.OVERWORLD, spawn, -90, true, false);
        protect(player);
        if (issue) Equipment.issue(player);
    }

    private void protect(ServerPlayer player) {
        player.getPersistentData().putLong("FrontlineShieldUntil", server.overworld().getGameTime() + 60);
        player.getPersistentData().putLong("FrontlineCombatUntil", 0);
    }

    private boolean nearBase(ServerPlayer player) {
        return player.level().dimension() == Level.OVERWORLD && (player.blockPosition().distSqr(field.spawn()) < 8 * 8
            || player.blockPosition().distSqr(new BlockPos(33, field.y + 1, 0)) < 8 * 8);
    }

    private boolean recentCombat(ServerPlayer player) {
        return player.getPersistentData().getLong("FrontlineCombatUntil") > player.serverLevel().getGameTime();
    }

    private void announce(String text) { server.getPlayerList().broadcastSystemMessage(Component.literal("[前線] " + text), false); }
}
