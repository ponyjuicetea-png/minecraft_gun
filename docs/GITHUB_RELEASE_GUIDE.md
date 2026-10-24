# 方塊前線：遊戲架構與 GitHub 發布指南

文件日期：2026-10-24。適用目前的 Windows x64 免帳號獨立版。

建議第一版以 **v0.1.0-alpha.1 測試版**發布：GitHub 倉庫提供原始碼，GitHub Releases 提供可直接遊玩的 ZIP。遊戲使用 Godot、Voxel Tools 與 VoxelGame 為基礎，包含本專案的射擊、敵人及對戰功能。

本文件是架構與操作說明。撰寫時，本機尚未初始化 Git 倉庫，也尚未建立遠端倉庫或上傳 Release。以下指令供維護者依步驟執行。

## 1. 目前已有的成果

| 項目 | 目前位置與狀態 |
| --- | --- |
| 原始碼 | standalone/game，主設定為 project.godot |
| 啟動入口 | 根目錄 Start-Game.cmd |
| Windows 程式 | standalone/dist/Frontline.exe |
| 遊戲資源包 | standalone/dist/Frontline.pck，須與 EXE 放在一起 |
| 玩家下載包 | standalone/dist/Frontline-Standalone-Windows-x64.zip |
| 完整性校驗 | 同資料夾內的 .zip.sha256 |
| 連線驗證 | standalone/reports/network-integration.json，17 項通過 |
| 真實畫面驗證 | standalone/reports/export-preview.png 與 export-smoke.log |

目前 ZIP 大約 55.4 MB，完整解壓後即可執行。玩家不需要 Python、Java、Minecraft 或遊戲帳號。Python 與含 Voxel Tools 的 Godot 是開發、測試及打包工具。

現有驗證使用同一台實體電腦上的獨立主機與兩個客戶端，經由真正的 ENet 連線交換資料。兩台實體電腦、跨網際網路、長時間遊玩及 8 人同時在線仍需補測。

## 2. 遊戲執行架構

~~~mermaid
flowchart TD
    A["Start-Game.cmd / Frontline.exe"] --> B["main.gd：主選單、暱稱、開房與加入"]
    B --> C["frontline/game.gd：整合遊戲場景"]
    C --> D["blocky_game：角色、方塊互動、地形同步"]
    C --> E["world_generator.gd：戰場、建築、周邊地形"]
    C --> F["combat.gd：槍械規則、血量、合作與對戰"]
    C --> G["VoxelStreamSQLite：主機世界存檔"]
    F --> H["npc.gd：敵人移動、索敵、開槍"]
    F --> I["weapon_view.gd / humanoid.gd：槍械與角色外觀"]
    D <-->|"ENet / UDP 28115"| J["其他玩家的遊戲客戶端"]
    F <-->|"射擊請求與戰鬥狀態"| J
~~~

| 檔案或資料夾 | 責任 |
| --- | --- |
| standalone/game/frontline/main.tscn、main.gd | 主場景、選單、命令列參數、開始與離開遊戲 |
| standalone/game/frontline/game.gd | 擴充方塊場景，配置材質、世界串流與角色 |
| standalone/game/frontline/world_generator.gd | 生成可挖掘、建造的方塊戰場與周邊環境 |
| standalone/game/frontline/combat.gd | 射擊、彈藥、換彈、傷害、得分、重生、波次、PvP 與 HUD |
| standalone/game/frontline/npc.gd | 由主機模擬敵人行為與攻擊 |
| standalone/game/frontline/weapon_view.gd、humanoid.gd | 第一人稱槍械、瞄準與後座力，以及第三人稱角色 |
| standalone/game/blocky_game | VoxelGame 基礎場景及對角色、背包、互動與同步的修改 |
| standalone/game/frontline/assets | 執行時載入的模型、音效、照片材質與法線貼圖 |
| standalone/assets | 素材來源、授權標示與 SHA-256 紀錄 |
| standalone/tools | 匯出、打包與自動驗證工具 |

### 連線資料流

單人模式在本機執行遊戲邏輯；合作房間由其中一位玩家的程式同時當主機。另有不顯示畫面的專用主機啟動模式。

射擊時，客戶端送出方向，主機依玩家身分、射速、彈藥、換彈與存活狀態判斷是否有效，再檢查方塊遮擋及角色命中，計算傷害並同步結果。敵人的 AI、傷害與波次由主機模擬。

角色移動目前沿用客戶端回報位置的方式，尚未形成完整的主機移動驗證系統。房間上限設定為 8 人；已實測的規模是兩個玩家客戶端，發布說明應區分兩者。

