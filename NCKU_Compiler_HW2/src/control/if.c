//
// Created by Wavjaby on 2026/3/26.
//

#include "if.h"

#include <WJCL/string/wjcl_string.h>

#include "lib/code_gen.h"
#include "compiler_util.h"
#include "scope.h"

bool code_if(Object* src) {
    compilerLog("> (if)\n");

    char regName[MAX_NAME_LENGTH];
    Object regSrc = object_nameLiteralOrLoadReg(src, regName, MAX_NAME_LENGTH);
    if (regSrc.type == OBJECT_TYPE_UNDEFINED) goto FAILED;

    ScopeData* scope = scope_pushType(SCOPE_IF_STMT);
    scope->u.ifInfo = (IfInfo){.elseifCount = 0, .containsElse = false};

    buffPrintln(&ctx->code, "br i1 %s, label %%if%d.true, label %%if%d.false",
                regName, scope->id, scope->id);
    buffPrintlnS(&ctx->code, "if%d.true:", scope->id);

    if (src->type == OBJECT_TYPE_SYMBOL) object_free(&regSrc);
    object_free(src);
    return false;
FAILED:
    object_free(src);
    return true;
}

bool code_elseIfLabel() {
    ScopeData* scope = scope_peek();
    const int scopeId = scope->id;
    const int n = scope->u.ifInfo.elseifCount;

    buffPrintln(&ctx->code, "br label %%if%d.endif", scopeId);
    if (n == 0)
        buffPrintlnS(&ctx->code, "if%d.false:", scopeId);
    else
        buffPrintlnS(&ctx->code, "if%d.elseif%d.false:", scopeId, n - 1);

    return false;
}

bool code_elseIf(Object* src) {
    const ScopeData* oldScope = scope_peek();
    const int scopeId = oldScope->id;
    const int n = oldScope->u.ifInfo.elseifCount;
    scope_dump();
    compilerLog("> (else if)\n");

    ScopeData* scope = scope_pushId(SCOPE_IF_STMT, scopeId);
    scope->u.ifInfo = (IfInfo){.elseifCount = n + 1, .containsElse = false};

    char regName[MAX_NAME_LENGTH];
    Object regSrc = object_nameLiteralOrLoadReg(src, regName, MAX_NAME_LENGTH);
    if (regSrc.type == OBJECT_TYPE_UNDEFINED) goto FAILED;

    buffPrintln(&ctx->code, "br i1 %s, label %%if%d.elseif%d.true, label %%if%d.elseif%d.false",
                regName, scopeId, n, scopeId, n);
    buffPrintlnS(&ctx->code, "if%d.elseif%d.true:", scopeId, n);

    if (src->type == OBJECT_TYPE_SYMBOL) object_free(&regSrc);
    object_free(src);
    return false;
FAILED:
    object_free(src);
    return true;
}

bool code_else() {
    const ScopeData* scope = scope_peek();
    const int scopeId = scope->id;
    const int n = scope->u.ifInfo.elseifCount;

    scope_dump();
    compilerLog("> (else)\n");

    buffPrintln(&ctx->code, "br label %%if%d.endif", scopeId);
    if (n == 0)
        buffPrintlnS(&ctx->code, "if%d.false:", scopeId);
    else
        buffPrintlnS(&ctx->code, "if%d.elseif%d.false:", scopeId, n - 1);

    ScopeData* newScope = scope_pushId(SCOPE_IF_STMT, scopeId);
    newScope->u.ifInfo = (IfInfo){.elseifCount = n, .containsElse = true};
    return false;
}

bool code_ifEnd() {
    const ScopeData* scope = scope_peek();
    const int scopeId = scope->id;
    const int n = scope->u.ifInfo.elseifCount;
    const bool hasElse = scope->u.ifInfo.containsElse;
    scope_dump();

    if (hasElse) {
        buffPrintln(&ctx->code, "br label %%if%d.endif", scopeId);
        buffPrintlnS(&ctx->code, "if%d.endif:", scopeId);
    } else if (n > 0) {
        buffPrintln(&ctx->code, "br label %%if%d.endif", scopeId);
        buffPrintlnS(&ctx->code, "if%d.elseif%d.false:", scopeId, n - 1);
        buffPrintln(&ctx->code, "br label %%if%d.endif", scopeId);
        buffPrintlnS(&ctx->code, "if%d.endif:", scopeId);
    } else {
        buffPrintln(&ctx->code, "br label %%if%d.false", scopeId);
        buffPrintlnS(&ctx->code, "if%d.false:", scopeId);
    }

    compilerLog("< (if end)\n");
    return false;
}
