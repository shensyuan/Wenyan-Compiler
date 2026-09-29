/* Definition section */
%code requires {
    # define YYLTYPE_IS_DECLARED 1
    # define YYLTYPE_IS_TRIVIAL 1
}

%{
    #include "compiler_util.h"
    #include "main.h"
    #include "expression.h"
    #include "value_data.h"
    #include "scope.h"
    #include "control/for.h"
    #include "control/if.h"
    #include "control/while.h"
    #include "control/function.h"
    #include "lib/code_gen.h"
%}

%define parse.error custom
%locations

/* Variable or self-defined structure */
%union {
    ObjectType var_type;

    bool b_var;
    ScientificNotation n_var;
    char *s_var;

    Object obj_val;
    ValueData val_data;

    FuncCallInfo* func_call;

    bool exp_left;
    ExpOp exp_op;
}
/* Token declarations */
%token COMMENT
%token HERE_ARE HERE_IS_A SAID NAME_IT
%token PRINT TO_CALL
%token RETURN

%token PAST TOPIC SET IS_THUS ITS
%token IF ELSE ELSE_IF
%token FOR WHILE_TRUE TIMES BREAK END
%token CALL TAKE THOSE LENGTH INDEX PUSH
%token TO_PERFORM_FUNC REQUIRE_ARGS FUNC_BEGIN FUNC_END_FOR FUNC_END

%token <n_var> NUMBER_LIT
%token <b_var> BOOL_LIT
%token <var_type> VAR_TYPE VAR_TYPE_FUNC
%token <s_var> STR_LIT IDENT
%token <exp_op> EXP_MATH_OP EXP_MATH_MOD_OP EXP_LOGIC_OP EXP_BINARY_LOGIC_OP
%token <exp_left> EXP_PREPOSITION

%left INDEX LENGTH
%left EXP_BINARY_LOGIC_OP
%left EXP_LOGIC_OP
%left EXP_MATH_OP EXP_MATH_MOD_OP

/* Nonterminal with return type */
%type <val_data> CreateValueDataListStmt VariableDefineStmt ValDataTail
%type <obj_val> ValueStmt ExpressionStmt ExpressionChainStmt CondExprStmt

%nonassoc LOWER_THAN_EXPR
%nonassoc RETURN

%start Program
%%
/* ── Program ─────────────────────────────────── */

Program
    : GlobalScopeStmt
;

GlobalScopeStmt
    : BodyListStmt
;

BodyListStmt
    : BodyListStmt BodyStmt
    |
;

BodyStmt
    : COMMENT STR_LIT { free($<s_var>2); }
    | OperationStmt
    | ConditionStmt
    | FunctionStmt
;

/* ── Function ─────────────────────────────────── */

FunctionStmt
    : TO_PERFORM_FUNC REQUIRE_ARGS FunctionArgsStmt FUNC_BEGIN { func_defineBody(); } BodyListStmt FUNC_END_FOR IDENT FUNC_END {
        Object funcObj = scope_findSymbol($<s_var>8);
        if (funcObj.type == OBJECT_TYPE_UNDEFINED) YYABORT;
        if (func_defineBodyEnd(&funcObj, $<s_var>8)) YYABORT;
        free($<s_var>8);
    }
;

FunctionArgsStmt
    : FunctionArgListStmt
    |
;

FunctionArgListStmt
    : FunctionArgListStmt NUMBER_LIT VAR_TYPE SAID IDENT {
        func_defineAddParam($<var_type>3, $<s_var>5);
    }
    | NUMBER_LIT VAR_TYPE SAID IDENT {
        func_defineAddParam($<var_type>2, $<s_var>4);
    }
    | FunctionArgListStmt SAID IDENT {
        func_defineAddParam(OBJECT_TYPE_UNDEFINED, $<s_var>3);
    }
    | SAID IDENT {
        func_defineAddParam(OBJECT_TYPE_UNDEFINED, $<s_var>2);
    }
;

/* ── Condition （IF / FOR / WHILE / BREAK）───── */

ConditionStmt
    : IfStmt
    | WhileStmt
    | ForStmt
    | BREAK { if (code_break(&@1)) YYABORT; }
;

IfStmt
    : IF CondExprStmt TOPIC { if (code_if(&$<obj_val>2)) YYABORT; }
      BodyListStmt ElseIfListStmt ElseStmt
      END { if (code_ifEnd()) YYABORT; }
;