### 存檔與玩家設定

世界存檔使用 VoxelStreamSQLite，預設位於：

~~~text
%APPDATA%\Godot\app_userdata\FrontlineStandalone\worlds\frontline.sqlite
~~~

暱稱存於同一個應用程式資料目錄的 settings.cfg。程式與 PCK 可以更新替換，玩家存檔另存於上述位置；不同版本的存檔相容性仍需驗證。

## 3. GitHub 倉庫整理

建議倉庫名稱為 frontline-standalone，先保留 standalone 子資料夾，讓現有工具的相對路徑繼續有效。

~~~text
frontline-standalone/
├─ README.md                         # 玩家下載、介紹、操作與實測範圍
├─ LICENSE                           # 發布前補上新增程式碼的授權
├─ .gitignore
├─ Start-Game.cmd
├─ 其他根目錄啟動 CMD
├─ docs/
│  └─ GITHUB_RELEASE_GUIDE.md
└─ standalone/
   ├─ README.md
   ├─ PROPOSAL.md
   ├─ .gitignore
   ├─ dependencies.lock.json          # 引擎版本、下載網址與 SHA-256
   ├─ Start-Game.cmd
   ├─ game/                          # 完整原始碼與必要素材
   │  ├─ project.godot
   │  ├─ export_presets.cfg
   │  ├─ frontline/
   │  ├─ blocky_game/
   │  └─ addons/
   ├─ assets/                        # 素材來源 JSON
   ├─ licenses/                      # 引擎、程式及第三方通知
   └─ tools/                         # Python 與 GDScript 工具
~~~

上圖是建議提交範圍；LICENSE 是待補檔案。舊 minecraft-java 與 Luanti 內容可留在本機，這個倉庫只提交獨立版相關內容。

Godot 原始資源、.import 設定、.uid 與 export_presets.cfg 應保留；.godot 是重新建置時產生的匯入快取。編輯器、匯出範本、EXE、PCK、ZIP、測試世界及本機暫存資料不放入原始碼提交。

現有 standalone/.gitignore 已排除 runtime、export-template、upstream、dist、.cache 與 game/.godot。第一次提交前，請在根目錄 .gitignore 追加：

~~~gitignore
/standalone/test-runs/
/standalone/reports/*.log
**/.godot/
*.sqlite
*.sqlite-*
.env
.env.*
~~~

EXE 與 ZIP 使用 Release 附件提供下載。GitHub 的一般 Git 倉庫對超過 50 MiB 的檔案顯示提醒，超過 100 MiB 的檔案會被擋下；官方也建議透過 Releases 分發大型成品。[GitHub 大型檔案說明](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)

## 4. 首次發布前待補項目

| 項目 | 具體處理 |
| --- | --- |
| 版本資訊 | 建議新增 project.godot 的 application/config/version，並在選單顯示相同版本 |
| 專案授權 | 由作者決定新增程式碼的授權，建立根目錄 LICENSE，保留上游通知 |
| GitHub 首頁 | README 加上 Release 下載、畫面、操作及連線說明，整理舊方案文字 |
| 版本變更 | 新增 CHANGELOG.md，記錄新增、修正及已知問題 |
| 跨電腦連線 | 兩台電腦實測開房、加入、共同射擊、地形編輯與主機退出 |
| 存檔相容性 | 實測關閉後重開同一世界，以及版本更新後讀取備份 |
| 硬體需求 | 實際量測幀率、記憶體與顯示卡相容性後，再公布需求 |
| 自動建置 | 補上不依賴原工作目錄快取的流程；目前尚無 GitHub Actions 工作流程 |

前述項目尚未全部完成，因此首版適合標為 Alpha。公開配對大廳、房間密碼與自動更新也還不是現有功能。

## 5. 從原始碼準備建置環境

以下範例使用 Windows PowerShell，工作目錄是本專案根目錄。需要 Git、Python 3，以及 dependencies.lock.json 記錄的特製 Godot 編輯器與匯出範本。

Voxel Tools 是此版本引擎內的模組，必須使用對應的編輯器與範本。下載依據為專案鎖定檔，目前記錄 godot_voxel v1.7。

### 5.1 建立資料夾並還原引擎

~~~powershell
Set-Location 'C:\c++\Minecraft_gun'
New-Item -ItemType Directory -Force -Path 'standalone/.cache', 'standalone/dist', 'standalone/reports', 'standalone/runtime', 'standalone/export-template' | Out-Null

