package dev.frontline;

import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.GameRules;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.saveddata.SavedData;

/** Builds an arena in a new native Minecraft world, preserving its surrounding terrain. */
public final class Battlefield extends SavedData {
    private boolean initialized;
    public int y = 80;

    public static Battlefield get(MinecraftServer server) {
        return server.overworld().getDataStorage().computeIfAbsent(Battlefield::load, Battlefield::new, "frontline_operations");
    }

    private static Battlefield load(CompoundTag tag) {
        Battlefield data = new Battlefield();
        data.initialized = tag.getBoolean("initialized");
        data.y = tag.getInt("y");
        return data;
    }

    @Override public CompoundTag save(CompoundTag tag) {
        tag.putBoolean("initialized", initialized);
        tag.putInt("y", y);
        return tag;
    }

    public BlockPos spawn() { return new BlockPos(-33, y + 1, 0); }

    public boolean contains(BlockPos pos) {
        return Math.abs(pos.getX()) <= 41 && Math.abs(pos.getZ()) <= 29 && pos.getY() >= y - 2 && pos.getY() <= y + 16;
    }

    public void ensure(MinecraftServer server) {
        ServerLevel level = server.overworld();
        if (!initialized) {
            y = Math.max(72, level.getHeight(Heightmap.Types.MOTION_BLOCKING_NO_LEAVES, 0, 0) + 1);
            box(level, -40, -1, -28, 40, 12, 28, Blocks.AIR);
            box(level, -41, -3, -29, 41, -1, 29, Blocks.STONE_BRICKS);
            box(level, -40, 0, -28, 40, 0, 28, Blocks.POLISHED_DEEPSLATE);
            for (int z : new int[]{-29, 29}) box(level, -41, 1, z, 41, 3, z, Blocks.STONE_BRICKS);
            for (int x : new int[]{-41, 41}) box(level, x, 1, -29, x, 3, 29, Blocks.STONE_BRICKS);
            // Two walkable buildings with windows, door openings and flat roofs.
            building(level, -25, -25, -10, -12);
            building(level, 10, 12, 25, 25);
            // Containers, pallets and a central open passage.
            box(level, -12, 1, 3, 0, 3, 6, Blocks.BLUE_CONCRETE);
            box(level, 3, 1, -6, 15, 3, -3, Blocks.ORANGE_CONCRETE);
            for (int x : new int[]{-20, 19}) {
                box(level, x, 1, -6, x + 2, 2, -4, Blocks.BARREL);
                box(level, -x - 2, 1, 4, -x, 2, 6, Blocks.OAK_PLANKS);
            }
            for (int x = -36; x <= 36; x += 6) {
                box(level, x, 0, -10, x + 2, 0, -10, Blocks.YELLOW_CONCRETE);
                box(level, x, 0, 10, x + 2, 0, 10, Blocks.YELLOW_CONCRETE);
            }
            for (int x : new int[]{-38, 0, 38}) for (int z : new int[]{-27, 27}) {
                box(level, x, 1, z, x, 6, z, Blocks.POLISHED_ANDESITE);
                box(level, x - 1, 7, z, x + 1, 7, z, Blocks.SEA_LANTERN);
            }
            box(level, -37, 0, -4, -29, 0, 4, Blocks.LIGHT_BLUE_CONCRETE);
            box(level, 29, 0, -4, 37, 0, 4, Blocks.ORANGE_CONCRETE);
            initialized = true;
            setDirty();
        }
        level.setDefaultSpawnPos(spawn(), -90);
        server.getGameRules().getRule(GameRules.RULE_SPAWN_RADIUS).set(0, server);
        server.getGameRules().getRule(GameRules.RULE_KEEPINVENTORY).set(true, server);
        server.getGameRules().getRule(GameRules.RULE_DO_IMMEDIATE_RESPAWN).set(true, server);
        server.getGameRules().getRule(GameRules.RULE_MOBGRIEFING).set(false, server);
    }

    private void building(ServerLevel level, int x1, int z1, int x2, int z2) {
        box(level, x1, 1, z1, x2, 5, z2, Blocks.STONE_BRICKS);
        box(level, x1 + 1, 1, z1 + 1, x2 - 1, 4, z2 - 1, Blocks.AIR);
        box(level, x1 - 1, 6, z1 - 1, x2 + 1, 6, z2 + 1, Blocks.SMOOTH_STONE_SLAB);
        int doorZ = z1 < 0 ? z2 : z1;
        box(level, x1 + 3, 1, doorZ, x1 + 5, 3, doorZ, Blocks.AIR);
        for (int x = x1 + 2; x < x2 - 1; x += 4) {
            box(level, x, 2, z1, x + 1, 3, z1, Blocks.GLASS);
            if (x < x1 + 3 || x > x1 + 5) box(level, x, 2, z2, x + 1, 3, z2, Blocks.GLASS);
        }
        box(level, x1 + 1, 5, z1 + 1, x1 + 1, 5, z1 + 1, Blocks.SEA_LANTERN);
    }

    private void box(ServerLevel level, int x1, int y1, int z1, int x2, int y2, int z2, Block block) {
        var state = block.defaultBlockState();
        for (int x = x1; x <= x2; x++) for (int z = z1; z <= z2; z++) for (int height = y1; height <= y2; height++) {
            BlockPos pos = new BlockPos(x, y + height, z);
            if (level.getBlockState(pos) != state) level.setBlock(pos, state, 2);
        }
    }
}
