// Written in D Programming Language
module idl;

pragma(lib, "user32");
import core.memory : GC;
import core.stdc.stdlib : malloc, calloc, free;
import core.stdc.string : memcpy, memset;
import core.sys.windows.threadaux;
import core.sys.windows.windows;
import std.conv : to, wtext, text;
import std.format : format;
import std.range : isInfinite, isIterable, isInputRange;
import std.string : startsWith;
import std.stdio : File;
import std.traits : isSomeString, isArray;
import utf = std.utf;

import processaux;
import lf2;

/// Returns whether a value exists in the given input-range.
/// The semantics of an input range (not checkable during compilation) are
/// assumed to be the following ($(D r) is an object of type $(D InputRange)):
/// $(UL $(LI $(D r.empty) returns $(D false) if there is more data
///		available in the range.)  $(LI $(D r.front) returns the current
///		element in the range. It may return by value or by reference. Calling
///		$(D r.front) is allowed only if calling $(D r.empty) has, or would
///		have, returned $(D false).) $(LI $(D r.popFront) advances to the next
///		element in the range. Calling $(D r.popFront) is allowed only if
///		calling $(D r.empty) has, or would have, returned $(D false).))
bool contains(Range, V)(Range haystack, V needle) if(isInputRange!Range)
{
	static if(isArray!Range)
	{
		static if(isSomeString!Range)
		{
			foreach(element; utf.byCodeUnit(haystack))
				if (element == needle)
					return true;
		}
		else
		{
			foreach(element; haystack)
				if (element == needle)
					return true;
		}
	}
	else
	{
		for ( ; !haystack.empty; haystack.popFront())
		{
			if (haystack.front == needle)
				return true;
		}
	}
	return false;
}

/// Suspend a list of threads to safely read/write the process memory without causing data races.
/// First parameter is a raw pointer to list of thread IDs, second is the length of it, and third is 
/// a BOOL (alias of int) value to indicate whether threads will be suspended (1) or resumed (0).
/// Returns TRUE (1) on success, FALSE (0) otherwise.
export extern(C) int SuspendThreadList(int* threadIds, int length, BOOL bSuspend) nothrow @nogc @system
{
	bool suspend = (bSuspend == TRUE);
	int ret = 0;
	for(size_t i = 0; i < length; i++)
	{
		HANDLE hThread = OpenThread(THREAD_SUSPEND_RESUME, false, threadIds[i]);
		if(hThread != INVALID_HANDLE_VALUE)
		{
			if(suspend)
			{
				if((threadIds[i] = SuspendThread(hThread)) != 0)
				{
					ret = 1;
				}
			}
			else
			{
				if((threadIds[i] = ResumeThread(hThread)) != 1)
				{
					ret = 1;
				}
			}

			CloseHandle(hThread);
		}
		else
		{
			threadIds[i] = ret = int.min;
		}
	}
	
	return ret;
}

/// Sends left mouse button click message to given window handle at {X=380, Y=230} 
/// LF2 somehow does not respond to WM_LBUTTONDOWN x,y coordinates so the function 
/// manually put cursor into the right place.
export extern(C) BOOL SendGameStartMsg(HWND window) nothrow @nogc @system
{
	RECT rect;
	if(GetWindowRect(window, &rect) == FALSE)
		return FALSE;

	//SendMessageA(window, WM_MOUSEMOVE, 15073680, 1); // Not working
	WPARAM xy = (400 | (230 << 16));
	if(SetCursorPos(rect.left + 400, rect.top + 25 + 230) == TRUE)
		SendMessageA(window, WM_LBUTTONDOWN, xy, 1);

	return TRUE;
}

enum TokenState : ubyte
{
	none,
	xml,
	token,
	comment
}

enum TokenType : ubyte
{
	normal,
	xml,
	property,
}

struct Token(S) if(isSomeString!S)
{
	S str;
	size_t line, col;
	TokenType type;

	string toString()
	{
		return format(`"%s"[line: %d col: %d]  `, str, line, col);
	}
}

const string tokenHeads = ['<'], tokenEnds = ['>', ':'], tokenDelims = [' ', '\t', '\n', '\r'], 
	lineEnd = ['\n', '\r'];
enum char lineCommentChar = '#';

/// This function tokenizes LF2 data and returns a slice-array of strings. Returned slices point to the given string.
public Token!S[] parseData(S)(S data, bool includeComments = false) if(isSomeString!S)
{
	debug
	{
		File parserLog = File("parser.log", "wb");
		scope(exit) parserLog.close();
	}
	Token!S[] slices = new Token!S[0];
	slices.reserve(data.length / 5); // Pre-allocate an aprox memory we might need

	TokenState state = TokenState.none;
	size_t tokenStart = 0, tokenCol = 1, tokenLine = 1, line = 1, col = 1;
Lforeach:
	foreach(i, ch; data)
	{
	Lswitch:
		final switch(state)
		{
			case TokenState.none:
				if(tokenDelims.contains(ch))
				{
					break Lswitch;
				}
				else if(tokenHeads.contains(ch)) // <
				{
					state = TokenState.xml;
					tokenStart = i;
					tokenCol = col;
					tokenLine = line;
				}
				else if(tokenEnds.contains(ch)) // > :
				{
					throw new Exception(format("Unexpected token ending delimeter: '%c' in line: %d; at col: %d", ch, line, col));
				}
				else if(ch == lineCommentChar && !includeComments) // #
				{
				    state = TokenState.comment;
				}
				else
				{
					state = TokenState.token;
					tokenStart = i;
					tokenCol = col;
					tokenLine = line;
				}
				break Lswitch;
			case TokenState.xml:
				if(tokenDelims.contains(ch))
				{
					throw new Exception(format("Unexpected token delimeter in line: %d; at col: %d", line, col));
				}
				else if(tokenHeads.contains(ch)) // <
				{
					throw new Exception(format("Unexpected token beginning delimeter: '%c' in line: %d; at col: %d", ch, line, col));
				}
				else if(tokenEnds[0] == ch) // >
				{
					slices ~= Token!S(data[tokenStart .. i + 1], tokenLine, tokenCol, TokenType.xml);
					state = TokenState.none;
				}
				else if(tokenEnds[1] == ch) // :
				{
					throw new Exception(format("Unexpected token ending delimeter: '%c' in line: %d; at col: %d", ch, line, col));
				}
				else if(ch == lineCommentChar && !includeComments) // #
				{
				    throw new Exception(format("Unexpected comment char: '%c' in line: %d; at col: %d", ch, line, col));
				}
				break Lswitch;
			case TokenState.token:
				if(tokenDelims.contains(ch))
				{
					slices ~= Token!S(data[tokenStart .. i], tokenLine, tokenCol);
					state = TokenState.none;
				}
				else if(tokenHeads.contains(ch)) // <
				{
					slices ~= Token!S(data[tokenStart .. i], tokenLine, tokenCol);
					state = TokenState.xml;
					tokenStart = i;
				}
				else if(ch == tokenEnds[0]) // >
				{
					throw new Exception(format("Unexpected token ending delimeter: '%c' in line: %d; at col: %d", ch, line, col));
				}
				else if(ch == tokenEnds[1]) // :
				{
					slices ~= Token!S(data[tokenStart .. i + 1], tokenLine, tokenCol, TokenType.property);
					state = TokenState.none;
				}
				else if(ch == lineCommentChar && !includeComments) // #
				{
				    slices ~= Token!S(data[tokenStart .. i], tokenLine, tokenCol);
				    state = TokenState.comment;
				}
				break Lswitch;
			case TokenState.comment:
				if(lineEnd.contains(ch))
				    state = TokenState.none;
				break Lswitch;
		}
		if(ch == '\n')
		{
			line++;
			col = 1;
		}
		else
			col++;
	}
	switch(state)
	{
		case TokenState.token:
			slices ~= Token!S(data[tokenStart .. $], tokenLine, tokenCol);
			break;
		case TokenState.xml:
			throw new Exception(format("Reached end of file unexpectedly while parsing token: \"%s\" in line: %d; at col: %d", data[tokenStart .. $], line, col));
		default:
			break;
	}
	debug
	{
		size_t ln = 1;
		foreach(t; slices)
		{
			if(ln < t.line)
			{
				parserLog.write("\r\n", t.toString);
				ln = t.line;
			}
			else
				parserLog.write(t.toString);
		}
		parserLog.writeln("\r\n");
		parserLog.close();
	}

	return slices;
}

