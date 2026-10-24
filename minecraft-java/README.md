# 前線作戰：Minecraft Java＋TaCZ

這是使用 **Minecraft Java 1.20.1、Forge 47.4.10、TaCZ 1.1.8-hotfix2** 的槍戰整合包。需要正版 Java 版帳號與官方 Minecraft Launcher，每名連線玩家使用自己的帳號。

已實作合作 NPC 波次、玩家槍戰、補給、重生、擊殺計分，以及原版方塊搭建的作戰場地。預設最多 8 人；一個人也能啟動合作模式打 Bandit 武裝敵人。敵人使用 TaCZ 槍枝與 NPC 模組的 AI。

目前是 **伺服器已測試的開發預覽版**：自訂模組編譯與 29 項原生 Forge 伺服器整合檢查已通過，包括 TaCZ 子彈命中 NPC、NPC 持槍還擊、移除目標後不崩潰、雙人對戰指令、合作波次、計分與屍體清理。安裝目錄中的伺服器也通過 TCP 25565 狀態回應、8 人上限、存檔與關服驗證。測試使用 Forge 模擬玩家；兩個正版帳號連線與客戶端光影畫面尚未實測。`VALIDATION.json` 與 `reports/` 記錄驗證狀態及結果。

## 這台電腦開始玩

這個工作目錄已配置好 Java、Forge 與模組；無須重跑安裝。本機已依使用者在對話中的明確同意記錄 EULA 接受；其他新安裝的電腦仍會由使用者自行確認。

1. 開啟 `Start-Game.cmd`。若伺服器尚未接受 EULA，會顯示 Minecraft 官方 EULA 網址；請閱讀並自行決定是否輸入 `YES` 接受。不同意則不會啟動。本機已記錄接受，不會重複詢問。
2. 官方 Minecraft Launcher 登入具有 Java 版遊戲授權的 Microsoft 帳號，選擇 **Frontline - TaCZ NPC Co-op**，按「開始遊戲」。沒有遊戲授權時，下載安裝包並不能解鎖遊戲。若看不到新設定，請關閉再重新開啟 Launcher。Launcher 若詢問是否繼續執行修改過的安裝版本，請自行閱讀提示。
3. 進入「多人遊戲」，選擇清單中的 **Frontline - Local host**。也可用「直接連線」輸入 `127.0.0.1:25565`。
4. 出生後有 M4A1、Glock 17、彈藥、食物與鐵裝。按 `9` 選作戰手冊，右鍵打開，點「開始合作作戰」；也可輸入 `/frontline start`。
5. 用 `Stop-Server.cmd` 存檔並關服。關閉 Minecraft 客戶端不會自動關閉伺服器。

## 安裝到另一台 Windows 電腦

