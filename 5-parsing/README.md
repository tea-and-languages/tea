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

    <<token declarations>>+=
    enum TokenCode
    {
        TOK_EOF = -1,
        <<token codes>>
    };

    <<token declarations>>+=
    struct Token
    {
        TokenCode code;
        SourceLoc loc;
    };

Lexer
-----

    <<lexer declarations>>+=
    TokenCode lexTokenImpl(InputStream& stream);
    Token lexToken(InputStream& stream)
    {
        Token token;
        token.loc = getLoc(stream);
        token.code = lexTokenImpl(stream);
        return token;
    }

Parser
------

    <<parser declarations>>+=
    struct Parser
    {
        InputStream*    stream;
        Token           token;

        void expect(TokenCode code) {}
    };


Structure
---------

    //<<lexer and parser>>=
    <<token declarations>>
    <<lexer declarations>>
    <<parser declarations>>