public void* getStagesAddr(HANDLE hProc) @system
{
	void* addr = null;
	if(ReadProcessMemory(hProc, sGameAddr + sGame.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
		throw new Exception("Could not read process memory: sGamePoint + sGame.files.offsetof");
	if(addr == null)
		throw new Exception("Could not read process memory: LF2 is not started");
	addr += sFileManager.stages.offsetof;
	return addr;
}

public void* getAddrOfObj(HANDLE hProc, int objIndex) @system
{
	void* addr = null;
	if(ReadProcessMemory(hProc, sGameAddr + sGame.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
		throw new Exception("Could not read process memory: sGamePoint + sGame.files.offsetof");
	if(addr == null)
		throw new Exception("Could not read process memory: LF2 is not started");
	if(ReadProcessMemory(hProc, addr + sFileManager.datas.offsetof + objIndex * size_t.sizeof, &addr, size_t.sizeof, null) == FALSE)
		throw new Exception("Could not read process memory: objIndex=" ~ objIndex.to!string);
	return addr;
}

public void* getBackgroundsAddr(HANDLE hProc) @system
{
	void* addr = null;
	if(ReadProcessMemory(hProc, sGameAddr + sGame.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
		throw new Exception("Could not read process memory: sGamePoint + sGame.files.offsetof");
	if(addr == null)
		throw new Exception("Could not read process memory: LF2 is not started");
	addr += sFileManager.backgrounds.offsetof;
	return addr;
}

public void* getAddrOfBackground(HANDLE hProc, int bgIndex) @system
{
	return getBackgroundsAddr(hProc) + sBackground.sizeof * bgIndex;
}

enum DataState : ubyte
{
	none,
	bmp,
	frame,
	weapon_strength_list,
	bdy,
	itr,
	wpoint,
	opoint,
	cpoint,
	bpoint,
	entry,
	stage,
	phase,
	layer
}

export extern(C) int ReadDataTxt(
	wchar* dataTxtFile, int length, 
	ref ObjectData* objects, ref int objCount, 
	ref BackgroundData* backgrounds, ref int bgCount, 
	HWND hMainWindow)
{
	try
	{
		auto dat = dataTxtFile[0 .. length];
		Token!(typeof(dat))[] tokens;
		try
		{
			tokens = parseData(dat, false);
		}
		catch(Exception ex)
		{
			MessageBoxW(hMainWindow, utf.toUTF16z(ex.toString), "[IDL.dll] data.txt Parsing Error", MB_SETFOREGROUND);
			return 1;
		}
		
		for(size_t i = 0; i < tokens.length; i++)
		{
			switch(tokens[i].str)
			{
				case "<object>":
					objects = null;
					ObjectData[] objs = new ObjectData[0];
					objs.reserve(ObjectData.sizeof * 100); //allocate an approx memory we might need
					size_t obji = -1;
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
								objs[obji].type = cast(ObjectType)tokens[++i].str.to!int;
								break;
							case "file:":
								if(obji < 0)
									continue Lloop1;
								i++;
								objs[obji].file = cast(wchar*)malloc(wchar.sizeof * (tokens[i].str.length + 1));
								foreach(j, ch; tokens[i].str)
									objs[obji].file[j] = ch;
								objs[obji].file[tokens[i].str.length] = '\0';
								break;
							case "<object_end>":
								objects = cast(ObjectData*)malloc(ObjectData.sizeof * objs.length);
								memcpy(objects, objs.ptr, objs.length * ObjectData.sizeof);
								objCount = objs.length;
								break Lloop1;
							default:
								//ignore
								break;
						}
					}
					break;
				case "<background>":
					backgrounds = null;
					BackgroundData[] bgs = new BackgroundData[0];
					bgs.reserve(BackgroundData.sizeof * 20); //allocate an approx memory we might need
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
								bgs[bgi].file = cast(wchar*)malloc(wchar.sizeof * (tokens[i].str.length + 1));
								foreach(j, ch; tokens[i].str)
									bgs[bgi].file[j] = ch;
								bgs[bgi].file[tokens[i].str.length] = '\0';
								break;
							case "<background_end>":
								backgrounds = cast(BackgroundData*)malloc(BackgroundData.sizeof * bgs.length);
								memcpy(backgrounds, bgs.ptr, bgs.length * BackgroundData.sizeof);
								bgCount = bgs.length;
								break Lloop2;
							default:
								//ignore
								break;
						}
					}
					break;
				default:
					//ignore
					break;
			}
		}
	}
	catch(Exception ex)
	{
		MessageBoxW(hMainWindow, utf.toUTF16z(ex.toString), "[IDL.dll] data.txt Reading Error", MB_SETFOREGROUND);
		return -1;
	}
	catch(Error err)
	{
		MessageBoxW(hMainWindow, utf.toUTF16z(err.toString), "[IDL.dll] Fatal Error", MB_SETFOREGROUND);
		return int.max;
	}
	return 0;
}

/// Loads decrypted data to LF2's memory using Read/WriteProcessMemory WINAPI functions. Care should be taken to 
/// first call SuspendThreadList on the target process to avoid data races and possible crashes.
/// It's not possible to load images and sounds for objects. layer bitmaps are supported and bgm works in stages.
/// Other than that, this is pure magic.
export extern(C) int InstantLoad(
	char* data, int length, 
	int procId, 
	DataType dataType, 
	int datIndex, 
	ObjectType objType, 
	HWND hMainWindow) @system
{
	try
	{
		try
		{
			auto dat = data[0 .. length];
			Token!(typeof(dat))[] tokens;
			try
			{
				tokens = parseData(dat, dataType == DataType.Stage); //parse comments in stages for LF2 compatibility
			}
			catch(Exception ex)
			{
				MessageBoxW(hMainWindow, utf.toUTF16z(ex.toString), "[IDL.dll] Data Parsing Error", MB_SETFOREGROUND);
				return 1;
			}
			
			HANDLE hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, procId);
			if(hProc == INVALID_HANDLE_VALUE)
				throw new Exception("Could not open process. Error code: " ~ GetLastError().to!string ~ "\r\nMaybe you need Administrator privileges?");
			scope(exit) CloseHandle(hProc);

			if(dataType == DataType.Background)
			{
				void* addr = getAddrOfBackground(hProc, datIndex);

				debug(LogFile)
				{
					File bgLog = File("bg.log", "wb");
					scope(exit) bgLog.close();
					File rbgLog = File("rbg.log", "wb");
					scope(exit) rbgLog.close();
				}

				sBackground rbg = void;

				if(ReadProcessMemory(hProc, addr, &rbg, sBackground.sizeof, null) == FALSE)
					throw new Exception("Could not read process memory: rbg");

				debug(LogFile) rbgLog.write(rbg);

				sBackground bg = void;
				//fill up with zeros
				memset(&bg, 0, sBackground.sizeof);

				bg.unkwn = rbg.unkwn;

				DataState state = DataState.none;
				ptrdiff_t layeri = -1;
			Lbloop1:
				for(size_t i = 0; i < tokens.length; i++)
				{
				Lbswitch1:
					switch(tokens[i].str)
					{
						case "name:":
						{
							string n = utf.toUTF8(tokens[++i].str);
							if(n.length >= bg.name.length)
								throw new Exception(format("length %d for name is overflow, it must be less than %d\r\n%s\r\nline: %d; col: %d", n.length, bg.name.length, n, tokens[i].line, tokens[i].col));
							{
								size_t j;
								for(j = 0; j < n.length; j++)
									bg.name[j] = n[j] == '_' ? ' ' : n[j];
								bg.name[j] = '\0';
							}
							break;
						}
						case "width:":
							bg.bg_width = tokens[++i].str.to!int;
							break;
						case "zboundary:":
							bg.zboundary1 = tokens[++i].str.to!int;
							bg.zboundary2 = tokens[++i].str.to!int;
							break;
						case "shadow:":
						{
							string s = utf.toUTF8(tokens[++i].str);
							if(s.length >= bg.shadow_bmp.length)
								throw new Exception(format("path length %d for shadow is overflow, it must be less than %d\r\n%s\r\nline: %d; col: %d", s.length, bg.shadow_bmp.length, s, tokens[i].line, tokens[i].col));
							{
								size_t j;
								for(j = 0; j < s.length && j < bg.shadow_bmp.length - 1; j++)
									bg.shadow_bmp[j] = s[j];
								bg.shadow_bmp[j] = '\0';
							}
							break;
						}
						case "shadowsize:":
							bg.shadowsize1 = tokens[++i].str.to!int;
							bg.shadowsize2 = tokens[++i].str.to!int;
							break;
						case "layer:":
							layeri++;
							if(layeri >= rbg.layer_count || layeri >= sBackground.layer_bmps.length)
								break;
							{
								string m = utf.toUTF8(tokens[++i].str);
								{
									size_t j;
									for(j = 0; j < m.length; j++)
										bg.layer_bmps[layeri][j] = m[j];
									bg.layer_bmps[layeri][j] = '\0';
								}
							}
							state = DataState.layer;
						Lbloop2:
							for(i++; i < tokens.length; i++)
							{
							Lbswitch2:
								switch(tokens[i].str)
								{
									case "transparency:":
										bg.transparency[layeri] = tokens[++i].str.to!int;
										break;
									case "x:":
										bg.layer_x[layeri] = tokens[++i].str.to!int;
										break;
									case "y:":
										bg.layer_y[layeri] = tokens[++i].str.to!int;
										break;
									case "width:":
										bg.layer_width[layeri] = tokens[++i].str.to!int;
										break;
									case "height:":
										bg.layer_height[layeri] = tokens[++i].str.to!int;
										break;
									case "loop:":
										bg.layer_loop[layeri] = tokens[++i].str.to!int;
										break;
									case "cc:":
										bg.layer_cc[layeri] = tokens[++i].str.to!int;
										break;
									case "c1:":
										bg.layer_c1[layeri] = tokens[++i].str.to!int;
										break;
									case "c2:":
										bg.layer_c2[layeri] = tokens[++i].str.to!int;
										break;
									case "layer_end":
										bg.layer_count = layeri + 1;
										state = DataState.none;
										break Lbloop2;
									default:
										//ignore
										break;
								}
							}
							break;
						default:
							//ignore
							break;
					}
				}
				debug(LogFile) bgLog.write(bg);
				if(WriteProcessMemory(hProc, addr, &bg, sBackground.sizeof, null) == FALSE)
					throw new Exception("Could not write background to process memory");
			}
			else if(dataType == DataType.Stage)
			{
				void* addr = getStagesAddr(hProc);

				debug
				{
					File rstagesLog = File("rstages.log", "wb");
					scope(exit) rstagesLog.close();
				}
				
				//allocate it cuz ReadProcessMemory won't do it for us
				sStage[] rstages = (cast(sStage*)malloc(sStage.sizeof * 60))[0 .. 60];
				if(!rstages)
					throw new Exception("Could not allocate rstages: " ~ (sStage.sizeof * 60).to!string ~ " byte");
				scope(exit) free(rstages.ptr);
				
				if(ReadProcessMemory(hProc, addr, rstages.ptr, (sStage.sizeof * 60), null) == FALSE)
					throw new Exception("Could not read process memory: stages");

				debug
				{
					foreach(i, ref stage; rstages)
					{
						rstagesLog.write(stage.toString(i));
					}

					File stagesLog = File("stages.log", "wb");
					scope(exit) stagesLog.close();
				}

				//start over cleanly
				sStage[] stages = (cast(sStage*)malloc(sStage.sizeof * 60))[0 .. 60];
				if(!stages)
					throw new Exception("Could not allocate stages: " ~ (sStage.sizeof * 60).to!string ~ " byte");
				scope(exit) free(stages.ptr);
				//fill up with zeros
				memset(stages.ptr, 0, sStage.sizeof * 60);
				
				for(size_t i = 0; i < 60; ++i)
				{
					stages[i].phase_count = -1;
					for(size_t j = 0; j < 100; ++j)
					{
						stages[i].phases[j].when_clear_goto_phase = -1;
						for(size_t k = 0; k < 60; ++k)
						{
							stages[i].phases[j].spawns[k].id = -1;
							// because static arrays are value types muhahahaaa:
							stages[i].phases[j].spawns[k].unkwn1 = rstages[i].phases[j].spawns[k].unkwn1;
							stages[i].phases[j].spawns[k].unkwn2 = rstages[i].phases[j].spawns[k].unkwn2;
							stages[i].phases[j].spawns[k].unkwn3 = rstages[i].phases[j].spawns[k].unkwn3;
						}
					}
				}
				DataState state = DataState.none;
			Lloop1:
				for(size_t i = 0; i < tokens.length; i++)
				{
				Lswitch1:
					switch(tokens[i].str)
					{
						case "<stage>":
							state = DataState.stage;
							sStage* stage = cast(sStage*)malloc(sStage.sizeof);
							if(stage == null)
								throw new Exception("Could not allocate stage");
							scope(exit) free(stage);
							stage.phase_count = -1;
							int stageId = -1;
							ptrdiff_t phasei = -1;
						Lloop2:
							for(i++; i < tokens.length; i++)
							{
							Lswitch2:
								switch(tokens[i].str)
								{
									case "id:":
										if(stageId > 0)
											continue Lloop2;
										stageId = tokens[++i].str.to!int;
										break;
									case "<phase>":
										if(phasei >= 100)
											continue Lloop2;
										state = DataState.phase;
										phasei++;
										sPhase phase;
										foreach(ref spn; phase.spawns)
											spn.id = -1;
										phase.when_clear_goto_phase = -1;
										ptrdiff_t spawni = -1;
									Lloop3:
										for(i++; i < tokens.length; i++)
										{
										Lswitch3:
											switch(tokens[i].str)
											{
												case "bound:":
													phase.bound = tokens[++i].str.to!int;
													break;
												case "music:":
													{
														string m = utf.toUTF8(tokens[++i].str);
														if(m.length >= phase.music.length)
															throw new Exception(format("path length %d for phase background music (bgm) is overflow, it must be less than %d\r\n%s\r\nline: %d; col: %d", m.length, phase.music.length, m, tokens[i].line, tokens[i].col));
														{
															size_t j;
															for(j = 0; j < m.length; j++)
																phase.music[j] = m[j];
															phase.music[j] = '\0';
														}
														break;
													}
													break;
												case "id:":
													spawni++;
													if(spawni >= 60)
														break Lloop3;
													phase.spawns[spawni].id = tokens[++i].str.to!int;
													phase.spawns[spawni].hp = 500;
													phase.spawns[spawni].act = 9;
													phase.spawns[spawni].times = 1;
													phase.spawns[spawni].x = 80 + phase.bound;
													break;
												case "x:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].x = tokens[++i].str.to!int;
													break;
												case "hp:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].hp = tokens[++i].str.to!int;
													break;
												case "act:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].act = tokens[++i].str.to!int;
													break;
												case "times:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].times = tokens[++i].str.to!int;
													break;
												case "ratio:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].ratio = tokens[++i].str.to!double;
													break;
												case "reserve:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].reserve = tokens[++i].str.to!int;
													break;
												case "join:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].join = tokens[++i].str.to!int;
													break;
												case "join_reserve:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].join_reserve = tokens[++i].str.to!int;
													break;
												case "<boss>":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].role = 2;
													break;
												case "<soldier>":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].role = 1;
													phase.spawns[spawni].times = 50;
													break;
												case "when_clear_goto_phase:":
													if(spawni < 0)
														continue Lloop3;
													phase.when_clear_goto_phase = tokens[++i].str.to!int;
													break;
												case "<phase_end>":
													stage.phases[phasei] = phase;
													stage.phase_count = phasei + 1;
													state = DataState.stage;
													break Lloop3;
												default:
													//ignore
													break;
											}
										}
										break;
									case "<stage>":
										i--;
										goto case;
									case "<stage_end>":
										if(stageId < 0)
											throw new Exception("Stage id could not be received");
										int m = stageId;
										{
											for(size_t n = 0; n < stage.phases.length; ++n)
											{
												for(size_t k = 0; k < stage.phases[n].spawns.length; ++k)
												{
													// because static arrays are value types muhahahaaa:
													stage.phases[n].spawns[k].unkwn1 = stages[m].phases[n].spawns[k].unkwn1;
													stage.phases[n].spawns[k].unkwn2 = stages[m].phases[n].spawns[k].unkwn2;
													stage.phases[n].spawns[k].unkwn3 = stages[m].phases[n].spawns[k].unkwn3;
												}
											}
										}
										stages[stageId] = *stage;
										debug stagesLog.write((*stage).toString(stageId));
										state = DataState.none;
										break Lloop2;
									default:
										//ignore
										break;
								}
							}
							break;
						default:
							//ignore
							break;
					}
				}
				if(WriteProcessMemory(hProc, addr, stages.ptr, sStage.sizeof * 60, null) == FALSE)
					throw new Exception("Could not write stages to process memory");
			}
			else if(dataType == DataType.Object)
			{
				void* addr = getAddrOfObj(hProc, datIndex);

				debug
				{
					File objLog = File("obj.log", "wb");
					scope(exit) objLog.close();
					File objUnknownLog = File("obj_unknown.log", "wb");
					scope(exit) objUnknownLog.close();
				}

				SYSTEM_INFO sysInfo;
				GetSystemInfo(&sysInfo);
				//dwPageSize is needed to figure out how big RegionSize will be when we allocate ourself
				
				uint allocItrSize = sysInfo.dwPageSize, allocBdySize = sysInfo.dwPageSize;
				
				while(allocItrSize < sItr.sizeof * 5) allocItrSize += sysInfo.dwPageSize;
				while(allocBdySize < sBdy.sizeof * 5) allocBdySize += sysInfo.dwPageSize;

				//allocate it cuz ReadProcessMemory won't do it for us
				sDataFile* RDataFile = cast(sDataFile*)malloc(sDataFile.sizeof);
				if(RDataFile == null)
					throw new Exception("Could not allocate RDataFile: " ~ sDataFile.sizeof.to!string ~ " bytes");
				scope(exit) free(RDataFile);

				if(ReadProcessMemory(hProc, addr, RDataFile, sDataFile.sizeof, null) == FALSE)
					throw new Exception(text("Could not read process memory: RDataFile\r\nAddr=", addr, 
							"\r\ndatId=", datIndex));
				debug
				{
					{
						objUnknownLog.writeln(RDataFile.weapon_strength_list);
						objUnknownLog.writeln(RDataFile.entry_names);
					}
				}

				//start over cleanly
				sDataFile* DataFile = cast(sDataFile*)malloc(sDataFile.sizeof);
				if(DataFile == null)
					throw new Exception("Could not allocate DataFile: " ~ sDataFile.sizeof.to!string ~ " bytes");
				scope(exit) free(DataFile);
				//fill up with zeros
				memset(DataFile, 0, sDataFile.sizeof);

				DataFile.id = RDataFile.id;
				DataFile.type = objType;

				DataFile.unkwn1 = RDataFile.unkwn1;
				//static arrays are value types:
				DataFile.unkwn2 = RDataFile.unkwn2;
				DataFile.unkwn3 = RDataFile.unkwn3;
				DataFile.unkwn4 = RDataFile.unkwn4;
				DataFile.unkwn5 = RDataFile.unkwn5;
				DataFile.unkwn6 = RDataFile.unkwn6;
				DataFile.unkwn7 = RDataFile.unkwn7;

				foreach(i, ref entry; DataFile.weapon_strength_list)
				{
					entry.unkwn1 = RDataFile.weapon_strength_list[i].unkwn1;
					entry.unkwn2 = RDataFile.weapon_strength_list[i].unkwn2;
					entry.unkwn3 = RDataFile.weapon_strength_list[i].unkwn3;
				}
				
				DataFile.pic_count = RDataFile.pic_count;
				DataFile.pic_bmps = RDataFile.pic_bmps;
				DataFile.pic_index = RDataFile.pic_index;
				DataFile.pic_width = RDataFile.pic_width;
				DataFile.pic_height = RDataFile.pic_height;
				DataFile.pic_row = RDataFile.pic_row;
				DataFile.pic_col = RDataFile.pic_col;
				DataFile.small_bmp = RDataFile.small_bmp;
				DataFile.face_bmp = RDataFile.face_bmp;
				
				for(int i = 0; i < DataFile.frames.length; i++)
				{
					DataFile.frames[i].sound = RDataFile.frames[i].sound;
					
					DataFile.frames[i].unkwn1 = RDataFile.frames[i].unkwn1;
					DataFile.frames[i].unkwn2 = RDataFile.frames[i].unkwn2;
					DataFile.frames[i].unkwn3 = RDataFile.frames[i].unkwn3;
					DataFile.frames[i].unkwn4 = RDataFile.frames[i].unkwn4;
					DataFile.frames[i].unkwn5 = RDataFile.frames[i].unkwn5;
					DataFile.frames[i].unkwn6 = RDataFile.frames[i].unkwn6;
					DataFile.frames[i].unkwn7 = RDataFile.frames[i].unkwn7; //static arrays are value types
					DataFile.frames[i].unkwn8 = RDataFile.frames[i].unkwn8;
					DataFile.frames[i].unkwn9 = RDataFile.frames[i].unkwn9;
				}

				DataState state = DataState.none;
			Lcloop1:
				for(size_t i = 0; i < tokens.length; i++)
				{
				Lcswitch1:
					switch(tokens[i].str)
					{
						case "<bmp_begin>":
							state = DataState.bmp;
						Lcloop2:
							for(i++; i < tokens.length; i++)
							{
								if(tokens[i].str.length >= 4 && tokens[i].str[0 .. 4] == "file")
									i += 9; //jump over: file w h row col
								else
								{
								Lcswitch2:
									switch(tokens[i].str)
									{
										case "name:":
										{
											string n = utf.toUTF8(tokens[++i].str);
											if(n.length >= DataFile.name.length)
												throw new Exception(format("length %d for name is overflow, it must be less than %d\r\n%s\r\nline: %d; col: %d", n.length, DataFile.name.length, n, tokens[i].line, tokens[i].col));
											{
												size_t j;
												for(j = 0; j < n.length; j++)
													DataFile.name[j] = n[j];
												DataFile.name[j] = '\0';
											}
											break;
										}
										case "walking_frame_rate":
											DataFile.walking_frame_rate = tokens[++i].str.to!int;
											break;
										case "walking_speed":
											DataFile.walking_speed = tokens[++i].str.to!double;
											break;
										case "walking_speedz":
											DataFile.walking_speedz = tokens[++i].str.to!double;
											break;
										case "running_frame_rate":
											DataFile.running_frame_rate = tokens[++i].str.to!int;
											break;
										case "running_speed":
											DataFile.running_speed = tokens[++i].str.to!double;
											break;
										case "running_speedz":
											DataFile.running_speedz = tokens[++i].str.to!double;
											break;
										case "heavy_walking_speed":
											DataFile.heavy_walking_speed = tokens[++i].str.to!double;
											break;
										case "heavy_walking_speedz":
											DataFile.heavy_walking_speedz = tokens[++i].str.to!double;
											break;
										case "heavy_running_speed":
											DataFile.heavy_running_speed = tokens[++i].str.to!double;
											break;
										case "heavy_running_speedz":
											DataFile.heavy_running_speedz = tokens[++i].str.to!double;
											break;
										case "jump_height":
											DataFile.jump_height = tokens[++i].str.to!double;
											break;
										case "jump_distance":
											DataFile.jump_distance = tokens[++i].str.to!double;
											break;
										case "jump_distancez":
											DataFile.jump_distancez = tokens[++i].str.to!double;
											break;
										case "dash_height":
											DataFile.dash_height = tokens[++i].str.to!double;
											break;
										case "dash_distance":
											DataFile.dash_distance = tokens[++i].str.to!double;
											break;
										case "dash_distancez":
											DataFile.dash_distancez = tokens[++i].str.to!double;
											break;
										case "rowing_height":
											DataFile.rowing_height = tokens[++i].str.to!double;
											break;
										case "rowing_distance":
											DataFile.rowing_distance = tokens[++i].str.to!double;
											break;
										case "weapon_hp:":
											DataFile.weapon_hp = tokens[++i].str.to!int;
											break;
										case "weapon_drop_hurt:":
											DataFile.weapon_drop_hurt = tokens[++i].str.to!int;
											break;
										case "<bmp_end>":
											state = DataState.none;
											break Lcloop2;
										default:
											//ignore
											break;
									}
								}
							}
							break;
						case "<weapon_strength_list>":
							state = DataState.weapon_strength_list;
							ptrdiff_t entryi = -1;
						Lwloop:
							for(i++; i < tokens.length; i++)
							{
								switch(tokens[i].str)
								{
									case "entry:":
										state = DataState.entry;
										entryi++;
										if(entryi >= DataFile.weapon_strength_list.length)
											throw new Exception("More than 4 weapon strength entry is overflow");
										i++; //jump over the entry index cuz I think it's not used (ie: "entry: 2 jump")
										{
											string n = utf.toUTF8(tokens[++i].str);
											if(n.length >= DataFile.entry_names[entryi].length)
												throw new Exception(format("length %d for entry name is overflow, it should be less than %d\r\n%s\r\nline: %d; col: %d", n.length, DataFile.entry_names[entryi].length, n, tokens[i].line, tokens[i].col));
											{
												size_t j;
												for(j = 0; j < n.length; j++)
													DataFile.entry_names[entryi][j] = n[j];
												DataFile.entry_names[entryi][j] = '\0';
											}
										}
										break;
									case "dvx:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].dvx = tokens[++i].str.to!int;
										break;
									case "dvy:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].dvy = tokens[++i].str.to!int;
										break;
									case "arest:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].arest = tokens[++i].str.to!int;
										break;
									case "vrest:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].vrest = tokens[++i].str.to!int;
										break;
									case "bdefend:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].bdefend = tokens[++i].str.to!int;
										break;
									case "effect:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].effect = tokens[++i].str.to!int;
										break;
									case "fall:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].fall = tokens[++i].str.to!int;
										break;
									case "injury:":
										if(entryi < 0)
											continue Lwloop;
										DataFile.weapon_strength_list[entryi].injury = tokens[++i].str.to!int;
										break;
									case "<weapon_strength_list_end>":
										state = DataState.none;
										break Lwloop;
									default:
										//ignore
										break;
								}
							}
							break;
						case "<frame>":
							state = DataState.frame;
							int frameId = tokens[++i].str.to!int;
							{
								string c = utf.toUTF8(tokens[++i].str);
								if(c.length >= DataFile.frames[frameId].fname.length)
									throw new Exception(format("length %d for frame caption is overflow, it should be less than %d\r\n%s\r\nline: %d; col: %d", c.length, DataFile.frames[frameId].fname.length, c, tokens[i].line, tokens[i].col));
								{
									size_t j;
									for(j = 0; j < c.length; j++)
										DataFile.frames[frameId].fname[j] = c[j];
									DataFile.frames[frameId].fname[j] = '\0';
								}
							}
							sBdy[] bdys = new sBdy[0];
							sItr[] itrs = new sItr[0];
							bdys.reserve(5);
							itrs.reserve(5);
						Lcloop3:
							for(i++; i < tokens.length; i++)
							{
							Lcswitch3:
								switch(tokens[i].str)
								{
									case "pic:":
										DataFile.frames[frameId].pic = tokens[++i].str.to!int;
										break;
									case "state:":
										DataFile.frames[frameId].state = tokens[++i].str.to!int;
										break;
									case "wait:":
										DataFile.frames[frameId].wait = tokens[++i].str.to!int;
										break;
									case "next:":
										DataFile.frames[frameId].next = tokens[++i].str.to!int;
										break;
									case "dvx:":
										DataFile.frames[frameId].dvx = tokens[++i].str.to!int;
										break;
									case "dvy:":
										DataFile.frames[frameId].dvy = tokens[++i].str.to!int;
										break;
									case "dvz:":
										DataFile.frames[frameId].dvz = tokens[++i].str.to!int;
										break;
									case "centerx:":
										DataFile.frames[frameId].centerx = tokens[++i].str.to!int;
										break;
									case "centery:":
										DataFile.frames[frameId].centery = tokens[++i].str.to!int;
										break;
									case "hit_a:":
										DataFile.frames[frameId].hit_a = tokens[++i].str.to!int;
										break;
									case "hit_d:":
										DataFile.frames[frameId].hit_d = tokens[++i].str.to!int;
										break;
									case "hit_j:":
										DataFile.frames[frameId].hit_j = tokens[++i].str.to!int;
										break;
									case "hit_Fa:":
										DataFile.frames[frameId].hit_Fa = tokens[++i].str.to!int;
										break;
									case "hit_Ua:":
										DataFile.frames[frameId].hit_Ua = tokens[++i].str.to!int;
										break;
									case "hit_Da:":
										DataFile.frames[frameId].hit_Da = tokens[++i].str.to!int;
										break;
									case "hit_Fj:":
										DataFile.frames[frameId].hit_Fj = tokens[++i].str.to!int;
										break;
									case "hit_Uj:":
										DataFile.frames[frameId].hit_Uj = tokens[++i].str.to!int;
										break;
									case "hit_Dj:":
										DataFile.frames[frameId].hit_Dj = tokens[++i].str.to!int;
										break;
									case "hit_ja:":
										DataFile.frames[frameId].hit_ja = tokens[++i].str.to!int;
										break;
									case "mp:":
										DataFile.frames[frameId].mp = tokens[++i].str.to!int;
										break;
									case "bdy:":
										state = DataState.bdy;
										sBdy bdy;
									LcloopBdy:
										for(i++; i < tokens.length; i++)
										{
										LcswitchBdy:
											switch(tokens[i].str)
											{
												case "kind:":
													bdy.kind = tokens[++i].str.to!int;
													break;
												case "x:":
													bdy.x = tokens[++i].str.to!int;
													break;
												case "y:":
													bdy.y = tokens[++i].str.to!int;
													break;
												case "w:":
													bdy.w = tokens[++i].str.to!int;
													break;
												case "h:":
													bdy.h = tokens[++i].str.to!int;
													break;
												case "bdy_end:":
													bdys ~= bdy;
													state = DataState.frame;
													break LcloopBdy;
												default:
													//ignore
													break;
											}
										}
										break;
									case "itr:":
										state = DataState.itr;
										sItr itr;
									LcloopI:
										for(i++; i < tokens.length; i++)
										{
										LcswitchI:
											switch(tokens[i].str)
											{
												case "kind:":
													itr.kind = tokens[++i].str.to!int;
													break;
												case "x:":
													itr.x = tokens[++i].str.to!int;
													break;
												case "y:":
													itr.y = tokens[++i].str.to!int;
													break;
												case "w:":
													itr.w = tokens[++i].str.to!int;
													break;
												case "h:":
													itr.h = tokens[++i].str.to!int;
													break;
												case "dvx:":
													itr.dvx = tokens[++i].str.to!int;
													break;
												case "dvy:":
													itr.dvy = tokens[++i].str.to!int;
													break;
												case "fall:":
													itr.fall = tokens[++i].str.to!int;
													break;
												case "arest:":
													itr.arest = tokens[++i].str.to!int;
													break;
												case "vrest:":
													itr.vrest = tokens[++i].str.to!int;
													break;
												case "effect:":
													itr.effect = tokens[++i].str.to!int;
													break;
												case "catchingact:":
													itr.catchingact1 = tokens[++i].str.to!int;
													itr.catchingact2 = tokens[++i].str.to!int;
													break;
												case "caughtact:":
													itr.caughtact1 = tokens[++i].str.to!int;
													itr.caughtact2 = tokens[++i].str.to!int;
													break;
												case "bdefend:":
													itr.bdefend = tokens[++i].str.to!int;
													break;
												case "injury:":
													itr.injury = tokens[++i].str.to!int;
													break;
												case "zwidth:":
													itr.zwidth = tokens[++i].str.to!int;
													break;
												case "itr_end:":
													itrs ~= itr;
													state = DataState.frame;
													break LcloopI;
												default:
													//ignore
													break;
											}
										}
										break;
									case "wpoint:":
										state = DataState.wpoint;
										sWpoint wp;
									LcloopW:
										for(i++; i < tokens.length; i++)
										{
										LcswitchW:
											switch(tokens[i].str)
											{
												case "kind:":
													wp.kind = tokens[++i].str.to!int;
													break;
												case "x:":
													wp.x = tokens[++i].str.to!int;
													break;
												case "y:":
													wp.y = tokens[++i].str.to!int;
													break;
												case "weaponact:":
													wp.weaponact = tokens[++i].str.to!int;
													break;
												case "attacking:":
													wp.attacking = tokens[++i].str.to!int;
													break;
												case "cover:":
													wp.cover = tokens[++i].str.to!int;
													break;
												case "dvx:":
													wp.dvx = tokens[++i].str.to!int;
													break;
												case "dvy:":
													wp.dvy = tokens[++i].str.to!int;
													break;
												case "dvz:":
													wp.dvz = tokens[++i].str.to!int;
													break;
												case "wpoint_end:":
													DataFile.frames[frameId].wpoint = wp;
													state = DataState.frame;
													break LcloopW;
												default:
													//ignore
													break;
											}
										}
										break;
									case "opoint:":
										state = DataState.opoint;
										sOpoint op;
									LcloopO:
										for(i++; i < tokens.length; i++)
										{
										LcswitchO:
											switch(tokens[i].str)
											{
												case "kind:":
													op.kind = tokens[++i].str.to!int;
													break;
												case "x:":
													op.x = tokens[++i].str.to!int;
													break;
												case "y:":
													op.y = tokens[++i].str.to!int;
													break;
												case "action:":
													op.action = tokens[++i].str.to!int;
													break;
												case "dvx:":
													op.dvx = tokens[++i].str.to!int;
													break;
												case "dvy:":
													op.dvy = tokens[++i].str.to!int;
													break;
												case "oid:":
													op.oid = tokens[++i].str.to!int;
													break;
												case "facing:":
													op.facing = tokens[++i].str.to!int;
													break;
												case "opoint_end:":
													DataFile.frames[frameId].opoint = op;
													state = DataState.frame;
													break LcloopO;
												default:
													//ignore
													break;
											}
										}
										break;
									case "cpoint:":
										state = DataState.cpoint;
										sCpoint cp;
									LcloopC:
										for(i++; i < tokens.length; i++)
										{
										LcswitchC:
											switch(tokens[i].str)
											{
												case "kind:":
													cp.kind = tokens[++i].str.to!int;
													break;
												case "x:":
													cp.x = tokens[++i].str.to!int;
													break;
												case "y:":
													cp.y = tokens[++i].str.to!int;
													break;
												case "injury:":
													cp.injury = tokens[++i].str.to!int;
													break;
												case "fronthurtact:":
													cp.fronthurtact = tokens[++i].str.to!int;
													break;
												case "cover:":
													cp.cover = tokens[++i].str.to!int;
													break;
												case "backhurtact:":
													cp.backhurtact = tokens[++i].str.to!int;
													break;
												case "vaction:":
													cp.vaction = tokens[++i].str.to!int;
													break;
												case "aaction:":
													cp.aaction = tokens[++i].str.to!int;
													break;
												case "jaction:":
													cp.jaction = tokens[++i].str.to!int;
													break;
												case "daction:":
													cp.daction = tokens[++i].str.to!int;
													break;
												case "throwvx:":
													cp.throwvx = tokens[++i].str.to!int;
													break;
												case "throwvy:":
													cp.throwvy = tokens[++i].str.to!int;
													break;
												case "throwvz:":
													cp.throwvz = tokens[++i].str.to!int;
													break;
												case "hurtable:":
													cp.hurtable = tokens[++i].str.to!int;
													break;
												case "decrease:":
													cp.decrease = tokens[++i].str.to!int;
													break;
												case "dircontrol:":
													cp.dircontrol = tokens[++i].str.to!int;
													break;
												case "throwinjury:":
													cp.throwinjury = tokens[++i].str.to!int;
													break;
												case "cpoint_end:":
													DataFile.frames[frameId].cpoint = cp;
													state = DataState.frame;
													break LcloopC;
												default:
													//ignore
													break;
											}
										}
										break;
									case "bpoint:":
										state = DataState.bpoint;
										sBpoint bp;
									LcloopB:
										for(i++; i < tokens.length; i++)
										{
										LcswitchB:
											switch(tokens[i].str)
											{
												case "x:":
													bp.x = tokens[++i].str.to!int;
													break;
												case "y:":
													bp.y = tokens[++i].str.to!int;
													break;
												case "bpoint_end:":
													DataFile.frames[frameId].bpoint = bp;
													state = DataState.frame;
													break LcloopB;
												default:
													//ignore
													break;
											}
										}
										break;
									case "<frame_end>":
										DataFile.frames[frameId].exists = 1;
										DataFile.frames[frameId].bdys = bdys.ptr;
										DataFile.frames[frameId].itrs = itrs.ptr;
										DataFile.frames[frameId].bdy_count = bdys.length;
										DataFile.frames[frameId].itr_count = itrs.length;
										state = DataState.none;
										break Lcloop3;
									default:
										//ignore
										break;
								}
							}
							break;
						default:
							//ignore
							break;
					}
				}

				foreach(i, ref frame; DataFile.frames)
				{
					{
						// simple math: calculate the outer-most bounding rectangle of bdys
						int left, top, right, bottom;
						if(frame.bdy_count > 0)
						{
							left = frame.bdys[0].x;
							top = frame.bdys[0].y;
							right = frame.bdys[0].w + frame.bdys[0].x;
							bottom = frame.bdys[0].h + frame.bdys[0].y;
							if(frame.bdy_count > 1)
							{
								foreach(ref bdy; frame.bdys[1 .. frame.bdy_count])
								{
									if(bdy.x < left)
										left = bdy.x;
									if(bdy.y < top)
										top = bdy.y;
									if(bdy.w + bdy.x > right)
										right = bdy.w + bdy.x;
									if(bdy.h + bdy.y > bottom)
										bottom = bdy.h + bdy.y;
								}
								frame.bdy_x = left;
								frame.bdy_y = top;
								frame.bdy_w = right - left;
								frame.bdy_h = bottom - top;
							}
						}
						frame.bdy_x = left;
						frame.bdy_y = top;
						frame.bdy_w = right - left;
						frame.bdy_h = bottom - top;
					}
					{
						// simple math: calculate the outer-most bounding rectangle of itrs
						int left, top, right, bottom;
						if(frame.itr_count > 0)
						{
							left = frame.itrs[0].x;
							top = frame.itrs[0].y;
							right = frame.itrs[0].w + frame.itrs[0].x;
							bottom = frame.itrs[0].h + frame.itrs[0].y;
							if(frame.itr_count > 1)
							{
								foreach(ref itr; frame.itrs[1 .. frame.itr_count])
								{
									if(itr.x < left)
										left = itr.x;
									if(itr.y < top)
										top = itr.y;
									if(itr.w + itr.x > right)
										right = itr.w + itr.x;
									if(itr.h + itr.y > bottom)
										bottom = itr.h + itr.y;
								}
								frame.itr_x = left;
								frame.itr_y = top;
								frame.itr_w = right - left;
								frame.itr_h = bottom - top;
							}
						}
						frame.itr_x = left;
						frame.itr_y = top;
						frame.itr_w = right - left;
						frame.itr_h = bottom - top;
						debug
						{
							objLog.writeln("itr_x: ", frame.itr_x,
								"  itr_y: ", frame.itr_y,
								"  itr_w: ", frame.itr_w,
								"  itr_h: ", frame.itr_h, "\n");
						}
					}
					
					if(frame.bdy_count > 0)
					{
						//should we allocate or simply use previously allocated memory
						if(RDataFile.frames[i].bdy_count <= 0)
						{
							//allocate bdys for LF2
							sBdy* bdyAlloc = cast(sBdy*)VirtualAllocEx(hProc, null, sBdy.sizeof * frame.bdy_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(bdyAlloc == null)
								throw new Exception("Could not allocate bdy array for LF2");
							
							if(WriteProcessMemory(hProc, bdyAlloc, frame.bdys, sBdy.sizeof * frame.bdy_count, null) == FALSE)
								throw new Exception("Could not write process memory: frame.bdys");
							frame.bdys = bdyAlloc;
						}
						else if(RDataFile.frames[i].bdy_count < frame.bdy_count)
						{
							MEMORY_BASIC_INFORMATION memInfo;
							if(VirtualQueryEx(hProc, RDataFile.frames[i].bdys, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
								throw new Exception("Could not query process memory: bdys");
							
							if(memInfo.RegionSize == allocBdySize)
							{
								if(VirtualFreeEx(hProc, RDataFile.frames[i].bdys, 0, MEM_RELEASE) == FALSE)
									throw new Exception("Could not free process memory: bdys");
							}
							//else throw new Exception(format("memInfo.RegionSize(%d) != allocBdySize(%d)", memInfo.RegionSize, allocBdySize));
							
							//allocate bdys for LF2
							sBdy* bdyAlloc = cast(sBdy*)VirtualAllocEx(hProc, null, sBdy.sizeof * frame.bdy_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(bdyAlloc == null)
								throw new Exception("Could not allocate bdy array for process memory");
							
							if(WriteProcessMemory(hProc, bdyAlloc, frame.bdys, sBdy.sizeof * frame.bdy_count, null) == FALSE)
								throw new Exception("Could not write process memory: frame.bdys");
							frame.bdys = bdyAlloc;
						}
						else
						{
							if(WriteProcessMemory(hProc, RDataFile.frames[i].bdys, frame.bdys, sBdy.sizeof * frame.bdy_count, null) == FALSE)
								throw new Exception("Could not write process memory: frame.bdys");
							frame.bdys = RDataFile.frames[i].bdys;
						}
					}
					else if(RDataFile.frames[i].bdy_count > 0)
					{
						MEMORY_BASIC_INFORMATION memInfo;
						if(VirtualQueryEx(hProc, RDataFile.frames[i].bdys, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
							throw new Exception("Could not query process memory: bdys");
						
						if(memInfo.RegionSize == allocBdySize)
						{
							if(VirtualFreeEx(hProc, RDataFile.frames[i].bdys, 0, MEM_RELEASE) == FALSE)
								throw new Exception("Could not free process memory: bdys");
						}
						//else throw new Exception(format("memInfo.RegionSize(%d) != allocBdySize(%d)", memInfo.RegionSize, allocBdySize));
					}

					if(frame.itr_count > 0)
					{
						//should we allocate or simply use previously allocated memory
						if(RDataFile.frames[i].itr_count <= 0)
						{
							//allocate itrs for LF2
							sItr* itrAlloc = cast(sItr*)VirtualAllocEx(hProc, null, sItr.sizeof * frame.itr_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(itrAlloc == null)
								throw new Exception("Could not allocate itr array for LF2");
							
							if(WriteProcessMemory(hProc, itrAlloc, frame.itrs, sItr.sizeof * frame.itr_count, null) == FALSE)
								throw new Exception("Could not write process memory: frame.itrs");
							frame.itrs = itrAlloc;
						}
						else if(RDataFile.frames[i].itr_count < frame.itr_count)
						{
							MEMORY_BASIC_INFORMATION memInfo;
							if(VirtualQueryEx(hProc, RDataFile.frames[i].itrs, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
								throw new Exception("Could not query process memory: itrs");
							
							if(memInfo.RegionSize == allocItrSize)
							{
								if(VirtualFreeEx(hProc, RDataFile.frames[i].itrs, 0, MEM_RELEASE) == FALSE)
									throw new Exception("Could not free process memory: itrs");
							}
							//else throw new Exception(format("memInfo.RegionSize(%d) != allocItrSize(%d)", memInfo.RegionSize, allocItrSize));
							
							//allocate itrs for LF2
							sItr* itrAlloc = cast(sItr*)VirtualAllocEx(hProc, null, sItr.sizeof * frame.itr_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(itrAlloc == null)
								throw new Exception("Could not allocate itr array for LF2");
							
							if(WriteProcessMemory(hProc, itrAlloc, frame.itrs, sItr.sizeof * frame.itr_count, null) == FALSE)
								throw new Exception("Could not write process memory: frame.itrs");
							frame.itrs = itrAlloc;
						}
						else
						{
							if(WriteProcessMemory(hProc, RDataFile.frames[i].itrs, frame.itrs, sItr.sizeof * frame.itr_count, null) == FALSE)
								throw new Exception("Could not write process memory: DataFile");
							frame.itrs = RDataFile.frames[i].itrs;
						}
					}
					else if(RDataFile.frames[i].itr_count > 0)
					{
						MEMORY_BASIC_INFORMATION memInfo;
						if(VirtualQueryEx(hProc, RDataFile.frames[i].itrs, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
							throw new Exception("Could not query process memory: itrs");
						
						if(memInfo.RegionSize == allocItrSize)
						{
							if(VirtualFreeEx(hProc, RDataFile.frames[i].itrs, 0, MEM_RELEASE) == FALSE)
								throw new Exception("Could not free process memory: itrs");
						}
						//else throw new Exception(format("memInfo.RegionSize(%d) != allocItrSize(%d)", memInfo.RegionSize, allocItrSize));
					}
				}

				if(WriteProcessMemory(hProc, addr, DataFile, sDataFile.sizeof, null) == FALSE)
					throw new Exception("Could not write process memory: DataFile");
			}
		}
		catch(Exception ex)
		{
			MessageBoxW(hMainWindow, utf.toUTF16z(ex.toString), "[IDL.dll] Data Loading Error", MB_SETFOREGROUND);
			return -1;
		}
		catch(Error err)
		{
			MessageBoxW(hMainWindow, utf.toUTF16z(err.toString), "[IDL.dll] Fatal Error", MB_SETFOREGROUND);
			return int.max;
		}
	}
	catch(Throwable t) { return int.min; }
	return 0;
}
