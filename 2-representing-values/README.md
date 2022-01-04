Values and Types
================

In this section we will investigate methods for representing the values that a language manipulates, as well as classifying those values with types to protect against programmer error.

Types and Type Systems
----------------------

Type Safety
-----------

A *type-safe* or *strongly-typed* language is one that does not allow an operation to be applied to a value of an inappropriate type.
Conversely, a *type-unsafe* or *weakly-typed* language is one that does not prevent such mistakes.

For example, our Forth interpreter is type-unsafe because it allows nonsense like trying to dereference an integer as a pointer:

> ```
> > 123 @
> ... crash
> ```

The exact definition of what is "appropriate" or not varies across languages, and can thus lead to pointless arguments about which languages are or are not "safe."
Type safety is less a binary concept and more a way to compare and contrast the design choices in different languages.

Dynamic and Static Type Systems
-------------------------------

Orthogonal to the question of what a type system enforces is the question of *when* the enforcement happens.

*Static* type checks are those that are completed before a program runs, while *dynamic* type checks are those that occur during program runtime.
Many languages use a combination of static and dynamic checks.

Value Representation
--------------------

    <<value declarations>>+=
    enum
    {
        INDIRECT_TAG_BITS = 3,
        INDIRECT_TAG_MASK = (1 << INDIRECT_TAG_BITS) - 1,

        DIRECT_TAG_BITS = 8,
        DIRECT_TAG_SHIFT = INDIRECT_TAG_BITS,
        DIRECT_TAG_MASK = ((1 << DIRECT_TAG_BITS) - 1) << DIRECT_TAG_SHIFT,
    };

    enum TypeTag
    {
        <<indirect type tags>>
        TYPE_TAG_DIRECT = INDIRECT_TAG_MASK,
        <<direct type tags>>
    };

    struct Value
    {
    #if TRICKY_ENCODING
        uint64_t bits;
    #else
        TypeTag tag;
        union
        {
            void* ptr;
            uint64_t bits;
            struct Pair* pair;
            struct Symbol* symbol;
        };
    #endif
    };

    TypeTag getTag(Value value)
    {
    #if TRICKY_ENCODING
        TypeTag tag = (TypeTag)(value.bits & INDIRECT_TAG_MASK);
        if(tag == TYPE_TAG_DIRECT)
        {
            tag = (TypeTag)((value.bits & DIRECT_TAG_MASK) >> DIRECT_TAG_SHIFT);
        }
        return tag;
    #else
        return value.tag;
    #endif
    }

    void* getIndirectValuePtr(Value value)
    {
    #if TRICKY_ENCODING
        assert(getTag(value) < TYPE_TAG_DIRECT);

        return (void*)(uintptr_t)(value.bits & ~(uint64_t)(DIRECT_TAG_MASK));
    #else
        return value.ptr;
    #endif
    }

    uint32_t getDirectValueBits(Value value)
    {
    #if TRICKY_ENCODING
        assert(getTag(value) >= TYPE_TAG_DIRECT);
        return (value.bits >> 32);
    #else
        return value.bits;
    #endif
    }

    Value tagIndirectValue(void* ptr, TypeTag tag)
    {
        assert(tag < TYPE_TAG_DIRECT);
        Value value;

    #if TRICKY_ENCODING
        uint64_t valueBits = (uint64_t)(uintptr_t)ptr;
        assert((valueBits & INDIRECT_TAG_MASK) == 0);

        value.bits = valueBits | tag;
    #else
        value.bits = 0;
        value.tag = tag;
        value.ptr = ptr;
    #endif
        return value;
    }

    Value tagDirectValue(uint32_t valueBits, TypeTag tag)
    {
        assert((tag >= TYPE_TAG_DIRECT));

        Value value;
    #if TRICKY_ENCODING
        value.bits =
            ((uint64_t) valueBits) << 32
            | (tag << DIRECT_TAG_SHIFT)
            | TYPE_TAG_DIRECT;
    #else
        value.tag = tag;
        value.bits = valueBits;
    #endif
        return value;
    }

    bool areValuesIdentical(Value left, Value right)
    {
        TypeTag leftTag = getTag(left);
        TypeTag rightTag = getTag(right);
        if(leftTag != rightTag)
            return false;
        
        switch(leftTag)
        {
        default:
            return left.bits == right.bits;

        <<value identity cases>>
        }
    }

### Objects

    <<indirect type tags>>+=
    //TYPE_TAG_OBJECT,

    <<value declarations>>+=
    #if 0
    struct ObjHeader
    {
        <<object header fields>>
    };
    typedef ObjHeader Object;

    Value tagObject(const ObjHeader* obj, TypeTag tag = TYPE_TAG_OBJECT)
    {
        return tagIndirectValue(obj, tag);
    }

    ObjHeader* getObject(Value value)
    {
        assert(getTag(value) == TYPE_TAG_OBJECT);
        return (ObjHeader*)(uintptr_t)getBaseValueBits(value);
    }
    #endif

### Integers

We will start off slowly by defining a type `Int` for integer values.
We start with a type tag to identify our new type of values.

    <<direct type tags>>+=
    TYPE_TAG_INT,

    <<value declarations>>+=
    typedef int32_t IntVal;

For convenience we define a subroutine `makeInt` for making integer values.

    <<value declarations>>+=
    Value makeInt(IntVal value);

	<<types>>+=
	Value makeInt(IntVal value)
	{
        return tagDirectValue(value, TYPE_TAG_INT);
	}

