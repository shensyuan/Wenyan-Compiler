# 中後段：文言文 LLVM 編譯器

以 Flex + Bison 實作 `wenyan-lang` 的 parser 與語意分析，建立符號表與型別系統，生成 LLVM IR，再透過 `llc` 與 `gcc` 連結自建 runtime，產出原生執行檔。

> 課程作業模板、測資與 runtime 骨架由助教 [WavJaby](https://github.com/WavJaby) 提供
> （[NCKU_Compiler_HW2](https://github.com/WavJaby/NCKU_Compiler_HW2)、[作業說明](https://hackmd.io/@WavJaby/NCKU_1142_COMPILER_HW2)）。
> 本目錄為個人實作版本：`compiler.y` 文法與語意動作、`scope.c` 符號表、`object.c` / `value_data.c` 物件系統、
> `main.c` 語意動作核心、`control/` 控制流 IR 生成等為自行完成的部分；
> `lib/`、`src/wy_rt/` 為模板既有的工具庫與 runtime。

---

## 編譯流程

```
.wy ──▶ compiler.l ──▶ compiler.y ──▶ 語意分析／符號表 ──▶ LLVM IR (.ll)
                                                              │
                                                     llc ─────┤
                                                              ▼
                                                       目標檔 (.o)
                                                              │
                                     gcc + libwenyan-runtime ─┤
                                                              ▼
                                                          原生執行檔
```

`wy` 負責前段到 IR；`wyc` 是使用者端驅動程式，把 `wy` → `llc` → `gcc` 串成一條命令。

---

## 實作重點

### 文法與語意動作（`compiler.y`）

以 Bison 的 LALR 文法描述文言語法，涵蓋：

| 語法 | 對應語意 |
|------|---------|
| `吾有一數。曰一。名之曰「甲」。` | 變數宣告（可一次宣告多值） |
| `加「乙」於「甲」。名之曰「和」。` | 四則與邏輯運算、結果命名 |
| `若…者。…若非。…云云。` | if / else if / else |
| `為是 五 遍。…云云。` | 計次迴圈 |
| `恆為是。…云云。` | 無窮迴圈 |
| `乃止。` | break |
| `吾有一術。名之曰…是謂…之術也。` | 函式宣告與定義 |
| `施「術」於…` / `以施` | 函式呼叫（前置與後置兩種語法） |
| `充「甲」以…`、`「甲」之長` | 陣列填充、索引、取長度 |

運算式用優先序宣告解消歧義，宣告類規則搭配 mid-rule action 在讀完型別後就先建好容器，避免把整串值堆到規約末端才處理。

### 作用域與符號表（`scope.c`）

`CompilerContext` 持有一個作用域堆疊，每層 `ScopeData` 帶自己的 HashMap 符號表與型別標記：

```
SCOPE_MAIN / SCOPE_FUNCTION / SCOPE_FOR_LOOP / SCOPE_WHILE_LOOP / SCOPE_IF_STMT
```

查名時由內而外逐層往上找。函式是獨立的 context，引用外層變數時會記錄成**捕獲變數**，在生成函式定義時一併帶入參數列，實作出閉包語意。

### 物件與型別系統（`object.c`、`value_data.c`）

`Object` 統一表示字面值、符號、SSA 暫存器與運算結果，型別列舉涵蓋 `I32` / `I64` / `F64` / `BOOL` / `STR` / `ARRAY` / `FUNC`。混合型別運算時做型別升級（`I32 → I64 → F64`），在生成 IR 前插入必要的 `sext` / `sitofp`，並在型別不相容時回報語意錯誤。

### 控制流 IR 生成（`control/`）

| 檔案 | 產生的結構 |
|------|-----------|
| `if.c` | 條件 `br` + then / elseif / else / end 區塊鏈 |
| `for.c` | 以 `phi` 節點維護迴圈計數器的 header / body / latch / exit |
| `while.c` | 條件區塊與 body 迴圈，支援 `乃止` 跳出到 exit |
| `function.c` | 函式定義、參數與捕獲變數登錄、`ret` |

比較運算依型別選 `icmp` 或 `fcmp`，布林輸出用 `select` 轉成字串指標再交給 `printf`。

### Runtime（`src/wy_rt/`）

`libwenyan-runtime` 提供執行期支援：UTF-8 字串長度與連接、陣列的增刪查與長度。IR 端以 `declare` 宣告後直接呼叫，連結時由 `wyc` 帶入 `-lwenyan-runtime`。

---

## 目錄結構

```
NCKU_Compiler_HW2/
├── src/
│   ├── compiler.l / compiler.y  # 詞法與文法
│   ├── main.c                   # 語意動作核心（宣告、賦值、輸出、取長度、push）
│   ├── expression.c             # 運算式 IR 生成與型別升級
│   ├── object.c / object_type.h # 值系統與型別列舉
│   ├── scope.c                  # 作用域堆疊與符號表
│   ├── value_data.c             # 多值宣告容器
│   ├── control/                 # if / for / while / function 控制流 IR
│   ├── lib/                     # code_gen、byte_buffer、chinese_number、console_color
│   ├── wy_rt/                   # runtime（字串、陣列）
│   └── wyc.c                    # wy → llc → gcc 驅動程式
├── lib/
│   ├── utf8.c/                  # UTF-8 函式庫（submodule）
│   └── WJCL/                    # LinkedList、HashMap（submodule）
├── cmake/                       # toolchain 與 find_package(Wenyan) 設定
├── test/
│   ├── 策問/                    # 基礎測資 13 題（.wy / .expected / .verbose）
│   └── 殿試/                    # 進階測資 3 題
├── LLVM_IR_CHEATSHEET.md        # IR 生成參考
├── YACC_CHEATSHEET.md           # Bison 進階語法參考
└── CMakeLists.txt
```

---

## 建置

| 工具 | 最低版本 |
|------|---------|
| `cmake` | 3.10 |
| `flex` | 2.6 |
| `bison` | 3.6（≥ 3.8 會開啟 `-Wcounterexamples`，衝突訊息好讀很多） |
| `gcc` | 支援 C11 |
| `llvm` / `llc` | 14 |

```bash
cmake -B build -S . -G "MinGW Makefiles"   # Linux 可用 Ninja 或預設產生器
cmake --build build
```

產出三個目標：`wy`（編譯器）、`wyc`（工具鏈驅動）、`libwenyan-runtime`（靜態 runtime）。

---

## 使用

```bash
# 只輸出 LLVM IR
./build/wy test/策問/09_百雞_算術.wy out.ll

# 一路編到原生執行檔
./build/wyc test/策問/09_百雞_算術.wy ./program
./program
```

`wy` 與 `wyc` 共用同一組選項：

| 選項 | 說明 |
|------|------|
| `-v` | 詳述其事（輸出語意分析日誌） |
| `-l` | 詳述解詞（輸出 lexer token 日誌） |
| `-x` | 唯解其詞（只做詞法分析） |
| `-c` | 顯色 |
| `-h` | 示此指南而退 |

`-v` 的語意日誌長這樣，也是測試比對的依據：

```
test/策問/01_開物_定名.wy:1:2     |> (scope id: 0, type: SCOPE_MAIN)
test/策問/01_開物_定名.wy:8:12    |    var 「甲」 <- 1
test/策問/01_開物_定名.wy:16:11   |    PRINT: 「甲」
```

---

## 測試

16 題測資（策問 13 + 殿試 3），每題比對兩件事：

1. **語意日誌**：`wy -v` 的輸出對 `.verbose`
2. **執行結果**：編成執行檔跑完的 stdout 對 `.expected`

```bash
./test/test.sh              # Linux / WSL
.\test\test.ps1           # Windows PowerShell
```

| 短選項 | PowerShell 參數 | 說明 |
|--------|----------------|------|
| `-f <name>` | `-File <name>` | 依檔名子字串篩選測試案例 |
| `-s` | `-Stop` | 遇到第一個失敗即停止 |
| `-n` | `-NoCompile` | 跳過 CMake 重新建置 |
| `-i` | `-Interactive` | 互動式 diff（透過 pager 翻頁） |
| `-b <dir>` | `-BuildDir <dir>` | 指定自訂 build 目錄 |

殿試三題是壓力測試：割圓術（劉徽割圓求圓周率，考浮點精度與迴圈）、曼德博集（巢狀迴圈與字元輸出）、牛頓求根法（函式遞迴與收斂判斷）。

---

## 參考文件

- [`LLVM_IR_CHEATSHEET.md`](LLVM_IR_CHEATSHEET.md) — 本專案用到的 IR 指令、`phi` 節點、控制流區塊結構
- [`YACC_CHEATSHEET.md`](YACC_CHEATSHEET.md) — `$<type>N`、`$0` / `$-1`、mid-rule action、shift/reduce 衝突除錯
