Forth
=====

The Forth programming language and environment was designed by Charles H. "Chuck" Moore, and came into being between 1968 and 1970.

Forth is minimalist in a way that even the other languages we will discuss cannot approach.
It is often implemented directly in assembly, but can still support high-level programming.
Many implementations have small enough footprint to run on microcontrollers or embedded systems with limited hardware, and Forth is a popular system to embed into firmware.

A Minimalist Command Processor
------------------------------



A simplistic view of how to implement a programming language interpreter might be summarized as:

	//<<interpret one command>>=
	<<read the name of a command>>
	<<look up a command with that name>>
	<<execute the command if one was found>>

The job of the interpreter is to read and execute commands one by one.

### Reading a Command Name

    <<utility functions>>+=
    char const* readName()
    {
        // skip whitespace
        while(isSpace(peekChar()))
            getchar();

        static char buffer[1024];
        char* cursor = buffer;
        while(!isSpace(peekChar()))
            *cursor++ = getchar();
        *cursor++ = 0;
        return buffer;
    }

	<<read the name of a command>>=
    const char* name = readName();

### Looking up Commands

The minimalist Interpreter outlined above is centered around *commands*, so we next turn our attention to defining what a command looks like.

	<<command type>>=
	struct Command
	{
		<<command type fields>>
	};

In order to be able to look up commands, we need them to have names.

	<<command type fields>>+=
    const char* name;

In addition, in order to look up commands by name, we need some sort of data structure.
A singly linked list is about as simple as possible.

	<<command type>>+=
	Command* gLatestCommand;

	<<command type fields>>+=
	Command* previous;

We will add new commands to the front of our list, so the head of the linked list points at the latest command defined, and each command has a pointer to the command defined before it.
We can then define a simple subroutine to look up a command by its name.

	<<command type>>+=
	Command* lookUpCommand(const char* name)
	{
        for(Command* command = gLatestCommand; command; command = command->previous)
        {
            if(strcmp(command->name, name) == 0)
				return command;
        }
		return NULL;
	}

At this point we can fill in part of our outline for a simplistic interpreter.

	<<look up a command with that name>>=
	gCurrentCommand = lookUpCommand(name);

### Executing a Command

In order to allow commands to be executed, we will associated each command with a host-language function that will perform an appropriate action.

	<<command type fields>>+=
	void (*action)();


Adding the logic to execute the command that was found is also simple, but is complicated by two factors.
First, we need to consider what to do if no command with the given `name` is found, which we will get to shortly.

	<<execute the command if one was found>>=
	if(gCurrentCommand)
	{
		<<execute the command that was found>>
	}
	else
	{
		<<handle the case where no command was found>>
	}

Second, later in this discussion we will be introducing the ability to compile commands rather then execute them immediately.

	<<execute the command that was found>>=
	if( <<should execute command immediately>> )
	{
		gCurrentCommand->action();
	}
	else
	{
		<<handle a command to be compiled>>
	}

### Registering Commands

In order to make the interpreter useful, we will need to define some commands ahead of time.
Registering a built-in command will be accomplished with a simple subroutine.

	<<command type>>+=
	Command* registerBuiltInCommand(char const* name, void (*action)(), CommandFlags flags = 0 )
	{
		<<allocate and initialize a built-in command>>
		<<add command to the linked list>>
        return command;
	}

	<<allocate and initialize a built-in command>>=
    Command* command = new Command();
    command->name = name;
    command->action = action;
	command->flags = flags;

	<<add command to the linked list>>=
    command->previous = gLatestCommand;
    gLatestCommand = command;

Here we have added support for commands to have some flags assocaited with them.
This is a feature we will make use of later, but for now it doesn't serve any purpose.

	<<command flags type>>=
	typedef unsigned int CommandFlags;
	enum CommandFlag
	{
		<<command flags>>
	};

	<<command type fields>>+=
	CommandFlags flags;

### Testing Simple commands

With the pieces of the implementation described so far, we can begin to define some trivial commands and their actions:

	<<built-in command actions>>+=
	void builtin_hello() { printf("hello"); }
	void builtin_world() { printf("world"); }
	void builtin_cr() { printf("\n"); }
	void builtin_exit() { exit(0); }

	<<register built-in commands>>+=
	registerBuiltInCommand("hello", &builtin_hello);
	registerBuiltInCommand("world", &builtin_world);
	registerBuiltInCommand("cr",    &builtin_cr);
	registerBuiltInCommand("exit",    &builtin_exit);