ElseIfListStmt
    :
    | ElseIfListStmt ElseIfClause
;

ElseIfClause
    : { if (code_elseIfLabel()) YYABORT; }
      ELSE_IF CondExprStmt TOPIC { if (code_elseIf(&$<obj_val>3)) YYABORT; }
      BodyListStmt
;

ElseStmt
    :
    | ELSE { code_else(); } BodyListStmt
;

WhileStmt
    : WHILE_TRUE { code_whileLoopStart(); } BodyListStmt END { code_whileLoopEnd(NULL); }
;

ForStmt
    : FOR ValueStmt TIMES { if (code_forLoop(&$<obj_val>2)) YYABORT; }
      BodyListStmt
      END { code_forLoopEnd(NULL); }
;

/* ── Operation ───────────────────────────────── */

OperationStmt
    /* 函式宣告：吾有一術。名之曰「牛頓求根法」。 */
    : HERE_IS_A VAR_TYPE_FUNC NAME_IT IDENT {
        static const ScientificNotation one = {.type = I32, .fraction = 1, .fractionLen = 0, .exp = 0};
        func_define(&one, $<s_var>4);
    }
    | HERE_ARE NUMBER_LIT VAR_TYPE_FUNC NAME_IT IDENT {
        func_define(&$<n_var>2, $<s_var>5);
    }

    /* 宣告 + 值 + 命名/印出 */
    | CreateValueDataListStmt LitOrVarList {
        $<val_data>$ = $<val_data>1;
    } ValDataTail

    /* 賦值：昔之「丙」者。今「大衍」是矣。 */
    | PAST ValueStmt TOPIC SET ValueStmt IS_THUS {
        if (code_assign(&$<obj_val>2, &$<obj_val>5)) YYABORT;
    }
    | PAST ValueStmt TOPIC SET ITS IS_THUS {
        YYLTYPE _s = yylloc; yylloc = @2;
        if (code_assign(&$<obj_val>2, &ctx->last_result)) YYABORT;
        yylloc = _s;
    }

    /* 運算式結果命名：加「甲」於「乙」。名之曰「和」。 */
    | ExpressionChainStmt NAME_IT IDENT {
        ObjectType objType = object_getValueType(&ctx->last_result);
        if (objType == OBJECT_TYPE_UNDEFINED) YYABORT;
        ValueData valData;
        object_ValueDataListCreate(objType, NULL, &valData);
        object_ValueDataListAdd(&valData, &ctx->last_result, &@1);
        code_createVariable(&valData, $<s_var>3);
        object_ValueDataListFree(&valData);
    }

    /* 運算式 */
    | ExpressionChainStmt

    /* 陣列 push：充「五音」以「「宮」」 */
    | PUSH ValueStmt { $<obj_val>$ = $<obj_val>2; } PushItemList

    /* 前綴呼叫：施「foo」於A於B */
    | CALL ValueStmt {
        $<func_call>$ = func_callInit(&$<obj_val>2);
        if (!$<func_call>$) YYABORT;
    } CallArgListStmt {
        ValueData ret = {0};
        func_call($<func_call>3, &$<obj_val>2, &ret, &@1);
        Object* result = object_ValueDataListPop(&ret);
        if (result) { ctx->last_result = *result; free(result); }
        object_ValueDataListFree(&ret);
    }

    /* 後綴呼叫：ValueStmt 以施「函式名」 */
    | ValueStmt TO_CALL ValueStmt {
        ValueData valData;
        linkedList_init(&valData.valueList);
        valData.valueType = OBJECT_TYPE_UNDEFINED;
        valData.count = 1;
        linkedList_addp(&valData.valueList, 0, cloneStruct(Object, &$<obj_val>1));
        if (func_takeAndCall(NULL, &$<obj_val>3, &valData, &@3)) YYABORT;
        Object* result = object_ValueDataListPop(&valData);
        if (result) { ctx->last_result = *result; free(result); }
        object_ValueDataListFree(&valData);
    }

    /* TAKE 呼叫 */
    | TAKE NUMBER_LIT TO_CALL ValueStmt {
        ValueData valData;
        linkedList_init(&valData.valueList);
        valData.valueType = OBJECT_TYPE_UNDEFINED;
        valData.count = sciToInt32(&$<n_var>2);
        for (int32_t _i = 0; _i < valData.count; _i++)
            linkedList_addp(&valData.valueList, 0, cloneStruct(Object, &ctx->last_result));
        if (func_takeAndCall(&$<n_var>2, &$<obj_val>4, &valData, &@4)) YYABORT;
        Object* result = object_ValueDataListPop(&valData);
        if (result) { ctx->last_result = *result; free(result); }
        object_ValueDataListFree(&valData);
    }

    /* RETURN：乃得 ValueStmt or 乃得 alone */
    | RETURN ValueStmt {
        if (code_return(&$<obj_val>2)) YYABORT;
    }
    | RETURN {
        YYLTYPE _ps = yylloc; yylloc = @1;
        if (code_return(&ctx->last_result)) YYABORT;
        yylloc = _ps;
    }

    /* 命名 last result：名之曰「股」（用在 TAKE 呼叫後） */
    | NAME_IT IDENT {
        ObjectType objType = object_getValueType(&ctx->last_result);
        if (objType == OBJECT_TYPE_UNDEFINED) YYABORT;
        ValueData valData;
        object_ValueDataListCreate(objType, NULL, &valData);
        object_ValueDataListAdd(&valData, &ctx->last_result, &@1);
        code_createVariable(&valData, $<s_var>2);
        object_ValueDataListFree(&valData);
    }

    /* PRINT：書之 (print last result) */
    | PRINT {
        ObjectType objType = object_getValueType(&ctx->last_result);
        if (objType == OBJECT_TYPE_UNDEFINED) YYABORT;
        ValueData valData;
        object_ValueDataListCreate(objType, NULL, &valData);
        object_ValueDataListAdd(&valData, &ctx->last_result, &@1);
        code_stdoutPrint(&valData, true);
        object_ValueDataListFree(&valData);
    }
