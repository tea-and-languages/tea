Smalltalk
=========

    <<forward type declarations>>+=
    struct Class;

	<<declarations>>+=

    struct FuncObj;

    struct MessageHandler
    {
        Value               selector;
        FuncObj*            func;
        MessageHandler*     next;
    };

    <<object type representation>>=
    typedef Class* ObjectType;
    #define GET_OBJECT_TYPE(NAME) g##NAME##Class

    <<object members>>+=
    Class* directClass;

	<<declarations>>+=
    struct FuncObj : Object
    {
        FuncObj();

        PrimitiveFunc func;
    };
    struct BytecodeFuncObj : FuncObj
    {
        BytecodeFuncObj();

        BytecodeFunc bytecode;
    };

    struct Class : Object
    {
        Class(Class* metaClass, Value::Tag tag)
            : Object(metaClass)
            , tag(tag)
        {}

        // base class
        Class* directBase;

        // Value tag
        Value::Tag tag;

        // slots for storage
        int slotCount;

        // dictionary for message lookup
        MessageHandler* messageHandlers;
    };
    Class* gClassClass;
    Class* gIntClass;
    Class* gSymbolClass;
    Class* gFuncObjClass;
    Class* gBytecodeFuncObjClass;

    <<declarations>>+=
    Class* getDirectClass(Value receiver);
    MessageHandler* lookUpMessageHandler(Class* directClass, Value selector);

    //<<definitions>>+=
    Value::Tag Value::getObjectTag(Object* object)
    {
        return object->directClass->tag;
    }

    FuncObj::FuncObj()
        : Object(GET_OBJECT_TYPE(FuncObj))
    {}

    BytecodeFuncObj::BytecodeFuncObj()
    {}

    //<<definitions>>+=
    Class* getDirectClass(Value receiver)
    {
        switch(receiver.getTag())
        {
        default:
            // error case
            return nullptr;

        case Value::Tag::Int:
            return gIntClass;

        case Value::Tag::Object:
            return receiver.getObject()->directClass;
        }
    }
    MessageHandler* lookUpMessageHandler(Class* directClass, Value selector)
    {
        for(Class* c = directClass; c; c = c->directBase)
        {
            for(MessageHandler* handler = c->messageHandlers; handler; handler = handler->next)
            {
                if(areValuesIdentical(selector, handler->selector))
                {
                    return handler;
                }
            }
        }

        return nullptr;
    }
    Value invokeBytecodeFuncObj(FuncObj* func, Value receiver, Value const* args)
    {
        auto self = (BytecodeFuncObj*) func;

        VMThread vmThread;
        VMContext vmContext;
        vmContext.thread() = &vmThread;

        return vmContext.executeBytecode(self->bytecode);
    }
    Value invokeMessageHandler(MessageHandler* handler, Value receiver, int argCount, Value const* args)
    {
        auto func = handler->func;
        auto prim = func->func;

        PrimitiveFuncContext context;
        context.args = args;
        context.argIndex = argCount;
        context.func = func;
        context.receiver = receiver;

        Value result = (context.*prim)();

        return result;
    }
    Value sendMessage(Value receiver, Value selector, int argCount, Value const* args)
    {
        // Get class from value.
        Class* directClass = getDirectClass(receiver);

        // Look up dictionary entry for selector...
        MessageHandler* handler = lookUpMessageHandler(directClass, selector);
        if(!handler)
        {
            // TODO: "message not understood" path
            // otherwise, error
        }

        // If we found a handler, then we should go ahead and invoke
        // it on the combination of receiver and arguments.
        //
        return invokeMessageHandler(handler, receiver, argCount, args);
    }

    <<primitive func context members>>+=
    Value receiver;
    struct FuncObj* func;

    <<program initialization>>+=

    <<register language primitives>>+=

    <<read in the prelude>>+=

    <<read files specified on command line>>+=

    <<run interactive interpreter>>+=



	<<definitions>>+=
    <<parser declarations>>
    void readSourceStream(InputStream& stream)
	{
        Lexer lexer;
        lexer.init(&stream);

        Parser parser;
        parser.init(&lexer);

        parser.parseSourceUnit();

        // executed the bytecode for our source unit...

        BytecodeFunc const& bytecodeFunc = parser.bytecode.getResult();
        
        VMThread vmThread;

        VMContext context;
        context.thread() = &vmThread;
        context.executeBytecode(bytecodeFunc);
	}

Parsing
-------

    <<definitions>>+=
    void Parser::parseTopLevelItem()
    {
        parseStmt();
    }
    void Parser::parseStmt()
    {
        switch(peekTokenCode())
        {
        default:
            parseExpr();
            advanceIf(TOK_SEMI);
            break;
        }
    }
    Parser::ExprResult Parser::parseExpr()
    {
        return parsePrefixExpr();
    }


### Message Sends

#### Unary Messages

    <<postfix expr parsing cases>>+=
    case TOK_IDENTIFIER:
    {
        Value selector = token.value;
        advance();

        bytecode.emitMessageSend(selector, 0);
    }
    break;


