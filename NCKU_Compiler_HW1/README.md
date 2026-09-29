# 前段：文言文詞法分析器

以 Flex 實作 `wenyan-lang` 的 scanner，把文言原始碼切成帶座標的 token 串流，是整條編譯管線的第一關。

> 課程作業模板與測資由助教 [WavJaby](https://github.com/WavJaby) 提供
> （[NCKU_Compiler_HW1](https://github.com/WavJaby/NCKU_Compiler_HW1)、[作業說明](https://hackmd.io/@WavJaby/NCKU_1142_COMPILER_HW)）。
> 本目錄為個人實作版本，`src/compiler.l`、`src/lib/chinese_number.*` 等為自行完成的部分。

---

## 實作重點

### UTF-8 位元組級比對

Flex 以位元組為單位運作，中文字無法直接用字元類別描述。這裡手刻了 UTF-8 各長度的合法位元組區段當作正規式的基礎：

```lex
ASCII   [\x00-\x7f]
U       [\x80-\xbf]
B2      [\xC2-\xDF]{U}
B3_1    \xE0[\xA0-\xBF]{U}
B3_2    [\xE1-\xEC]{U}{U}
```

識別子、字串、註解內容都建構在這組區段上，因此能正確吃下中文、日文假名、emoji 等任意 UTF-8 字元，同時排除非法位元組序列。

### 兩套座標系統

錯誤訊息若用位元組位移報欄位，中文原始碼會全部指錯位置。`YY_USER_ACTION` 在每次比對後呼叫 `processUtf8Char()`，用 `utf8.c` 算出這段文字的**顯示字元數**，另外維護 `yycolumnUtf8`：

- `yyleng` / `yytext`：位元組，交給 Flex 與後續字串處理
- `yycolumnUtf8` / `yylengUtf8`：顯示字元，只用於輸出座標

搭配 `yymore()` 的規則（多行字串、註解）另外包了一層 `yymore_utf8()`，在累積 token 時把欄位回捲到字串起點，讓跨行 token 仍回報開頭位置。

### 多狀態機

字串（`「「…」」`）、識別子（`「…」`）、註解各自有起始條件，處理巢狀標點、跨行內容與未封閉時的錯誤回報。`trimStringToken()` 依 padding 長度裁掉前後引號，取出真正的字面值。

### UTF-8 BOM

以八進位逸出序列明確匹配並略過檔頭 BOM，避免第一個 token 的座標被推移。

### 中文數字解析

`src/lib/chinese_number.c` 是獨立的中文數字剖析器，以 token 表加遞迴組合處理：

- 一般數字：一、二、三…十、百、千、萬、億、兆
- 金融大寫：壹、貳、參、肆、拾、佰、仟
- 修飾詞：負、又、兩、點

輸出 `ScientificNotation` 結構（尾數加指數），整數與浮點共用同一條路徑，`四萬三千二百一十一` 與 `三又七分` 都能正確還原。

---

## 目錄結構

```text
NCKU_Compiler_HW1/
├── src/
│   ├── compiler.l               # Flex 詞法規則
│   ├── compiler_util.h          # 共用巨集與錯誤處理
│   ├── main.c                   # scanner 驅動程式
│   └── lib/
│       ├── chinese_number.c/.h  # 中文數字解析
│       └── utf8_console.h       # Windows 主控台 UTF-8 輸出設定
├── lib/utf8.c/                  # 第三方 UTF-8 函式庫（submodule）
├── test/
│   ├── 策問/                    # 基礎測資 12 題（.wy）
│   ├── 殿試/                    # 進階測資 2 題（.wy）
│   └── 對勘/                    # 對應的期望 token 輸出（.out）
├── test.sh / test.ps1           # 對勘式測試腳本
└── CMakeLists.txt
```

---

## 建置

需要 `cmake` 3.10 以上、`flex` 2.6 以上、支援 C99 的 `gcc`。

```bash
cmake -B build -S . -G Ninja
cmake --build build
```

第三方 `utf8.c` 為 submodule，clone 時請加 `--recursive`，或補跑 `git submodule update --init`。

---

## 使用

```bash
./build/lexer_test test/策問/04_九章_算術.wy
```

輸出格式為 `行:欄: TOKEN 值`，欄位是顯示字元位置：

```text
7:1: HERE_ARE 今有
7:3: NUMBER_LIT 1
7:4: VAR_TYPE 爻
7:6: SAID 曰
7:7: BOOL_LIT false
7:9: NAME_IT 名之曰
7:12: IDENT '陰陽'
```

---

## 測試

採對勘式測試：把 scanner 實際輸出與 `test/對勘/*.out` 逐字比對，14 題（策問 12 加殿試 2）全綠才算通過。

```bash
./test.sh          # Linux / WSL
.\test.ps1         # Windows PowerShell
```

常用選項：`-i` / `-Interactive` 進互動式 diff 逐題翻閱差異，`-s` / `-StopOnFirstError` 在第一個錯誤就停。

> PowerShell 若因執行原則擋下腳本，先跑一次
> `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`。
