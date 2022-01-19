Lexing and Parsing
==================

The languages we have covered so far have had only minimal syntax.
In order to cope with the increasing complexity of syntax in the languages that follow, we will now take the time to start the implementation of a lexer and parser.

A *lexer* (sometimes called a scanner or tokenizer) is responsible for breaking the sequence of characters in an input stream into individiaul "words," known as *tokens*.
A token might be a number, an identifier, a string literal, etc.

A *parser* is responsible for analyzing a sequence of tokens and recognizing the hierarchical structure of a given language.
If tokens are like words, then a parser is responsible for recognizing phrases, sentences, and paragraphs.

Tokens
------

    <<declarations>>+=
    <<token declarations>>

    <<once:token declarations>>+=
    enum TokenCode
    {
        TOK_EOF = -1,
        TOK_INVALID = 0,
        <<token codes>>
    };

    <<token declarations>>+=
    struct Token
    {
        TokenCode   code;
        SourceLoc   loc;
        Value       value;
    };
    const char* getTokenName(TokenCode code);

    <<definitions>>+=
    const char* getTokenName(TokenCode code)
    {
        return "TODO";
    }

Lexer
-----

    <<declarations>>+=
    <<lexer declarations>>

    <<once:lexer declarations>>+=
    <<token declarations>>
    struct Lexer
    {
        InputStream* stream;

        void init(InputStream* stream)
        {
            this->stream = stream;
        }

        int peek() { return peekChar(*stream); }
        int get() { return readChar(*stream); } 

        SourceLoc getLoc() { return ::getLoc(*stream); }
        Token lexToken();
        TokenCode lexTokenImpl(Value* outValue);
    };

    <<definitions>>+=
    TokenCode Lexer::lexTokenImpl(Value* outValue)
    {
        int c = get();
        switch(c)
        {
            <<lexer cases>>
        }    
        <<lexer trailing cases>>
        <<handle unknown input in lexer>>
    }

    Token Lexer::lexToken()
    {
        for(;;)
        {
            Token token;
            token.loc = getLoc(); // TODO: start/end loc in range?
            token.code = lexTokenImpl(&token.value);
            <<filter out unwanted tokens>>
            return token;
        }
    }

    <<handle unknown input in lexer>>=
    error(getLoc(), "unexpected character '%c'", c);
    return TOK_INVALID;

### Whitespace
    <<lexer cases>>+=
    case EOF: return TOK_EOF;

### Whitespace

    <<lexer cases>>+=
    case '\n': return TOK_NEWLINE;

    <<token codes>>+=
    TOK_NEWLINE,
    TOK_WHITESPACE,

    <<lexer cases>>+=
    #define CASE_HORIZONTAL_SPACE case ' ': case '\t'
    CASE_HORIZONTAL_SPACE:
        {
            for(;;)
            {
                int d = peek();
                switch(d)
                {
                CASE_HORIZONTAL_SPACE:
                    continue;

                default:
                    return TOK_WHITESPACE;
                }
            }
        }

    <<filter out unwanted tokens>>=
    switch(token.code)
    {
    default:
        break;
    <<unwanted token cases>>
        continue;
    }

    <<unwanted token cases>>+=
    case TOK_NEWLINE:
    case TOK_WHITESPACE:

### Punctuation

    <<token codes>>+=
    TOK_SEMI,
    TOK_LPAREN,
    TOK_RPAREN,
    TOK_PLUS,

    <<lexer cases>>+=
    case ';': return TOK_SEMI;
    case '(': return TOK_LPAREN;
    case ')': return TOK_RPAREN;
    case '+': return TOK_PLUS; // TODO: multi-character operators like `++`

### Numbers

    <<token codes>>+=
    TOK_INTEGER_LITERAL,

    <<lexer cases>>+=
    #define CASE_DIGIT \
        case '0': case '1': case '2': case '3': case '4': \
        case '5': case '6': case '8': case '9'

    CASE_DIGIT:
        {
            int value = c - '0';
            for(;;)
            {
                int d = peek();
                switch(d)
                {
                CASE_DIGIT:
                    value = value*10 + d-'0';
                    continue;

                default:
                    *outValue = value;
                    return TOK_INTEGER_LITERAL;
                }
            }
        }

### Identifiers

    <<token codes>>+=
    TOK_IDENTIFIER,

    <<lexer trailing cases>>+=
    if(isIdentifierStart(c))
    {
        Array<char> buffer;
        buffer.add(char(c));
        while(isIdentifier(peek()))
        {
            buffer.add(char(get()));
        }
        buffer.add(0);

        *outValue = Symbol::get(StringSpan(buffer.begin(),  buffer.end()));

        if(peek() == ':')
        {
            get();
            return TOK_KEYWORD;
        }

        return TOK_IDENTIFIER;
    }

    <<token codes>>+=
    TOK_KEYWORD,

