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

In order to read in a program to execute it, we need a way to read values from an input stream:

	<<definitions>>+=
	Value read(InputStream& stream)
	{
		skipSpace(stream);
		<<read cases>>
        <<handle unknown input for read>>
	}

    <<handle unknown input for read>>=
    error(getLoc(stream), "unexpected input");
    return Value::getNil();

Because of homoiconicity, these two functions give us multiple facilities.
The `print` function can be used to print the values manipulated by a program, but can also be used to print programs.
The `read` function can be used by the interpreter to read in source code, but can also be leveraged by the interpreted program to read data.

### Evaluating

Because values in Lisp are used to represent both data and code, the core of our interpreter is a function for evaluating an expression represented as a `Value`.
This function is traditionally called `eval`.

    <<value declarations>>+=
	Value eval(Value value, Value env);

	<<definitions>>+=
	Value eval(Value value, Value env)
	{
		<<eval implementation>>
	}

As with `print`, the way to evaluate an expression will depend on its type.

	<<eval implementation>>=
	switch(value.getTag())
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

    <<constants>>+=
    #define GET_OBJECT_TYPE(NAME) Value::Tag::NAME

    <<object type representation>>=
    typedef Value::Tag ObjectType;

    <<definitions>>+=
    Value::Tag Value::getObjectTag(Object* object)
    {
        return object->type;
    }

### Integers

We recognize an integer when `read`ing input by looking for a digit:

	<<read cases>>+=
	if(isDigit(peekChar(stream)))
	{
		IntVal val = 0;
		while(isDigit(peekChar(stream)))
		{
			val = val*10 + (readChar(stream) - '0');
		}
		return val;
	}

### Booleans



