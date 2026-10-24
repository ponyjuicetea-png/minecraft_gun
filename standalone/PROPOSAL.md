# 前線：獨立方塊槍戰版

目標是直接執行 Windows 遊戲，不需要 Minecraft、Microsoft 帳號、Launcher 或中央登入服務。單人模式可離線遊玩；兩人以上使用暱稱與主機 IP 直接連線。

採用 Godot 4＋Voxel Tools 的開源方塊底座，接續官方 Voxel Game 範例已有的地形串流、挖掘、建造及多人方塊同步，加入本專案的槍械、戰鬥和敵人 AI。這個路線能獨立發佈，需要重新實作 TaCZ 的遊玩機制，不能直接執行 Java 模組。

第一版交付範圍：

- 方塊世界、挖掘、放置、探索與存檔。
- 單人作戰、開房與 IP 加入，無註冊、無外部帳號驗證。
- 槍械射擊、瞄準、換彈、血量與重生。
- 可受傷、追蹤玩家並持槍還擊的人形敵人。
- 至少兩個獨立客戶端連線，合作與玩家對戰。
- 使用可獨立再發佈的材質與模型，提供完整 Windows 執行包及原始碼。

畫面以 Minecraft 的方塊形狀為基礎，採用寫實表面、動態陰影和有比例細節的槍械。畫面以實際執行截圖與遊戲包驗收；第一版是玩法原型，並非已包含 Minecraft 全部生存、紅石和合成內容的成品。

底座和素材來源：

- [Godot Engine](https://github.com/godotengine/godot)：MIT。
- [Voxel Tools](https://github.com/Zylann/godot_voxel)：MIT。
- [Voxel Game 範例](https://github.com/Zylann/voxelgame)：MIT，已有基本方塊多人同步。
- [nisu 的 M4A1 模型](https://opengameart.org/content/m4a1-assault-rifle)：CC0。
- [Poly Haven](https://polyhaven.com/)：CC0 表面材質。

目前新的獨立版工作目錄是 `standalone/`。先前的 Java／TaCZ 及 Luanti 資料保留，待新版本驗證通過後才切換根目錄的啟動入口。
