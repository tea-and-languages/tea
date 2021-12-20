Lisp
====

Lisp is one of the oldest programming languages still being actively used today.
Lisp was developed in 1958 by John McCarthy, and first implemented by Steve Russell.

Today there is no single Lisp language, but rather an expansive family of languages and dialects.
The Lisp interpreter we present here is influenced heavily by the Scheme dialect.

Homoiconicity
-------------

Many of Lisp's most interesting properties stem from the way that the language is *homoiconic*.
In the most general terms, a programming language is homoiconic if programs written in the language can be represented directly using the primitive types of the language itself.

The above definition is unfortunately not very useful, because most popular languages have strings, and source code can be represented as strings, so it would seem that most langauges are trivially homoiconic.

Lisp is homoiconic in a much deeper way, and its homoiconicity is used to provide leverage so that a surprisingly simple implementation can still yield a powerful language.

During the following presentation we will strive to show how homoiconicity is used to build an interpreter that is more than the sum of its parts.


Values
------

The fundamental value types in Lisp serve a dual role, both as values to be manipulated by programs and also as the abstract syntax tree that represents programs themselves.

### Reading and Writing

In order to display the results of computation, we need a way to print out values.
The way we print values will, in general, depend on their type:

	<<subroutines>>+=
	void print(Value value)
	{
		<<print implementation>>
	}

	<<print implementation>>=
	switch(getType(value))
	{
		<<print cases>>
	}

We define a fallback case for `print` to handle any types that don't have a convenient textual representation.

	<<print cases>>
	default:
		printf("<unknown>");
		break;


In order to read in a program to execute it, we need a way to read values from an input stream:

	<<subroutines>>+=
	Value read(InputStream& stream)
	{
		skipSpace(stream);
		<<read cases>>
        <<handle unknown input for read>>
	}

    <<handle unknown input for read>>=
    error(getLoc(stream), "unexpected input");
    return makeNil();

Because of homoiconicity, these two functions give us multiple facilities.
The `print` function can be used to print the values manipulated by a program, but can also be used to print programs.
The `read` function can be used by the interpreter to read in source code, but can also be leveraged by the interpreted program to read data.

### Evaluating

Because values in Lisp are used to represent both data and code, the core of our interpreter is a function for evaluating an expression represented as a `Value`.
This function is traditionally called `eval`.

	<<subroutines>>+=
	Value eval(Value value, Value env)
	{
		<<eval implementation>>
	}

As with `print`, the way to evaluate an expression will depend on its type.

	<<eval implementation>>=
	switch(getType(value))
	{
		<<eval cases>>
	}

Many kinds of values evaluate to themselves.
For example, the value `5`, when interpeted as an expression, evaluates to the value `5`.
We capture this common case as the default behavior in `eval`.

	<<eval cases>>+=
	default:
		return value;

The Read-Eval-Print Loop
------------------------

A *real-eval-print loop* (REPL) is the core of an interactive interpeter.
Its job is to *read* input code (typically an expression) from the user, *evaluate* that code to perform side effects and optionally produce a value, and then *print* the result value.
As the name implies, these steps are performed in a loop to support an ongoing session with the user:

	<<read-eval-print loop>>=
	for(;;)
	{
		printf("> ");
		Value expr = read(gStandardInput);
		Value value = eval(expr, env);
		print(value);
		printf("\n");
	}



Types of Values
---------------

In this section we will define the main types of values supported by our interpeter.
Each concrete type of value needs to define a few things:

* A `Type` tag to identify the new type
* A subtype of `Object` to hold values of the type
* A "factory" routine for creating instances of the type
* A matching routine for recognizing instances of the type
* Support for `print`ing values of the type
* Support for `read`int values of the type
* Support for `eval`uating value of the type, if necessary

While that might look like a lot of steps, recall that because of homoiconicity each of these types serves double duty as a data type for programs to manipulate *and*  piece of syntax that can be used when writing programs.

### Integers