We recognize an integer when `read`ing input by looking for a digit:

	<<read cases>>+=
    if(peekChar(stream) == '#')
	{
        readChar(stream);
        switch(readChar(stream))
        {
        case 't': return true;
        case 'f': return false;
        default:
            error(getLoc(stream), "unexpected character after '#'");
            return Value::getNil();
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
We therefore define the `Value::getNil` factory function to return the same `static` variable on every invocation.


### Pairs

A non-empty list is represented as a pair, with a *head* that is the first element of the list, and a *tail* that is a list of those elements after the first.

    <<object cases>>+=
    OBJECT_CASE(Pair)

    <<value declarations>>+=
	struct Pair : Object
	{
        Pair(Value head, Value tail);

		Value head;
		Value tail;
	};

	<<definitions>>+=
	Pair::Pair(Value h, Value t)
        : Object(GET_OBJECT_TYPE(Pair))
	{
        this->head = h;
        this->tail = t;
	}

For historical reasons, many Lisps refer to the head of a list as "car," the tail as "cdr," and the operation to make a pair as "cons."
In our implementation we favor directness over tradition.

Pairs are used not only to represent lists, but are also used to encode other data structures.
For example a dictionary can be encoded as a list of key-value pairs.
Such an "associative list" or *a-list* is a commonly-used structure in Lisp.

### Notation

The empty list, nil, is written `()`.

	<<print cases>>
	case Value::Tag::Nil:
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
	case Value::Tag::Pair:
	{
        Pair* pair = value.asPair();

		printf("(");
        print(pair->head);
		Value rest = pair->tail;
        while(auto restPair = rest.asPair())
		{
			printf(" ");
			print(restPair->head);
            rest = restPair->tail;
		}
        if(!rest.isNil())
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
			Pair* pair = new Pair(value, Value::getNil());
			*link = pair;
			link = &pair->tail;
		}
		*link = Value::getNil();
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
	case Value::Tag::Pair:
	{
        auto pair = value.getPair();
        Value funcExpr = pair->head;
        Value argExprs = pair->tail;
        Value func = eval(funcExpr, env);

        switch(func.getTag())
        {
        default:
            return apply(func, evalList(argExprs, env));

        <<other pair eval cases>>
        }
	}
	break;

    <<definitions>>+=
    Value evalList(Value list, Value env)
    {
        Value result;
        Value* link = &result;

        Value rest = list;
        while(Pair* restPair = rest.asPair())
        {
            Value argExpr = restPair->head;
            Value arg = eval(argExpr, env);

            Pair* argPair = new Pair(arg, Value::getNil());
            *link = argPair;
            link = &argPair->tail;

            rest = restPair->tail;
        }
        *link = eval(rest, env);
        return result;
    }

    <<definitions>>+=
    Value apply(Value func, Value args)
    {
        switch(func.getTag())
        {
        <<apply cases>>
        }
    }

    <<apply cases>>+=
    default:
        fprintf(stderr, "couldn't apply value of this type");
        return Value::getNil();

Primitive Functions
------------------

    <<object cases>>+=
    OBJECT_CASE(PrimitiveFuncObj)

    <<value declarations>>+=
    struct PrimitiveFuncObj : Object
    {
        PrimitiveFuncObj(PrimitiveFunc value);

        PrimitiveFunc value;
    };

	<<definitions>>+=
    PrimitiveFuncObj::PrimitiveFuncObj(PrimitiveFunc value)
        : Object(GET_OBJECT_TYPE(PrimitiveFuncObj))
    {
        this->value = value;
    }

    <<forward type declarations>>+=
    #define OBJECT_CASE(NAME) struct NAME;
    <<object cases>>
    #undef OBJECT_CASE


    <<value members>>+=
    #define OBJECT_CASE(NAME) \
        NAME* as##NAME() const { return (NAME*) asObject(Value::Tag::NAME); }   \
        NAME* get##NAME() const { /* TODO: assert */ return (NAME*) asObject(Value::Tag::NAME); }   \
        /*end*/
    <<object cases>>
    #undef OBJECT_CASE

    <<primitive func context members>>+=
    #if 0
    Value readHead(Value* ioList);
    #endif

    <<definitions>>+=
    Value PrimitiveFuncContext::readArg()
    {
        if(Pair* argsPair = args.asPair())
        {
            Value result = argsPair->head;
            args = argsPair->tail;
            return result;
        }
        else
        {
            fprintf(stderr, "error: expected a pair");
            return Value::getNil();
        }
    }

    <<apply cases>>+=
    case Value::Tag::PrimitiveFuncObj:
    {
        auto primitiveFuncObj = func.getPrimitiveFuncObj();
        auto primitive = primitiveFuncObj->value;

        PrimitiveFuncContext context;
        context.args = args;

        Value result = (context.*primitive)();
        return result;
    }

    <<primitive func context members>>+=
    Value args;


Primitive Syntax
----------------

    <<object cases>>+=
    OBJECT_CASE(PrimitiveSyntaxObj)

    <<value declarations>>+=
    typedef PrimitiveFunc PrimitiveSyntax;
    struct PrimitiveSyntaxObj : Object
    {
        PrimitiveSyntaxObj(PrimitiveSyntax value);

        PrimitiveSyntax value;
    };

	<<definitions>>+=
    PrimitiveSyntaxObj::PrimitiveSyntaxObj(PrimitiveSyntax value)
        : Object(GET_OBJECT_TYPE(PrimitiveSyntaxObj))
	{
        this->value = value;
    }

    <<primitive func declarations>>+=
    PRIMITIVE_FUNC_DECL(if);

    <<primitive func definitions>>+=
    PRIMITIVE_FUNC_DEF(if)
    {
        Value conditionExpr = readArg();
        Value condition = eval(conditionExpr, env);

        Value thenExpr = readArg();

        Value elseExpr = areAnyArgsLeft() ? readArg() : Value::getNil();

        BoolValue* conditionBool = condition.asBool();
        if(conditionBool)
        {
            return Value::getNil();
        }

        if(*conditionBool)
        {
            return eval(thenExpr, env);
        }
        return eval(elseExpr, env);
    }

    <<other pair eval cases>>+=
    case Value::Tag::PrimitiveSyntaxObj:
    {
        auto primitiveSyntaxObj = func.asPrimitiveSyntaxObj();

        PrimitiveFuncContext context;
        context.args = argExprs;
        context.env = env;

        auto prim = primitiveSyntaxObj->value;
        Value result = (context.*prim)();
        return result;
    }

    <<primitive func context members>>+=
    Value env;

    bool areAnyArgsLeft() const { return !args.isNil(); }



User-Defined Functions
----------------------

    <<object cases>>+=
    OBJECT_CASE(UserFunc)

    <<forward type declarations>>+=
    struct UserFuncObj;

    <<value declarations>>+=
    struct UserFuncObj
    {
        UserFuncObj(Value params, Value body, Value env);

        Value params;
        Value body;
        Value env;
    };

    <<value members>>+=
    UserFuncObj* asUserFunc();

	<<definitions>>+=
    UserFuncObj::UserFuncObj(Value params, Value body, Value env)
	{
        this->params = params;
        this->body = body;
        this->env = env;
	}
    UserFuncObj* Value::asUserFunc()
	{
        return (UserFuncObj*) asObject(Value::Tag::UserFunc);
	}

    <<definitions>>+=
    Value evalBody(Value body, Value env)
    {
        Value result = Value::getNil();

        while(Pair* bodyPair = body.asPair())
        {
            result = eval(bodyPair->head, env);
            body = bodyPair->tail;
        }

        return result;
    }

    <<apply cases>>+=
    case Value::Tag::UserFunc:
    {
        UserFuncObj* userFunc = func.asUserFunc();

        // bind params to args
        Pair* paramEnv = new Pair(Value::getNil(), userFunc->env);

        Value params = userFunc->params;
        while(Pair* paramsPair = params.asPair())
        {
            Value param = paramsPair->head;
            params = paramsPair->tail;

            Pair* argsPair = args.getPair();
            Value arg = argsPair->head;
            args = argsPair->tail;

            define(paramEnv, param, arg);
        }

		// handle the "rest" argument, if any
		if(!params.isNil())
		{
			define(paramEnv, params, args);
		}
        //

        return evalBody(userFunc->body, paramEnv);
    }

    <<primitive func declarations>>+=
    PRIMITIVE_FUNC_DECL(lambda);

    <<primitive func definitions>>+=
    PRIMITIVE_FUNC_DEF(lambda)
    {
        Value params = readArg();
        Value body = readRestArg();

        return new UserFuncObj(params, body, env);
    }

    <<primitive func context members>>+=
    Value readRestArg()
    {
        Value result = args;
        args = Value::getNil();
        return result;
    }

    

Symbols
-------

	<<print cases>>+=
	case Value::Tag::Symbol:
        {
            auto symbol = value.asSymbol();
            auto text = symbol->text;
            printf("%.*s", (int)text.getSize(), text.begin());
        }
		break;

	<<read cases>>+=
	if(isSymbolChar(peekChar(stream)))
	{
        static StringBuffer buffer;
        buffer.reset();

		while(isSymbolChar(peekChar(stream)) || isDigit(peekChar(stream)))
		{
            buffer.writeChar(readChar(stream));
		}
		return Symbol::get(buffer.getText());
	}

    <<definitions>>+=
    bool isSymbolChar(int c)
    {
        return isalpha(c) || strchr("!@#$%^&*:;\\|-_+=/?<>,.", c);
    }

    <<declarations>>+=
    bool isSymbolChar(int c);


Symbols are our first case of a value that does *not* evaluate to itself.

	<<eval cases>>+=
	case Value::Tag::Symbol:
	{
        Symbol* symbol = value.getSymbol();

		Value scope = env;
        while(Pair* scopePair = scope.asPair())
		{
			Value bindingList = scopePair->head;
            while(Pair* bindingListPair = bindingList.asPair())
			{
				Value binding = bindingListPair->head;
                Pair* bindingPair = binding.asPair();
                if(!bindingPair)
                    continue;

                Value bindingName = bindingPair->head;
                if(areValuesIdentical(bindingName, symbol))
                    return bindingPair->tail;

				bindingList = bindingListPair->tail;
			}

			scope = scopePair->tail;
		}

        error(SourceLoc(), "undefined identifier '%s'\n", symbol->text.begin());
		return Value::getNil();
	}
	break;


Macros
------

    <<object cases>>+=
    OBJECT_CASE(Macro)

    <<forward type declarations>>+=
    struct MacroObj;

    <<value declarations>>+=
    struct MacroObj
    {
        MacroObj(Value transformer);

        Value transformer;
    };

    <<value members>>+=
    MacroObj* asMacro();

	<<definitions>>+=
    MacroObj::MacroObj(Value transformer)
	{
        this->transformer = transformer;
	}
    MacroObj* Value::asMacro()
	{
        return (MacroObj*) asObject(Value::Tag::Macro);
	}

    <<other pair eval cases>>+=
    case Value::Tag::Macro:
    {
        auto macro = value.asMacro();
        return eval(apply(macro->transformer, argExprs), env);
    }

	<<primitive func declarations>>+=
    PRIMITIVE_FUNC_DECL(macro);

	<<primitive func definitions>>+=
    PRIMITIVE_FUNC_DEF(macro)
	{
		Value transformer = readArg();
        return new MacroObj(transformer);
	}

Quotation
---------

	<<primitive func declarations>>+=
    PRIMITIVE_FUNC_DECL(quote);

	<<primitive func definitions>>+=
    PRIMITIVE_FUNC_DEF(quote)
	{
		Value arg = readArg();
		return arg;
	}

	<<read cases>>+=
	if(peekChar(stream) == '\'')
	{
		readChar(stream);
		Value arg = read(stream);
		return new Pair(
			Symbol::get("quote"),
			new Pair(arg, Value::getNil()));
	}


Homoiconicity
-------------

	<<definitions>>+=
	void define(Value env, Value key, Value val)
	{
        Pair* envPair = env.getPair();

		Value binding = new Pair(key,val);
        envPair->head = new Pair(binding, envPair->head);
	}

    <<primitive func declarations>>+=
    PRIMITIVE_FUNC_DECL(define);
    PRIMITIVE_FUNC_DECL(pair);
    PRIMITIVE_FUNC_DECL(isPair);
    PRIMITIVE_FUNC_DECL(head);
    PRIMITIVE_FUNC_DECL(tail);

    <<primitive func definitions>>+=
    PRIMITIVE_FUNC_DEF(define)
	{
		Value name = readArg();
        Value body = readArg();
		Value value = eval(body, env);

		define(env, name, value);

		return value;
	}
    PRIMITIVE_FUNC_DEF(pair)
	{
		Value head = readArg();
		Value tail = readArg();
		return new Pair(head, tail);
	}
    PRIMITIVE_FUNC_DEF(isPair)
	{
		Value arg = readArg();
        return arg.asPair() != nullptr;
	}
    PRIMITIVE_FUNC_DEF(head)
	{
		Pair* pair = readArg().getPair();
        return pair->head;
	}
    PRIMITIVE_FUNC_DEF(tail)
	{
		Pair* pair = readArg().getPair();
        return pair->tail;
	}

    <<definitions>>+=
    Value gEnv;

    <<program initialization>>=
	Value env = new Pair(Value::getNil(), Value::getNil());
    gEnv = env;

    <<register language primitives>>+=
    define(env, Symbol::get("if"),       new PrimitiveSyntaxObj(PRIMITIVE_FUNC(if)));
    define(env, Symbol::get("lambda"),   new PrimitiveSyntaxObj(PRIMITIVE_FUNC(lambda)));
    define(env, Symbol::get("define"),   new PrimitiveSyntaxObj(PRIMITIVE_FUNC(define)));
    define(env, Symbol::get("quote"),    new PrimitiveSyntaxObj(PRIMITIVE_FUNC(quote)));

    define(env, Symbol::get("+"), new PrimitiveFuncObj(PRIMITIVE_FUNC(add)));
    define(env, Symbol::get("-"), new PrimitiveFuncObj(PRIMITIVE_FUNC(sub)));
    define(env, Symbol::get("*"), new PrimitiveFuncObj(PRIMITIVE_FUNC(mul)));
    define(env, Symbol::get("/"), new PrimitiveFuncObj(PRIMITIVE_FUNC(div)));

    define(env, Symbol::get(">"),    new PrimitiveFuncObj(PRIMITIVE_FUNC(cmp_gt)));

    define(env, Symbol::get("macro"),    new PrimitiveFuncObj(PRIMITIVE_FUNC(macro)));
    define(env, Symbol::get("exit"),     new PrimitiveFuncObj(PRIMITIVE_FUNC(exit)));
    define(env, Symbol::get("print"),    new PrimitiveFuncObj(PRIMITIVE_FUNC(print)));
    define(env, Symbol::get("pair"),     new PrimitiveFuncObj(PRIMITIVE_FUNC(pair)));
    define(env, Symbol::get("pair?"),    new PrimitiveFuncObj(PRIMITIVE_FUNC(isPair)));
    define(env, Symbol::get("head"),     new PrimitiveFuncObj(PRIMITIVE_FUNC(head)));
    define(env, Symbol::get("tail"),     new PrimitiveFuncObj(PRIMITIVE_FUNC(tail)));

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

	<<definitions>>+=
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

    <<declarations>>+=
    <<value declarations>>
    Value evalList(Value list, Value env);
    Value apply(Value func, Value args);
	void define(Value env, Value key, Value val);
    Value evalBody(Value body, Value env);

    //<<file:lisp.cpp>>=
    <<interpreter program>>

Extras
------

	<<definitions>>+=
    void readSourceStream(InputStream& stream)
	{
        load(stream, gEnv);
	}
