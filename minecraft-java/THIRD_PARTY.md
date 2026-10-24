# Original upstream components

The installer downloads unchanged upstream artifacts using URLs and hashes in `downloads.lock.json`. The distributable ZIP contains this project's addon and source, installation scripts, configuration templates, and the Gradle wrapper. It does not embed Minecraft, the Java runtime, third-party mods, shaders or resource packs. Installing a pack does not grant ownership of its upstream assets.

| Component | Source / notices |
|---|---|
| Minecraft Java 1.20.1 | [Official download](https://www.minecraft.net/download), [EULA](https://www.minecraft.net/eula). A licensed account is required per player. EULA acceptance is left to the user. |
| Forge 47.4.10 | [Forge downloads](https://files.minecraftforge.net/net/minecraftforge/forge/index_1.20.1.html), [source and license](https://github.com/MinecraftForge/MinecraftForge). |
| TaCZ 1.1.8-hotfix2 | [Serene Wave Studio / Timeless Squad source](https://github.com/MCModderAnchor/TACZ). The artifact declares GPL3 / CC BY-NC-ND 4.0; code and art have different terms. Original models, textures, sounds and animations are downloaded unchanged. |
| TaCZ NPCs 1.0.3-craftorio | [Craftorio fork](https://github.com/craftorio/tacz-npcs/tree/1.0.3), original mod by Corrinedev. The repository has MIT notices, while the released JAR's metadata says All Rights Reserved. Preserve both notices; this package references its upstream release rather than redistributing the JAR. |
| SmartBrainLib 1.15 | [Tslat source](https://github.com/Tslat/SmartBrainLib), MPL-2.0. |
| PlayerAnimator | [KosmX source](https://github.com/KosmX/fabricPlayerAnimation), MIT. |
| Embeddium 0.3.31 | [Source](https://github.com/FiniteReality/embeddium), LGPL-3.0-only. |
| Oculus 1.8.0 | [Source](https://github.com/Asek3/Oculus), LGPL-3.0-only. |
| Complementary Unbound r5.9.3 | [Official project](https://modrinth.com/shader/complementary-unbound), [upstream license](https://github.com/ComplementaryDevelopment/ComplementaryShadersV4/blob/main/License.txt). |
| rotrBLOCKS V88 128x, 2D foliage | [Official project](https://modrinth.com/resourcepack/rotrblocks), [illystray terms](https://illystray.com/terms/). Downloaded unchanged; not bundled as an asset owned by this project. |
| Eclipse Temurin 17 | [Adoptium downloads](https://adoptium.net/temurin/releases/), original runtime includes its own license and notices. |
| Gradle 8.8 wrapper | [Gradle](https://github.com/gradle/gradle), Apache-2.0. Wrapper obtained from the official Forge MDK. |

`LICENSE` applies only to the Frontline Operations code, authored scripts, and authored configurations in this subproject. No TaCZ or NPC implementation code was copied into the addon. Weapon items are created using TaCZ item IDs and NBT; NPCs use their upstream registered entity type.
