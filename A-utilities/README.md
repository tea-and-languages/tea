Utilities
=========

This section defines utility code that is shared across all the language implementations.


	//<<`InputStream` members>>=
	const char* cursor = nullptr;
	const char* end    = nullptr;
    SourceLoc   loc;
	virtual void refill() {}

	<<definitions>>+=
	bool isAtEnd(InputStream& stream)
	{
		if(stream.cursor == stream.end)
		{
			stream.refill();
		}
		return stream.cursor == stream.end;
	}

	//<<definitions>>+=
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

	//<<definitions>>+=
	int peekChar(InputStream& stream)
	{
		if(isAtEnd(stream))
			return EOF;

		return *stream.cursor;
	}

    //<<definitions>>+=
    SourceLoc getLoc(InputStream& stream)
    {
        return stream.loc;
    }

Standard Input
==============

	<<definitions>>+=
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

	<<declarations>>+=
	<<character classification declarations>>

	<<once:character classification declarations>>+=
	bool isSpace(int c);
	bool isDigit(int c);
	bool isAlpha(int c);
	bool isAlphaNum(int c);
    bool isIdentifierStart(int c);
    bool isIdentifier(int c);

	<<definitions>>+=
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

	<<declarations>>+=
	<<array declarations>>

	<<once:array declarations>>+=
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

		void clear()
		{
			count = 0;
		}

		T const* begin() const { return elements; }
		T const* end() const { return elements + count; }

    private:
        T* elements = nullptr;
        int count = 0;
        int capacity = 0;
    };

Strings
-------

	<<declarations>>+=
	<<string declarations>>

	<<once:string declarations>>+=
	struct StringSpan
	{
		StringSpan()
		{}

		StringSpan(char const* begin, char const* end)
			: _begin(begin)
			, _end(end)
		{}

		StringSpan(const char* begin, size_t size)
			: _begin(begin)
			, _end(begin + size)
		{}

		template<size_t N>
		StringSpan(const char (&text)[N])
			: _begin(text)
			, _end(text + N-1)
		{}

		size_t getSize() const { return _end - _begin; }

		char const* begin() const { return _begin; }
		char const* end() const { return _end; }

		char const* _begin = nullptr;
		char const* _end = nullptr;

		bool operator==(StringSpan const& that) const;
	};

	<<definitions>>+=
	bool StringSpan::operator==(StringSpan const& that) const
	{
		size_t size = getSize();
		if(size != that.getSize())
			return false;

		return memcmp(begin(), that.begin(), size) == 0;
	}


	<<declarations>>+=
	<<once:string input stream declarations>>

	<<once:string input stream declarations>>+=
	StringSpan readLine(InputStream& stream);

	<<definitions>>+=
	static Array<char> lineBuffer;
	StringSpan readLine(InputStream& stream)
	{
		lineBuffer.clear();
		for(;;)
		{
			Char c = readChar(stream);
			switch(c)
			{
			default:
				lineBuffer.add(c);
				continue;

			case EOF:
				break;

			case '\r': case '\n':
				lineBuffer.add('\n');
				break;
			}
			break;
		}
		lineBuffer.add(0);

		return StringSpan(lineBuffer.begin(), lineBuffer.end()-1);
	}

	<<declarations>>+=
	<<input stream declarations>>
	<<string declarations>>
	<<string input stream declarations>>

	<<string input stream declarations>>+=
	struct StringInputStream : InputStream
	{
		StringInputStream(StringSpan const& span)
		{
			cursor = span.begin();
			end = span.end();
		}

		void refill()
		{}
	};

	<<declarations>>+=
	struct StringBuffer
	{
	public:
		StringSpan getText() const
		{
			return StringSpan(data.begin(), data.end());
		}

		void reset()
		{
			data.clear();
		}

		void writeChar(Char c)
		{
			data.add(c);
		}

	private:
		Array<char> data;
	};
