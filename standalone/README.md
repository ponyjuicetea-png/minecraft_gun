# 方塊前線：獨立版

這是免帳號的 Windows 方塊射擊遊戲原型，使用 Godot 與 Voxel Tools。包含可破壞與建造的方塊場景、M4A1、武裝敵人 NPC、合作波次及玩家對戰。

## 執行

在本專案雙擊 Start-Game.cmd，或進入 standalone/dist 雙擊 Frontline.exe。選擇「單人開始」即可遊玩，敵人會在開局幾秒後出現。不需要安裝 Python、Java 或 Minecraft，也不需要註冊帳號。

可攜包請先完整解壓縮，再雙擊 Frontline.exe。Frontline.pck 必須與 EXE 放在同一個資料夾。

## 兩人以上連線

1. 每位玩家準備相同版本的完整遊戲資料夾，連接相同區域網路。
2. 主機填寫暱稱，按「開啟合作房間」。
3. 朋友填寫暱稱，在「朋友主機的 IP 位址」輸入主機的區網 IPv4 位址，例如 192.168.1.10，按「加入朋友的房間」。
4. 若 Windows 首次詢問防火牆連線，允許遊戲在私人網路連線。使用的連接埠是 UDP 28115。

主機可在命令提示字元執行 ipconfig 查看目前使用中的網路卡 IPv4。不同電腦不能用 127.0.0.1 加入，這個位址只指向自己的電腦。

同一台電腦測試兩個視窗時，先開合作房間，再開第二個遊戲視窗，輸入另一個暱稱與 127.0.0.1 加入。一般房間設定最多 8 人。

跨網際網路需要額外網路設定，目前已完成的自動驗證範圍是同一台電腦上的獨立主機與兩個客戶端；尚未實測兩台實體電腦或外網連線。

## 操作

| 按鍵 | 功能 |
| --- | --- |
| WASD、空白鍵 | 移動、跳躍 |
| 滑鼠左鍵、右鍵 | 射擊、瞄準 |
| R | 換彈 |
| G | 切換槍械與方塊建造模式 |
| 建造模式左鍵、右鍵 | 挖方塊、放方塊 |
| E | 方塊背包 |
| F2 | 主機開始合作波次 |
| F3 | 主機開始玩家對戰，至少兩人 |
| F5 | 主機存檔 |
| Esc | 選單、釋放滑鼠 |

合作模式中的敵人會移動並開槍。玩家對戰先取得 10 次擊殺者獲勝。主機存檔位於 %APPDATA%\Godot\app_userdata\FrontlineStandalone\worlds\frontline.sqlite。

## 目前範圍

這是獨立遊戲原型，尚未具備原版 Minecraft 的完整合成、生存、紅石與內容量。槍械與連線功能是本專案的實作，未使用 Minecraft 或 TaCZ 的遊戲檔案。

真實連線測試報告：reports/network-integration.json。已驗證免帳號啟動、兩個客戶端、地形同步、挖掘建造同步、NPC 傷害、玩家射擊、換彈、對戰、重生與存檔。

## 開源與素材

- Godot、Voxel Tools、VoxelGame：MIT 授權，通知見 licenses/。
- M4A1 模型：nisu，OpenGameArt，CC0。
- 表面材質：Poly Haven，CC0。
- 素材來源與雜湊見 assets/ 中的 JSON。

修改遊戲原始碼時，使用 runtime 裡包含 Voxel Tools 的 Godot 版本開啟 game/project.godot。