;

/* 值收集列表：SAID 值 或 inline NUMBER/BOOL/STR 或 SAID 運算式 */
LitOrVarList
    : SAID ValueStmt {
        if (object_ValueDataListAdd(&$<val_data>0, &$<obj_val>2, &@2)) YYABORT;
        $<val_data>$ = $<val_data>0;
    }
    | SAID ExpressionChainStmt {
        if (object_ValueDataListAdd(&$<val_data>0, &$<obj_val>2, &@2)) YYABORT;
        $<val_data>$ = $<val_data>0;
    }
    | LitOrVarList SAID ValueStmt {
        if (object_ValueDataListAdd(&$<val_data>1, &$<obj_val>3, &@3)) YYABORT;
        $<val_data>$ = $<val_data>1;
    }
    | LitOrVarList SAID ExpressionChainStmt {
        if (object_ValueDataListAdd(&$<val_data>1, &$<obj_val>3, &@3)) YYABORT;
        $<val_data>$ = $<val_data>1;
    }
    | LitOrVarList TAKE NUMBER_LIT TO_CALL ValueStmt {
        if (func_takeAndCall(&$<n_var>3, &$<obj_val>5, &$<val_data>1, &@5)) YYABORT;
        if ($<val_data>1.valueList.length > 0)
            ctx->last_result = *(Object*)$<val_data>1.valueList.head->next->value;
        $<val_data>$ = $<val_data>1;
    }
    | ValueStmt {
        if (object_ValueDataListAdd(&$<val_data>0, &$<obj_val>1, &@1)) YYABORT;
        $<val_data>$ = $<val_data>0;
    }
    | {
        $<val_data>$ = $<val_data>0;
    }
;

ValDataTail
    : VariableDefineStmt
    | PRINT {
        object_ValueDataListAddDefaults(&$<val_data>0, &@1);
        code_stdoutPrint(&$<val_data>0, true);
        object_ValueDataListFree(&$<val_data>0);
    }
;

CreateValueDataListStmt
    : HERE_ARE NUMBER_LIT VAR_TYPE {
        if (object_ValueDataListCreate($<var_type>3, &$<n_var>2, &$<val_data>$)) YYABORT;
    }
    | HERE_IS_A VAR_TYPE {
        if (object_ValueDataListCreate($<var_type>2, NULL, &$<val_data>$)) YYABORT;
    }
;

VariableDefineStmt
    : NAME_IT IDENT {
        object_ValueDataListAddDefaults(&$<val_data>0, &@1);
        if (code_createVariable(&$<val_data>0, $<s_var>2)) YYABORT;
        $<val_data>$ = $<val_data>0;
    }
    | VariableDefineStmt SAID IDENT {
        if (code_createVariable(&$<val_data>1, $<s_var>3)) YYABORT;
        $<val_data>$ = $<val_data>1;
    }
    | {
        object_ValueDataListFree(&$<val_data>0);
    }
