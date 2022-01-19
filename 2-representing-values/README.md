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

    <<declarations>>+=
    <<value declarations>>

    <<once:value declarations>>+=
    struct Value
    {
    public:
        <<value members>>

    protected:
        <<value protected members>>
    };

### Tagging Values

    <<value members>>+=
    enum class Tag : int32_t
    {
        <<value tags>>
    };
    Tag getTag() const;

    <<value members>>+=
    union Payload
    {
        <<value payload members>>
    };

### Direct and Indirect Storage

    <<value payload members>>+=
    typedef uintptr_t Bits;
    Bits bits;

    <<forward type declarations>>+=
    typedef intptr_t IntVal;

    <<forward type declarations>>+=
    struct Object;

    <<value payload members>>+=
    Object* object;

    <<value tags>>=
    <<special value tags>>
    <<simple value tags>>
    <<object value tags>>

    <<special value tags>>+=
    Nil,
    Object,
    Int,

    <<value members>>+=
    Value();
    Value(Object* object);
    Value(IntVal intVal);
    bool operator==(Value const& that) const;
    IntVal getInt() const;
    Object* getObject() const;

    <<value protected members>>+=
    typedef uint32_t BasicDirectValueBits;
    Value::Tag getBasicTag() const;
    BasicDirectValueBits getBasic() const;
    void init(Tag tag, BasicDirectValueBits bits);

    <<value protected members>>+=
    static Tag getObjectTag(Object* object);

    <<definitions>>+=
    Value::Tag Value::getTag() const
    {
        Value::Tag basicTag = getBasicTag();
        if(basicTag != Tag::Object)
            return basicTag;
        return getObjectTag(getObject());
    }

### Simple Tagged Values

We are going to define both a simple and a more optimized encoding for values that the runtime could use.
We will start with the simple encoding, and then present the optimized one next.
To control the choice between the two we will use a configuration `#define`:

    <<configuration>>+=
    #define USE_SIMPLE_VALUE_ENCODING 1
    #define USE_OPTIMIZED_VALUE_ENCODING !USE_SIMPLE_VALUE_ENCODING

When it comes to representing tagged values, the simplest thing that could possibly work is to directly store both a tag and a payload:

    <<simple value encoding members>>+=
    Tag _tag;
    Payload _payload;

    <<value payload members>>+=
    #if USE_SIMPLE_VALUE_ENCODING
    typedef IntVal EncodedIntVal;
    IntVal intVal;
    #endif

    <<value members>>+=
    #if USE_SIMPLE_VALUE_ENCODING
        <<simple value encoding members>>
    #endif

    <<definitions>>+=
    #if USE_SIMPLE_VALUE_ENCODING
        <<simple value encoding definitions>>
    #endif


    <<simple value encoding definitions>>+=
    Value::Tag Value::getBasicTag() const
    {
        return _tag;
    }

    Object* Value::getObject() const
    {
        assert(getBasicTag() == Tag::Object);
        return _payload.object;
    }

    IntVal Value::getInt() const
    {
        assert(getBasicTag() == Tag::Int);
        return _payload.intVal;
    }

    Value::BasicDirectValueBits Value::getBasic() const
    {
        assert(getBasicTag() != Tag::Object);
        assert(getBasicTag() != Tag::Int);
        return _payload.bits;
    }

    Value::Value()
    {
        _tag = Tag::Nil;
        _payload.bits = 0;
    }

    Value::Value(Object* object)
    {
        _tag = Tag::Object;
        _payload.object = object;
    }

    Value::Value(IntVal intVal)
    {
        _tag = Tag::Int;
        _payload.intVal = intVal;
    }

    void Value::init(Value::Tag tag, BasicDirectValueBits bits)
    {
        assert(tag != Tag::Object);
        _tag = tag;
        _payload.bits = bits;
    }

    bool Value::operator==(Value const& that) const
    {
        return (this->_tag == that._tag)
            && (this->_payload.bits == that._payload.bits);
    }

