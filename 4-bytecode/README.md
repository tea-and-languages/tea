A Simple Bytecode and Virtual Machine
=====================================

Bytecode
--------

    //<<bytecode types>>=

    typedef uint8_t Code;

    enum class Opcode : Code
    {
        Nop = 0,
        <<opcodes>>
    };

    struct BytecodeFunc
    {
        Code const* code;
        Value const* constants;
        int stackValueCount;
    };

Virtual Machine
---------------

    //<<dependencies>>+=
    #include <new>

    //<<bytecode declarations>>=

    struct VMFrame
    {
        BytecodeFunc const*     func = nullptr;
        Code const*             ip = nullptr;
        VMFrame*                parent = nullptr;
        Value*                  stackPtr = nullptr;
        Value const*            args = nullptr;
        int                     argCount = 0;

        Value                   stackData[1];
    };

    struct VMThread
    {
        VMFrame* frame = nullptr;

    //        Array<Value> stack;
    //        Array<VMFrame> frames;

        <<vm thread members>>
    };

    struct VMContext
    {
        VMThread*       _thread = nullptr;

        VMThread*& thread() { return _thread; }
        VMFrame*& frame() { return thread()->frame; }
        Code const*& ip() { return frame()->ip; }
        Value*& stackPtr() { return frame()->stackPtr; }

        <<vm context members>>
    };

    <<vm context members>>+=
    unsigned readByte()
    {
        return *ip()++;
    }

    unsigned readUInt()
    {
        return readByte();
    }

    unsigned readInt()
    {
        unsigned u = readUInt();
        if(u & 1)
            return ~(u >> 1);
        else
            return (u >> 1);
    }

    void pushValue(Value value)
    {
        *stackPtr()++ = value;
    }

    Value popValue()
    {
        --stackPtr();
        return *stackPtr();
    }

    Value& valueAtIndex(int index)
    {
        return *(stackPtr() - index);
    }

    Value* getValuesAtIndex(int index)
    {
        return stackPtr() - index;
    }

    VMFrame* createFrame(int stackValueCount)
    {
        size_t size = sizeof(VMFrame) + (stackValueCount-1)*sizeof(Value);

        void* data = malloc(size);
        memset(data, 0, size);

        VMFrame* frame = new(data) VMFrame();
        frame->stackPtr = frame->stackData;
        return frame;
    }

    VMFrame* createFrame(BytecodeFunc const* func, int argCount, Value const* args)
    {
        VMFrame* newFrame = createFrame(func->stackValueCount);
        newFrame->func = func;
        newFrame->ip = func->code;
        newFrame->args = args;
        newFrame->argCount = argCount;
        return newFrame;
    }

    void pushFrame(VMFrame* newFrame)
    {
        newFrame->parent = frame();
        frame() = newFrame;
    }

    VMFrame* pushFrame(BytecodeFunc const* func, int argCount, Value const* args)
    {
        VMFrame* newFrame = createFrame(func, argCount, args);
        pushFrame(newFrame);
        return newFrame;
    }

    void popFrame()
    {
        frame() = frame()->parent;
    }

    Value executeBytecode(BytecodeFunc const& func)
    {
        auto frame = createFrame(func.stackValueCount);
        frame->func = &func;
        frame->ip = func.code;

        pushFrame(frame);

        return execute();
    }

    Value execute()
    {
        for(;;)
        {
            // get next opcode
            Opcode op = (Opcode) readByte();
            switch(op)
            {
            default:
                error(SourceLoc(), "unexpected opcode 0x%x", (unsigned)op);
                return makeNil(); // TODO: makeError()

            case Opcode::Nop:
                // no-op means nothing to do!
                break;

            <<virtual machine cases>>
            }

        }
    }

Emitting Bytecode
-----------------

    //<<bytecode declarations>>=
    struct BytecodeEmitter
    {
        typedef int ExprResult;

        Array<Code> code;

        <<bytecode emitter members>>
    };

    //<<bytecode declarations>>=

    <<bytecode emitter members>>+=
    void emitOpcode(Opcode op)
    {
        emitRawUInt((unsigned) op);
    }
    void emitRawInt(unsigned value)
    {
        if(value < 0)
        {
            emitRawUInt((~value)*2 + 1);
        }        
        else
        {
            emitRawUInt(value*2 + 0);
        }
    }
    void emitRawUInt(unsigned value)
    {
        // TODO: variable-size integer encoding
        emitRawByte((Code) value);
    }
    void emitRawByte(Code byte)
    {
        code.add(byte);
    }

    BytecodeFunc func;

    BytecodeFunc const& getResult()
    {
        size_t codeBufferSize = code.getCount();
        Code* codeBuffer = (Code*) malloc(codeBufferSize);
        memcpy(codeBuffer, code.getBuffer(), codeBufferSize);

        int constantCount = constants.getCount();
        size_t constantsBufferSize = constantCount * sizeof(Value);
        Value* constantsBuffer = (Value*) malloc(constantsBufferSize);
        memcpy(constantsBuffer, constants.getBuffer(), constantsBufferSize);

        func.code = codeBuffer;
        func.constants = constantsBuffer;
        func.stackValueCount = 100; // TODO: actually figure this bit out!!!

        return func;
    }

Constants
---------

    <<bytecode emitter members>>+=
    Array<Value> constants;

    <<opcodes>>+=
    LoadConstant,

    <<bytecode emitter members>>+=
    ExprResult emitConstant(Value value);
    ExprResult emitPushNil();

    <<bytecode definitions>>+=
    BytecodeEmitter::ExprResult BytecodeEmitter::emitConstant(Value value)
    {
        unsigned index = constants.getCount();
        constants.add(value);

        emitOpcode(Opcode::LoadConstant);
        emitRawUInt(index);
        return 0;
    }
    BytecodeEmitter::ExprResult BytecodeEmitter::emitPushNil()
    {
        return emitConstant(makeNil());
    }

    <<virtual machine cases>>+=
    case Opcode::LoadConstant:
    {
        unsigned index = readUInt();
        Value value = frame()->func->constants[index];
        pushValue(value);
    }
    break;

Call and Return
---------------

    <<opcodes>>+=
    Call,
    Return,

    <<bytecode emitter members>>+=
    ExprResult emitCall(int argCount);
    void emitReturn();

    <<bytecode definitions>>+=
    BytecodeEmitter::ExprResult BytecodeEmitter::emitCall(int argCount)
    {
        emitOpcode(Opcode::Call);
        emitRawUInt(unsigned(argCount));
        return 0;
    }
    void BytecodeEmitter::emitReturn()
    {
        emitOpcode(Opcode::Return);
    }

    <<virtual machine cases>>+=
    case Opcode::Return:
    {
        // in the simplest case, returning from a call is just
        // a matter of popping the current frame.
        //
        // Well, except for one important detail... the callee
        // will have pushed the return value (whatever it was)
        // onto its stack, and we need to move that value onto
        // the stack of the caller.
        //
        Value result = popValue();
        popFrame();
        if(!frame())
        {
            // If there is no frame being returned to, then we
            // have finished executing this thread...
            return result;
        }
        pushValue(result);
    }
    break;