1. 安裝並登入官方 [Minecraft Launcher](https://www.minecraft.net/download)，至少開啟一次 Launcher。
2. 解壓縮 `Frontline-Minecraft-Java-Installer.zip` 到固定資料夾，例如 `C:\Games\FrontlineJava`。請先解壓縮，再執行檔案。
3. 主機執行 `Setup.cmd`；只加入朋友伺服器的玩家執行 `Setup-Client.cmd`。安裝時需要網路與數 GB 可用空間，會從原作者來源下載並核對檔案雜湊。安裝器下載 Java 17，無須自行安裝 Java、Python 或 C++。
4. 主機執行 `Start-Game.cmd`；朋友執行 `Join-Game.cmd` 並在 Launcher 按「開始遊戲」。

ZIP 是下載式安裝包，沒有內附 Minecraft 本體、第三方模組或材質二進位檔。第一次下載、Forge 安裝、光影編譯與世界生成可能花數分鐘；錯誤時命令視窗會保留訊息。

## 兩人以上連線

- 主機使用 `Start-Game.cmd`，或只開服時使用 `Start-Server.cmd`。`Start-Server.cmd` 的視窗會持續顯示伺服器輸出。
- 同一個區域網路：主機啟動時會列出 IPv4 位址。朋友在 Minecraft「多人遊戲 → 直接連線」輸入主機位址，例如 `192.168.1.10:25565`。朋友不要使用 `127.0.0.1`，那是他自己的電腦。
- 若 Windows 跳出 Java 防火牆詢問，主機須允許所在的私人網路。不同住處需要可互通的虛擬區網，或主機路由器轉發 **TCP 25565**；是否能直接轉發取決於主機的網路環境。
- 主機與朋友必須安裝相同整合包，各自登入不同的正版 Java 版帳號。預設 `online-mode=true`，不提供免驗證模式。
- 玩家到齊後輸入 `/frontline start` 合作，或 `/frontline pvp` 開始玩家對戰。玩家對戰至少需要兩名已連線玩家。

## 操作與模式

| 操作 | 按鍵／指令 |
|---|---|
| 移動、跳躍、蹲下 | WASD、空白鍵、Shift |
| 射擊、瞄準 | 滑鼠左鍵、右鍵 |
| 換彈、切換射擊模式 | R、B |
| 主武器、副武器、手冊 | 1、2、9 |
| 開始合作 NPC 波次 | `/frontline start` |
| 玩家槍戰，先到 10 擊殺獲勝 | `/frontline pvp` |
| 返回基地 | `/frontline arena` |
| 基地補給 | `/frontline kit` |
| 前往周圍原版生存世界 | `/frontline explore` |
| 結束目前模式／查看狀態 | `/frontline stop`、`/frontline status` |

合作模式停用隊友傷害，清完一波後倒數 5 秒刷新下一波，人數越多敵人越多，每波最多 16 名。補給須在基地附近、脫離戰鬥 10 秒後使用。死亡保留物品，戰場玩家重生後重新補給；探索模式保留原版重生位置。

基地的方塊禁止一般玩家破壞，周圍仍是可探索的原版世界。這套模組會在世界原點附近建造場地並調整重生與保留物品規則，請使用整合包新建的獨立世界。不要直接將模組放進珍貴舊存檔。

目前模式控制供私人合作伺服器使用：所有玩家都可開始／停止模式，開始模式會集合目前線上玩家。

## 材質與效能

預設選用 rotrBLOCKS 128x 材質、Complementary Unbound 光影、Oculus 與 Embeddium；光影採中階設定並開啟 labPBR 材質模式。這是原版 Minecraft 的材質／光影渲染，不是完整光線追蹤。沒有預先產生的畫面截圖或實測 FPS。

客戶端預留最多 5 GB 記憶體，伺服器最多 4 GB。若畫面慢或初次進入卡頓，可在「影片設定 → 光影包」關閉光影，再降低渲染距離；需要時在資源包選單停用 rotrBLOCKS。另一台電腦的效能取決於其硬體。

## 檔案與修改

| 路徑 | 用途 |
|---|---|
| `addon/frontline-operations-1.20.1-1.0.0.jar` | 本專案自訂槍戰流程模組 |
| `src/main/java/dev/frontline/` | 波次、場地、計分、裝備、驗證程式的原始碼 |
| `downloads.lock.json` | 固定版本、原作者下載網址與雜湊 |
| `client/` | 隔離的客戶端遊戲目錄 |
| `server/world/` | 新伺服器存檔 |
| `server/server.properties` | 人數、正版驗證與連線埠設定 |
| `server/logs/latest.log`、`client/logs/latest.log` | 故障排查紀錄 |
| `tools/setup.ps1`、`tools/launch.ps1` | 安裝與啟動腳本 |

修改完 Java 原始碼後，可以在已執行過 Setup 的目錄用 PowerShell 編譯。開發工具 `init_dev.py` 需要 Python 3；一般玩家不需要。

```powershell
python tools/init_dev.py
$env:JAVA_HOME = (Resolve-Path 'runtime/java17').Path
.\gradlew.bat --console=plain build
```

編譯結果位於 `build/libs/`。先關閉遊戲與伺服器，再將新 JAR 複製到 `addon/`、`client/mods/` 與 `server/mods/`。若要重新打包，執行 `python tools/package.py`。

伺服器整合驗證指令為 `python tools/test_server.py`，會先檢查本機已接受 EULA，再於獨立測試世界實測 TaCZ 子彈與 NPC AI。兩名 Forge 模擬玩家不能替代兩個正版帳號的網路連線測試。

`python tools/smoke_server.py` 可檢查安裝目錄的正常伺服器開服、TCP 狀態回應及存檔關服，使用連線埠 25565，執行前須先關閉既有伺服器。`python tools/server_status.py --host 127.0.0.1 --port 25565` 只查詢正在運作伺服器的公開狀態，不登入玩家帳號。

本專案自訂程式碼採 MIT；第三方模組、槍枝資產、光影與材質保留原作者權利，詳見 `THIRD_PARTY.md`。Minecraft Java 是 Mojang／Microsoft 的商業遊戲。