#### Infix Operators

    <<postfix expr parsing cases>>+=
    case TOK_PLUS:
    {
        advance();
        ExprResult arg = parseSimpleExpr();

        // Emit a message sense for `+`
        bytecode.emitMessageSend(Symbol::get("+"), 1);
    }
    break;

    <<bytecode emitter members>>+=
    ExprResult emitMessageSend(Value selector, int argCount);


    <<definitions>>+=
    BytecodeEmitter::ExprResult BytecodeEmitter::emitMessageSend(Value selector, int argCount)
    {
        // push the selector...
        emitConstant(selector);
        return emitCall(argCount + 1);
    }

    <<primitive func context members>>+=
    Value invokeBytecodeFunc();

    <<definitions>>+=
    Value PrimitiveFuncContext::invokeBytecodeFunc()
    {
        auto bytecodeFunc = (BytecodeFuncObj*) func;

        // TODO: need to set up arguments, etc. for call

        VMThread vmThread;

        VMContext vmContext;
        vmContext.thread() = &vmThread;
        return vmContext.executeBytecode(bytecodeFunc->bytecode);
    }

    <<virtual machine cases>>+=
    case Opcode::Call:
    {
        unsigned argCount = readUInt();
        Value selector = popValue();

        Value* args = getValuesAtIndex(argCount);
        stackPtr() = args;

        assert(argCount > 0);
        Value receiver = args[0];

        Class* directClass = getDirectClass(receiver);
        MessageHandler* handler = lookUpMessageHandler(directClass, selector);
        if(!handler)
        {
            // TODO: "message not understood" path
            // otherwise, error
        }
        auto func = handler->func;
        if(func->func != &PrimitiveFuncContext::invokeBytecodeFunc)
        {
            auto prim = func->func;

            PrimitiveFuncContext context;
            context.args = args;
            context.argIndex = 0;
            context.argCount = argCount;
            context.receiver = receiver;
            context.func = func;

            Value result = (context.*prim)();

            // TODO: do something with result!

            // TODO: need to pop everything that was part of the send...

            pushValue(result);
        }
        else
        {
            auto bytecodeFuncObj = (BytecodeFuncObj*) func;

            pushFrame(&bytecodeFuncObj->bytecode, argCount, args);
        }

    }
    break;

Primitive Func Stuff
--------------------

    <<primitive func context members>>+=
    Value const* args;
    int argIndex;
    int argCount;

    <<definitions>>+=
    Value PrimitiveFuncContext::readArg()
    {
        return args[argIndex++];
    }

Setting up the Built-in Classes
-------------------------------

    <<bytecode declarations>>+=
    VMEnv gBuiltinEnv;

    //<<register language primitives>>+=
    gClassClass = new Class(nullptr, Value::Tag::Object);
    gClassClass->directClass = gClassClass;
    gIntClass = new Class(gClassClass, Value::Tag::Int);

    // TODO: need to install a `+` handler into the `Int` class...

    auto clazz = gIntClass;

    auto func = new FuncObj();
    func->func = PRIMITIVE_FUNC(add);

    auto handler = new MessageHandler();
    handler->selector = Symbol::get("+");
    handler->func = func;

    handler->next = clazz->messageHandlers;
    clazz->messageHandlers = handler;

    func = new FuncObj();
    func->func = PRIMITIVE_FUNC(print);

    handler = new MessageHandler();
    handler->selector = Symbol::get("print");
    handler->func = func;

    handler->next = clazz->messageHandlers;
    clazz->messageHandlers = handler;

    // create the Object class
    clazz = new Class(gClassClass, Value::Tag::Object);

    gBuiltinEnv.assign("Class", clazz);


Outline of the Interpreter
------------------------------------

    //<<file:smalltalk.cpp>>=
    <<interpreter program>>

Interactive Interpreter
-----------------------

	<<run interactive interpreter>>=
	for(;;)
	{
        <<print interpreter prompt>>
        <<read a line of input>>
        <<evaluate the line of input>>
        <<print the result of evaluation>>
	}

    <<print interpreter prompt>>=
    printf("> ");

    <<read a line of input>>=
    StringSpan line = readLine(gStandardInput);

    <<evaluate the line of input>>=
    Value value = evalLine(line);

    <<print the result of evaluation>>=
    print(value);
    printf("\n");

    <<smalltalk types>>+=
    Value evalLine(StringSpan line);

    <<definitions>>+=
    Value evalLine(StringSpan line)
    {
        StringInputStream stream(line);

        Lexer lexer;
        lexer.init(&stream);

        Parser parser;
        parser.init(&lexer);

        parser.parseExpr();
        parser.bytecode.emitReturn();

        // executed the bytecode for our source unit...

        BytecodeFunc const& bytecodeFunc = parser.bytecode.getResult();
        
        VMThread vmThread;

        VMContext context;
        context.thread() = &vmThread;
        return context.executeBytecode(bytecodeFunc);
    }