$frontlineLock = Get-Content 'standalone/dependencies.lock.json' -Raw | ConvertFrom-Json
$frontlineDependencies = @(
    @{ Name = 'godot_voxel_editor'; Destination = 'standalone/runtime' }
    @{ Name = 'godot_voxel_export'; Destination = 'standalone/export-template' }
)

foreach ($frontlineItem in $frontlineDependencies) {
    $frontlineArtifact = $frontlineLock.artifacts | Where-Object { $_.name -eq $frontlineItem.Name }
    if ($null -eq $frontlineArtifact) { throw '鎖定檔缺少必要的引擎項目' }
    $frontlineArchive = Join-Path 'standalone/.cache' ($frontlineItem.Name + '.zip')
    Invoke-WebRequest -Uri $frontlineArtifact.url -OutFile $frontlineArchive
    $frontlineHash = (Get-FileHash -LiteralPath $frontlineArchive -Algorithm SHA256).Hash
    if ($frontlineHash -ne $frontlineArtifact.sha256) {
        throw ('SHA-256 不符合：' + $frontlineItem.Name)
    }
    Expand-Archive -LiteralPath $frontlineArchive -DestinationPath $frontlineItem.Destination -Force
}
~~~

遊戲所需的現有模型、貼圖與音效應隨 game 提交，一般建置直接使用這些資源。prepare.py 是早期準備工具，仍引用父目錄 .cache/frontline_rifle.wav，不是乾淨 checkout 的完整初始化工具。也不要重新解壓上游範例覆蓋已修改的 game。

### 5.2 匯入與連線測試

~~~powershell
python standalone/tools/run_engine.py --log import.log -- --headless --import
if ($LASTEXITCODE -ne 0) { throw 'Godot 資源匯入失敗' }

python standalone/tools/test_network.py
if ($LASTEXITCODE -ne 0) { throw '主機與雙客戶端測試失敗' }
~~~

run_engine.py 等待 Windows Godot 程序完成並記錄輸出。連線測試使用 UDP 28315，與玩家房間的 UDP 28115 分開；結果寫入 reports，測試世界寫入 test-runs。

## 6. 匯出與打包

### 6.1 匯出 Windows Release

~~~powershell
$frontlineExport = Join-Path (Get-Location).Path 'standalone/dist/Frontline.exe'
python standalone/tools/run_engine.py --log export.log -- --headless --export-release 'Windows Desktop' $frontlineExport
if ($LASTEXITCODE -ne 0) { throw 'Windows 匯出失敗' }

python standalone/tools/test_export.py
if ($LASTEXITCODE -ne 0) { throw '匯出成品的啟動與畫面驗證失敗' }
~~~

匯出設定取自 game/export_presets.cfg，範本位於 export-template，會產生 EXE 與獨立 PCK。命令列匯入與 Release 匯出參數見 [Godot 官方說明](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html)。

test_export.py 會實際開啟遊戲視窗、進入測試世界並擷取畫面，需要可正常執行本遊戲渲染的桌面環境，與純 headless 連線測試的目的不同。

### 6.2 準備通知與可攜包啟動檔

~~~powershell
$frontlineLicenseScript = Join-Path (Get-Location).Path 'standalone/tools/extract_licenses.gd'
python standalone/tools/run_engine.py --log licenses.log -- --headless --script $frontlineLicenseScript
if ($LASTEXITCODE -ne 0) { throw '引擎通知匯出失敗' }

@'
@echo off
start "" /d "%~dp0" "%~dp0Frontline.exe" %*
'@ | Set-Content -LiteralPath 'standalone/dist/Start-Game.cmd' -Encoding ASCII

python standalone/tools/build_package.py
if ($LASTEXITCODE -ne 0) { throw '玩家下載包製作失敗' }
~~~

dist 被 Git 忽略，因此乾淨 checkout 必須重新建立上述啟動檔。打包工具會讀取已存在的連線報告、成品截圖與日誌，將成品、README、來源紀錄和 licenses 放進 ZIP，檢查 ZIP 並輸出 SHA-256。

現有通知包括 Godot-MIT.txt、VoxelTools-MIT.txt、VoxelGame-MIT.txt 與 Engine-Third-Party.json。M4A1 與表面材質的來源及 CC0 標示記錄在 assets JSON。

打包完成後，另外解壓到新資料夾執行 Frontline.exe，確認不依賴原工作目錄。這個「完整解壓後啟動」仍需在每次發布時實際檢查。

## 7. 建立 GitHub 原始碼倉庫

先完成第 3 節的 .gitignore 與首頁整理，再到 GitHub 建立空白倉庫 frontline-standalone。使用下列首次推送流程時，遠端倉庫不要預先產生 README、LICENSE 或 .gitignore，避免出現兩份初始歷史。[GitHub 本機專案匯入說明](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)

