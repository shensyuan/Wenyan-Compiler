//
// Created by Wavjaby on 2026/3/27.
//

#include "while.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "../compiler_util.h"
#include "scope.h"

bool code_whileLoopStart() {
    compilerLog("> (while loop)\n");

    const ScopeData* scope = scope_pushType(SCOPE_WHILE_LOOP);

    buffPrintln(&ctx->code, "");
    buffPrintln(&ctx->code, "br label %%loop%d.body", scope->id);
    buffPrintlnS(&ctx->code, "loop%d.body:", scope->id);

    return false;
}

bool code_whileLoopEnd(Object* obj) {
    const ScopeData* scope = scope_peek();

    buffPrintln(&ctx->code, "br label %%loop%d.body", scope->id);
    buffPrintlnS(&ctx->code, "loop%d.exit:", scope->id);
    buffPrintln(&ctx->code, "");

    scope_dump();
    compilerLog("< (while loop end)\n");
    (void)obj;
    return false;
}

bool code_break(const YYLTYPE* tokenLoc) {
    const ScopeData* loopScope = scope_findNearestLoop();

    if (!loopScope || loopScope->id < 0) {
        yyerrorf("「乃止」不在迴圈之內\n");
        return true;
    }

    YYLTYPE _s = yylloc; yylloc = *tokenLoc;
    compilerLog("break (loop%d)\n", loopScope->id);
    yylloc = _s;
    buffPrintln(&ctx->code, "br label %%loop%d.exit", loopScope->id);
    return false;
}
