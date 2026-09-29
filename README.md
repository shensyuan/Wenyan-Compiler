# 文言編譯器 (Wenyan Compiler)

這是成功大學編譯系統課程作業紀錄，一套將**文言文程式語言（wenyan-lang）**編譯為**原生執行檔**的完整編譯器工具鏈。

本專案以古典中文（文言文）作為程式語言的語法載體，涵蓋從原始碼到可執行檔的完整流程：

```
.wy 原始碼  →  詞法分析 (Flex)  →  語法/語意分析 (Bison)  →  符號表 & 型別系統  →  LLVM IR  →  llc/gcc  →  原生執行檔
```

---

## 專案概觀

這個專案將兩個階段整合為一條完整的編譯管線：

| 階段 | 目錄 | 職責 |
|------|------|------|
| **前段 — 詞法分析器** | `NCKU_Compiler_HW1/` | 以 Flex 實作 scanner，將文言原始碼切分為 token 串流，包含 UTF-8 定位、中文數字解析 |
| **中後段 — 編譯器** | `NCKU_Compiler_HW2/` | 以 Flex + Bison 實作 parser 與語意分析，建立符號表／型別系統，生成 LLVM IR，並透過 `llc` 與 `gcc` 連結 runtime 成為原生執行檔 |

兩個階段的**作業模板、測資與 runtime 骨架由課程助教 [WavJaby](https://github.com/WavJaby) 提供**
（[HW1](https://github.com/WavJaby/NCKU_Compiler_HW1)、[HW2](https://github.com/WavJaby/NCKU_Compiler_HW2)）。
本倉庫是在該模板上完成的個人實作，詳細的分工說明見各目錄的 README。

---

## 語言簡介：文言文程式設計

以 `wenyan-lang` 的文言語法為基礎，例如：

```
吾有一數。曰一。名之曰「甲」。        // 宣告整數變數甲 = 1
加「乙」於「甲」。名之曰「和」。      // 和 = 甲 + 乙
若「甲」大於「乙」者。               // if (甲 > 乙)
    書之。                           // print
若非。云云。                         // else ...
為是 五 遍。                         // for (i = 0; i < 5; i++)
    書之。                           //     print
云云。                               // }
吾有一術。名之曰「牛頓求根法」。      // 函式宣告與定義
欲行是術。必先得一數。曰「試」。乃行是術曰。
    乃得「甲」。                      // return 甲
是謂「牛頓求根法」之術也。
施「牛頓求根法」於二。書之。          // 呼叫函式
```

---

## 系統架構

### 整體管線

```
                ┌─────────────────────────────────────────────────────────┐
  .wy 原始碼 ──▶ │  Flex Scanner (compiler.l)                             │
                │    · UTF-8 位元組級比對與字元欄位定位                     │
                │    · 字串／識別子／註解 多狀態機 (start condition)         │
                │    · 中文數字（一、二、百、萬…）解析為數值                  │
                └───────────────────────────────┬─────────────────────────┘
                                                │ token 串流
                ┌───────────────────────────────▼─────────────────────────┐
                │  Bison Parser (compiler.y)                              │
                │    · LALR 文法規則、優先序、自訂錯誤訊息                   │
                │    · 語意動作 (semantic action) 驅動語意分析               │
                └───────────────────────────────┬─────────────────────────┘
                                                │
                ┌───────────────────────────────▼─────────────────────────┐
                │  語意分析與符號表                                          │
                │    · 作用域堆疊（MAIN / FUNCTION / FOR_LOOP / WHILE_LOOP / IF_STMT）    │
                │    · 符號表（HashMap）與閉包捕獲                           │
                │    · Object / 型別系統（I32、I64、F64、Bool、Str、Array…）  │
                │    · 型別推導與升級（I32 → I64 → F64）                     │
                └───────────────────────────────┬─────────────────────────┘
                                                │
                ┌───────────────────────────────▼─────────────────────────┐
                │  LLVM IR 程式碼生成                                        │
                │    · SSA 暫存器、alloca/load/store、phi 節點               │
                │    · if/elseif/else、for、while、break 控制流 IR           │
                │    · 函式定義、呼叫、回傳                                    │
                └───────────────────────────────┬─────────────────────────┘
                                                │
                ┌───────────────────────────────▼─────────────────────────┐
                │  wyc 驅動程式 (後端整合)                                   │
                │    llc (LLVM IR → obj) + gcc (obj + runtime → 執行檔)     │
                └─────────────────────────────────────────────────────────┘
```

### 各階段重點實作

- **詞法分析**：手刻 UTF-8 正規式區段（`B2`/`B3`/`B4`），在 Flex 中完成對多語系字元的位元組精確匹配，並同時維護「位元組欄位」與「顯示字元欄位」兩套座標，讓錯誤訊息能精確指向中文原始碼位置。
- **中文數字**：實作完整的中文數字解析器，支援「負、點、又、兩、十、百、千、萬、億…」及金融大寫（壹、貳、拾、佰…），輸出科學記號結構（`ScientificNotation`）以涵蓋整數與浮點數。
- **語法分析**：以 Bison 實作 `wenyan-lang` 的完整文法，包含變數宣告／賦值、四則與邏輯運算、`若/或若/若非`、`為是…遍`（for）、`恆為是`（while）、`乃止`（break）、函式宣告／呼叫（`吾有一術…是謂…之術也`、`施…於…`）、陣列（`充…以…`、索引、`之長`）等。
- **語意分析**：多層作用域堆疊與符號表，支援**閉包捕獲**（captured variable / upvalue）、函式參數、型別檢查與型別升級。
- **程式碼生成**：輸出標準 **LLVM IR**（SSA 形式），包含 `phi` 節點處理迴圈計數器、`icmp`/`fcmp` 比較、`select` 布林輸出、以及對 runtime 函式（字串／陣列操作）的外部呼叫。
- **Runtime**：自建輕量 runtime（`wy_rt`），提供 UTF-8 字串長度／連接、陣列增刪查與長度等執行期支援。
- **工具鏈整合**：`wyc` 驅動程式將 `wy`（前端）→ `llc`（IR → 目標檔）→ `gcc`（連結 runtime）串接，一鍵產出原生執行檔。

---

## 專案結構

```
Wenyan-Compiler/
├── NCKU_Compiler_HW1/             # 前段：詞法分析器
│   ├── src/
│   │   ├── compiler.l             # Flex 詞法規則（UTF-8、字串/識別子狀態機、token）
│   │   ├── main.c                 # scanner 驅動程式
│   │   └── lib/chinese_number.*   # 中文數字解析
│   ├── lib/utf8.c/                # 第三方 UTF-8 字串函式庫 (submodule)
│   ├── test/                      # 策問／殿試 測試案例（.wy 與 .out 期望輸出）
│   └── CMakeLists.txt
│
├── NCKU_Compiler_HW2/             # 中後段：編譯器
│   ├── src/
│   │   ├── compiler.l             # Flex 詞法（token + yylval + 位置追蹤）
│   │   ├── compiler.y             # Bison 文法與語意動作
│   │   ├── main.c                 # 語意動作核心（宣告、賦值、輸出、取長度、push）
│   │   ├── expression.c           # 運算式 IR 生成
│   │   ├── object.c / object_type.h # Object 值系統與型別列舉
│   │   ├── scope.c                # 作用域堆疊與符號表
│   │   ├── value_data.c           # 多值宣告容器
│   │   ├── control/               # if / for / while / function 控制流 IR
│   │   ├── wy_rt/                 # runtime 函式庫（字串、陣列）
│   │   ├── wyc.c                  # 前端 → llc → gcc 驅動程式
│   │   └── lib/                   # code_gen、byte_buffer、chinese_number 等工具
│   ├── lib/WJCL/                  # 資料結構庫：LinkedList、HashMap (submodule)
│   ├── test/                      # 策問／殿試 測試案例（.wy / .expected / .verbose）
│   ├── CMakeLists.txt
│   ├── LLVM_IR_CHEATSHEET.md      # IR 生成參考文件
│   └── YACC_CHEATSHEET.md         # Bison 進階語法參考文件
│
└── README.md
```

---

## 建置與使用

### 取得原始碼

第三方函式庫（`utf8.c`、`WJCL`）以 git submodule 管理，clone 時請一併取得：

```bash
git clone --recursive https://github.com/shensyuan/Wenyan-Compiler.git

# 若已經 clone 過
git submodule update --init --recursive
```

### 相依套件

| 工具 | 最低版本 | 用途 |
|------|---------|------|
| `cmake` | 3.10 | 建置系統 |
| `flex` | 2.6 | 詞法分析器生成 |
| `bison` | 3.6（≥3.8 提供衝突提示） | 語法分析器生成 |
| `gcc` | C11 支援 | 編譯與連結 |
| `llvm` / `llc` | 14 | IR → 目標檔 |

### 前段（詞法分析器）

```bash
# NCKU_Compiler_HW1/
cmake -B build -S . -G Ninja
cmake --build build

# 產出 token 串流
./build/lexer_test test/策問/04_九章_算術.wy

# 執行全部測試
./test.ps1      # Windows PowerShell
./test.sh       # Linux
```

### 中後段（編譯器）

```bash
# NCKU_Compiler_HW2/
cmake -B build -S . -G "MinGW Makefiles"
cmake --build build

# 僅輸出 LLVM IR
./build/wy test/input.wy out.ll

# 一鍵編譯為原生執行檔
./build/wyc test/input.wy ./program
./program

# 執行全部測試
./test/test.sh -n    # Windows: .\test\test.ps1 -NoCompile
```

### `wy` 命令列選項

| 選項 | 說明 |
|------|------|
| `-v` | 詳述其事（輸出語意日誌） |
| `-l` | 詳述解詞（輸出 lexer token 日誌） |
| `-x` | 唯解其詞（僅詞法分析） |
| `-c` | 顯色（彩色輸出） |
| `-h` | 顯示幫助 |

---

## 測試

兩階段皆採用「所見即所得」的對勘式測試：將編譯器的實際輸出與期望輸出（`.out` / `.expected`）逐字比對。

- **前段**：比對 token 串流（座標、型別、值）。
- **中後段**：比對 `-v` 語意日誌（Part 1）與最終執行結果（Part 2）。

測試案例涵蓋：變數定名、值傳遞、輸出、四則運算、決策（if/else）、迴圈（for/while）、乘算口訣、百雞問題、陣列、以及函式（牛頓求根法），另含進階測資「割圓術」（求圓周率）與「曼德博集合」。

---

## 技術棧

- **語言**：C（C99 / C11）
- **詞法**：Flex（含自訂 UTF-8 狀態機與座標追蹤）
- **語法／語意**：Bison（LALR、優先序、自訂錯誤、mid-rule action）
- **程式碼生成**：LLVM IR（SSA、phi 節點、型別升級）
- **後端整合**：`llc` + `gcc` + 自建 runtime（`wy_rt`）
- **建置**：CMake、git submodules（`utf8.c`、`WJCL` 資料結構庫）
- **核心概念**：編譯器前後端、符號表與作用域、閉包、型別系統、控制流 IR 生成

---

## 致謝與出處

- **課程作業模板**：成功大學 1142 編譯系統課程，助教 [WavJaby](https://github.com/WavJaby)
  - 作業一模板與測資：[WavJaby/NCKU_Compiler_HW1](https://github.com/WavJaby/NCKU_Compiler_HW1)（[作業說明](https://hackmd.io/@WavJaby/NCKU_1142_COMPILER_HW)）
  - 作業二模板、測資與 runtime 骨架：[WavJaby/NCKU_Compiler_HW2](https://github.com/WavJaby/NCKU_Compiler_HW2)（[作業說明](https://hackmd.io/@WavJaby/NCKU_1142_COMPILER_HW2)）
  - `LLVM_IR_CHEATSHEET.md`、`YACC_CHEATSHEET.md` 亦出自課程教材
- **語言設計**：[wenyan-lang](https://github.com/wenyan-lang/wenyan) — 文言文程式語言
- **第三方函式庫**（以 submodule 引入，未收錄原始碼）
  - [zahash/utf8.c](https://github.com/zahash/utf8.c) — UTF-8 字串處理（MIT）
  - [WavJaby/WJCL](https://github.com/WavJaby/WJCL) — LinkedList、HashMap 資料結構
