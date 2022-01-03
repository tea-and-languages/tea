Smalltalk
=========

    <<indirect type tags>>+=
    TYPE_TAG_OBJECT,

    <<utility declarations>>+=
    struct Class;

	<<types>>+=

    struct MessageHandler
    {
        Value           selector;

        BytecodeFunc    bytecode;

        MessageHandler* next;
    };

    struct Object
    {
        Class* directClass;
    };
    Object* getObject(Value value)
    {
        assert(getTag(value) == TYPE_TAG_OBJECT);
        return (Object*) getIndirectValuePtr(value);
    }

    struct Class
    {
        Object asObject;

        // base class
        Class* directBase;

        // slots for storage
        int slotCount;

        // dictionary for message lookup
        MessageHandler* messageHandlers;
    };

    <<types>>+=

    //<<subroutines>>+=
    Class* getDirectClass(Value receiver)
    {
        switch(getTag(receiver))
        {
        default:
            // error case
            return nullptr;

        case TYPE_TAG_OBJECT:
            return getObject(receiver)->directClass;
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
    Value invokeMessageHandler(MessageHandler* handler, Value receiver, Value const* args)
    {
        VMThread vm;
        vm.executeBytecode(handler->bytecode);
        return makeNil();
    }
    Value sendMessage(Value receiver, Value selector, Value const* args)
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
        return invokeMessageHandler(handler, receiver, args);
    }



    <<program initialization>>+=

    <<register language primitives>>+=

    <<read in the prelude>>+=

    <<read files specified on command line>>+=

    <<run interactive interpreter>>+=



	<<subroutines>>+=
    void readSourceStream(InputStream& stream)
	{
        Lexer lexer;
        lexer.init(&stream);

        Parser parser;
        parser.init(&lexer);

        parser.parseSourceUnit();

        // executed the bytecode for our source unit...

        BytecodeFunc const& bytecodeFunc = parser.bytecode.getResult();
        
        VMThread vm;
        vm.executeBytecode(bytecodeFunc);
	}

Parsing
-------

    <<subroutines>>=
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
        bytecode.emitMessageSend(makeSymbol("+"), 1);
    }
    break;

    <<opcodes>>+=
    OP_MESSAGE_SEND,

    <<bytecode emitter members>>+=
    ExprResult emitMessageSend(Value selector, int argCount);


    <<bytecode definitions>>+=
    BytecodeEmitter::ExprResult BytecodeEmitter::emitMessageSend(Value selector, int argCount)
    {
        // push the selector...
        emitConstant(selector);
        emitOpcode(OP_MESSAGE_SEND);
        emitRawUInt((unsigned) argCount);
        return 0;
    }


Outline of the Interpreter
------------------------------------

    <<subroutine declarations>>+=

    //<<file:smalltalk.cpp>>=
    <<interpreter program>>

    //<<utility code>>+=
    <<value declarations>>
    <<bytecode declarations>>
    <<bytecode definitions>>
    <<lexer and parser>>

