Smalltalk
=========

    <<utility declarations>>+=
    struct Class;

	<<types>>+=
    struct Class
    {
        Object asObject;
    };


    //<<interpreter program>>=
    // hello, world!

    <<object header fields>>+=
    Class* directClass;

Outline of the Interpreter
------------------------------------

    <<subroutine declarations>>+=

    //<<file:smalltalk.cpp>>=
    <<interpreter program>>

    //<<utility code>>+=
    <<value declarations>>
