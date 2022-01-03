Preliminaries
=============

Philosophy
----------

Our goal is to present a diverse set of programming languages, via working implementations, in a way that is both enjoyable to read and informative.
These goals are often in tension, and we will discuss here the guiding principles that shaped our approach.

### Terminology

Whenever possible, we will strive to use uniform terminology for concepts across all the languages we present, even in cases where the history, community, and traditions of those languages use other terms.
This is a trade-off, but one that we feel is appropriate.
When reading our discussion of a language you are already familiar with, you may find it irksome when we do not use the terms you are used to; we hope that your familiarity with the underlying concepts will prevent any great confusion.
On the other hand, when reading about languages you don't already know, you may benefit from being able to easily relate those concepts tha appear in more than one implementation.

### Implementation Language

All of the implementations we will present are in plain C (C89 to be precise).

Using a single language for all the code simplifies comparisons between implementations.
It also means that we can share code between the language implementations when it is convenient to do so.

We chose C as our implementation language, over various higher-level languages, because we want to make the low-level details of our implementations clear, and give readers confidence that there are no details being swept under the rug.
For example, if we had chosen an implementation language that supported automatic garbage collection, it might have obscured the language implementation choices that pertain to memory management.

### Completeness of Implementations

The language implementations here are not suitable for day-to-day use in solving real problems.
They typically do not support all the language features and library operations of a full implementation of the same language.
Error checking, diagnostic messages, and runtime robustness are typically also incomplete.

We hope that readers will see that incompleteness is a deliberate choice.
Our goal is to impart the flavor of each language, and communicate certain unique aspects of its implementation.
Readers who want to explore more are encouraged to seek out more advanced implementations with established communities.

Literate Programming
--------------------

The literate programming methodology was developed by Donald Knuth, based on the idea that programs should first and foremost be written for consumption by humans, rather than machines.
A literate program is authored in a combination of a document formatting language and a programming language.
In the case of this book, we use Markdown as our formatting language and C as the programming language.
The literate programming syntax used for this work is a custom one, inspired primarily by the notation used in Matt Pharr et al.'s book [Physically-Based Rendering: from Theory to Implementation](http://pbr-book.org).

A literate program can contain ordinary prose, and it can also contain code blocks:

    int main(int argc, char** argv)
    {
        printf("Hello, World!");
        return 0;
    }

An arbitrary code block does not, however, get included when a literate program is compiled for execution.
Code blocks that can be included in the compiled program must use the syntax for a *scrap* (sometimes called a "fragment").
For example:

    //<<Hello World program>>=
    int main(int argc, char** argv)
    {
        <<print the greeting>>
        return 0;
    }

The prefix in `<<...>>=` marks this code block as a *scrap definition*.
The scrap defined here has a name: `Hello World program`.
It also contains a *scrap reference* to a scrap named `<<print the greeting>>`.
We can define a suitable scrap to match that name as follows:

    <<print the greeting>>=
    printf("Hello, World!");

A custom tool (traditionally called a *tangler*) walks the source text of a literate program to find all of the scrap definitions and references.
The tangler then outputs one or more files of code where any references to a scrap are replaced with its definition.

Shared Utilities
----------------

Certain utilities

Error Handling
--------------

    <<source location declarations>>=
    struct SourceLoc
    {
        const char* file = NULL;
        int line = 0;
        int column = 0;
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
        fprintf(stderr, "\n");
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
    <<utility declarations>>
	<<utility code>>
    <<options declarations>>
    <<options code>>
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
        <<parse options>>

        <<program initialization>>

        <<register language primitives>>

        <<read in the prelude>>

        <<read files specified on command line>>

        <<run interactive interpreter>>

        return 0;
    }

#### Options Parsing Nonsense

    //<<options declarations>>=
    struct Options
    {
        <<options members>>
    };
    Options gOptions;

    <<options members>>+=
    const char* programName; // the name that this application was invoked with

    <<options members>>+=
    const char* const* sourceFiles;
    int sourceFileCount;

    //<<options code>>=
    void parseOptions(Options* outOptions, int argc, char** argv)
    {
        char** argCursor = argv;
        char** argsEnd = argCursor + argc;

        char** sourceFiles = argv;
        outOptions->sourceFiles = (const char* const*) sourceFiles;

        if(argCursor != argsEnd)
        {
            outOptions->programName = *argCursor++;
        }

        while(argCursor != argsEnd)
        {
            char const* arg = *argCursor++;
            if(arg[0] == '-')
            {
                // TODO: actually do something here!
            }
            else
            {
                // No `-` prefix? Then it is a source file...
                *sourceFiles++ = (char*)arg;
                outOptions->sourceFileCount++;
            }
        }

        while(argCursor != argsEnd)
        {
            *sourceFiles++ = *argCursor++;
            outOptions->sourceFileCount++;
        }
    }

    <<parse options>>+=
    parseOptions(&gOptions, argc, argv);


#### Handling Input Files

    <<forward declarations>>+=
    void readSourceFile(const char* path);
    void readSourceStream(InputStream& stream);

    //<<read files specified on command line>>=
    printf("About to read %d input files\n", gOptions.sourceFileCount);
    for(int i = 0; i < gOptions.sourceFileCount; i++)
    {
        char const* sourceFilePath = gOptions.sourceFiles[i];
        printf("About to read: %s\n", sourceFilePath);
        readSourceFile(sourceFilePath);
    }

	<<subroutines>>+=
    void readSourceFile(const char* path)
    {
        SourceLoc loc;
        loc.file = path;
        loc.line = 0;
        loc.column = 0;

        FILE* file = fopen(path, "rb");
        if(!file)
        {
            error(loc, "couldn't open the file");
            return;
        }

        fseek(file, 0, SEEK_END);
        size_t fileSize = ftell(file);
        fseek(file, 0, SEEK_SET);

        char* data = (char*) malloc(fileSize + 1);
        fread(data, fileSize, 1, file);
        data[fileSize] = 0;

    	InputStream fileStream;
        fileStream.cursor = data;
        fileStream.end = data + fileSize;

        readSourceStream(fileStream);
    }


