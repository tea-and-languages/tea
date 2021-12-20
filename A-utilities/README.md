Utilities
=========

This section defines utility code that is shared across all the language implementations.


	//<<`InputStream` members>>=
	const char* cursor = nullptr;
	const char* end    = nullptr;
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

		return *stream.cursor++;
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
        // TODO: actually track it!
        return SourceLoc();
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




Exercise for the reader: extend the `readChar()` and `peekChar()` routines to support UTF-8 encoded input.