# comet · UIlib

Roblox 用の自作 UI ライブラリ。外部アセット・外部依存なし。
アクリルガラス調の半透明パネル、斜めに流れるグレア、四隅に配置するカテゴリタブ、
上部のサブタブ帯、そして全要素にトゥイーンアニメーション。

```
comet/
├─ script.luau          ← メイン（ACbypass）
├─ UI/
│  ├─ main.luau         ← UI ライブラリ本体
│  └─ README.md         ← これ（UI の使い方）
├─ method/
│  └─ ACbypass.lua      ← 原本
├─ ROADMAP.md
└─ MEMORY.md
```

---

## 1. 読み込み

### ModuleScript として置く場合

`UI/main.luau` を `ModuleScript` として `ReplicatedStorage` か `PlayerGui` 配下に置く。

```lua
local UIlib = require(game:GetService("ReplicatedStorage"):WaitForChild("UIlib"))
```

### ローカルファイルから読む場合（エグゼキュータ）

```lua
local UIlib = loadstring(readfile("UI/main.luau"))()
```

`UIlib` はテーブルを返す。`UIlib:CreateWindow(...)` でも `UIlib.CreateWindow(...)` でも動く。

---

## 2. 最小構成

```lua
local UIlib = loadstring(readfile("UI/main.luau"))()

local win = UIlib:CreateWindow({
    Title = "comet",
    Subtitle = "loaded",
    Size = Vector2.new(720, 404),
})

local combat = win:Tab({ Name = "Combat", Side = "TopRight" })
local aimbot = combat:SubTab("Aimbot")
local target = aimbot:Section("Targeting")

target:Toggle({ Name = "Enabled", Default = false, Callback = function(v)
    print("aimbot", v)
end })

target:Slider({ Name = "FOV", Min = 0, Max = 180, Default = 90, Step = 1, Suffix = "°" })
```

これだけで、ガラスパネル・四隅タブ・サブタブ帯・スクロールコンテンツが組み上がる。

---

## 3. 画面構成

```
┌──────────────────────────────────────────────────────────┐
│                              [ SUB ] [ SUB ] [ SUB ]      │  ← サブタブ帯（上部中央）
│  [COMBAT]                                       [SETTING] │  ← 四隅タブ（右上 / 左上）
│                                                          │
│   ┌ TARGETING ────────────────────────────────────────┐  │
│   │ Enabled                                ( o)        │  │
│   │ FOV                    90°  ──────●──────          │  │
│   └───────────────────────────────────────────────────┘  │
│                                                          │
│  [VISUAL]                                      [MISC]     │  ← 四隅タブ（左下 / 右下）
└──────────────────────────────────────────────────────────┘
```

| 位置 | `Side` の値 |
|---|---|
| 右上 | `"TopRight"` |
| 左下 | `"BottomLeft"` |
| 右下 | `"BottomRight"` |
| 左上 | `"TopLeft"` |

`Side` はアンカー基準で固定されるので、解像度が変わってもズレない。

---

## 4. API

### `UIlib:CreateWindow(option)`

| フィールド | 型 | 既定 | 説明 |
|---|---|---|---|
| `Title` | string | `"comet"` | 通知の見出しに使う名前 |
| `Subtitle` | string | `"loaded"` | 起動通知の本文 |
| `Size` | Vector2 | `(720, 404)` | ウィンドウの初期サイズ |
| `ToggleKey` | Enum.KeyCode | `RightShift` | 表示 / 非表示のキー |
| `OpenNotification` | boolean | `true` | 起動時に通知を出すか |

**戻り値**: ウィンドウオブジェクト。

| メソッド / フィールド | 説明 |
|---|---|
| `win:Tab{ Name, Side }` | カテゴリタブを生成して返す |
| `win:SelectTab(tab)` | タブを切り替える（通常は自動） |
| `win:SelectSub(tab, sub)` | サブタブを切り替える（通常は自動） |
| `win:Notify{ Title, Text, Duration }` | 通知を出す。既定 3 秒 |
| `win:SetVisible(bool)` | 表示 / 非表示をアニメーション付きで切替 |
| `win:Destroy()` | 接続を全部切って UI を破棄 |
| `win.Tabs` | 生成済みタブの配列 |
| `win.ActiveTab` | 現在のカテゴリ |

`RightShift` は `UserInputService:GetFocusedTextBox()` を見て、テキスト入力中は無視する。

---

### `win:Tab{ Name, Side }`

| フィールド | 型 | 既定 | 説明 |
|---|---|---|---|
| `Name` | string | `"Tab N"` | ボタンのラベル |
| `Side` | string | `"TopRight"` | 上表の四隅 |

**戻り値**: タブオブジェクト。

| メソッド | 説明 |
|---|---|
| `tab:SubTab(name)` | サブタブを追加して返す |

タブの生成時点で自動的に選択状態になる（最初のタブ）。

---

### `tab:SubTab(name)` → `sub`

| メソッド | 説明 |
|---|---|
| `sub:Section(name)` | セクション（見出し付きの囲み）を追加して返す |

サブタブを追加した瞬間、そのタブがアクティブなら上部の帯も更新される。

---

### `sub:Section(name)` → `section`

セクションは自動で縦に伸びる。中身はすべてここに積む。

```lua
local s = sub:Section("Targeting")
```

---

### コンポーネント

すべて `section` に対して呼ぶ。`Callback` は `task.spawn` で走るので、
中で `task.wait` しても UI は固まらない。

#### `section:Toggle(option)`

