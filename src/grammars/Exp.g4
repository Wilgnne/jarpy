grammar Exp;

/*---------------- PARSER INTERNALS ----------------*/

@parser::header {
  import { exit } from 'process';

  var symbol_table = Array();
  var used_table = Array();
  let stack_curr = 0;
  let stack_max = stack_curr;

  let if_curr = 0;
  let while_curr = -1;

  function programHeader() {
    // console.log(".source Test.src");
    // console.log(".class  public Test");
    console.log(".super  java/lang/Object");
    console.log();
    console.log(".method public <init>()V");
    console.log("    aload_0");
    console.log("    invokenonvirtual java/lang/Object/<init>()V");
    console.log("    return");
    console.log(".end method");
    console.log();

  }

  function programFooter() {
    const [_, ...rest] = symbol_table
    const difference = rest.filter(x => !used_table.includes(x));
    if (difference.length !== 0) {
      console.error("Unused Variables:", difference)
      exit(2)
    }
  }

  function mainHeader() {
    console.log(".method public static main([Ljava/lang/String;)V");
    symbol_table.push('args')
  }

  function mainFooter() {
    console.log("    return");
    console.log();
    console.log(".limit stack", stack_max);
    console.log(".limit locals", symbol_table.length);
    console.log(".end method");

    console.log();
    console.log("; symbol_table: " + symbol_table);
  }

  function attribution(name) {
    let index = symbol_table.indexOf(name.text);
    index = index !== -1 ? index : symbol_table.length;
    symbol_table[index] = name.text;

    console.log("    istore", index);
    updateStack(-1);
  }

  function ifHeader() {
    const if_local = if_curr;
    console.log(`NOT_IF_${if_curr}`);
    if_curr += 1;
    return if_local;
  }

  function ifElseFooter(current, nextIsElse, ifEnd, main, prevIsElse) {
    if (ifEnd) {
      if (nextIsElse) {
        console.log(`    goto END_ELSE_${main}\n`);
      }
      if (!prevIsElse)
        console.log(`NOT_IF_${current}:`);
    }
    if (!nextIsElse)
      console.log(`END_ELSE_${current}:\n`);
  }

  function whileHeader() {
    while_curr += 1;
    const while_local = while_curr;
    console.log(`BEGIN_WHILE_${while_curr}:`);
    return while_local;
  }

  function whileFooter(while_local) {
    console.log(`    goto   BEGIN_WHILE_${while_local}`)
    console.log(`END_WHILE_${while_local}:`);
  }

  function whileFlowControl(while_local, tag) {
    console.log(`    goto ${tag}_WHILE_${while_local} ; ${tag === 'END' ? 'break' : 'continue'}`)
  }

  function comparasion(ExpParser, operator) {
    const if_decoder = {
      [ExpParser.EQ]: "ne",
      [ExpParser.NE]: "eq",
      [ExpParser.GT]: "le",
      [ExpParser.GE]: "lt",
      [ExpParser.LT]: "ge",
      [ExpParser.LE]: "gt",
    }
    const op = if_decoder[operator.type];
    process.stdout.write(`\n    if_icmp${op} `);
  }

  function expression(operator) {
    if (operator.type === ExpParser.PLUS) console.log("    iadd");
    if (operator.type === ExpParser.SUB)  console.log("    isub");
    updateStack(-1);
  }

  function term(operator) {
    if (operator.type === ExpParser.PLUS) console.log("    iadd");
    if (operator.type === ExpParser.TIMES) console.log("    imul");
    if (operator.type === ExpParser.DIV)   console.log("    idiv");
    if (operator.type === ExpParser.MOD)   console.log("    irem");
    updateStack(-1);
  }

  function number(value) {
    console.log("    ldc " + value);
    updateStack(1);
  }

  function name(value) {
    const index = symbol_table.indexOf(value);
      if (index === -1) {
        console.error("Undefined Variable:", value)
        exit(1)
      }
      used_table[index] = value;

      console.log("    iload", index);
      updateStack(1);
  }

  function readInt() {
    console.log("    invokestatic Runtime/readInt()I");
    updateStack(1);
  }

  function updateStack(sideEffect) {
    // console.log("; ", stack_curr, stack_max, sideEffect)

    stack_curr += sideEffect;
    if (stack_curr > stack_max) {
      stack_max = stack_curr
    }
  }

  function getPrint() {
    console.log("    getstatic java/lang/System/out Ljava/io/PrintStream;");
    updateStack(1);
  }

  function printInt() {
    console.log("    invokevirtual java/io/PrintStream/print(I)V");
    console.log()
    updateStack(-2);
  }

  function printStr() {
    console.log("    invokevirtual java/io/PrintStream/print(Ljava/lang/String;)V");
    console.log()
    updateStack(-2);
  }

  function println() {
    console.log("    invokevirtual java/io/PrintStream/println()V");
    console.log()
    updateStack(-1);
  }
}

