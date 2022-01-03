A Simple Bytecode and Virtual Machine
=====================================

Bytecode
--------

    //<<bytecode declarations>>=

    typedef uint8_t Code;

    enum Opcode
    {
        OPCODE_NOP = 0,
        OPCODE_RET,
        <<opcodes>>
    };

    struct BytecodeFunc
    {
        Code const* code;
        Value const* constants;
    };

Virtual Machine
---------------

    //<<bytecode declarations>>=

    struct VMFrame
    {
        BytecodeFunc const*   func;
        Code const*     ip;
    };

    struct VMThread
    {
        VMFrame frame;

        Array<Value> stack;
        Array<VMFrame> frames;

        <<vm thread members>>
    };

    <<vm thread members>>+=
    unsigned readByte()
    {
        return *frame.ip++;
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
        stack.add(value);
    }

    void executeBytecode(BytecodeFunc const& func)
    {
        frame.func = &func;
        frame.ip = func.code;

        execute();
    }

    void execute()
    {
        for(;;)
        {
            // get next opcode
            Opcode op = (Opcode) readByte();
            switch(op)
            {
            default:
                error(SourceLoc(), "unexpected opcode 0x%x", (unsigned)op);
                return;

            case OPCODE_NOP:
                // no-op means nothing to do!
                break;

            case OPCODE_RET:
                // return from current call frame (whatever that looks like)
                assert(!"unimplemented");
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

        return func;
    }

Constants
---------

    <<bytecode emitter members>>+=
    Array<Value> constants;

    <<opcodes>>+=
    OP_CONSTANT,

    <<bytecode emitter members>>+=
    ExprResult emitConstant(Value value);

    <<bytecode definitions>>+=
    BytecodeEmitter::ExprResult BytecodeEmitter::emitConstant(Value value)
    {
        unsigned index = constants.getCount();
        constants.add(value);

        emitOpcode(OP_CONSTANT);
        emitRawUInt(index);
        return 0;
    }

    <<virtual machine cases>>+=
    case OP_CONSTANT:
    {
        unsigned index = readUInt();
        Value value = frame.func->constants[index];
        pushValue(value);
    }
    break;