將 YOUR_ACCOUNT 換成自己的 GitHub 帳號或組織名稱。首次推送依 Git 工具提示登入 GitHub；遊戲玩家仍不需要帳號。

~~~powershell
git init -b main
git add -- README.md .gitignore Start-Game.cmd Setup.cmd Join-Game.cmd Start-Server.cmd Start-SecondPlayer.cmd Stop-Server.cmd standalone docs/GITHUB_RELEASE_GUIDE.md
git diff --cached --stat
git status --short
~~~

確認待提交清單只有獨立版需要的原始碼、素材與文件，且沒有 dist、runtime、test-runs 或世界資料。新增 LICENSE、CHANGELOG.md 或其他發布文件後，也要明確加入提交。

~~~powershell
git commit -m "Prepare standalone alpha release"
git remote add origin https://github.com/YOUR_ACCOUNT/frontline-standalone.git
git push -u origin main
git tag -a v0.1.0-alpha.1 -m "Frontline standalone alpha 1"
git push origin v0.1.0-alpha.1
~~~

標籤應指向實際測試與建置成品使用的提交。後續修正以新版本標籤發布，讓原始碼、成品與測試結果可以對應。

## 8. 發布 GitHub Release

進入倉庫的 Releases，選 Draft a new release，選擇 v0.1.0-alpha.1 標籤，填寫標題及版本說明，上傳：

~~~text
Frontline-Standalone-Windows-x64.zip
Frontline-Standalone-Windows-x64.zip.sha256
~~~

勾選 This is a pre-release，先存草稿供審視，確認附件齊全後再 Publish release。操作欄位與流程見 [GitHub Release 官方說明](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository)。

GitHub 自動產生的 Source code ZIP 是標籤當下的原始碼封存；玩家應下載上述手動上傳的遊戲 ZIP。[GitHub Releases 說明](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)

### 可直接使用的 Release 說明範本

~~~markdown
# 方塊前線 v0.1.0-alpha.1

Windows x64 獨立方塊射擊測試版，免遊戲帳號。

## 下載與開始

下載附件 Frontline-Standalone-Windows-x64.zip，完整解壓後執行 Frontline.exe。
請保留同資料夾的 Frontline.pck。

## 內容

- 方塊戰場，可挖掘與建造。
- M4A1 射擊、瞄準、換彈。
- 會移動及射擊的敵人 NPC。
- 合作波次及玩家對戰。
- 區網房間，使用 UDP 28115。

## 兩人連線

主機按「開啟合作房間」；朋友在相同區網輸入主機 IPv4，
按「加入朋友的房間」。

## 操作

WASD 移動、空白跳躍、左鍵射擊、右鍵瞄準、R 換彈、
G 切換建造、Esc 選單。主機 F2 合作、F3 玩家對戰、F5 存檔。

## 實測與限制

已通過同一台電腦上主機與兩個客戶端的 17 項連線檢查，
以及匯出 EXE 的實際畫面驗證。
尚未完成兩台實體電腦、外網、8 人負載與長時間穩定性測試。
本版本為獨立遊戲原型，尚未包含 Minecraft 的完整玩法。

若本次發布前已完成更多實測，請在此補上環境與結果。
~~~

發布後，README 的玩家下載連結可填：

~~~text
https://github.com/YOUR_ACCOUNT/frontline-standalone/releases/tag/v0.1.0-alpha.1
~~~

## 9. 後續自動發布架構

目前沒有已建置的 GitHub Actions 發布流程。建議先跑通手動發布，再導入：

~~~mermaid
flowchart LR
    A["功能提交 / PR"] --> B["Windows：還原引擎、匯入、連線測試"]
    B --> C["建立版本標籤"]
    C --> D["從標籤匯出 Windows 成品"]
    D --> E["可渲染機器：成品畫面與雙機驗證"]
    E --> F["打包 ZIP、SHA-256、測試紀錄"]
    F --> G["建立 GitHub Release 草稿"]
    G --> H["維護者審視後發布"]
~~~

自動化時固定引擎網址與雜湊，從乾淨 checkout 建置，將版本、Git 提交編號及測試環境寫入發布紀錄。有圖形需求的檢查安排在可渲染環境；現有 test_export.py 尚未在一般雲端 runner 驗證。

後續版本依序安排：Alpha 補齊雙機連線與存檔測試；Beta 加入畫質、音量、按鍵設定與穩定性改善；完成目標硬體及升級驗證後再規劃 v1.0.0。