@parser::members {
}

/*---------------- LEXER RULES ----------------*/
COMMENT: '#' ~('\n')* -> skip;
SPACE: (' ' | '\t' | '\r' | '\n')+ -> skip;

EQ: '==';
NE: '!=';
GT: '>';
GE: '>=';
LT: '<';
LE: '<=';

/* OPERATORS */
PLUS: '+';
SUB: '-';
TIMES: '*';
DIV: '/';
MOD: '%';
OP_PAR: '(';
CL_PAR: ')';
OP_CUR: '{';
CL_CUR: '}';
ATTRIB: '=';
COMMA: ',';

PRINT: 'print';
READ_INT: 'read_int';

IF: 'if';
ELSE: 'else';

WHILE: 'while';
BREAK: 'break';
CONTINUE: 'continue';

NUMBER: '0' ..'9'+;
NAME: 'a' ..'z'+;

/*---------------- PARSER RULES ----------------*/

program: { programHeader(); } main { programFooter(); };

main: { mainHeader(); } (statement)+ { mainFooter(); };

statement:
	st_print
	| st_attrib { console.log(); }
	| st_if
	| st_while
	| BREAK { whileFlowControl(while_curr, 'END'); }
	| CONTINUE { whileFlowControl(while_curr, 'BEGIN'); };

st_print:
	PRINT OP_PAR { getPrint(); } (
		expression { printInt(); getPrint(); } (
			COMMA {
        console.log('    ldc " "')
        updateStack(1)
        printStr();
        getPrint();
      } expression { printInt(); getPrint(); }
		)*
	)? CL_PAR { println(); };

st_attrib: NAME ATTRIB expression { attribution($NAME); };

st_if:
	IF comparasion {
    let current_if = ifHeader();
    const main_if = current_if;
    let prevIsElse;
  } OP_CUR (statement*) (
		CL_CUR { ifElseFooter(current_if, true, true, main_if) } ELSE IF comparasion {
      current_if = ifHeader();
		} OP_CUR (statement*)
	)* (
		CL_CUR { ifElseFooter(current_if, true, true, main_if); prevIsElse = true; } ELSE OP_CUR (
			statement*
		)
	)? CL_CUR { ifElseFooter(main_if, false, true, main_if, prevIsElse) };

st_while:
	WHILE { const while_local = whileHeader(); } comparasion {
    console.log(`END_WHILE_${while_local}\n`);
	} OP_CUR (statement)* CL_CUR { whileFooter(while_local); };

comparasion:
	expression (
		op = (EQ | NE | GT | GE | LT | LE) expression { comparasion(ExpParser, $op); }
	);

expression: term ( op = (PLUS | SUB) term { expression($op); })*;

term: factor ( op = (TIMES | DIV | MOD) factor { term($op); })*;

factor:
	NUMBER { number($NUMBER.text); }
	| OP_PAR expression CL_PAR
	| NAME { name($NAME.text); }
	| READ_INT OP_PAR CL_PAR { readInt(); };