### Symbols

    <<token codes>>+=
    TOK_SYMBOL_LITERAL,

    <<lexer cases>>+=
    case '#':
        {
            if(isIdentifierStart(peek()))
            {
                Array<char> buffer;
                while(isIdentifier(peek()))
                {
                    buffer.add(char(get()));
                }
                buffer.add(0);

                *outValue = Symbol::get(StringSpan(buffer.begin(), buffer.end()));

                return TOK_SYMBOL_LITERAL;
            }
        }
        break;



Parser
------

    <<once:parser declarations>>+=
    <<lexer declarations>>
    <<bytecode declarations>>
    struct Parser
    {
        Lexer*  lexer;
        Token   token;
        int64_t state = 0;
        bool    isRecovering = false;

        BytecodeEmitter bytecode;

        void advance()
        {
            token = lexer->lexToken();
            state++;
        }

        TokenCode peekTokenCode() { return token.code; }

        void unexpected(char const* message)
        {
            if(!isRecovering)
            {
                error(token.loc, "unexpected token; expected a %s", message);
                isRecovering = true;
            }
            // TODO: recover!!!
        }

        void unexpected(TokenCode expected)
        {
            if(!isRecovering)
            {
                error(token.loc, "unexpected token; expected a %s", getTokenName(expected));
                isRecovering = true;
            }
            // TODO: recover at next token that matches `expected`.
        }

        bool expect(TokenCode expected)
        {
            if(peekTokenCode() == expected)
            {
                advance();
                return true;
            }
            unexpected(expected);
            return false;
        }

        bool advanceIf(TokenCode code)
        {
            if(peekTokenCode() == code)
            {
                advance();
                return true;
            }
            return false;
        }

        void init(Lexer* lexer);

        void parseSourceUnit();
        void parseTopLevelItem();

        // TODO: return values?
        void parseStmt();

        <<parser members>>
    };

    <<definitions>>+=
    void Parser::init(Lexer* lexer)
    {
        this->lexer = lexer;
        advance();
    }
    void Parser::parseSourceUnit()
    {
        int64_t lastState = state;
        while(peekTokenCode() != TOK_EOF)
        {
            parseTopLevelItem();
            if(state == lastState)
                return;
            lastState = state;
        }

        bytecode.emitPushNil();
        bytecode.emitReturn();
    }

### Expressions

    <<parser members>>+=
    typedef int ExprResult;
    ExprResult parseExpr();

#### Simple Expressions

    <<parser members>>+=
    ExprResult parseSimpleExpr();
    ExprResult identifierExpr(Value name);

    <<definitions>>+=
    Parser::ExprResult Parser::parseSimpleExpr()
    {
        switch(peekTokenCode())
        {
        case TOK_LPAREN:
            {
                advance();
                ExprResult result = parseExpr();
                expect(TOK_RPAREN);
                return result;
            }
            break;

        case TOK_INTEGER_LITERAL:
        case TOK_SYMBOL_LITERAL:
            {
                Value value = token.value;
                advance();
                return bytecode.emitConstant(value);
            }

        case TOK_IDENTIFIER:
            {
                Value name = token.value;
                advance();

                return identifierExpr(name);
            }

        default:
            unexpected("expected an expression");

                // TODO: meaningful return value...
            return 0;
        }
    }
    Parser::ExprResult Parser::identifierExpr(Value name)
    {
        // TODO: need to handle the case of local bindings...

        return bytecode.emitLoadGlobal(name);
    }


### Postfix Expressions

    <<parser members>>+=
    ExprResult parsePostfixExpr();

    <<definitions>>+=
    Parser::ExprResult Parser::parsePostfixExpr()
    {
        ExprResult result = parseSimpleExpr();

        for(;;)
        {
            switch(peekTokenCode())
            {
            default:
                return result;

            <<postfix expr parsing cases>>
            }
        }
    }

### Prefix Expressions

    <<parser members>>+=
    ExprResult parsePrefixExpr();

    <<definitions>>+=
    Parser::ExprResult Parser::parsePrefixExpr()
    {
        switch(peekTokenCode())
        {
        default:
            return parsePostfixExpr();

        <<prefix expr parsing cases>>
        }
    }

Structure
---------

    <<declarations>>+=
    <<token declarations>>
    <<lexer declarations>>
    <<parser declarations>>
