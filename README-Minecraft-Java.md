# 前線作戰：Minecraft Java＋TaCZ

目前開發方案已改成 **原版 Minecraft Java 1.20.1＋Forge＋TaCZ**，新增 Bandit 武裝敵人、合作波次與玩家槍戰。預設伺服器上限 8 人，支援兩人以上；每位玩家需要自己的正版 Java 版帳號。

**[下載 Windows 安裝包](minecraft-java/dist/Frontline-Minecraft-Java-Installer.zip)** · **[完整安裝與連線說明](minecraft-java/README.md)** · **[驗證狀態](minecraft-java/VALIDATION.json)**

這是開發預覽版，自訂模組編譯與 29 項伺服器整合檢查已通過，包括 TaCZ 子彈傷害、NPC 還擊、雙人對戰指令、合作波次與計分。正式安裝目錄也通過 TCP 25565 狀態回應與存檔關服驗證。測試使用 Forge 模擬玩家；目前沒有可用的正版 Java 帳號，因此兩個正版帳號連線及客戶端光影畫面尚未實測。安裝包本身不包含 Minecraft 遊戲授權。詳細結果位於 `minecraft-java/reports/`。

## 這台電腦的入口

所需檔案與官方 Launcher 安裝設定已建立在 `minecraft-java/`。根目錄的啟動檔現在全部指向這套原版 Minecraft 方案。

- `Start-Game.cmd`：啟動本機伺服器並開啟官方 Launcher；選 **Frontline - TaCZ NPC Co-op** 按「開始遊戲」，進入多人清單中的 **Frontline - Local host**。
- `Start-Server.cmd`：只啟動伺服器。
- `Join-Game.cmd`：朋友加入時的客戶端入口。
- `Stop-Server.cmd`：存檔並停止本專案伺服器。
- `Setup.cmd`：重新配置或安裝到另一台電腦。安裝包需先解壓縮。

尚未接受 EULA 的新安裝會在首次開服時顯示條款網址，等待本人決定是否接受；本機已依使用者同意記錄接受。進入遊戲後按 `9`、右鍵打開作戰手冊，點合作模式開始打武裝 NPC。兩名玩家到齊後可用 `/frontline pvp` 開始對戰。

同區網朋友連線主機 IPv4 位址加 `:25565`；完整步驟、跨網路連線、材質光影與修改原始碼方式請見上面的完整說明。

## 舊版資料

原有 Luanti／VoxeLibre 原型仍保存在原路徑，舊說明備份為 `README-Luanti.md`。舊版引擎、Lua 模組與安裝包不屬於目前的 Java 方案。Java 新模組的原始碼與 MIT 授權位於 `minecraft-java/`，第三方來源見該資料夾的 `THIRD_PARTY.md`。
