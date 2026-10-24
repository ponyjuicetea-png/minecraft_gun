package dev.frontline;

import java.util.ArrayList;
import java.util.List;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.nbt.ListTag;
import net.minecraft.nbt.StringTag;
import net.minecraft.network.chat.ClickEvent;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;
import net.minecraftforge.registries.ForgeRegistries;

/** Uses TaCZ's public item NBT format; all weapon models/animations remain upstream. */
public final class Equipment {
    private Equipment() {}

    public static ItemStack gun(String id, int rounds, String mode) {
        Item item = ForgeRegistries.ITEMS.getValue(new ResourceLocation("tacz", "modern_kinetic_gun"));
        if (item == null || item == Items.AIR) throw new IllegalStateException("TaCZ gun item is unavailable");
        ItemStack stack = new ItemStack(item);
        CompoundTag tag = stack.getOrCreateTag();
        tag.putString("GunId", "tacz:" + id);
        tag.putInt("GunCurrentAmmoCount", rounds);
        tag.putBoolean("HasBulletInBarrel", true);
        tag.putString("GunFireMode", mode);
        tag.putBoolean("FrontlineIssued", true);
        return stack;
    }

    public static ItemStack ammunition(String id, int count) {
        Item item = ForgeRegistries.ITEMS.getValue(new ResourceLocation("tacz", "ammo"));
        if (item == null || item == Items.AIR) throw new IllegalStateException("TaCZ ammunition item is unavailable");
        ItemStack stack = new ItemStack(item, count);
        stack.getOrCreateTag().putString("AmmoId", "tacz:" + id);
        stack.getOrCreateTag().putBoolean("FrontlineIssued", true);
        return stack;
    }

    private static Component action(String label, String command) {
        return Component.literal(label).withStyle(style -> style.withColor(0x24668D)
            .withUnderlined(true).withClickEvent(new ClickEvent(ClickEvent.Action.RUN_COMMAND, command)));
    }

    public static ItemStack handbook() {
        ItemStack book = new ItemStack(Items.WRITTEN_BOOK);
        CompoundTag tag = book.getOrCreateTag();
        tag.putString("title", "前線作戰手冊");
        tag.putString("author", "Frontline Operations");
        tag.putBoolean("FrontlineIssued", true);
        ListTag pages = new ListTag();
        Component page = Component.literal("前線作戰\nMinecraft Java + TaCZ\n\n")
            .append(action("▶ 開始合作作戰", "/frontline start")).append("\n\n")
            .append(action("▶ 玩家槍戰（至少兩人）", "/frontline pvp")).append("\n\n")
            .append(action("▶ 返回基地", "/frontline arena")).append("\n\n")
            .append(action("▶ 基地補給", "/frontline kit"));
        pages.add(StringTag.valueOf(Component.Serializer.toJson(page)));
        pages.add(StringTag.valueOf(Component.Serializer.toJson(Component.literal(
            "操作\n\n左鍵：射擊\n右鍵：瞄準\nR：換彈\nB：切換射擊模式\n1 / 2：切換武器\n\n合作模式的敵人是會持槍還擊的 Bandit NPC。\n\n探索原版世界：\n/frontline explore\n\n結束目前對戰：\n/frontline stop"))));
        tag.put("pages", pages);
        return book;
    }

    public static void issue(ServerPlayer player) {
        var inventory = player.getInventory();
        List<ItemStack> displaced = new ArrayList<>();
        for (int index = 0; index < inventory.getContainerSize(); index++) {
            ItemStack stack = inventory.getItem(index);
            if (stack.hasTag() && stack.getTag().getBoolean("FrontlineIssued")) inventory.setItem(index, ItemStack.EMPTY);
        }
        for (int slot : new int[]{0, 1, 8}) {
            if (!inventory.getItem(slot).isEmpty()) displaced.add(inventory.removeItemNoUpdate(slot));
        }
        inventory.setItem(0, gun("m4a1", 30, "AUTO"));
        inventory.setItem(1, gun("glock_17", 17, "SEMI"));
        inventory.setItem(8, handbook());
        add(player, ammunition("556x45", 180));
        add(player, ammunition("9mm", 96));
        ItemStack food = new ItemStack(Items.COOKED_BEEF, 16);
        food.getOrCreateTag().putBoolean("FrontlineIssued", true);
        add(player, food);
        for (ItemStack stack : displaced) add(player, stack);
        if (player.getItemBySlot(EquipmentSlot.CHEST).isEmpty()) player.setItemSlot(EquipmentSlot.CHEST, new ItemStack(Items.IRON_CHESTPLATE));
        if (player.getItemBySlot(EquipmentSlot.HEAD).isEmpty()) player.setItemSlot(EquipmentSlot.HEAD, new ItemStack(Items.IRON_HELMET));
        inventory.selected = 0;
        inventory.setChanged();
        player.getFoodData().setFoodLevel(20);
        player.setHealth(player.getMaxHealth());
    }

    private static void add(ServerPlayer player, ItemStack stack) {
        player.getInventory().add(stack);
        if (!stack.isEmpty()) player.drop(stack, false);
    }
}
