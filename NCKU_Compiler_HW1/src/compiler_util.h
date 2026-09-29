#ifndef COMPILER_UTIL_H
#define COMPILER_UTIL_H

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

// Internal variable
extern int yylineno;
extern int yyleng;
extern FILE* yyout;
extern FILE* yyin;
extern int yylex();
extern int yylex_destroy();

#endif
