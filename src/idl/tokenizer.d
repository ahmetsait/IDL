module idl.tokenizer;

import std.algorithm;
import std.array;
import std.string;

struct Token
{
	string str;
	size_t line, col;
	
	//string toString() const
	//{
	//	import std.format;
	//	return format(`"%s"[line: %d col: %d] `, str, line, col);
	//}
}

/// This function tokenizes LF2 data and returns a Token array.
/// Returned tokens' slices point to the given string.
Token[] tokenize(string data) pure
{
	static immutable ubyte[] delimeters = " \r\n\t".representation;
	
	auto slices = appender!(Token[]);
	
	bool inToken = false;
	size_t tokenStart = 0, tokenCol = 1, tokenLine = 1;
	
	size_t line = 1, col = 1;
	
	foreach(i, ch; data.representation)
	{
		if (delimeters.canFind(ch))
		{
			if (inToken)
			{
				slices ~= Token(data[tokenStart .. i], tokenLine, tokenCol);
				inToken = false;
			}
		}
		else
		{
			if (!inToken)
			{
				inToken = true;
				tokenStart = i;
				tokenLine = line;
				tokenCol = col;
			}
		}
		
		if(ch == '\n')
		{
			line++;
			col = 1;
		}
		else
			col++;
	}
	if (inToken)
		slices ~= Token(data[tokenStart .. $], tokenLine, tokenCol);
	
	return slices[];
}
