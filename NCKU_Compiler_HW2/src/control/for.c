//
// Created by WavJaby on 2026/03/26.
//

#include "for.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "compiler_util.h"
#include "scope.h"

bool code_forLoop(Object* src) {
    if (src->type == OBJECT_TYPE_UNDEFINED)
        goto FAILED;

    compilerLog("> (for loop, count: %s)\n", object_print(src));

    const ObjectType srcType = object_getValueType(src);
    const ObjectType targetType = ObjectType_isInteger(srcType) || srcType == OBJECT_TYPE_NUM
                                      ? object_getPromotedType(srcType, OBJECT_TYPE_I32)
                                      : OBJECT_TYPE_I32;
    char countName[MAX_NAME_LENGTH];
    Object regCount = object_loadRegAndPromote(src, targetType, countName, MAX_NAME_LENGTH);
    if (regCount.type == OBJECT_TYPE_UNDEFINED) goto FAILED;

    ScopeData* scope = scope_pushType(SCOPE_FOR_LOOP);
    const SymbolData phiSym = object_createRegisterSymbol(targetType);
    scope->u.forLoop.symbol = phiSym;
    // borrow the sym name, don't free
    scope->u.forLoop.symbol.name = strdup(phiSym.name);
    symbol_freeReg(&phiSym);

    const int id = scope->id;
    const char* llvmType = objectType2llvmType[targetType];

    buffPrintln(&ctx->code, "");
    buffPrintln(&ctx->code, "br label %%loop%d.entry", id);
    buffPrintlnS(&ctx->code, "loop%d.entry:", id);
    buffPrintln(&ctx->code, "br label %%loop%d.header", id);
    buffPrintlnS(&ctx->code, "loop%d.header:", id);
    buffPrintln(&ctx->code, "%%loop%d.i = phi %s [ 0, %%loop%d.entry ], [ %%loop%d.i.next, %%loop%d.update ]",
                id, llvmType, id, id, id);
    buffPrintln(&ctx->code, "%%loop%d.cond = icmp slt %s %%loop%d.i, %s",
                id, llvmType, id, countName);
    buffPrintln(&ctx->code, "br i1 %%loop%d.cond, label %%loop%d.body, label %%loop%d.exit",
                id, id, id);
    buffPrintlnS(&ctx->code, "loop%d.body:", id);

    if (src->type == OBJECT_TYPE_SYMBOL) object_free(&regCount);
    object_free(src);
    return false;
FAILED:
    object_free(src);
    return true;
}

bool code_forLoopEnd(Object* obj) {
    const ScopeData* scope = scope_peek();
    const int id = scope->id;
    const char* llvmType = objectType2llvmType[scope->u.forLoop.symbol.type];

    buffPrintln(&ctx->code, "br label %%loop%d.update", id);
    buffPrintlnS(&ctx->code, "loop%d.update:", id);
    buffPrintln(&ctx->code, "%%loop%d.i.next = add nsw %s %%loop%d.i, 1",
                id, llvmType, id);
    buffPrintln(&ctx->code, "br label %%loop%d.header", id);
    buffPrintlnS(&ctx->code, "loop%d.exit:", id);
    buffPrintln(&ctx->code, "");

    free(scope->u.forLoop.symbol.name);
    scope_dump();
    compilerLog("< (for loop end)\n");
    (void)obj;
    return false;
}
