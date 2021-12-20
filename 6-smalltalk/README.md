Smalltalk
=========

    <<utility declarations>>+=
    struct Class;

	<<types>>+=

    struct MessageHandler
    {
        Value           selector;
        // TODO: #of arguments?
        // TODO: bytecode?
        MessageHandler* next;
    };

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

    <<object header fields>>+=
    Class* directClass;

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
    Value invokeMessageHandler(MessageHandler* handler, Value receiver, Value const* args);
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




Outline of the Interpreter
------------------------------------

    <<subroutine declarations>>+=

    //<<file:smalltalk.cpp>>=
    <<interpreter program>>

    //<<utility code>>+=
    <<value declarations>>
