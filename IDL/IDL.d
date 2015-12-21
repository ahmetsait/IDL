// Written in D Programming Language
module IDL;

pragma(lib, "user32");
import stdio = std.stdio;
import std.string : startsWith;
import std.range : isInfinite, isIterable, isInputRange;
import std.traits : isSomeString, isArray;
import core.stdc.stdlib : malloc, calloc, free;
import core.stdc.string : memcpy, memset;
import utf = std.utf;
import std.format : format;
import std.conv : to, wtext, text;
import core.sys.windows.threadaux;
import core.sys.windows.windows;
import core.memory : GC;
import LF2;

/**
Returns whether a value exists in the given input-range.
The semantics of an input range (not checkable during compilation) are
assumed to be the following ($(D r) is an object of type $(D InputRange)):
$(UL $(LI $(D r.empty) returns $(D false) if there is more data
		available in the range.)  $(LI $(D r.front) returns the current
		element in the range. It may return by value or by reference. Calling
		$(D r.front) is allowed only if calling $(D r.empty) has, or would
		have, returned $(D false).) $(LI $(D r.popFront) advances to the next
		element in the range. Calling $(D r.popFront) is allowed only if
		calling $(D r.empty) has, or would have, returned $(D false).))
*/
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

version(EXE)
{
	void main()
	{

	}
}
version(DLL)
{
	enum int THREAD_SUSPEND_RESUME = 2;

	extern(Windows) BOOL ReadProcessMemory(HANDLE hProcHandle, LPCVOID pSrcAddr, PVOID pDestAddr, DWORD dwReadSize, PDWORD) nothrow @nogc @system;
	extern(Windows) BOOL WriteProcessMemory(HANDLE hProcHandle, LPVOID pDestAddr, LPCVOID pSrcAddr, SIZE_T szWriteSize, SIZE_T*) nothrow @nogc @system;
	extern(Windows) HANDLE OpenProcess(DWORD dwDesiredAccess, BOOL bInheritHandle, DWORD dwProcId) nothrow @nogc @system;
	
	enum : DWORD
	{
		SYNCHRONIZE					= 0x100000L,
		STANDARD_RIGHTS_REQUIRED	= 0xF0000,
		PROCESS_TERMINATE			= 1,
		PROCESS_CREATE_THREAD		= 2,
		PROCESS_SET_SESSIONID		= 4,
		PROCESS_VM_OPERATION		= 8,
		PROCESS_VM_READ				= 16,
		PROCESS_VM_WRITE			= 32,
		PROCESS_DUP_HANDLE			= 64,
		PROCESS_CREATE_PROCESS		= 128,
		PROCESS_SET_QUOTA			= 256,
		PROCESS_SUSPEND_RESUME		= 0x0800,
		PROCESS_SET_INFORMATION		= 512,
		PROCESS_QUERY_INFORMATION	= 1024,
		PROCESS_ALL_ACCESS			= (STANDARD_RIGHTS_REQUIRED | SYNCHRONIZE | 0xFFF),
	}

	/// Suspend a list of threads to safely read/write the process memory without causing data races.
	/// First parameter is a raw pointer to list of thread IDs, second is the length of it, and third is 
	/// a BOOL (alias of int) value to indicate whether threads will be suspended (1) or resumed (0).
	/// Returns TRUE (1) on success, FALSE (0) otherwise.
	export extern(C) BOOL SuspendThreadList(int* threadIds, int length, BOOL bSuspend) nothrow @nogc @system
	{
		bool suspend = (bSuspend == TRUE);
		BOOL ret = TRUE;
		for(int i = 0; i < length; i++)
		{
			HANDLE hThread = OpenThread(THREAD_SUSPEND_RESUME, false, threadIds[i]);
			if(hThread != INVALID_HANDLE_VALUE)
			{
				if(suspend)
				{
					if((threadIds[i] = SuspendThread(hThread)) != 0)
						ret = FALSE;
				}
				else
				{
					if((threadIds[i] = ResumeThread(hThread)) != 1)
						ret = FALSE;
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

//		SendMessageA(window, WM_MOUSEMOVE, 15073680, 1); // Not working
		WPARAM xy = (380 | (230 << 16));
		if(SetCursorPos(rect.left + 380, rect.top + 25 + 230) == TRUE)
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

	const string tokenHeads = ['<'], tokenEnds = ['>', ':'], tokenDelims = [' ', '\t', '\n', '\r'], 
		lineEnd = ['\n', '\r'];
	const char lineCommentChar = '#';

	/// This function tokenizes LF2 data and returns a slice-array of strings. Returned slices point to the given string.
	public T[] parseData(T)(T data) pure if(isSomeString!T)
	{
		T[] slices = new T[0];
		slices.reserve(data.length / 5); // Pre-allocate an aprox memory we might need

		TokenState state = TokenState.none;
		size_t tokenStart = 0, line = 0, col = 0;
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
					}
					else if(tokenEnds.contains(ch)) // > :
					{
						throw new Exception(format("Unexpected token ending delimeter: '%c' in line: %d; at col: %d", ch, line, col));
					}
					else if(ch == lineCommentChar) // #
					{
						state = TokenState.comment;
					}
					else
					{
						state = TokenState.token;
						tokenStart = i;
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
						slices ~= data[tokenStart .. i + 1];
						state = TokenState.none;
					}
					else if(tokenEnds[1] == ch) // :
					{
						throw new Exception(format("Unexpected token ending delimeter: '%c' in line: %d; at col: %d", ch, line, col));
					}
					else if(ch == lineCommentChar) // #
					{
						throw new Exception(format("Unexpected comment char: '%c' in line: %d; at col: %d", ch, line, col));
					}
					break Lswitch;
				case TokenState.token:
					if(tokenDelims.contains(ch))
					{
						slices ~= data[tokenStart .. i];
						state = TokenState.none;
					}
					else if(tokenHeads.contains(ch)) // <
					{
						slices ~= data[tokenStart .. i];
						state = TokenState.xml;
						tokenStart = i;
					}
					else if(tokenEnds.contains(ch)) // > :
					{
						slices ~= data[tokenStart .. i + 1];
						state = TokenState.none;
					}
					else if(ch == lineCommentChar) // #
					{
						slices ~= data[tokenStart .. i];
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
				col = 0;
			}
			else
				col++;
		}

		return slices;
	}

	public void* getStagesAddr(HANDLE hProc)
	{
		void* addr = null;
		if(ReadProcessMemory(hProc, sGamePoint + sGame.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
			throw new Exception("Could not read process memory: sGamePoint + sGame.files.offsetof");
		if(ReadProcessMemory(hProc, addr + sFileManager.stages.offsetof, &addr, size_t.sizeof, null) == FALSE)
			throw new Exception("Could not read process memory: addr + sFileManager.stages.offsetof");
		return addr;
	}

	public void* getDataAddrOfObj(HANDLE hProc, int objId)
	{
		void* addr = null;
		if(ReadProcessMemory(hProc, sGamePoint + sGame.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
			throw new Exception("Could not read process memory: sGamePoint + sGame.files.offsetof");
		if(ReadProcessMemory(hProc, addr + sFileManager.datas.offsetof + objId * size_t.sizeof, &addr, size_t.sizeof, null) == FALSE)
			throw new Exception(("Could not read process memory: addr + sFileManager.datas.offsetof + objId * size_t.sizeof"));
		return addr;
	}
	
	public void* getBackgroundsAddr(HANDLE hProc)
	{
		void* addr = null;
		if(ReadProcessMemory(hProc, sGamePoint + sGame.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
			throw new Exception("Could not read process memory: sGamePoint + sGame.files.offsetof");
		addr += sFileManager.backgrounds.offsetof;
		return addr;
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

	/**
	Loads decrypted data to LF2's memory using Read/WriteProcessMemory WINAPI functions. Care should be taken to
	first call SuspendThreadList on the target process to avoid data races and possible crashes.
	It's not possible to load images and sounds, bgm works in stages. Loading weapon_strength_list entries are 
	currently not supported due to data sequences being not known at the moment. It needs some more 
	reverse engineering of LF2. Other than that, this is pure magic.
	 */
	export extern(C) int InstantLoad(wchar* data, int length, int procId, 
		DataType dataType, int objId, ObjectType objType, HWND hMainWindow) @system
	{
//		GC.disable();
//		scope(exit)
//		{
//			GC.enable();
//			GC.collect();
//		}
		
		try
		{
			auto dat = data[0 .. length];
			typeof(dat)[] tokens;
			try
			{
				tokens = parseData(dat);
			}
			catch(Exception ex)
			{
				MessageBoxW(hMainWindow, utf.toUTF16z(ex.toString), "[IDL.dll] Data Parsing Error", MB_SETFOREGROUND);
				return 1;
			}
			
			HANDLE hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, procId);
			if(hProc == INVALID_HANDLE_VALUE)
				throw new Exception("Could not open process");
			scope(exit) CloseHandle(hProc);
			
			SYSTEM_INFO sysInfo;
			GetSystemInfo(&sysInfo);//dwPageSize is needed to figure out how big RegionSize will be when we allocate ourself
			
			uint allocItrSize = sItr.sizeof / sysInfo.dwPageSize + (sItr.sizeof % sysInfo.dwPageSize > 0 ? sysInfo.dwPageSize : 0),
				allocBdySize = sBdy.sizeof / sysInfo.dwPageSize + (sBdy.sizeof % sysInfo.dwPageSize > 0 ? sysInfo.dwPageSize : 0);

			version(all)
			{
				if(dataType == DataType.Background)
				{
					void* Addr = getBackgroundsAddr(hProc) + sBackground.sizeof * objId;
					
					//TODO: support background
				}
				else if(dataType == DataType.Stage)
				{
					delegate void()
					{
					void* Addr = getStagesAddr(hProc);

					// allocate it cuz ReadProcessMemory won't do it for us
					sStageProxy* RStage = cast(sStageProxy*)malloc(sStageProxy.sizeof);
					if(!RStage)
						throw new Exception("Could not allocate RStage array: " ~ sStageProxy.sizeof.to!string ~ " byte");
					scope(exit) free(RStage);
					
					if(ReadProcessMemory(hProc, Addr, RStage, sStage.sizeof * 60, null) == FALSE)
						throw new Exception("Could not read process memory: stages");
					
					// ditto
					sStageProxy* Stage = cast(sStageProxy*)calloc(sStage.sizeof, 60);
					if(!Stage)
						throw new Exception("Could not allocate Stage array: " ~ sStageProxy.sizeof.to!string ~ " byte");
					scope(exit) free(Stage);
					
					for(uint i = 0; i < 60; ++i)
					{
						(*Stage)[i].phase_count = 0;
						for(uint j = 0; j < 100; ++j)
						{
							(*Stage)[i].phases[j].when_clear_goto_phase = -1;
							for(uint k = 0; k < 60; ++k)
							{
								(*Stage)[i].phases[j].spawns[k].id = -1;
								// because static arrays are value types muhahahaaa:
								(*Stage)[i].phases[j].spawns[k].unkwn1 = (*RStage)[i].phases[j].spawns[k].unkwn1;
								(*Stage)[i].phases[j].spawns[k].unkwn2 = (*RStage)[i].phases[j].spawns[k].unkwn2;
								(*Stage)[i].phases[j].spawns[k].unkwn3 = (*RStage)[i].phases[j].spawns[k].unkwn3;
							}
						}
					}
					DataState state = DataState.none;
				Lloop1:
					for(size_t i = 0; i < tokens.length; i++)
					{
					Lswitch1:
						switch(tokens[i])
						{
							case "<stage>":
								state = DataState.stage;
								sStage stage = void;
								stage.phase_count = -1;
								int stageId = -1;
								size_t phasei = 0;
							Lloop2:
								for(i++; i < tokens.length; i++)
								{
								Lswitch2:
									switch(tokens[i])
									{
										case "id:":
											stageId = tokens[++i].to!int;
											break;
										case "<phase>":
											state = DataState.phase;
											sPhase phase = void;
											foreach(ref spw; phase.spawns)
												spw.id = -1;
											phase.when_clear_goto_phase = -1;
											size_t currentPhase = phasei++;
											ptrdiff_t spawni = -1;
										Lloop3:
											for(i++; i < tokens.length; i++)
											{
											Lswitch3:
												switch(tokens[i])
												{
													case "bound:":
														phase.bound = tokens[++i].to!int;
														break;
													case "music:":
														string m = utf.toUTF8(tokens[++i]);
														{
															size_t j;
															for(j = 0; j < m.length && j < 52; j++)
																phase.music[j] = m[j];
															phase.music[j] = '\0';
														}
														break;
													case "id:":
														spawni++;
														if(spawni >= 60)
															break Lloop3;
														phase.spawns[spawni].id = tokens[++i].to!int;
														phase.spawns[spawni].hp = 500;
														phase.spawns[spawni].act = 9;
														phase.spawns[spawni].times = 1;
														phase.spawns[spawni].ratio = 0; //not sure about this
														phase.spawns[spawni].x = 80 + phasei > 0 ? stage.phases[phasei - 1].bound : 0;
														break;
													case "x:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].x = tokens[++i].to!int;
														break;
													case "hp:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].hp = tokens[++i].to!int;
														break;
													case "act:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].act = tokens[++i].to!int;
														break;
													case "times:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].times = tokens[++i].to!int;
														break;
													case "ratio:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].ratio = tokens[++i].to!double;
														break;
													case "reserve:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].reserve = tokens[++i].to!int;
														break;
													case "join:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].join = tokens[++i].to!int;
														break;
													case "join_reserve:":
														if(spawni < 0)
															continue Lloop3;
														phase.spawns[spawni].join_reserve = tokens[++i].to!int;
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
														phase.when_clear_goto_phase = tokens[++i].to!int;
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
										case "<stage_end>":
											if(stageId < 0)
												throw new Exception("Stage id could not be received");
											auto m = stageId;
											{
												for(uint n = 0; n < 100; ++n)
												{
													stage.phases[n].when_clear_goto_phase = -1;
													for(uint k = 0; k < 60; ++k)
													{
														stage.phases[n].spawns[k].id = -1;
														// because static arrays are value types muhahahaaa:
														stage.phases[n].spawns[k].unkwn1 = (*Stage)[m].phases[n].spawns[k].unkwn1;
														stage.phases[n].spawns[k].unkwn2 = (*Stage)[m].phases[n].spawns[k].unkwn2;
														stage.phases[n].spawns[k].unkwn3 = (*Stage)[m].phases[n].spawns[k].unkwn3;
													}
												}
											}
											(*Stage)[stageId] = stage;
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
					if(WriteProcessMemory(hProc, Addr, Stage, sStage.sizeof * 60, null) == FALSE)
						throw new Exception("Could not write stages to process memory");
					}
					();
				}
				else if(dataType == DataType.Char)
				{
					delegate void() {
					void* Addr = getDataAddrOfObj(hProc, objId);

					// allocate it cuz ReadProcessMemory won't do it for us
					sDataFile* RDataFile = cast(sDataFile*)malloc(sDataFile.sizeof);
					if(RDataFile == null) throw new Exception("Could not allocate RDataFile: " ~ sDataFile.sizeof.to!string ~ " bytes");
					scope(exit) free(RDataFile);

					if(ReadProcessMemory(hProc, Addr, &RDataFile, sDataFile.sizeof, null) == FALSE)
						throw new Exception("Could not read process memory: RDataFile");
					
					sDataFile* DataFile = cast(sDataFile*)malloc(sDataFile.sizeof);
					if(DataFile == null) throw new Exception("Could not allocate DataFile");
					scope(exit) free(RDataFile);

					DataFile.unkwn1 = RDataFile.unkwn1;
					DataFile.unkwn3 = RDataFile.unkwn3;
					DataFile.unkwn4 = RDataFile.unkwn4;
					//static arrays are value types:
					DataFile.unkwn2 = RDataFile.unkwn2;
					DataFile.unkwn5 = RDataFile.unkwn5;
					
					DataFile.pic_count = RDataFile.pic_count;
					DataFile.pic_bmps = RDataFile.pic_bmps;
					DataFile.pic_index = RDataFile.pic_index;
					DataFile.pic_width = RDataFile.pic_width;
					DataFile.pic_height = RDataFile.pic_height;
					DataFile.pic_row = RDataFile.pic_row;
					DataFile.pic_col = RDataFile.pic_col;
					DataFile.small_bmp = RDataFile.small_bmp;
					DataFile.face_bmp = RDataFile.face_bmp;
					
					for(int i = 0; i < 400; i++)
					{
						DataFile.frames[i].sound = RDataFile.frames[i].sound;
						
						DataFile.frames[i].unkwn1 = RDataFile.frames[i].unkwn1;
						DataFile.frames[i].unkwn2 = RDataFile.frames[i].unkwn2;
						DataFile.frames[i].unkwn3 = RDataFile.frames[i].unkwn3;
						DataFile.frames[i].unkwn4 = RDataFile.frames[i].unkwn4;
						DataFile.frames[i].unkwn5 = RDataFile.frames[i].unkwn5;
						DataFile.frames[i].unkwn6 = RDataFile.frames[i].unkwn6;
						DataFile.frames[i].unkwn7 = RDataFile.frames[i].unkwn7;
						DataFile.frames[i].unkwn8 = RDataFile.frames[i].unkwn8;
						DataFile.frames[i].unkwn9 = RDataFile.frames[i].unkwn9;
					}

					DataFile.id = objId;
					DataFile.type = dataType;
					
					DataState state = DataState.none;
				Lcloop1:
					for(size_t i = 0; i < tokens.length; i++)
					{
					Lcswitch1:
						switch(tokens[i])
						{
							case "<bmp_begin>":
								state = DataState.bmp;
							Lcloop2:
								for(i++; i < tokens.length; i++)
								{
									if(tokens[i].startsWith("file"))
										i += 9; //jump over: file w h row col
									else
									{
									Lcswitch2:
										switch(tokens[i])
										{
											case "name:":
												string n = utf.toUTF8(tokens[++i]);
												{
													size_t j;
													for(j = 0; j < n.length && j < 12; j++)
														DataFile.name[j] = n[j];
													DataFile.name[j] = '\0';
												}
												break;
											case "walking_frame_rate":
												DataFile.walking_frame_rate = tokens[++i].to!int;
												break;
											case "walking_speed":
												DataFile.walking_speed = tokens[++i].to!double;
												break;
											case "walking_speedz":
												DataFile.walking_speedz = tokens[++i].to!double;
												break;
											case "running_frame_rate":
												DataFile.running_frame_rate = tokens[++i].to!int;
												break;
											case "running_speed":
												DataFile.running_speed = tokens[++i].to!double;
												break;
											case "running_speedz":
												DataFile.running_speedz = tokens[++i].to!double;
												break;
											case "heavy_walking_speed":
												DataFile.heavy_walking_speed = tokens[++i].to!double;
												break;
											case "heavy_walking_speedz":
												DataFile.heavy_walking_speedz = tokens[++i].to!double;
												break;
											case "heavy_running_speed":
												DataFile.heavy_running_speed = tokens[++i].to!double;
												break;
											case "heavy_running_speedz":
												DataFile.heavy_running_speedz = tokens[++i].to!double;
												break;
											case "jump_height":
												DataFile.jump_height = tokens[++i].to!double;
												break;
											case "jump_distance":
												DataFile.jump_distance = tokens[++i].to!double;
												break;
											case "jump_distancez":
												DataFile.jump_distancez = tokens[++i].to!double;
												break;
											case "dash_height":
												DataFile.dash_height = tokens[++i].to!double;
												break;
											case "dash_distance":
												DataFile.dash_distance = tokens[++i].to!double;
												break;
											case "dash_distancez":
												DataFile.dash_distancez = tokens[++i].to!double;
												break;
											case "rowing_height":
												DataFile.rowing_height = tokens[++i].to!double;
												break;
											case "rowing_distance":
												DataFile.rowing_distance = tokens[++i].to!double;
												break;
											case "weapon_hp:":
												DataFile.weapon_hp = tokens[++i].to!int;
												break;
											case "weapon_drop_hurt:":
												DataFile.weapon_drop_hurt = tokens[++i].to!int;
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
							case "<frame>":
								state = DataState.frame;
								int frameId = tokens[++i].to!int;
								string buf = utf.toUTF8(tokens[++i]);
								{
									size_t j;
									for(j = 0; j < buf.length && j < 20; j++)
										DataFile.frames[frameId].fname[j] = buf[j];
									DataFile.frames[frameId].fname[j] = '\0';
								}
								sBdy[] bdys = new sBdy[0];
								sItr[] itrs = new sItr[0];
								bdys.reserve(5);
								itrs.reserve(5);
							Lcloop3:
								for(i++; i < tokens.length; i++)
								{
								Lcswitch3:
									switch(tokens[i])
									{
										case "pic:":
											DataFile.frames[frameId].pic = tokens[++i].to!int;
											break;
										case "state:":
											DataFile.frames[frameId].state = tokens[++i].to!int;
											break;
										case "wait:":
											DataFile.frames[frameId].wait = tokens[++i].to!int;
											break;
										case "next:":
											DataFile.frames[frameId].next = tokens[++i].to!int;
											break;
										case "dvx:":
											DataFile.frames[frameId].dvx = tokens[++i].to!int;
											break;
										case "dvy:":
											DataFile.frames[frameId].dvy = tokens[++i].to!int;
											break;
										case "dvz:":
											DataFile.frames[frameId].dvz = tokens[++i].to!int;
											break;
										case "centerx:":
											DataFile.frames[frameId].centerx = tokens[++i].to!int;
											break;
										case "centery:":
											DataFile.frames[frameId].centery = tokens[++i].to!int;
											break;
										case "hit_a:":
											DataFile.frames[frameId].hit_a = tokens[++i].to!int;
											break;
										case "hit_d:":
											DataFile.frames[frameId].hit_d = tokens[++i].to!int;
											break;
										case "hit_j:":
											DataFile.frames[frameId].hit_j = tokens[++i].to!int;
											break;
										case "hit_Fa:":
											DataFile.frames[frameId].hit_Fa = tokens[++i].to!int;
											break;
										case "hit_Ua:":
											DataFile.frames[frameId].hit_Ua = tokens[++i].to!int;
											break;
										case "hit_Da:":
											DataFile.frames[frameId].hit_Da = tokens[++i].to!int;
											break;
										case "hit_Fj:":
											DataFile.frames[frameId].hit_Fj = tokens[++i].to!int;
											break;
										case "hit_Uj:":
											DataFile.frames[frameId].hit_Uj = tokens[++i].to!int;
											break;
										case "hit_Dj:":
											DataFile.frames[frameId].hit_Dj = tokens[++i].to!int;
											break;
										case "mp:":
											DataFile.frames[frameId].mp = tokens[++i].to!int;
											break;
										case "bdy:":
											state = DataState.bdy;
											sBdy bdy;
										LcloopBdy:
											for(i++; i < tokens.length; i++)
											{
											LcswitchBdy:
												switch(tokens[i])
												{
													case "kind:":
														bdy.kind = tokens[++i].to!int;
														break;
													case "x:":
														bdy.x = tokens[++i].to!int;
														break;
													case "y:":
														bdy.y = tokens[++i].to!int;
														break;
													case "w:":
														bdy.w = tokens[++i].to!int;
														break;
													case "h:":
														bdy.h = tokens[++i].to!int;
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
												switch(tokens[i])
												{
													case "kind:":
														itr.kind = tokens[++i].to!int;
														break;
													case "x:":
														itr.x = tokens[++i].to!int;
														break;
													case "y:":
														itr.y = tokens[++i].to!int;
														break;
													case "w:":
														itr.w = tokens[++i].to!int;
														break;
													case "h:":
														itr.h = tokens[++i].to!int;
														break;
													case "dvx:":
														itr.dvx = tokens[++i].to!int;
														break;
													case "dvy:":
														itr.dvy = tokens[++i].to!int;
														break;
													case "fall:":
														itr.fall = tokens[++i].to!int;
														break;
													case "arest:":
														itr.arest = tokens[++i].to!int;
														break;
													case "vrest:":
														itr.vrest = tokens[++i].to!int;
														break;
													case "effect:":
														itr.effect = tokens[++i].to!int;
														break;
													case "catchingact:":
														itr.catchingact1 = tokens[++i].to!int;
														itr.catchingact2 = tokens[++i].to!int;
														break;
													case "caughtact:":
														itr.caughtact1 = tokens[++i].to!int;
														itr.caughtact2 = tokens[++i].to!int;
														break;
													case "bdefend:":
														itr.bdefend = tokens[++i].to!int;
														break;
													case "injury:":
														itr.injury = tokens[++i].to!int;
														break;
													case "zwidth:":
														itr.zwidth = tokens[++i].to!int;
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
												switch(tokens[i])
												{
													case "kind:":
														wp.kind = tokens[++i].to!int;
														break;
													case "x:":
														wp.x = tokens[++i].to!int;
														break;
													case "y:":
														wp.y = tokens[++i].to!int;
														break;
													case "weaponact:":
														wp.weaponact = tokens[++i].to!int;
														break;
													case "attacking:":
														wp.attacking = tokens[++i].to!int;
														break;
													case "cover:":
														wp.cover = tokens[++i].to!int;
														break;
													case "dvx:":
														wp.dvx = tokens[++i].to!int;
														break;
													case "dvy:":
														wp.dvy = tokens[++i].to!int;
														break;
													case "dvz:":
														wp.dvz = tokens[++i].to!int;
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
												switch(tokens[i])
												{
													case "kind:":
														op.kind = tokens[++i].to!int;
														break;
													case "x:":
														op.x = tokens[++i].to!int;
														break;
													case "y:":
														op.y = tokens[++i].to!int;
														break;
													case "action:":
														op.action = tokens[++i].to!int;
														break;
													case "dvx:":
														op.dvx = tokens[++i].to!int;
														break;
													case "dvy:":
														op.dvy = tokens[++i].to!int;
														break;
													case "oid:":
														op.oid = tokens[++i].to!int;
														break;
													case "facing:":
														op.facing = tokens[++i].to!int;
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
												switch(tokens[i])
												{
													case "kind:":
														cp.kind = tokens[++i].to!int;
														break;
													case "x:":
														cp.x = tokens[++i].to!int;
														break;
													case "y:":
														cp.y = tokens[++i].to!int;
														break;
													case "injury:":
														cp.injury = tokens[++i].to!int;
														break;
													case "fronthurtact:":
														cp.fronthurtact = tokens[++i].to!int;
														break;
													case "cover:":
														cp.cover = tokens[++i].to!int;
														break;
													case "backhurtact:":
														cp.backhurtact = tokens[++i].to!int;
														break;
													case "vaction:":
														cp.vaction = tokens[++i].to!int;
														break;
													case "aaction:":
														cp.aaction = tokens[++i].to!int;
														break;
													case "jaction:":
														cp.jaction = tokens[++i].to!int;
														break;
													case "daction:":
														cp.daction = tokens[++i].to!int;
														break;
													case "throwvx:":
														cp.throwvx = tokens[++i].to!int;
														break;
													case "throwvy:":
														cp.throwvy = tokens[++i].to!int;
														break;
													case "throwvz:":
														cp.throwvz = tokens[++i].to!int;
														break;
													case "hurtable:":
														cp.hurtable = tokens[++i].to!int;
														break;
													case "decrease:":
														cp.decrease = tokens[++i].to!int;
														break;
													case "dircontrol:":
														cp.dircontrol = tokens[++i].to!int;
														break;
													case "throwinjury:":
														cp.throwinjury = tokens[++i].to!int;
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
												switch(tokens[i])
												{
													case "x:":
														bp.x = tokens[++i].to!int;
														break;
													case "y:":
														bp.y = tokens[++i].to!int;
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
								foreach(bdy; frame.bdys[1 .. frame.bdy_count])
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
							}
							frame.bdy_x = left;
							frame.bdy_y = top;
							frame.bdy_w = left - right;
							frame.bdy_h = top - bottom;
						}
						{
							// simple math: calculate the outer-most bounding rectangle of itrs
							int left, top, right, bottom;
							if(frame.itr_count > 0)
							{
								foreach(itr; frame.itrs[1 .. frame.itr_count])
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
							}
							frame.itr_x = left;
							frame.itr_y = top;
							frame.itr_w = left - right;
							frame.itr_h = top - bottom;
						}
						
						if(frame.bdy_count > 0)
						{
							//should we allocate or simply use previously allocated memory
							if(RDataFile.frames[i].bdy_count == 0)
							{
								//allocate bdys for LF2
								sBdy* bdyAlloc = cast(sBdy*)VirtualAllocEx(hProc, null, sBdy.sizeof * frame.bdy_count, MEM_COMMIT, PAGE_READWRITE);
								
								if(!bdyAlloc)
									throw new Exception("Could not allocate bdy array for process memory");
								
								WriteProcessMemory(hProc, bdyAlloc, frame.bdys, sBdy.sizeof * frame.bdy_count, null);
							}
							else if(RDataFile.frames[i].bdy_count < frame.bdy_count)
							{
								MEMORY_BASIC_INFORMATION memInfo;
								if(VirtualQueryEx(hProc, RDataFile.frames[i].bdys, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == FALSE)
									throw new Exception("Could not query process memory: bdys");
								
								if(memInfo.RegionSize == allocBdySize)
								{
									if(VirtualFreeEx(hProc, RDataFile.frames[i].bdys, 0, MEM_RELEASE) == FALSE)
										throw new Exception("Could not free process memory: bdys");
								}
								
								//allocate bdys for LF2
								sBdy* bdyAlloc = cast(sBdy*)VirtualAllocEx(hProc, null, sBdy.sizeof * frame.bdy_count, MEM_COMMIT, PAGE_READWRITE);
								
								if(!bdyAlloc)
									throw new Exception("Could not allocate bdy array for process memory");
								
								WriteProcessMemory(hProc, bdyAlloc, frame.bdys, sBdy.sizeof * frame.bdy_count, null);
							}
							else
							{
								WriteProcessMemory(hProc, RDataFile.frames[i].bdys, frame.bdys, sBdy.sizeof * frame.bdy_count, null);
							}
						}
						else if(RDataFile.frames[i].bdy_count > 0)
						{
							MEMORY_BASIC_INFORMATION memInfo;
							if(VirtualQueryEx(hProc, RDataFile.frames[i].bdys, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == FALSE)
								throw new Exception("Could not query process memory: bdys");
							
							if(memInfo.RegionSize == allocBdySize)
							{
								if(VirtualFreeEx(hProc, RDataFile.frames[i].bdys, 0, MEM_RELEASE) == FALSE)
									throw new Exception("Could not free process memory: bdys");
							}
						}
						
						if(frame.itr_count > 0)
						{
							//should we allocate or simply use previously allocated memory
							if(RDataFile.frames[i].itr_count == 0)
							{
								//allocate itrs for LF2
								sItr* itrAlloc = cast(sItr*)VirtualAllocEx(hProc, null, sItr.sizeof * frame.itr_count, MEM_COMMIT, PAGE_READWRITE);
								
								if(!itrAlloc)
									throw new Exception("Could not allocate itr array for process memory");
								
								WriteProcessMemory(hProc, itrAlloc, frame.itrs, sItr.sizeof * frame.itr_count, null);
							}
							else if(RDataFile.frames[i].itr_count < frame.itr_count)
							{
								MEMORY_BASIC_INFORMATION memInfo;
								if(VirtualQueryEx(hProc, RDataFile.frames[i].itrs, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == FALSE)
									throw new Exception("Could not query process memory: itrs");
								
								if(memInfo.RegionSize == allocItrSize)
								{
									if(VirtualFreeEx(hProc, RDataFile.frames[i].itrs, 0, MEM_RELEASE) == FALSE)
										throw new Exception("Could not free process memory: itrs");
								}
								
								//allocate itrs for LF2
								sItr* itrAlloc = cast(sItr*)VirtualAllocEx(hProc, null, sItr.sizeof * frame.itr_count, MEM_COMMIT, PAGE_READWRITE);
								
								if(!itrAlloc)
									throw new Exception("Could not allocate itr array for process memory");
								
								WriteProcessMemory(hProc, itrAlloc, frame.itrs, sItr.sizeof * frame.itr_count, null);
							}
							else
							{
								WriteProcessMemory(hProc, RDataFile.frames[i].itrs, frame.itrs, sItr.sizeof * frame.itr_count, null);
							}
						}
						else if(RDataFile.frames[i].itr_count > 0)
						{
							MEMORY_BASIC_INFORMATION memInfo;
							if(VirtualQueryEx(hProc, RDataFile.frames[i].itrs, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == FALSE)
								throw new Exception("Could not query process memory: itrs");
							
							if(memInfo.RegionSize == allocItrSize)
							{
								if(VirtualFreeEx(hProc, RDataFile.frames[i].itrs, 0, MEM_RELEASE) == FALSE)
									throw new Exception("Could not free process memory: itrs");
							}
						}
					}
					
					if(WriteProcessMemory(hProc, Addr, &DataFile, sDataFile.sizeof, null) == FALSE)
						throw new Exception("Could not write process memory: DataFile");
					}();
				}
			}
		}
		catch(Exception ex)
		{
			MessageBoxW(hMainWindow, utf.toUTF16z(ex.toString), "[IDL.dll] Data Loading Error", MB_SETFOREGROUND);
			return -1;
		}
		catch(Error er)
		{
			MessageBoxW(hMainWindow, utf.toUTF16z(er.toString), "[IDL.dll] Fatal Error", MB_SETFOREGROUND);
			return int.max;
		}
		
		return 0;
	}
}
