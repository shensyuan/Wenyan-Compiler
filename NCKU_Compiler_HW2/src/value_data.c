//
// Created by WavJaby on 2026/3/2.
//

#include "value_data.h"

#include <string.h>

#include "compiler_util.h"

// linkedList_init / linkedList_addp / linkedList_deleteNode / linkedList_freeA / cloneStruct 用法：見 README.md §工具函式速查
bool object_ValueDataListCreate(ObjectType valueType, const ScientificNotation* count, ValueData* valueData) {
    linkedList_init(&valueData->valueList);
    valueData->valueType = valueType;
    valueData->count = (count != NULL) ? sciToInt32(count) : 1;
    if (valueData->count <= 0) {
        yyerrorf("欲立變數之數不可為負或零\n");
        linkedList_free(&valueData->valueList);
        return true;
    }
    return false;
}

bool object_ValueDataListAdd(ValueData* valueData, const Object* obj, const YYLTYPE* tokenLoc) {
    Object* clone = cloneStruct(Object, obj);

    ObjectType objValueType = object_getValueType(obj);

    if (valueData->valueType == OBJECT_TYPE_AUTO) {
        if (objValueType == OBJECT_TYPE_NUM)
            valueData->valueType = OBJECT_TYPE_I32;
        else
            valueData->valueType = objValueType;
    }

    if ((int32_t)valueData->valueList.length >= valueData->count) {
        yyerrorf("所立之數超乎定額\n");
        free(clone);
        return true;
    }

    if (obj->type == OBJECT_TYPE_STR && obj->value.str)
        clone->value.str = strdup(obj->value.str);
    else if (obj->type == OBJECT_TYPE_I32 || obj->type == OBJECT_TYPE_I64 || obj->type == OBJECT_TYPE_F64)
        clone->value.number = cloneStruct(ScientificNotation, obj->value.number);
    else if (obj->type == OBJECT_TYPE_REGISTER) {
        clone->value.symbol = cloneStruct(SymbolData, obj->value.symbol);
        clone->value.symbol->name = strdup(obj->value.symbol->name);
    }
    linkedList_addp(&valueData->valueList, 0, clone);
    return false;
}

bool object_ValueDataListAddDefaults(ValueData* valueData, const YYLTYPE* tokenLoc) {
    const int32_t currentCount = (int32_t)valueData->valueList.length;
    for (int32_t i = currentCount; i < valueData->count; i++) {
        Object defaultObj = {.type = OBJECT_TYPE_UNDEFINED};
        switch (valueData->valueType) {
        case OBJECT_TYPE_NUM:
        case OBJECT_TYPE_I32: {
            ScientificNotation zero = {.type = I32, .fraction = 0, .fractionLen = 1, .exp = 0};
            defaultObj = object_createNumber(&zero);
            break;
        }
        case OBJECT_TYPE_I64: {
            ScientificNotation zero = {.type = I64, .fraction = 0, .fractionLen = 1, .exp = 0};
            defaultObj = object_createNumber(&zero);
            break;
        }
        case OBJECT_TYPE_F64: {
            ScientificNotation zero = {.type = F64, .fraction = 0, .fractionLen = 1, .exp = 0};
            defaultObj = object_createNumber(&zero);
            break;
        }
        case OBJECT_TYPE_BOOL:
            defaultObj = object_createBool(false);
            break;
        case OBJECT_TYPE_STR:
            defaultObj = object_createStr(strdup(""));
            break;
        case OBJECT_TYPE_ARRAY:
            defaultObj = object_createArray();
            break;
        default:
        case OBJECT_TYPE_AUTO:
            break;
        }
        if (defaultObj.type != OBJECT_TYPE_UNDEFINED) {
            object_ValueDataListAdd(valueData, &defaultObj, tokenLoc);
            object_free(&defaultObj);
        }
    }
    return false;
}

Object* object_ValueDataListPop(ValueData* valueData) {
    if (valueData->valueList.length == 0)
        return NULL;
    LinkedListNode* node = valueData->valueList.head->next;
    Object* obj = node->value;
    linkedList_deleteNode(&valueData->valueList, node);
    return obj;
}

bool object_ValueDataListFree(ValueData* valueData) {
    linkedList_freeA(&valueData->valueList, free);
    return false;
}