;

CallArgListStmt
    :
    | CallArgListStmt EXP_PREPOSITION ValueStmt {
        YYLTYPE _s = yylloc; yylloc = @3;
        if (func_callArgAdd($<func_call>0, &$<obj_val>3, &@3)) YYABORT;
        yylloc = _s;
    }
;

PushItemList
    : EXP_PREPOSITION ValueStmt {
        YYLTYPE _s = yylloc; yylloc = @2;
        if (code_arrayPush(&$<obj_val>0, &$<obj_val>2, &@2)) YYABORT;
        yylloc = _s;
    }
    | PushItemList EXP_PREPOSITION ValueStmt {
        YYLTYPE _s = yylloc; yylloc = @3;
        if (code_arrayPush(&$<obj_val>0, &$<obj_val>3, &@3)) YYABORT;
        yylloc = _s;
    }
;

/* ── Expressions ─────────────────────────────── */

ExpressionChainStmt
    : ExpressionStmt {
        $<obj_val>$ = $<obj_val>1;
        ctx->last_result = $<obj_val>$;
    }
    | ExpressionChainStmt ExpressionStmt {
        $<obj_val>$ = $<obj_val>2;
        ctx->last_result = $<obj_val>$;
    }
;

ExpressionStmt
    : EXP_MATH_OP ValueStmt EXP_PREPOSITION ValueStmt {
        $<obj_val>$ = code_expression($<exp_op>1, $<exp_left>3, &$<obj_val>4, &$<obj_val>2, &@4, &@2);
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
        ctx->last_result = $<obj_val>$;
    }
    | EXP_MATH_OP ValueStmt EXP_PREPOSITION ValueStmt EXP_MATH_MOD_OP {
        $<obj_val>$ = code_expressionMod(OP_DIV, $<exp_op>5, $<exp_left>3, &$<obj_val>4, &$<obj_val>2, &@4, &@2);
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
        ctx->last_result = $<obj_val>$;
    }
    | ValueStmt {
        $<obj_val>$ = $<obj_val>1;
    }
;

CondExprStmt
    : ValueStmt EXP_LOGIC_OP ValueStmt {
        $<obj_val>$ = code_expression($<exp_op>2, true, &$<obj_val>1, &$<obj_val>3, &@1, &@3);
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
    }
    | ValueStmt EXP_BINARY_LOGIC_OP ValueStmt {
        $<obj_val>$ = code_expression($<exp_op>2, true, &$<obj_val>1, &$<obj_val>3, &@1, &@3);
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
    }
    | THOSE ValueStmt ValueStmt EXP_BINARY_LOGIC_OP {
        $<obj_val>$ = code_expression($<exp_op>4, true, &$<obj_val>2, &$<obj_val>3, &@2, &@3);
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
    }
;

/* ── Values ──────────────────────────────────── */

ValueStmt
    : NUMBER_LIT {
        $<obj_val>$ = object_createNumber(&$<n_var>1);
    }
    | BOOL_LIT {
        $<obj_val>$ = object_createBool($<b_var>1);
    }
    | STR_LIT {
        $<obj_val>$ = object_createStr($<s_var>1);
    }
    | IDENT {
        $<obj_val>$ = scope_findSymbol($<s_var>1);
        free($<s_var>1);
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
    }
    | ITS {
        $<obj_val>$ = ctx->last_result;
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
    }
    | THOSE ValueStmt {
        $<obj_val>$ = $<obj_val>2;
    }
    | ValueStmt INDEX ValueStmt {
        $<obj_val>$ = object_getIndex(&$<obj_val>1, &$<obj_val>3, &@1, &@3);
        if ($<obj_val>$.type != OBJECT_TYPE_UNDEFINED) {
            yylloc = @3;
            compilerLog("index %s[%s] -> %s\n", object_print(&$<obj_val>1), object_print(&$<obj_val>3), object_print(&$<obj_val>$));
        }
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
    }
    | ValueStmt LENGTH {
        YYLTYPE _s = yylloc; yylloc = @2;
        $<obj_val>$ = code_getLength(&$<obj_val>1, &@1);
        yylloc = _s;
        if ($<obj_val>$.type == OBJECT_TYPE_UNDEFINED) YYABORT;
    }
;

%%

#include "compiler.h"
