Preliminaries
=============

This section will cover all the "ground rules" that are required to understand the goals of the project and follow along with the later sections.

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


Notes
-----

Terminology: whenever possible we will use uniform terminology for concepts across all languages, even in cases where the history and traditions of those languages involve other terms.
This is a trade-off, but one that we feel is appropriate.
When reading about a language you are already familiar with, you may find it confusing when we do not use the terms you already known.
On the other hand, when reading about languages you don't already know, you will benefit from being able to easily identify concepts that appear in more than one language.

Error Messages
--------------

    <<source location declarations>>=
    struct SourceLoc
    {
        const char* file;
        int line;
        int column;
    };
    enum Severity
    {
        SEVERITY_NOTE,
        SEVERITY_WARNING,
        SEVERITY_ERROR,
        SEVERITY_FATAL,
    };
    static const char* kSeverityNames[] =
    {
        "note",
        "warning",
        "error",
        "fatal",
    };
    void vdiagnose(SourceLoc loc, Severity severity, const char* message, va_list args)
    {
        fprintf(stderr, "%s:%d: %s: ", loc.file, loc.line, kSeverityNames[severity]);
        vfprintf(stderr, message, args);
    }
    void diagnose(SourceLoc loc, Severity severity, const char* message, ...)
    {
        va_list args;
        va_start(args, message);
        vdiagnose(loc, severity, message, args);
        va_end(args);
    }
    void error(SourceLoc loc, const char* message, ...)
    {
        va_list args;
        va_start(args, message);
        vdiagnose(loc, SEVERITY_ERROR, message, args);
        va_end(args);
    }

Reading Input
-------------

Every programming language implementation needs to read input source code, whether it is files of code stored on disk or commands specified interactively via a console.
In this section we will introduce the interface that all of our interpreters will use to read input, but we will defer the implementation to an appendix.

### Basics of Input

A simple implementation of input just needs a type for input streams,

	<<input declarations>>=
	struct InputStream
	{
		<<`InputStream` members>>
	};

and a way to read input one character at a time:

	<<input declarations>>+=
	int readChar(InputStream& stream);

We are intentionally being loose about the term "character" here, and will come back to it later in this section.

When an input stream is at its end, the `readChar()` function will return `-1` (equivalent to the `EOF` macro in the C standard library).

### One Code Point of Lookahead

When reading structured input, it is often helpful to be able to look ahead to the next character that will be returned.

	<<input declarations>>+=
	int peekChar(InputStream& stream);

    SourceLoc getLoc(InputStream& stream);

### Unicode

When we describe the result of `readChar()` or `peekChar()` as a "character," we really mean a Unicode *code point*.
The 7-bit ASCII characters are a strict subset of the Unicode code points, and are the only case our interpreters care about.
Code points do not always correspond one-to-one with what a person thinks of as a written character, but the difference is unimportant for our purposes.

### Classifying Code Points

	<<input declarations>>+=
	bool isSpace(int c);
	bool isDigit(int c);
	bool isAlpha(int c);
	bool isAlphaNum(int c);

	<<input declarations>>+=
	void skipSpace(InputStream& stream);


Memory Management
-----------------

### Reference Counting

### Garbage Collection

Organization of the Interpreter Program
---------------------------------------

    //<<interpreter program>>=
    <<dependencies>>
    <<source location declarations>>
	<<input declarations>>
	<<utility code>>
    <<forward declarations>>
	<<types>>
    <<subroutine declarations>>
	<<subroutines>>
	<<prelude definition>>
    <<main entry point>>

	//<<dependencies>>+=
    #include <assert.h>
    #include <stdarg.h>
	#include <stdio.h>
    #include <stdint.h>
    #include <stdlib.h>
	#include <string.h>
	#include <ctype.h>

 ### The Main Entry Point
 
    //<<main entry point>>=
    int main(int argc, char** argv)
    {
        <<program initialization>>

        <<register language primitives>>

        <<read in the prelude>>

        <<read files specified on command line>>

        <<run interactive interpreter>>

        return 0;
    }