### Optimized Value Encoding

    <<value members>>+=
    #if USE_OPTIMIZED_VALUE_ENCODING
        <<optimized value encoding members>>
    #endif

    <<definitions>>+=
    #if USE_OPTIMIZED_VALUE_ENCODING
        <<optimized value encoding definitions>>
    #endif

    <<optimized value encoding members>>+=
    Payload payload;

    <<optimized value encoding definitions>>+=
    Value::Tag Value::getTag() const
    {
        Payload::Bits bits = _payload.bits;
        if(bits == 0) return Tag::Nil;
        if((bits & OBJECT_TAG_MASK) == 0) return Tag::Object;
        if(bits & 1) return Tag::Int;
        return Tag((bits & DIRECT_TAG_MASK) >> 1) + 2;
    }

    <<value payload members>>+=
    #if USE_OPTIMIZED_VALUE_ENCODING
    struct EncodedIntVal
    {
    };
    EncodedIntVal intVal;
    #endif


    <<before value payload>>+=
    struct EncodedIntVal
    {

    };

    <<optimized value encoding members>>+=
    enum
    {
        OBJECT_TAG_BITS = 3,
        OBJECT_TAG_MASK = (1 << OBJECT_TAG_BITS) - 1,

        DIRECT_TAG_BITS = 8,
        DIRECT_TAG_MASK = (1 << DIRECT_TAG_BITS) - 1,
    }

    Object* Value::getObject() const
    {
        assert(getTag() == Tag::Object);
        return _payload.object;
    }

    IntVal Value::getInt() const
    {
        assert(getTag() == Tag::Int);
        return _payload.intVal >> 1;
    }

    Value::BasicDirectValueBits Value::getBasic() const
    {
        assert(getTag() != Tag::Object);
        assert(getTag() != Tag::Int);
        return _payload.bits >> DIRECT_TAG_BITS;
    }

    Value::Value()
    {
        _payload.bits = 0;
    }

    Value::Value(Object* object)
    {
        _payload.object = object;
    }

    Value::Value(IntVal intVal)
    {
        // TODO: assertions around range!
        _payload.intVal = (intVal << 1) | 1;
    }

    void Value::init(Value::Tag tag, BasicDirectValueBits bits)
    {
        assert(tag != Tag::Object);
        assert(tag != Tag::IntVal);
        _payload.bits = (bits << DIRECT_TAG_BITS) | (tag + 2) << 1;
    }

    bool Value::operator==(Value const& that) const
    {
        return this->_payalad.bits == that->_payload.bits;
    }

    <<value declarations>>+=
    bool areValuesIdentical(Value left, Value right)
    {
        return left == right;
    }

### Objects

    <<forward type declarations>>+=
    struct Object;

    <<object value tags>>=
    #define OBJECT_CASE(NAME) NAME,
    <<object cases>>
    #undef OBJECT_CASE

    <<value declarations>>+=
    <<object type representation>>
    struct Object
    {
        virtual ~Object() {}

        <<object members>>
    };

    <<object members>>+=
    ObjectType type;
    Object(ObjectType type)
        : type(type)
    {}

    <<value members>>+=
    Object* asObject(Tag tag) const;

    <<definitions>>+=
    Object* Value::asObject(Tag tag) const
    {
        return getTag() == tag ? getObject() : nullptr;
    }




### Integers

We will start off slowly by defining a type `Int` for integer values.
We start with a type tag to identify our new type of values.

For convenience we define a subroutine `makeInt` for making integer values.

Next, we define a way to test if a given `Value` is an integer.

    <<forward type declarations>>+=
    struct IntValProxy;

    <<value members>>+=
    IntValProxy* asInt() const;

    <<value declarations>>+=
    struct IntValProxy : Value
    {
        operator IntVal() const { return getInt(); }
    };

	<<definitions>>+=
    IntValProxy* Value::asInt() const
    {
        return (getTag() == Value::Tag::Int) ? (IntValProxy*)this : nullptr;
    }

Printing an `Int` is straightforward:

	<<print cases>>+=
	case Value::Tag::Int:
		printf("%lld", (long long) *value.asInt());
		break;

### Booleans

Next we need a type for Boolean truth values.

    <<simple value tags>>+=
    Bool,

There can only be two possible Boolean values, so rather than
create them on the fly, we will create them once and re-use them.

    <<forward type declarations>>+=
    struct BoolValue;

    <<value declarations>>+=
    struct BoolValue : Value
    {
        operator bool() const { return getBasic() != 0; }
    };

    <<value members>>+=
    Value(bool value);
    BoolValue* asBool();

	<<definitions>>+=
    Value::Value(bool value)
    {
        init(Tag::Bool, value ? 1 : 0);
    }

    BoolValue* Value::asBool()
    {
        return getTag() == Tag::Bool ? (BoolValue*)this : nullptr;
    }

Next, we define a way to test if a given `Value` is a Boolean.

	<<print cases>>+=
	case Value::Tag::Bool:
        puts(*value.asBool() ? "true" : "false");
		break;

