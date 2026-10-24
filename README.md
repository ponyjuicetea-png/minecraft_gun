# 方塊前線：免帳號獨立版

**雙擊 [Start-Game.cmd](Start-Game.cmd) 就能開啟遊戲。** 選「單人開始」可直接和武裝 NPC 戰鬥，不需要 Minecraft、Java 或帳號。

也可以直接執行 [Frontline.exe](standalone/dist/Frontline.exe)。請將 Frontline.pck 保留在 EXE 同一個資料夾。

兩人遊玩：主機按「開啟合作房間」，朋友在同一個區域網路輸入主機的 IPv4，按「加入朋友的房間」。連線使用 UDP 28115。

操作：WASD 移動、空白鍵跳躍、左鍵射擊、右鍵瞄準、R 換彈、G 切換方塊建造、Esc 選單。主機可按 F2 開始合作波次、F3 開始玩家對戰。

完整說明與實測範圍見 [獨立版說明](standalone/README.md)，原始碼在 standalone/game。

遊戲架構、倉庫整理、建置與 GitHub Release 發布步驟見 [GitHub 發布指南](docs/GITHUB_RELEASE_GUIDE.md)。

根目錄入口已統一改為獨立版：

- Start-Game.cmd、Setup.cmd、Join-Game.cmd：開啟主選單。
- Start-Server.cmd：直接開啟合作房間，主機也可遊玩。
- Start-SecondPlayer.cmd：在本機開第二個客戶端，加入 127.0.0.1；請先開合作房間。
- Stop-Server.cmd：顯示主機存檔與離開方式。

這是獨立方塊射擊原型，目前未包含原版 Minecraft 的全部玩法。已完成同一台電腦上獨立主機加兩個客戶端的真實連線測試，尚未實測兩台實體電腦或外網。

舊版專案保留在 minecraft-java 與原 Luanti 資料夾。舊 Java 說明另存為 README-Minecraft-Java.md。
