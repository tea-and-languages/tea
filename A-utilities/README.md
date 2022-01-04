Utilities
=========

This section defines utility code that is shared across all the language implementations.


	//<<`InputStream` members>>=
	const char* cursor = nullptr;
	const char* end    = nullptr;
    SourceLoc   loc;
	virtual void refill() {}

	<<utility code>>+=
	bool isAtEnd(InputStream& stream)
	{
		if(stream.cursor == stream.end)
		{
			stream.refill();
		}
		return stream.cursor == stream.end;
	}

	//<<utility code>>+=
	int readChar(InputStream& stream)
	{
		if(isAtEnd(stream))
			return EOF;

        stream.loc.column++;

        int c = *stream.cursor++;
        <<handle end-of-line characters>>
        return c;
	}

    <<handle end-of-line characters>>=
    switch(c)
    {
    case '\r':
        if(peekChar(stream) == '\n')
        {
            stream.cursor++;
        }
    case '\n':
        stream.loc.column = 1;
        stream.loc.line++;
        return '\n';        
    }

	//<<utility code>>+=
	int peekChar(InputStream& stream)
	{
		if(isAtEnd(stream))
			return EOF;

		return *stream.cursor;
	}

    //<<utility code>>+=
    SourceLoc getLoc(InputStream& stream)
    {
        return stream.loc;
    }

Standard Input
==============

	<<utility code>>+=
	#define INPUT_BUFFER_SIZE 1024
	struct StandardInputStream : InputStream
	{
		char buffer[INPUT_BUFFER_SIZE];

		StandardInputStream()
		{}

		void refill()
		{
			cursor = buffer;

			char* writeCursor = buffer;
			for(;;)
			{
				int c = fgetc(stdin);
				if(c == EOF)
					break;

				*writeCursor++ = c;

				if(c == '\n')
					break;
			}
			end = writeCursor;
		}
	};
	StandardInputStream gStandardInput;

Text Utilities
==============

	<<utility declarations>>+=
	bool isSpace(int c);
	bool isDigit(int c);
	bool isAlpha(int c);
	bool isAlphaNum(int c);
    bool isIdentifierStart(int c);
    bool isIdentifier(int c);

	<<utility code>>+=
	void skipSpace(InputStream& stream)
	{
		while(isSpace(peekChar(stream)))
			readChar(stream);
	}

	bool isSpace(int c)
	{
		switch(c)
		{
		default: return false;

		case ' ':  return true;
		case '\t': return true;
		case '\r': return true;
		case '\n': return true;
		}
	}

	bool isDigit(int c)
	{
		return ((c >= '0') && (c <= '9'));
	}

	bool isAlpha(int c)
	{
		return ((c >= 'a') && (c <= 'z'))
			|| ((c >= 'A') && (c <= 'Z'));
	}

	bool isAlphaNum(int c)
	{
		return isAlpha(c) || isDigit(c);
	}
    bool isIdentifierStart(int c)
    {
        return isAlpha(c);
    }
    bool isIdentifier(int c)
    {
        return isAlphaNum(c);
    }


Exercise for the reader: extend the `readChar()` and `peekChar()` routines to support UTF-8 encoded input.

Dynamically-Allocated Arrays
----------------------------

	<<utility declarations>>+=
    template<typename T>
    struct Array
    {
    public:
        int getCount() const { return count; }

        T const* getBuffer() const { return elements; }

        void add(T const& element)
        {
            int neededCapacity = count+1;
            if(capacity < neededCapacity)
            {
                int newCapacity = capacity;
                if(newCapacity < 16) newCapacity = 16;
                while(newCapacity < neededCapacity)
                    newCapacity = (newCapacity * 3) / 2;

                elements = (T*) realloc(elements, newCapacity * sizeof(T));
                capacity = newCapacity;
            }
            elements[count++] = element;
        }

		T& operator[](int index) { return elements[index]; }
		T const& operator[](int index) const { return elements[index]; }

		void removeLast()
		{
			count--;
		}

    private:
        T* elements = nullptr;
        int count = 0;
        int capacity = 0;
    };