Next, we define a way to test if a given `Value` is an integer.

	<<types>>+=
    IntVal getIntVal(Value value)
	{
        assert(getTag(value) == TYPE_TAG_INT);
        return (IntVal) getDirectValueBits(value);
	}

Printing an `Int` is straightforward:

	<<print cases>>+=
	case TYPE_TAG_INT:
		printf("%lld", (long long)getIntVal(value));
		break;

### Booleans

Next we need a type for Boolean truth values.

	<<direct type tags>>+=
	TYPE_BOOL,

There can only be two possible Boolean values, so rather than
create them on the fly, we will create them once and re-use them.

	<<types>>+=
    Value makeBool(bool value)
    {
        return tagDirectValue( value ? 1 : 0, TYPE_BOOL );
    }

Next, we define a way to test if a given `Value` is a Boolean.

	<<types>>+=
    bool getBoolVal(Value value)
	{
        assert(getTag(value) == TYPE_BOOL);
        return getDirectValueBits(value) != 0;
	}

	<<print cases>>+=
	case TYPE_BOOL:
        puts(getBoolVal(value) ? "true" : "false");
		break;

### Errors

    <<direct type tags>>=
    TYPE_TAG_ERROR,
    TYPE_TAG_VOID,

### Nil

We define nil as its own  type of object:

	<<direct type tags>>+=
	TYPE_NIL,

	<<value declarations>>+=
	Value makeNil()
	{
        return tagDirectValue(0, TYPE_NIL);
	}

### Strings

TODO: logic to allocate and manage strings

### Symbols

	<<indirect type tags>>+=
	TYPE_TAG_SYMBOL,

	<<types>>+=
	struct Symbol
	{
		char const* value;
		<<additional symbol members>>
	};

    <<value declarations>>+=
	Value makeSymbol(char const* value);

	<<types>>+=
	Value makeSymbol(char const* value)
	{
		<<try to find existing symbol>>

		Symbol* result = new Symbol();
		result->value = _strdup(value);
		<<add new symbol>>
		return tagIndirectValue(result, TYPE_TAG_SYMBOL);
	}

	<<additional symbol members>>=
	Symbol* next;

	<<try to find existing symbol>>=
	static Symbol* gSymbols = NULL;
	for(Symbol* sym = gSymbols; sym; sym = sym->next)
	{
		if(strcmp(sym->value, value) == 0)
			return tagIndirectValue(sym, TYPE_TAG_SYMBOL);
	}

	<<add new symbol>>=
	result->next = gSymbols;
	gSymbols = result;

	<<types>>+=
	const char* getSymbolVal(Value value)
	{
        assert(getTag(value) == TYPE_TAG_SYMBOL);
        return ((Symbol*) getIndirectValuePtr(value))->value;
	}


TODO: Make symbols hold a reference to the string

Representing Values
-------------------

Many of the languages being covered here are dynamic and/or interpreted languages.
An important design decision when building an interpreter is how values in the language being implemented (the *object language*) will be represented in the language of the implementation.

A variable `x` in a dynamic language might refer to a value of any type, and different types may require different amounts of storage.
A simple Boolean truth value needs only a single bit in theory, while a string holding the contents of a file could easily consume multiple megabytes.

Two questions then arise around the representation of the value of a variable like `x`:

1. How do we determine the type of the value stored in `x`?
2. Where do we put the bits that make up the value of `x`?

### Type Tags

For languages that have a small and fixed number of types, it is often convenient to represent each type as an integer *tag* that can be associated with a value.

For example, an interpreter might define:

    enum class TypeTag
    {
    	Nil,
    	Bool,
    	Int,
    	String,
    	// ...
    };

### Tagged Unions

In a langauge that uses type tags, we can then define a value as a *tagged union* that combines a tag with a tag-specific *payload* of data. For example:

    struct Value
    {
    	TypeTag tag;
    	union
    	{
    		bool boolVal;
    		int intVal;
    		const char* stringVal;
    		...
		} payload;
    }

One advantage of a tagged union is that values of simple types like numbers can usually be stored and manipulated without needing to allocate memory, avoiding the overhead of memory management in many simple cases.

A potential disadvantage of typical tagged union approaches is that they can be wasteful of space.
A typical tagged-union `Value` consumes two pointers worth of space (e.g., 128 bits on a 64-bit platform).
Only a very small number of those bits are used for values of Boolean or small integer types.
Having a `Value` consume two pointers also means that `Value`s cannot be assigned to or updated atomically (for interpreters that support concurrent threads).

### Objects

One of the simplest techniques for representing values is to represent every value as a pointer to a heap-allocated *object* that stores a type tag or similar field in its initial bytes:

    struct Object
    {
    	TypeTag tag;
    };
    typedef Object* Value;

Different types of value are then represented as refined version of Object, either via inheritance, or by embedding an `Object` as an initial field:

	struct BoolObject
	{
		Object base;
		bool 	val;
	};

Objects are simple to implement and can represent many different types of values uniformly.
They also guarantee that every `Value` is just the size of one pointer, which is a space advantage over simpler tagged-union representations.

An important disadgantage of using objects to represent values is that even simple integer values must be represented as heap-allocated objects.
If an interpreter will often be used to perform a lot of processing on small values (numbers, Booleans, etc.), then the overhead of managing memory can hurt performance.