### Errors

    <<simple value tags>>=
    TYPE_TAG_ERROR,
    TYPE_TAG_VOID,

### Nil

We define nil as its own  type of object:

    <<value members>>+=
    static Value getNil() { return Value(); }
    bool isNil() const { return getTag() == Tag::Nil; }

### Strings

TODO: logic to allocate and manage strings

### Symbols

    <<object cases>>+=
    OBJECT_CASE(Symbol)

	<<value declarations>>+=
    <<string declarations>>
	struct Symbol : Object
	{
        Symbol();

        StringSpan text;
		<<additional symbol members>>
	};

	<<additional symbol members>>=
    static Symbol* get(StringSpan const& text);
    StringSpan getText() { return text; }

	<<definitions>>+=
    Symbol::Symbol()
        : Object(GET_OBJECT_TYPE(Symbol))
    {}
	Symbol* Symbol::get(StringSpan const& text)
	{
		<<try to find existing symbol>>

        size_t size = text.getSize();
        char* buffer = (char*) malloc(size + 1);
        memcpy(buffer, text.begin(), size);
        buffer[size] = 0;

		Symbol* result = new Symbol();
		result->text = StringSpan(buffer, size);
		<<add new symbol>>
        return result;
	}



	<<additional symbol members>>=
	Symbol* next;

	<<try to find existing symbol>>=
	static Symbol* gSymbols = NULL;
	for(Symbol* sym = gSymbols; sym; sym = sym->next)
	{
		if(sym->getText() == text)
            return sym;
	}

	<<add new symbol>>=
	result->next = gSymbols;
	gSymbols = result;


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


### Printing Values

In order to display the results of computation, we need a way to print out values.
The way we print values will, in general, depend on their type:

	<<value declarations>>+=
	void print(Value value);

	<<definitions>>+=
	void print(Value value)
	{
		<<print implementation>>
	}

	<<print implementation>>=
	switch(value.getTag())
	{
		<<print cases>>
	}

We define a fallback case for `print` to handle any types that don't have a convenient textual representation.

	<<print cases>>
	default:
		printf("<unknown>");
		break;


### Primitive Functions

    <<value declarations>>+=
    typedef Value PrimitiveFuncResult;
    struct PrimitiveFuncContext;
    typedef PrimitiveFuncResult (PrimitiveFuncContext::*PrimitiveFunc)();
    #define PRIMITIVE_FUNC(NAME) &PrimitiveFuncContext::primitive_##NAME

    struct PrimitiveFuncContext
    {
        <<primitive func context members>>

        Value readArg();
        IntVal readIntArg();
        PrimitiveFuncResult returnNil();

    #define PRIMITIVE_FUNC_DECL(NAME) PrimitiveFuncResult primitive_##NAME()
        <<primitive func declarations>>
    #undef PRIMITIVE_FUNC_DECL
    };

    <<once:primitive func declarations>>+=

    PRIMITIVE_FUNC_DECL(print);
    PRIMITIVE_FUNC_DECL(exit);

    #define PRIMITIVE_INT_OP(NAME, OP)                  \
        PRIMITIVE_FUNC_DECL(NAME)                \
        {                                               \
            IntVal left = readIntArg();                 \
            IntVal right = readIntArg();                \
            return left OP right;              \
        }

    PRIMITIVE_INT_OP(add, +)
    PRIMITIVE_INT_OP(sub, -)
    PRIMITIVE_INT_OP(mul, *)
    PRIMITIVE_INT_OP(div, /)

    #define PRIMITIVE_INT_CMP_OP(NAME, OP)              \
        PRIMITIVE_FUNC_DECL(NAME)          \
        {                                           \
            IntVal left = readIntArg();   \
            IntVal right = readIntArg();  \
            return left OP right;          \
        }

    PRIMITIVE_INT_CMP_OP(cmp_gt, >)

    <<definitions>>+=
    #define PRIMITIVE_FUNC_DEF(NAME) PrimitiveFuncResult PrimitiveFuncContext::primitive_##NAME()
    <<primitive func definitions>>
    #undef PRIMITIVE_FUNC_DEF

    <<definitions>>+=
    IntVal PrimitiveFuncContext::readIntArg()
    {
        return readArg().getInt();
    }

    <<primitive func definitions>>+=
    PRIMITIVE_FUNC_DEF(exit)
	{
		exit(0);
	}
    PRIMITIVE_FUNC_DEF(print)
	{
		Value arg = readArg();
        print(arg);
        return Value::getNil();
	}