We recognize an integer when `read`ing input by looking for a digit:

	<<read cases>>+=
	if(isDigit(peekChar(stream)))
	{
		int val = 0;
		while(isDigit(peekChar(stream)))
		{
			val = val*10 + (readChar(stream) - '0');
		}
		return makeInt(val);
	}

### Booleans



We recognize an integer when `read`ing input by looking for a digit:

	<<read cases>>+=
    if(peekChar(stream) == '#')
	{
        readChar(stream);
        switch(readChar(stream))
        {
        case 't': return makeBool(true);
        case 'f': return makeBool(false);
        default:
            error(getLoc(stream), "unexpected character after '#'");
            return makeNil();
        }
	}


Lists
-----

The name "Lisp" derives from its role as a "list processor."
Linked lists are the primary structure used to store both code and data.

A list in Lisp is either the designated empty list, *nil*, or it is a *pair*.

### Nil, the Empty List

The emtpy list, nil, often serves the same role as a null pointer in other languages, being used to represent the absence of data.
In many Lisp dialects, nil is treated as false for the purposes of `if` and other conditionals, and may even be the de facto standard false value.


All empty lists are equivalent, so it would be wasteful to create multiple objects to represent nil.
We therefore define the `makeNil` factory function to return the same `static` variable on every invocation.


### Pairs

A non-empty list is represented as a pair, with a *head* that is the first element of the list, and a *tail* that is a list of those elements after the first.

    <<object header fields>>+=
    uint64_t type;

	<<extended type tags>>+=
	TYPE_PAIR,

	<<types>>+=
    TypeTag getType(Value value)
    {
        TypeTag tag = getTag(value);
        if(tag != TYPE_TAG_OBJECT)
            return tag;
        return TypeTag(getObject(value)->type);
    }
	struct PairObj
	{
        ObjHeader asObject;
		Value head;
		Value tail;
	};
	Value makePair(Value head, Value tail)
	{
		PairObj* pair = new PairObj();
		pair->asObject.type = TYPE_PAIR;
		pair->head = head;
		pair->tail = tail;
		return tagObject(&pair->asObject);
	}
    Value& head(Value value)
    {
        assert(getType(value) == TYPE_PAIR);
        return ((PairObj*) getObject(value))->head;
    }
    Value& tail(Value value)
    {
        assert(getType(value) == TYPE_PAIR);
        return ((PairObj*) getObject(value))->tail;
    }

For historical reasons, many Lisps refer to the head of a list as "car," the tail as "cdr," and the operation to make a pair as "cons."
In our implementation we favor directness over tradition.

Pairs are used not only to represent lists, but are also used to encode other data structures.
For example a dictionary can be encoded as a list of key-value pairs.
Such an "associative list" or *a-list* is a commonly-used structure in Lisp.

### Notation

The empty list, nil, is written `()`.

	<<print cases>>
	case TYPE_NIL:
		printf("()");
		break;

A pair of the values `a` and `b` can be written as `(a . b)`.
This notation is referred to as a *dotted pair*.

When the tail of a list is itself a list, a more compact notation is used.
For example, the value `(a . (b . c))` can instead be written `(a b . c)`.

A *proper* list is either nil or a pair where the tail is a proper list.
A proper list can be written leaving off the `.` and the final nil.
For example, the proper list `(a . (b . ()))` can be written `(a b)`.

When printing a pair, we want to use the most compact notation possible.

	<<print cases>>+=
	case TYPE_PAIR:
	{
		printf("(");
        print(head(value));
		Value rest = tail(value);
        while(getType(rest) == TYPE_PAIR)
		{
			printf(" ");
			print(head(rest));
            rest = tail(rest);
		}
        if(getType(rest) == TYPE_NIL)
		{
			printf(" . ");
			print(rest);
		}
		printf(")");
	}
	break;

### Reading Lists