With these commands we can now run our interpreter and interact with it:

	> hello world cr exit
	helloworld

A Stack-Based Calculator
------------------------

Of course, an interpreter that can only perform simple imperative actions like `hello` above is not very useful.
In order to make an interpereter more powerful we need a way for commands to consume and/or produce data.
One of the simplest models for passing data between commands is to use a *stack*.

### Pushing and Popping

Our stack will consist of simple values, and will be stored in a fixed-size region of memory.

	<<stack definition>>=
    Value gStack[kMaxStackSize];
    Value* SP = gStack;

The values we store on the stack will all be sized to match the pointer/"word" size of the host processor.

	<<value type>>=
	typedef uintptr_t Value;

Pushing and popping values from the stack is accomplished with some simpler helper functions.

	<<stack definition>>+=
	inline void push(Value value) { *SP++ = value; }
	inline Value pop() { return *--SP; }

The stack memory (and memory throughout Forth) is not typed or "safe"; it is possible to write a word as an intereger and then later read it as a pointer.
We can still define typed versons of `push` and `pop` to make accessing values on the stack with an expected type easier.

	<<stack definition>>+=
	typedef intptr_t Int;
	inline void pushInt(Int intValue) { push(Value(intValue)); }
	inline Int popInt() { return Int(pop()); }

### Integer Literals

In order to turn our simplistic interpreter into a useful calculator, we need a way for the user to write integer literals that get pushed onto the stack.
The existing interpreter logic already reads space-delimited command "names," and does not care whether the bytes of those names represent an identifier, an operator, or a number.
In the case where looking up a command by name has failed, we can simply check if the name could instead be parsed as a number:

	<<handle the case where no command was found>>=
	Int value = 0;
	if(tryParseIntegerLiteral(name, &value))
	{
		<<handle an integer literal>>
	}
	else
	{
		fprintf(stderr, "unknown command '%s'\n", name);
	}

When we are simply executing commands immediately, we will handle an integer literal by pushing it to the stack.

	<<handle an integer literal>>=
	if( <<should execute command immediately>> )
	{
		pushInt(value);
	}
	else
	{
		<<handle an integer literal to be compiled>>
	}

	<<utility functions>>+=
	bool tryParseIntegerLiteral(const char* text, Int* outValue)
	{
		Int value = 0;
		bool negate = false;
		const char* cursor = text;
		if(*cursor == '-')
		{
			cursor++;
			negate = true;
		}
        while(isDigit(*cursor))
            value = value*10 + (*cursor++ - '0');

		if(*cursor != 0)
			return false;

		*outValue = value;
		return true;
	}

### Simple Math Operators

	<<built-in command actions>>+=
    void builtin_add()
    {
        Int left = popInt();
		Int right = popInt();
		pushInt(left + right);
    }

	<<register built-in commands>>+=
	registerBuiltInCommand("+", &builtin_add);

### Printing Results

	<<built-in command actions>>+=
    void builtin_print()
    {
        Int value = popInt();
		printf("%" PRIdPTR, value);
    }

	<<register built-in commands>>+=
	registerBuiltInCommand("print", &builtin_print);

### Example

With the features defined so far we can use our Forth interpreter as a very basic calculator based on postifx notation.

    > 1 2 + print cr
    3

Compilation
-----------

One problem with the interpreter we've been building so far is that all the commands have been built-in.
Our next task in builtin up a Forth implementation is to allow user-defined commands to be compiled.

In the simplest case, a user-defined command would be composed from pre-existing commands (whether built-in or user-defined), and would be stored as a sequence of those sub-commands.

    Command* userDefinedCommand[] = { &commandForHello, &commandForWorld, ... };