```lua
local t = section:Toggle({
    Name = "Enabled",
    Description = "master switch",   -- 省略可
    Default = false,
    Callback = function(value) end,
})
```

| 戻り値 | 説明 |
|---|---|
| `t.Value` | 現在値（boolean） |
| `t.Set(v)` | 値を書き換える（Callback は走らない） |

#### `section:Slider(option)`

```lua
local slider = section:Slider({
    Name = "FOV",
    Min = 0, Max = 180,
    Default = 90,
    Step = 1,              -- 省略可。丸める刻み
    Suffix = "°",          -- 省略可。値の後ろに付く
    Callback = function(value) end,
})
```

ドラッグ中も `Callback` が走る。`Step` を入れるとスナップする。

| 戻り値 | 説明 |
|---|---|
| `slider.Value` | 現在値（number） |
| `slider.Set(v)` | 値を書き換える（Callback は走らない） |

#### `section:Dropdown(option)`

```lua
local dd = section:Dropdown({
    Name = "Hitbox",
    Options = { "Head", "Torso", "Random" },
    Default = "Head",
    Callback = function(value) end,
})
```

インラインで下に展開する（スクロール領域内でも切れない）。

| 戻り値 | 説明 |
|---|---|
| `dd.Value` | 選択中の項目 |
| `dd.Set(v)` | 選択を書き換える |

#### `section:Keybind(option)`

```lua
local kb = section:Keybind({
    Name = "Toggle",
    Default = Enum.KeyCode.RightShift,
    Callback = function(key) end,
})
```

ボタンを押すと `...` になり、次のキー / マウス入力で確定する。

| 戻り値 | 説明 |
|---|---|
| `kb.Value` | `Enum.KeyCode` または `Enum.UserInputType` |

#### `section:Button(option)`

```lua
section:Button({
    Name = "Apply",
    Callback = function() end,
})
```

ホバーでアクセント色、押下で 0.98 スケール。

#### `section:Textbox(option)`

```lua
local tb = section:Textbox({
    Name = "Name",
    Placeholder = "input",
    Default = "",
    Callback = function(text) end,
})
```

`FocusLost` で `Callback`。`tb.Box` で生の `TextBox` に触れる。

#### `section:Label(text)`

折り返し付きの説明文。高さは自動。

#### `section:Divider()`

1px の区切り線。

---

### `win:Notify{ Title, Text, Duration }`

```lua
win:Notify({ Title = "comet", Text = "script loaded", Duration = 3 })
```

右下からスライドインし、`Duration` 秒後に右へ抜ける。

---

## 5. テーマ

`Theme` は UIlib 直下に公開されている。**ウィンドウ生成前に**書き換える。

```lua
local T = UIlib.Theme
T.Accent    = Color3.fromRGB(150, 220, 255)
T.AccentAlt = Color3.fromRGB(210, 160, 255)
T.Base      = Color3.fromRGB(10, 12, 18)
T.Radius    = 10
T.BlurSize  = 20
```

| フィールド | 役割 |
|---|---|
| `Accent` / `AccentAlt` | アクセント色 |
| `Text` / `TextDim` | 本文 / 補助文字 |
| `Base` | パネルの下地色 |
| `Stroke` | 枠線色 |
| `Radius` | 角丸半径 |
| `BlurSize` | アクリルのブラー強度 |
| `Font` / `FontMedium` / `FontBold` / `FontMono` | フォント |

フォントは存在しない名前を渡してもフォールバックする。

---

## 6. 見た目とアニメーションの仕組み

| 要素 | 実装 |
|---|---|
| アクリル | `Lighting.BlurEffect` を depth 管理で 1 個だけ生成。閉じると消える |
| 半透明 | パネル `BackgroundTransparency = 0.30` ＋ 白→青のウォッシュ `UIGradient` |
| グレア（静止） | 斜めのグロス帯 `Frame` ＋ 5 点の `Transparency` キーフレーム |
| グレア（動く） | `Heartbeat` で `UIGradient.Offset` を回し、斜めの帯が横切る |
| 面取り | 四隅に 45° のヘアライン 4 本。継ぎ目なしで切落としの輪郭に見せる |
| 起動 | `UIScale` 0.94→1（Back）＋ フェード ＋ 下から 14px |
| 閉じる | フェード ＋ 少し縮んでから `Gui.Enabled = false` |
| タブ | 背景・文字色・文字サイズ・下線グローを同時トゥイーン |
| サブタブ | 同上。切替時にコンテンツ側もフェード |
| コンテンツ | `CanvasGroup.GroupTransparency` でアウト → イン |
| 通知 | 右からスライドイン、右へスライドアウト |

`Heartbeat` のスイープはウィンドウが非表示の間は止まる。

---

## 7. 注意点

- `BlurEffect` は画面全体に効く。ウィンドウを複数作ると最後の 1 個が残る形になるので、
  ウィンドウは 1 個を前提にしている（多重生成は depth が合わない）。
- `RightShift` の開閉はテキスト入力中は無効化される。
- `win:Destroy()` を呼ぶと `ScreenGui` ごと消える。作り直すなら `CreateWindow` から。
- すべての `Callback` は `task.spawn`。UI スレッドを塞がない。
- スクロールは `AutomaticCanvasSize` 任せなので、コンポーネントは自動で高さを伸ばす。

---

## 8. まだ無いもの

- 本体機能との結線（`script.luau` から UIlib をロードしてトグルに繋ぐ段）
- カラーピッカー
- 設定の保存 / 読み込み（JSON）

必要になった時点で足す。