Lists both empty and non-empty are enclosed in parentheses, so we check for an opening `(` to know when we are reading a list.

	<<read cases>>+=
	if(peekChar(stream) == '(')
	{
		readChar(stream);

		Value result;
		Value* link = &result;

		for(;;)
		{
			skipSpace(stream);
			if(peekChar(stream) == ')')
			{
				readChar(stream);
                break;
			}
            if(peekChar(stream) == EOF)
            {
                error(getLoc(stream), "unexpected end of file");
                break;
            }

			if(peekChar(stream) == '.')
			{
				readChar(stream);
				*link = read(stream);

				if(peekChar(stream) == ')')
				{
					readChar(stream);
				}
				return result;
			}

			Value value = read(stream);
			Value pair = makePair(value, makeNil());
			*link = pair;
			link = &tail(pair);
		}
		*link = makeNil();
		return result;
	}

Evaluating a List
-----------------

The empty list is an atom in Lisp, so it evaluates to itself.
Because the `default` path in `eval` already handles self-evaluating expressions, there is nothing that we need to write for `()`.

    > ()
    ()

When a non-empty list like `(f a0 a1 a2)` is evauated as an expression it usually represents the application of the functon to arguments (e.g., applying `f` to the arguments `a0`, `a1, and `a2`).
There are some special cases we will deal with shortly, but for now let's handle the common case.

	<<eval cases>>+=
	case TYPE_PAIR:
	{
        Value funcExpr = head(value);
        Value argExprs = tail(value);
        Value func = eval(funcExpr, env);

        switch(getType(func))
        {
        default:
            return apply(func, evalList(argExprs, env));

        <<other pair eval cases>>
        }
	}
	break;

    <<subroutines>>+=
    Value evalList(Value list, Value env)
    {
        Value result;
        Value* link = &result;

        Value rest = list;
        while(getType(rest) == TYPE_PAIR)
        {
            Value argExpr = head(rest);
            Value arg = eval(argExpr, env);

            Value argPair = makePair(arg, makeNil());
            *link = argPair;
            link = &tail(argPair);

            rest = tail(rest);
        }
        *link = eval(rest, env);
        return result;
    }

    <<subroutines>>+=
    Value apply(Value func, Value args)
    {
        switch(getType(func))
        {
        <<apply cases>>
        }
    }

    <<apply cases>>+=
    default:
        fprintf(stderr, "couldn't apply value of this type");
        return makeNil();

Primitive Functions
------------------

	<<extended type tags>>+=
    TYPE_PRIMITIVE_FUNC,

    <<types>>+=
    typedef Value (*PrimitiveFunc)(Value args);
    struct PrimitiveFuncObj
    {
        Object asObject;
        PrimitiveFunc value;
    };

	<<types>>+=
    Value makePrimitiveFunc(PrimitiveFunc value)
	{
		PrimitiveFuncObj* result = new PrimitiveFuncObj();
		result->asObject.type = TYPE_PRIMITIVE_FUNC;
		result->value = value;
        return tagObject(&result->asObject);
	}
    PrimitiveFunc getPrimitiveFunc(Value value)
	{
        assert(getType(value) == TYPE_PRIMITIVE_FUNC);
        return ((PrimitiveFuncObj*) getObject(value))->value;
	}

    <<subroutines>>+=
    Value readHead(Value* ioList)
    {
        Value list = *ioList;
        if(getType(list) == TYPE_PAIR)
        {
           *ioList = tail(list);
           return head(list);
        }
        else
        {
            fprintf(stderr, "error: expected a pair");
            return makeNil();
        }
    }

    <<subroutines>>+=
    #define PRIMITIVE_INT_OP(NAME, OP)              \
        Value primitive_##NAME(Value args)          \
        {                                           \
            IntVal left = getIntVal(readHead(&args));   \
            IntVal right = getIntVal(readHead(&args));  \
            return makeInt(left OP right);          \
        }

    PRIMITIVE_INT_OP(add, +)
    PRIMITIVE_INT_OP(sub, -)
    PRIMITIVE_INT_OP(mul, *)
    PRIMITIVE_INT_OP(div, /)

    #define PRIMITIVE_INT_CMP_OP(NAME, OP)              \
        Value primitive_##NAME(Value args)          \
        {                                           \
            IntVal left = getIntVal(readHead(&args));   \
            IntVal right = getIntVal(readHead(&args));  \
            return makeBool(left OP right);          \
        }

    PRIMITIVE_INT_CMP_OP(cmp_gt, >)

    <<apply cases>>+=
    case TYPE_PRIMITIVE_FUNC:
        return getPrimitiveFunc(func)(args);


Primitive Syntax
----------------

	<<extended type tags>>+=
    TYPE_PRIMITIVE_SYNTAX,

    <<types>>+=
    typedef Value (*PrimitiveSyntax)(Value body, Value env);
    struct PrimitiveSyntaxObj : Object
    {
        PrimitiveSyntax value;
    };

	<<types>>+=
    Value makePrimitiveSyntax(PrimitiveSyntax value)
	{
		PrimitiveSyntaxObj* result = new PrimitiveSyntaxObj();
		result->type = TYPE_PRIMITIVE_SYNTAX;
		result->value = value;
		return tagObject(result);
	}
    PrimitiveSyntax getPrimitiveSyntax(Value value)
	{
        assert(getType(value) == TYPE_PRIMITIVE_SYNTAX);
        return ((PrimitiveSyntaxObj*) getObject(value))->value;
	}

    <<subroutines>>+=
    Value builtin_if(Value syntax, Value env)
    {
        Value conditionExpr = readHead(&syntax);
        Value condition = eval(conditionExpr, env);

        Value thenExpr = readHead(&syntax);

        Value elseExpr = getType(syntax) == TYPE_NIL ? makeNil() : readHead(&syntax);

        if(getType(condition) != TYPE_BOOL)
        {
            return makeNil();
        }

        if(getBoolVal(condition))
        {
            return eval(thenExpr, env);
        }
        return eval(elseExpr, env);
    }

    <<other pair eval cases>>+=
    case TYPE_PRIMITIVE_SYNTAX:
        return getPrimitiveSyntax(func)(argExprs, env);


User-Defined Functions
----------------------

	<<extended type tags>>+=
	TYPE_USER_FUNC,

    <<types>>+=
    struct UserFuncObj : Object
    {
        Value params;
        Value body;
        Value env;
    };

	<<types>>+=
    Value makeUserFunc(Value params, Value body, Value env)
	{
		UserFuncObj* result = new UserFuncObj();
		result->type = TYPE_USER_FUNC;
        result->params = params;
        result->body = body;
        result->env = env;
        return tagObject(result);
	}
    UserFuncObj* getUserFunc(Value value)
	{
        assert(getType(value) == TYPE_USER_FUNC);
        return (UserFuncObj*) getObject(value);
	}

    <<subroutines>>+=
    Value evalBody(Value body, Value env)
    {
        Value result = makeNil();

        while(getType(body) == TYPE_PAIR)
        {
            result = eval(head(body), env);
            body = tail(body);
        }

        return result;
    }

    <<apply cases>>+=
    case TYPE_USER_FUNC:
    {
        UserFuncObj* userFunc = getUserFunc(func);

        // bind params to args
        Value paramEnv = makePair(makeNil(), userFunc->env);

        Value params = userFunc->params;
        while(getType(params) == TYPE_PAIR)
        {
            Value param = head(params);
            params = tail(params);

            Value arg = head(args);
            args = tail(args);

            define(paramEnv, param, arg);
        }

		// handle the "rest" argument, if any
		if(getType(params) != TYPE_NIL)
		{
			define(paramEnv, params, args);
		}
        //

        return evalBody(userFunc->body, paramEnv);
    }

    <<subroutines>>+=
    Value primitive_lambda(Value syntax, Value env)
    {
        Value params = readHead(&syntax);
        Value body = syntax;

        return makeUserFunc(params, body, env);
    }










    

Symbols
-------

	<<extended type tags>>+=
	TYPE_SYMBOL,

	<<types>>+=
	struct SymbolObj
	{
        Object asObject;
		char const* value;
		<<additional symbol members>>
	};

	<<types>>+=
	Value makeSymbol(char const* value)
	{
		<<try to find existing symbol>>

		SymbolObj* result = new SymbolObj();
		result->asObject.type = TYPE_SYMBOL;
		result->value = _strdup(value);
		<<add new symbol>>
		return tagObject(&result->asObject);
	}

	<<additional symbol members>>=
	SymbolObj* next;

	<<try to find existing symbol>>=
	static SymbolObj* gSymbols = NULL;
	for(SymbolObj* sym = gSymbols; sym; sym = sym->next)
	{
		if(strcmp(sym->value, value) == 0)
			return tagObject(&sym->asObject);
	}

	<<add new symbol>>=
	result->next = gSymbols;
	gSymbols = result;


	<<types>>+=
	const char* getSymbolVal(Value value)
	{
        assert(getType(value) == TYPE_SYMBOL);
        return ((SymbolObj*) getObject(value))->value;
	}

	<<print cases>>+=
	case TYPE_SYMBOL:
		printf("%s", getSymbolVal(value));
		break;

	<<read cases>>+=
	if(isSymbolChar(peekChar(stream)))
	{
		char buffer[1024];
		char* cursor = buffer;
		while(isSymbolChar(peekChar(stream)) || isDigit(peekChar(stream)))
		{
			*cursor++ = readChar(stream);
		}
		*cursor++ = 0;
		return makeSymbol(buffer);
	}

    <<subroutines>>+=
    bool isSymbolChar(int c)
    {
        return isalpha(c) || strchr("!@#$%^&*:;\\|-_+=/?<>,.", c);
    }

    <<subroutine declarations>>+=
    bool isSymbolChar(int c);


Symbols are our first case of a value that does *not* evaluate to itself.

	<<eval cases>>+=
	case TYPE_SYMBOL:
	{
		Value scope = env;
        while(getType(scope) == TYPE_PAIR)
		{
			Value bindingList = head(scope);
			while(getType(bindingList) == TYPE_PAIR)
			{
				Value binding = head(bindingList);
                if(head(binding).bits == value.bits)
                    return tail(binding);

				bindingList = tail(bindingList);
			}

			scope = tail(scope);
		}

		fprintf(stderr, "error: undefined identifier '%s'\n", getSymbolVal(value));
		return makeNil();
	}
	break;


Macros
------

	<<extended type tags>>+=
    TYPE_MACRO,

    <<types>>+=
    struct MacroObj : Object
    {
        Value transformer;
    };

	<<types>>+=
    Value makeMacro(Value transformer)
	{
		MacroObj* result = new MacroObj();
		result->type = TYPE_MACRO;
		result->transformer = transformer;
        return tagObject(result);
	}
    Value getMacroTransformer(Value value)
	{
        assert(getType(value) == TYPE_MACRO);
        return ((MacroObj*) getObject(value))->transformer;
	}

    <<other pair eval cases>>+=
    case TYPE_MACRO:
        return eval(apply(getMacroTransformer(func), argExprs), env);

	<<subroutines>>+=
	Value primitive_macro(Value args)
	{
		Value transformer = readHead(&args);
		return makeMacro(transformer);
	}

Quotation
---------

	<<subroutines>>+=
	Value primitive_quote(Value body, Value env)
	{
		Value arg = readHead(&body);
		return arg;
	}

	<<read cases>>+=
	if(peekChar(stream) == '\'')
	{
		readChar(stream);
		Value arg = read(stream);
		return makePair(
			makeSymbol("quote"),
			makePair(arg, makeNil()));
	}


Homoiconicity
-------------

	<<subroutines>>+=
	void define(Value env, Value key, Value val)
	{
		Value binding = makePair(key,val);
        head(env) = makePair(binding, head(env));
	}
	Value primitive_define(Value body, Value env)
	{
		Value name = readHead(&body);
		Value value = eval(readHead(&body), env);

		define(env, name, value);

		return value;
	}
	Value primitive_exit(Value args)
	{
		exit(0);
	}
	Value primitive_pair(Value args)
	{
		Value head = readHead(&args);
		Value tail = readHead(&args);
		return makePair(head, tail);
	}
	Value primitive_isPair(Value args)
	{
		Value arg = readHead(&args);
        return makeBool(getType(arg) == TYPE_PAIR);
	}
	Value primitive_head(Value args)
	{
		Value pair = readHead(&args);
        return head(pair);
	}
	Value primitive_tail(Value args)
	{
		Value pair = readHead(&args);
        return tail(pair);
	}

    <<program initialization>>=
	Value env = makePair(makeNil(), makeNil());

    <<register language primitives>>+=
    define(env, makeSymbol("if"), makePrimitiveSyntax(&builtin_if));
    define(env, makeSymbol("lambda"), makePrimitiveSyntax(&primitive_lambda));
    define(env, makeSymbol("define"), makePrimitiveSyntax(&primitive_define));
    define(env, makeSymbol("quote"), makePrimitiveSyntax(&primitive_quote));

    define(env, makeSymbol("+"), makePrimitiveFunc(&primitive_add));
    define(env, makeSymbol("-"), makePrimitiveFunc(&primitive_sub));
    define(env, makeSymbol("*"), makePrimitiveFunc(&primitive_mul));
    define(env, makeSymbol("/"), makePrimitiveFunc(&primitive_div));

    define(env, makeSymbol(">"), makePrimitiveFunc(&primitive_cmp_gt));

    define(env, makeSymbol("macro"), makePrimitiveFunc(&primitive_macro));
    define(env, makeSymbol("exit"), makePrimitiveFunc(&primitive_exit));
    define(env, makeSymbol("pair"), makePrimitiveFunc(&primitive_pair));
    define(env, makeSymbol("pair?"), makePrimitiveFunc(&primitive_isPair));
    define(env, makeSymbol("head"), makePrimitiveFunc(&primitive_head));
    define(env, makeSymbol("tail"), makePrimitiveFunc(&primitive_tail));

    <<run interactive interpreter>>=
	<<read-eval-print loop>>

Prelude
-------

    <<prelude definition>>+=
    const char kPrelude[] = R"(
    <<prelude>>
    )";

    <<raw:prelude>>+=
    (define a 123)
    (define list (lambda args args))

    (define def2-proc-inner (lambda (signature body)
        (if (pair? signature)
            (pair 'define
                (pair (head signature) 
                    (pair 'lambda
                        (pair (tail signature)
                            body
                        )
                    )
                )
            )
    		(pair 'define (pair signature body))
        )
    ))
    (define def2-proc (lambda (syntax)
        (def2-proc (head syntax) (tail syntax))
    ))
	(define def2 (macro def2-proc))

    <<read in the prelude>>=
    // need to do this bit
	InputStream preludeStream;
	preludeStream.cursor = kPrelude;
	preludeStream.end = kPrelude + sizeof(kPrelude)-1;

	load(preludeStream, env);

	<<subroutines>>+=
	void load(InputStream& stream, Value env)
	{
		for(;;)
		{
			skipSpace(stream);
			if(isAtEnd(stream))
				break;

			Value expr = read(stream);
			eval(expr, env);
		}
	}

Outline of the Interpreter
------------------------------------

    <<subroutine declarations>>+=
    Value evalList(Value list, Value env);
    Value apply(Value func, Value args);
	void define(Value env, Value key, Value val);
    Value evalBody(Value body, Value env);

    //<<file:lisp.cpp>>=
    <<interpreter program>>

    //<<utility code>>+=
    <<value declarations>>