Under this model, we can store a global "instruction pointer" that refers to the next command to execute and build an interpreter to execute code from the current intstruction pointer:

	<<vm interpreter>>=
	Command** IP = NULL;
    Command* gCurrentCommand = NULL;
    Value gHeap[kMaxHeapSize];
    Value* gHeapCursor = gHeap;

    <<main vm loop>>=
	for(;;)
	{
		gCurrentCommand = *IP++;
		gCurrentCommand->action();
	}

	<<built-in command actions>>+=
    Command** gReturnStack[32];
    Command*** RSP = gReturnStack;
    void builtin_userDefined()
    {
        *RSP++ = IP;
        IP = (Command**) (gCurrentCommand + 1);
    }
    void pushPtr(void* ptr) { push(Value(ptr)); }
    void* popPtr() { return (void*) pop(); }
    void builtin_beginDefinition()
    {
        const char* name = _strdup(readName());

        Command* command = (Command*) gHeapCursor;
        gHeapCursor = (Value*) (command+1);

        command->name = name;
        command->action = &builtin_userDefined;

        pushPtr(command);

		gMode = kMode_Compile;
        printf("{beginDef}\n");
    }

	<<register built-in commands>>+=
	registerBuiltInCommand(":", &builtin_beginDefinition);

	<<built-in command actions>>+=
    Command* gReturnCommand;
    void builtin_return()
    {
        IP = *(--RSP);
    }
    void builtin_endDefinition()
    {
        *gHeapCursor++ = Value(gReturnCommand);

        Command* command = (Command*) popPtr();

        command->previous = gLatestCommand;
        gLatestCommand = command;

		gMode = kMode_Interpret;
        printf("{endDef}\n");
    }

    <<command flags>>+=
    kCommandFlag_Immediate = 0x1,

	<<register built-in commands>>+=
	gReturnCommand = registerBuiltInCommand("return", &builtin_return);
	registerBuiltInCommand(";", &builtin_endDefinition, kCommandFlag_Immediate);


A simple representation for user-defined comma

The same basic interpreter loop we have been building is also responsible for m


	<<handle a command to be compiled>>=
    if(gCurrentCommand->flags & kCommandFlag_Immediate)
    {
        gCurrentCommand->action();
    }
    else
    {
        *(gHeapCursor++) = Value(gCurrentCommand);
        printf("compiling a command '%s'", gCurrentCommand->name);
    }

### Compiling a Literal

	<<built-in command actions>>+=
    Command* gLitCommand;
    void builtin_lit()
    {
        push(Value(*(IP++)));
    }

	<<register built-in commands>>+=
	gLitCommand = registerBuiltInCommand("lit", &builtin_lit);

    <<handle an integer literal to be compiled>>=
    *(gHeapCursor++) = Value(gLitCommand);
    *(gHeapCursor++) = value;


Control Flow
------------

	<<subroutines>>+=
	enum Mode { kMode_Interpret, kMode_Compile };
	Mode gMode = kMode_Interpret;

	<<should execute command immediately>>=
	gMode == kMode_Interpret



	<<defines>>+=
	enum { kMaxStackSize = 1024 };
	enum { kMaxHeapSize = 1024 };

    //<<file:forth.cpp>>=
    <<interpreter program>>

	<<dependencies>>+=
	#include <inttypes.h>

	<<subroutines>>=

	<<defines>>
	<<value type>>
	<<command flags type>>
	<<command type>>

    bool isImmediate(Command* word) { return false; }

	<<stack definition>>

    int peekChar()
    {
        int c = getchar();
        ungetc(c, stdin);
        return c;
    }
	<<utility functions>>

	<<vm interpreter>>

	<<built-in command actions>>

    void debug()
    {
        for(auto c = gStack; c < SP; c++)
            printf("0x%" PRIXPTR " ", *c);
        printf("\n");
    }

    Command* gInterpretOneCommandCommand;
    void builtin_interpretOneCommand()
    {
        IP = &gInterpretOneCommandCommand;
        <<interpret one command>>
    }

    //<<register language primitives>>=
    <<register built-in commands>>

    //<<run interactive interpreter>>=
    gInterpretOneCommandCommand = registerBuiltInCommand("__interpret", &builtin_interpretOneCommand);
    IP = &gInterpretOneCommandCommand;
	<<main vm loop>>

Extras
------

	<<subroutines>>+=
    void readSourceStream(InputStream& stream)
	{
		// TODO: fill in for the Forth-y case...
	}
