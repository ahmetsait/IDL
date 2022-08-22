module idl.datatxt;

import core.stdc.stdlib;

pragma(lib, "user32");
import core.sys.windows.windef;
import core.sys.windows.winbase;
import core.sys.windows.winuser;

import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.string;
import std.traits;

import idl.lf2;
import idl.tokenizer;
import idl.util;

struct ObjectData
{
	int id;
	ObjectType type;
	immutable(char)* file;
	int fileLength;
}

struct BackgroundData
{
	int id;
	immutable(char)* file;
	int fileLength;
}

/+
struct DataTxt
{
	ObjectData* objects;
	size_t objCount;
	BackgroundData* backgrounds;
	size_t bgCount;
}
+/

alias Dealloc = extern(C) void function(void*) nothrow @nogc;

/// Reads and parses data.txt content, returns the result via its out parameters.
export extern(C) int readDataTxt(
	immutable(char)* dataTxtContent,
	int dataTxtLength,
	out ObjectData* objects,
	out int objCount,
	out BackgroundData* backgrounds,
	out int bgCount,
	out Dealloc dealloc,
	HWND hMainWindow) nothrow
{
	try
	{
		dealloc = &free;
		try
		{
			string dat = dataTxtContent[0 .. dataTxtLength];
			Token[] tokens;
			try
			{
				tokens = tokenize(dat);
			}
			catch(Exception ex)
			{
				MessageBoxA(hMainWindow, toStringz(ex.toString), "[IDL.dll] data.txt Parsing Error", MB_SETFOREGROUND);
				return 1;
			}
			
			for(size_t i = 0; i < tokens.length; i++)
			{
				switch(tokens[i].str)
				{
					case "<object>":
						objects = null;
						// 100 seems fair
						MallocArray!ObjectData objs = MallocArray!ObjectData(100);
						ptrdiff_t obji = -1;
						Lloop1:
						for(i++; i < tokens.length; i++)
						{
							switch(tokens[i].str)
							{
								case "id:":
									objs ~= ObjectData();
									obji++;
									objs[obji].id = tokens[++i].str.to!int;
									break;
								case "type:":
									if(obji < 0)
										continue Lloop1;
									objs[obji].type = cast(ObjectType)tokens[++i].str.to!(OriginalType!ObjectType);
									break;
								case "file:":
									if(obji < 0)
										continue Lloop1;
									i++;
									objs[obji].file = tokens[i].str.ptr;
									objs[obji].fileLength = tokens[i].str.length;
									break;
								case "<object_end>":
									objects = objs.ptr;
									objCount = objs.length;
									break Lloop1;
								default:
									// Ignore
									break;
							}
						}
						break;
					case "<background>":
						backgrounds = null;
						// 20 seems fair
						MallocArray!BackgroundData bgs = MallocArray!BackgroundData(20);
						size_t bgi = -1;
						Lloop2:
						for(i++; i < tokens.length; i++)
						{
							switch(tokens[i].str)
							{
								case "id:":
									bgs ~= BackgroundData();
									bgi++;
									bgs[bgi].id = tokens[++i].str.to!int;
									break;
								case "file:":
									if(bgi < 0)
										continue Lloop2;
									i++;
									bgs[bgi].file = tokens[i].str.ptr;
									bgs[bgi].fileLength = tokens[i].str.length;
									break;
								case "<background_end>":
									backgrounds = bgs.ptr;
									bgCount = bgs.length;
									break Lloop2;
								default:
									// Ignore
									break;
							}
						}
						break;
					default:
						// Ignore
						break;
				}
			}
		}
		catch(Exception ex)
		{
			MessageBoxA(hMainWindow, toStringz(ex.toString), "[IDL.dll] data.txt Reading Error", MB_SETFOREGROUND);
			return -1;
		}
		catch(Error err)
		{
			MessageBoxA(hMainWindow, toStringz(err.toString), "[IDL.dll] Fatal Error", MB_SETFOREGROUND);
			return int.max;
		}
	}
	catch(Throwable)
	{
		return int.min;
	}
	return 0;
}
