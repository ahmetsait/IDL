module idl.loader;

pragma(lib, "user32");
import core.sys.windows.windef;
import core.sys.windows.winbase;
import core.sys.windows.winuser;

pragma(lib, "ole32");
import core.sys.windows.objbase : CoTaskMemAlloc, CoTaskMemFree, CoTaskMemRealloc;

import core.memory : GC;
import core.stdc.stdlib;
import core.stdc.string;

debug import std.stdio;

import std.algorithm;
import std.conv;
import std.format;
import std.string;

import idl.lf2;
import idl.tokenizer;
import idl.util;

pragma(lib, "ntdll");
extern(Windows) LONG NtSuspendProcess(HANDLE processHandle) nothrow @nogc;
extern(Windows) LONG NtResumeProcess(HANDLE processHandle) nothrow @nogc;

/// Suspends a process using undocumented `NtSuspendProcess` NtApi function.
/// This is more bullet proof than suspending threads of the process one by one.
/// Params:
/// 	processId = The ID of the process to be suspended.
/// Returns:
/// 	Return value of `NtSuspendProcess` call, or -1 if `OpenProcess` failed.
LONG suspendProcessId(DWORD processId) nothrow @nogc
{
	HANDLE pHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, processId);
	if (pHandle == INVALID_HANDLE_VALUE) return -1;
	scope(exit) CloseHandle(pHandle);
	return NtSuspendProcess(pHandle);
}

/// Resumes a process using undocumented `NtResumeProcess` NtApi function.
/// This is more bullet proof than resuming threads of the process one by one.
/// Params:
/// 	processId = The ID of the process to be resumed.
/// Returns:
/// 	Return value of `NtResumeProcess` call, or -1 if `OpenProcess` failed.
LONG resumeProcessId(DWORD processId) nothrow @nogc
{
	HANDLE pHandle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, processId);
	if (pHandle == INVALID_HANDLE_VALUE) return -1;
	scope(exit) CloseHandle(pHandle);
	return NtResumeProcess(pHandle);
}

void* getStagesAddr(HANDLE hProc)
{
	void* addr = null;
	if(ReadProcessMemory(hProc, gameAddr + Game.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
		throw new IdlException("Could not read process memory: gameAddr + Game.files.offsetof");
	if(addr == null)
		throw new IdlException("Could not read process memory: LF2 is not started");
	addr += FileManager.stages.offsetof;
	return addr;
}

void* getAddrOfObj(HANDLE hProc, size_t objIndex)
{
	void* addr = null;
	if(ReadProcessMemory(hProc, gameAddr + Game.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
		throw new IdlException("Could not read process memory: gameAddr + Game.files.offsetof");
	if(addr == null)
		throw new IdlException("Could not read process memory: LF2 is not started");
	if(ReadProcessMemory(hProc, addr + FileManager.datas.offsetof + objIndex * size_t.sizeof, &addr, size_t.sizeof, null) == FALSE)
		throw new IdlException(format("Could not read process memory: objIndex = %s", objIndex));
	return addr;
}

void* getBackgroundsAddr(HANDLE hProc)
{
	void* addr = null;
	if(ReadProcessMemory(hProc, gameAddr + Game.files.offsetof, &addr, size_t.sizeof, null) == FALSE)
		throw new IdlException("Could not read process memory: gameAddr + Game.files.offsetof");
	if(addr == null)
		throw new IdlException("Could not read process memory: LF2 is not started");
	addr += FileManager.backgrounds.offsetof;
	return addr;
}

void* getAddrOfBackground(HANDLE hProc, size_t bgIndex)
{
	return getBackgroundsAddr(hProc) + Background.sizeof * bgIndex;
}

class IdlException : Exception
{
	this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null) @nogc @safe pure nothrow
	{
		super(msg, file, line, next);
	}
}

enum MsgType : ubyte
{
	Info,
	Warning,
	Error,
}

alias Logger = extern(C) void function(immutable(char)* message, immutable(char)* title, MsgType messageType);

/// Loads decrypted data to LF2's memory using Read/WriteProcessMemory WinApi functions.
/// It's not possible to load images and sounds for objects. layer bitmaps are supported and bgm works in stages.
/// Other than that, this is pure magic.
export extern(C) int instantLoad(
	immutable(char)* data,
	int dataLength,
	int procId,
	DataType dataType,
	int datIndex,
	ObjectType objType,
	HWND hMainWindow,
	Logger logFunc) nothrow
{
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
	
	enum : string
	{
		unhandledMsg = "Unhandled token: '%s' in line %d at col %d",
		warningHigh = "Warning level too high",
	}
	
	enum maxWarning = 10;
	uint warn = 0;
	try
	{
		try
		{
			string dat = data[0 .. dataLength];
			Token[] tokens = tokenize(dat);

			HANDLE hProc = OpenProcess(PROCESS_ALL_ACCESS, FALSE, procId);
			if(hProc == INVALID_HANDLE_VALUE)
			{
				DWORD error = GetLastError();
				LPSTR messageBuffer;
				DWORD success = FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM, null, error, 0, cast(LPSTR)&messageBuffer, 0, null);
				scope(exit) LocalFree(messageBuffer);
				string msg;
				if (success)
					msg = format("Could not access process: %s", fromStringz(messageBuffer));
				else
					msg = format("Could not access process: Code %d", error);
				throw new IdlException(msg);
			}
			scope(exit) CloseHandle(hProc);
			
			if (NtSuspendProcess(hProc) != 0)
				throw new IdlException("Failed to suspend process.");
			scope(exit) NtResumeProcess(hProc);
			
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

				Background rbg = void;

				if(ReadProcessMemory(hProc, addr, &rbg, Background.sizeof, null) == FALSE)
					throw new IdlException("Could not read process memory: rbg");

				debug(Unknown)
				{
					auto bgLog = File("rbg.log", "wb");
					bgLog.writeln(rbg.unknown);
					bgLog.close();
				}

				debug(LogFile) rbgLog.write(rbg);

				Background bg = void;
				// Fill up with zeros
				memset(&bg, 0, Background.sizeof);

				bg.unknown = rbg.unknown;

				DataState state = DataState.none;
				ptrdiff_t layeri = -1;
				for(size_t i = 0; i < tokens.length; i++)
				{
					switch(tokens[i].str)
					{
						case "name:":
						{
							string n = tokens[++i].str;
							if(n.length >= bg.name.length)
								throw new IdlException(format("Length %d for name is overflow, it must be less than %d: \"%s\" in line: %d at col: %d", n.length, bg.name.length, n, tokens[i].line, tokens[i].col));
							{
								emplaceString(n, bg.name);
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
							string s = tokens[++i].str;
							if(s.length >= bg.shadow_bmp.length)
								throw new IdlException(format("Path length %d for shadow is overflow, it must be less than %d: \"%s\" in line: %d at col: %d", s.length, bg.shadow_bmp.length, s, tokens[i].line, tokens[i].col));
							{
								emplaceString(s, bg.shadow_bmp);
							}
							break;
						}
						case "shadowsize:":
							bg.shadowsize1 = tokens[++i].str.to!int;
							bg.shadowsize2 = tokens[++i].str.to!int;
							break;
						case "layer:":
							layeri++;
							if(layeri >= Background.layer_bmps.length)
								throw new IdlException(format("Layer count %d is overflow, it must be less or equal to %d", layeri + 1, bg.layer_bmps.length));
							{
								string m = tokens[++i].str;
								if(m.length >= bg.layer_bmps[layeri].length)
									throw new IdlException(format("Layer bitmap path length %d is overflow, it must be less than %d", m.length, bg.layer_bmps[layeri].length));
								{
									emplaceString(m, bg.layer_bmps[layeri]);
								}
							}
							state = DataState.layer;
							Lbloop2:
							for(i++; i < tokens.length; i++)
							{
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
										if(logFunc != null)
										{
											logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
										}
										break;
								}
							}
							break;
						default:
							if(logFunc != null)
							{
								logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
							}
							break;
					}
				}
				debug(LogFile) bgLog.write(bg);
				if(WriteProcessMemory(hProc, addr, &bg, Background.sizeof, null) == FALSE)
					throw new IdlException("Could not write background to process memory");
			}
			else if(dataType == DataType.Stage)
			{
				void* addr = getStagesAddr(hProc);

				debug(LogFile)
				{
					File rstagesLog = File("rstages.log", "wb");
					scope(exit) rstagesLog.close();
				}
				
				// Allocate it cuz ReadProcessMemory won't do it for us
				Stage[] rstages = (cast(Stage*)malloc(Stage.sizeof * 60))[0 .. 60];
				if(!rstages)
					throw new IdlException(format("Could not allocate rstages: %d Bytes", Stage.sizeof * 60));
				scope(exit) free(rstages.ptr);

				if(ReadProcessMemory(hProc, addr, rstages.ptr, (Stage.sizeof * 60), null) == FALSE)
					throw new IdlException("Could not read process memory: stages");

				debug(LogFile)
				{
					foreach(i, ref stage; rstages)
					{
						rstagesLog.write(stage.toString(i));
					}

					File stagesLog = File("stages.log", "wb");
					scope(exit) stagesLog.close();
				}

				// Start over cleanly
				Stage[] stages = (cast(Stage*)malloc(Stage.sizeof * 60))[0 .. 60];
				if(!stages)
					throw new IdlException(format("Could not allocate stages: %d byte", Stage.sizeof * 60));
				scope(exit) free(stages.ptr);
				// Fill up with zeros
				memset(stages.ptr, 0, Stage.sizeof * 60);
				
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
							stages[i].phases[j].spawns[k].unknown1 = rstages[i].phases[j].spawns[k].unknown1;
							stages[i].phases[j].spawns[k].unknown2 = rstages[i].phases[j].spawns[k].unknown2;
						}
					}
				}
				DataState state = DataState.none;
				for(size_t i = 0; i < tokens.length; i++)
				{
					switch(tokens[i].str)
					{
						case "<stage>":
							state = DataState.stage;
							Stage* stage = cast(Stage*)malloc(Stage.sizeof);
							if(stage == null)
								throw new IdlException("Could not allocate stage: Out of memory");
							scope(exit) free(stage);
							stage.phase_count = -1;
							int stageId = -1;
							ptrdiff_t phasei = -1;
							Lloop2:
							for(i++; i < tokens.length; i++)
							{
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
										Phase phase;
										foreach(ref spn; phase.spawns)
											spn.id = -1;
										phase.when_clear_goto_phase = -1;
										ptrdiff_t spawni = -1;
										Lloop3:
										for(i++; i < tokens.length; i++)
										{
											switch(tokens[i].str)
											{
												case "bound:":
													phase.bound = tokens[++i].str.to!int;
													break;
												case "music:":
													{
														string m = tokens[++i].str;
														if(m.length >= phase.music.length)
															throw new IdlException(format("Path length %d for phase background music (bgm) is overflow, it must be less than %d: \"%s\" in line: %d at col: %d", m.length, phase.music.length, m, tokens[i].line, tokens[i].col));
														{
															emplaceString(m, phase.music);
														}
														break;
													}
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
												case "y:":
													if(spawni < 0)
														continue Lloop3;
													phase.spawns[spawni].y = tokens[++i].str.to!int;
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
													//if(logFunc != null)
													//{
													//	auto msg = toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col));
													//	logFunc(msg, null, MsgType.Warning);
													//}
													break;
											}
										}
										break;
									case "<stage>":
										if(logFunc != null)
										{
											auto msg = toStringz(format("Stage recursion in line %d at col %d", 
													tokens[i].line, tokens[i].col));
											logFunc(msg, null, MsgType.Warning);
											warn++;
											if(warn >= maxWarning)
												throw new IdlException(format(warningHigh));
										}
										i--;
										goto case;
									case "<stage_end>":
										if(stageId < 0)
											throw new IdlException("Stage id could not be received");
										int m = stageId;
										{
											for(size_t n = 0; n < stage.phases.length; ++n)
											{
												for(size_t k = 0; k < stage.phases[n].spawns.length; ++k)
												{
													// because static arrays are value types muhahahaaa:
													stage.phases[n].spawns[k].unknown1 = stages[m].phases[n].spawns[k].unknown1;
													stage.phases[n].spawns[k].unknown2 = stages[m].phases[n].spawns[k].unknown2;
												}
											}
										}
										stages[stageId] = *stage;
										debug(LogFile) stagesLog.write((*stage).toString(stageId));
										state = DataState.none;
										break Lloop2;
									default:
										//if(logFunc != null)
										//{
										//	auto msg = toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col));
										//	logFunc(msg, null, MsgType.Warning);
										//}
										break;
								}
							}
							break;
						default:
							//if(logFunc != null)
							//{
							//	auto msg = toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col));
							//	logFunc(msg, null, MsgType.Warning);
							//}
							break;
					}
				}
				if(WriteProcessMemory(hProc, addr, stages.ptr, Stage.sizeof * 60, null) == FALSE)
					throw new IdlException("Could not write stages to process memory");
			}
			else if(dataType == DataType.Object)
			{
				void* addr = getAddrOfObj(hProc, datIndex);

				debug(LogFile)
				{
					File objLog = File("obj.log", "wb");
					scope(exit) objLog.close();
					File objUnknownLog = File("obj_unknown.log", "wb");
					scope(exit) objUnknownLog.close();
				}

				SYSTEM_INFO sysInfo;
				GetSystemInfo(&sysInfo);
				// dwPageSize is needed to figure out how big RegionSize will be when we allocate ourself
				
				uint allocItrSize = sysInfo.dwPageSize, allocBdySize = sysInfo.dwPageSize;
				
				while(allocItrSize < Itr.sizeof * 5) allocItrSize += sysInfo.dwPageSize;
				while(allocBdySize < Bdy.sizeof * 5) allocBdySize += sysInfo.dwPageSize;

				// Allocate it cuz ReadProcessMemory won't do it for us
				DataFile* dataFileRead = cast(DataFile*)malloc(DataFile.sizeof);
				if(dataFileRead == null)
					throw new IdlException(format("Could not allocate dataFileRead: %d Bytes", DataFile.sizeof));
				scope(exit) free(dataFileRead);

				if(ReadProcessMemory(hProc, addr, dataFileRead, DataFile.sizeof, null) == FALSE)
					throw new IdlException(format("Could not read process memory: dataFileRead\r\nAddr=%s\r\ndatId=", addr, datIndex));

				debug(LogFile)
				{
					{
						objUnknownLog.writeln(dataFileRead.weapon_strength_list);
						objUnknownLog.writeln(dataFileRead.entry_names);
					}
				}

				// Start over cleanly
				DataFile* dataFile = cast(DataFile*)malloc(DataFile.sizeof);
				if(dataFile == null)
					throw new IdlException(format("Could not allocate DataFile: %d Bytes", DataFile.sizeof));
				scope(exit) free(dataFile);
				// Fill up with zeros
				memset(dataFile, 0, DataFile.sizeof);

				dataFile.id = dataFileRead.id;
				dataFile.type = objType;

				dataFile.unknown1 = dataFileRead.unknown1;
				// Static arrays are value types:
				dataFile.unknown2 = dataFileRead.unknown2;
				dataFile.unknown3 = dataFileRead.unknown3;
				dataFile.unknown4 = dataFileRead.unknown4;
				dataFile.unknown5 = dataFileRead.unknown5;
				dataFile.unknown6 = dataFileRead.unknown6;
				dataFile.unknown7 = dataFileRead.unknown7;

				foreach(i, ref entry; dataFile.weapon_strength_list)
				{
					entry.unknown1 = dataFileRead.weapon_strength_list[i].unknown1;
					entry.unknown2 = dataFileRead.weapon_strength_list[i].unknown2;
					entry.unknown3 = dataFileRead.weapon_strength_list[i].unknown3;
				}
				
				dataFile.pic_count = dataFileRead.pic_count;
				dataFile.pic_bmps = dataFileRead.pic_bmps;
				dataFile.pic_index = dataFileRead.pic_index;
				dataFile.pic_width = dataFileRead.pic_width;
				dataFile.pic_height = dataFileRead.pic_height;
				dataFile.pic_row = dataFileRead.pic_row;
				dataFile.pic_col = dataFileRead.pic_col;
				dataFile.small_bmp = dataFileRead.small_bmp;
				dataFile.face_bmp = dataFileRead.face_bmp;
				
				for(int i = 0; i < dataFile.frames.length; i++)
				{
					dataFile.frames[i].sound = dataFileRead.frames[i].sound;
					
					dataFile.frames[i].unknown1 = dataFileRead.frames[i].unknown1;
					dataFile.frames[i].unknown2 = dataFileRead.frames[i].unknown2;
					dataFile.frames[i].unknown3 = dataFileRead.frames[i].unknown3;
					dataFile.frames[i].unknown4 = dataFileRead.frames[i].unknown4;
					dataFile.frames[i].unknown5 = dataFileRead.frames[i].unknown5;
					dataFile.frames[i].unknown6 = dataFileRead.frames[i].unknown6;
					dataFile.frames[i].unknown7 = dataFileRead.frames[i].unknown7; //static arrays are value types
					dataFile.frames[i].unknown8 = dataFileRead.frames[i].unknown8;
					dataFile.frames[i].unknown9 = dataFileRead.frames[i].unknown9;
				}

				DataState state = DataState.none;
				for(size_t i = 0; i < tokens.length; i++)
				{
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
									switch(tokens[i].str)
									{
										case "name:":
										{
											string n = tokens[++i].str;
											if(n.length >= dataFile.name.length)
												throw new IdlException(format("Length %d for name is overflow, it must be less than %d: \"%s\" in line: %d at col: %d", n.length, dataFile.name.length, n, tokens[i].line, tokens[i].col));
											{
												emplaceString(n, dataFile.name);
											}
											break;
										}
										case "head:":
											i++; //ignore
											break;
										case "small:":
											i++; //ignore
											break;
										case "walking_frame_rate":
											dataFile.walking_frame_rate = tokens[++i].str.to!int;
											break;
										case "walking_speed":
											dataFile.walking_speed = tokens[++i].str.to!double;
											break;
										case "walking_speedz":
											dataFile.walking_speedz = tokens[++i].str.to!double;
											break;
										case "running_frame_rate":
											dataFile.running_frame_rate = tokens[++i].str.to!int;
											break;
										case "running_speed":
											dataFile.running_speed = tokens[++i].str.to!double;
											break;
										case "running_speedz":
											dataFile.running_speedz = tokens[++i].str.to!double;
											break;
										case "heavy_walking_speed":
											dataFile.heavy_walking_speed = tokens[++i].str.to!double;
											break;
										case "heavy_walking_speedz":
											dataFile.heavy_walking_speedz = tokens[++i].str.to!double;
											break;
										case "heavy_running_speed":
											dataFile.heavy_running_speed = tokens[++i].str.to!double;
											break;
										case "heavy_running_speedz":
											dataFile.heavy_running_speedz = tokens[++i].str.to!double;
											break;
										case "jump_height":
											dataFile.jump_height = tokens[++i].str.to!double;
											break;
										case "jump_distance":
											dataFile.jump_distance = tokens[++i].str.to!double;
											break;
										case "jump_distancez":
											dataFile.jump_distancez = tokens[++i].str.to!double;
											break;
										case "dash_height":
											dataFile.dash_height = tokens[++i].str.to!double;
											break;
										case "dash_distance":
											dataFile.dash_distance = tokens[++i].str.to!double;
											break;
										case "dash_distancez":
											dataFile.dash_distancez = tokens[++i].str.to!double;
											break;
										case "rowing_height":
											dataFile.rowing_height = tokens[++i].str.to!double;
											break;
										case "rowing_distance":
											dataFile.rowing_distance = tokens[++i].str.to!double;
											break;
										case "weapon_hp:":
											dataFile.weapon_hp = tokens[++i].str.to!int;
											break;
										case "weapon_hit_sound:":
											i++; //ignore
											break;
										case "weapon_drop_sound:":
											i++; //ignore
											break;
										case "weapon_broken_sound:":
											i++; //ignore
											break;
										case "weapon_drop_hurt:":
											dataFile.weapon_drop_hurt = tokens[++i].str.to!int;
											break;
										case "<bmp_end>":
											state = DataState.none;
											break Lcloop2;
										default:
											if(logFunc != null)
											{
												logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
											}
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
										if(entryi >= dataFile.weapon_strength_list.length)
											throw new IdlException("More than 4 weapon strength entry is overflow");
										i++; //jump over the entry index cuz I think it's not used (ie: "entry: 2 jump")
										{
											string n = tokens[++i].str;
											if(n.length >= dataFile.entry_names[entryi].length)
											{
												if(logFunc != null)
												{
													logFunc(toStringz(format("Length %d for entry name is overflow, it should be less than %d: \"%s\" in line: %d at col: %d", n.length, dataFile.entry_names[entryi].length, n, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
													warn++;
													if(warn >= maxWarning)
														throw new IdlException(format(warningHigh));
												}
											}
											{
												emplaceString(n, dataFile.entry_names[entryi]);
											}
										}
										break;
									case "dvx:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].dvx = tokens[++i].str.to!int;
										break;
									case "dvy:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].dvy = tokens[++i].str.to!int;
										break;
									case "arest:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].arest = tokens[++i].str.to!int;
										break;
									case "vrest:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].vrest = tokens[++i].str.to!int;
										break;
									case "bdefend:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].bdefend = tokens[++i].str.to!int;
										break;
									case "effect:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].effect = tokens[++i].str.to!int;
										break;
									case "fall:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].fall = tokens[++i].str.to!int;
										break;
									case "injury:":
										if(entryi < 0)
											continue Lwloop;
										dataFile.weapon_strength_list[entryi].injury = tokens[++i].str.to!int;
										break;
									case "<weapon_strength_list_end>":
										state = DataState.none;
										break Lwloop;
									default:
										if(logFunc != null)
										{
											logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
										}
										break;
								}
							}
							break;
						case "<frame>":
							state = DataState.frame;
							int frameId = tokens[++i].str.to!int;
							{
								string c = tokens[++i].str;
								if(c.length >= dataFile.frames[frameId].fname.length)
								{
									if(logFunc != null)
									{
										logFunc(toStringz(format("Length %d for frame caption is overflow, it should be less than %d: \"%s\" in line: %d at col: %d", c.length, dataFile.frames[frameId].fname.length, c, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
										warn++;
										if(warn >= maxWarning)
											throw new IdlException(format(warningHigh));
									}
								}
								{
									emplaceString(c, dataFile.frames[frameId].fname);
								}
							}
							Bdy[] bdys = new Bdy[0];
							Itr[] itrs = new Itr[0];
							bdys.reserve(5);
							itrs.reserve(5);
							Lcloop3:
							for(i++; i < tokens.length; i++)
							{
								switch(tokens[i].str)
								{
									case "pic:":
										dataFile.frames[frameId].pic = tokens[++i].str.to!int;
										break;
									case "state:":
										dataFile.frames[frameId].state = tokens[++i].str.to!int;
										break;
									case "wait:":
										dataFile.frames[frameId].wait = tokens[++i].str.to!int;
										break;
									case "next:":
										dataFile.frames[frameId].next = tokens[++i].str.to!int;
										break;
									case "dvx:":
										dataFile.frames[frameId].dvx = tokens[++i].str.to!int;
										break;
									case "dvy:":
										dataFile.frames[frameId].dvy = tokens[++i].str.to!int;
										break;
									case "dvz:":
										dataFile.frames[frameId].dvz = tokens[++i].str.to!int;
										break;
									case "centerx:":
										dataFile.frames[frameId].centerx = tokens[++i].str.to!int;
										break;
									case "centery:":
										dataFile.frames[frameId].centery = tokens[++i].str.to!int;
										break;
									case "hit_a:":
										dataFile.frames[frameId].hit_a = tokens[++i].str.to!int;
										break;
									case "hit_d:":
										dataFile.frames[frameId].hit_d = tokens[++i].str.to!int;
										break;
									case "hit_j:":
										dataFile.frames[frameId].hit_j = tokens[++i].str.to!int;
										break;
									case "hit_Fa:":
										dataFile.frames[frameId].hit_Fa = tokens[++i].str.to!int;
										break;
									case "hit_Ua:":
										dataFile.frames[frameId].hit_Ua = tokens[++i].str.to!int;
										break;
									case "hit_Da:":
										dataFile.frames[frameId].hit_Da = tokens[++i].str.to!int;
										break;
									case "hit_Fj:":
										dataFile.frames[frameId].hit_Fj = tokens[++i].str.to!int;
										break;
									case "hit_Uj:":
										dataFile.frames[frameId].hit_Uj = tokens[++i].str.to!int;
										break;
									case "hit_Dj:":
										dataFile.frames[frameId].hit_Dj = tokens[++i].str.to!int;
										break;
									case "hit_ja:":
										dataFile.frames[frameId].hit_ja = tokens[++i].str.to!int;
										break;
									case "mp:":
										dataFile.frames[frameId].mp = tokens[++i].str.to!int;
										break;
									case "sound:":
										i++; //ignore
										break;
									case "bdy:":
										state = DataState.bdy;
										Bdy bdy;
										LcloopBdy:
										for(i++; i < tokens.length; i++)
										{
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
													if(logFunc != null)
													{
														logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
													}
													break;
											}
										}
										break;
									case "itr:":
										state = DataState.itr;
										Itr itr;
										LcloopI:
										for(i++; i < tokens.length; i++)
										{
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
													if(logFunc != null)
													{
														logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
													}
													break;
											}
										}
										break;
									case "wpoint:":
										state = DataState.wpoint;
										Wpoint wp;
										LcloopW:
										for(i++; i < tokens.length; i++)
										{
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
													dataFile.frames[frameId].wpoint = wp;
													state = DataState.frame;
													break LcloopW;
												default:
													if(logFunc != null)
													{
														logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
													}
													break;
											}
										}
										break;
									case "opoint:":
										state = DataState.opoint;
										Opoint op;
										LcloopO:
										for(i++; i < tokens.length; i++)
										{
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
													dataFile.frames[frameId].opoint = op;
													state = DataState.frame;
													break LcloopO;
												default:
													if(logFunc != null)
													{
														logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
													}
													break;
											}
										}
										break;
									case "cpoint:":
										state = DataState.cpoint;
										Cpoint cp;
										LcloopC:
										for(i++; i < tokens.length; i++)
										{
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
												case "taction:":
													cp.taction = tokens[++i].str.to!int;
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
													dataFile.frames[frameId].cpoint = cp;
													state = DataState.frame;
													break LcloopC;
												default:
													if(logFunc != null)
													{
														logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
													}
													break;
											}
										}
										break;
									case "bpoint:":
										state = DataState.bpoint;
										Bpoint bp;
										LcloopB:
										for(i++; i < tokens.length; i++)
										{
											switch(tokens[i].str)
											{
												case "x:":
													bp.x = tokens[++i].str.to!int;
													break;
												case "y:":
													bp.y = tokens[++i].str.to!int;
													break;
												case "bpoint_end:":
													dataFile.frames[frameId].bpoint = bp;
													state = DataState.frame;
													break LcloopB;
												default:
													if(logFunc != null)
													{
														logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
													}
													break;
											}
										}
										break;
									case "<frame_end>":
										dataFile.frames[frameId].exists = 1;
										dataFile.frames[frameId].bdys = bdys.ptr;
										dataFile.frames[frameId].itrs = itrs.ptr;
										dataFile.frames[frameId].bdy_count = bdys.length;
										dataFile.frames[frameId].itr_count = itrs.length;
										state = DataState.none;
										break Lcloop3;
									default:
										if(logFunc != null)
										{
											logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
										}
										break;
								}
							}
							break;
						default:
							if(logFunc != null)
							{
								logFunc(toStringz(format(unhandledMsg, tokens[i].str, tokens[i].line, tokens[i].col)), null, MsgType.Warning);
							}
							break;
					}
				}

				foreach(i, ref frame; dataFile.frames)
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
						debug(LogFile)
						{
							objLog.writeln("itr_x: ", frame.itr_x,
								"  itr_y: ", frame.itr_y,
								"  itr_w: ", frame.itr_w,
								"  itr_h: ", frame.itr_h, "\n");
						}
					}
					
					if(frame.bdy_count > 0)
					{
						// Should we allocate or simply use previously allocated memory
						if(dataFileRead.frames[i].bdy_count <= 0)
						{
							// Allocate bdys for LF2
							Bdy* bdyAlloc = cast(Bdy*)VirtualAllocEx(hProc, null, Bdy.sizeof * frame.bdy_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(bdyAlloc == null)
								throw new IdlException("Could not allocate bdy array for LF2");
							
							if(WriteProcessMemory(hProc, bdyAlloc, frame.bdys, Bdy.sizeof * frame.bdy_count, null) == FALSE)
								throw new IdlException("Could not write process memory: frame.bdys");
							frame.bdys = bdyAlloc;
						}
						else if(dataFileRead.frames[i].bdy_count < frame.bdy_count)
						{
							MEMORY_BASIC_INFORMATION memInfo;
							if(VirtualQueryEx(hProc, dataFileRead.frames[i].bdys, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
								throw new IdlException("Could not query process memory: bdys");
							
							if(memInfo.RegionSize == allocBdySize)
							{
								if(VirtualFreeEx(hProc, dataFileRead.frames[i].bdys, 0, MEM_RELEASE) == FALSE)
									throw new IdlException("Could not free process memory: bdys");
							}
							//else
							//	throw new IdlException(format("memInfo.RegionSize(%d) != allocBdySize(%d)", memInfo.RegionSize, allocBdySize));
							
							// Alocate bdys for LF2
							Bdy* bdyAlloc = cast(Bdy*)VirtualAllocEx(hProc, null, Bdy.sizeof * frame.bdy_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(bdyAlloc == null)
								throw new IdlException("Could not allocate bdy array for process memory");
							
							if(WriteProcessMemory(hProc, bdyAlloc, frame.bdys, Bdy.sizeof * frame.bdy_count, null) == FALSE)
								throw new IdlException("Could not write process memory: frame.bdys");
							frame.bdys = bdyAlloc;
						}
						else
						{
							if(WriteProcessMemory(hProc, dataFileRead.frames[i].bdys, frame.bdys, Bdy.sizeof * frame.bdy_count, null) == FALSE)
								throw new IdlException("Could not write process memory: frame.bdys");
							frame.bdys = dataFileRead.frames[i].bdys;
						}
					}
					else if(dataFileRead.frames[i].bdy_count > 0)
					{
						MEMORY_BASIC_INFORMATION memInfo;
						if(VirtualQueryEx(hProc, dataFileRead.frames[i].bdys, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
							throw new IdlException("Could not query process memory: bdys");
						
						if(memInfo.RegionSize == allocBdySize)
						{
							if(VirtualFreeEx(hProc, dataFileRead.frames[i].bdys, 0, MEM_RELEASE) == FALSE)
								throw new IdlException("Could not free process memory: bdys");
						}
						//else
						//	throw new IdlException(format("memInfo.RegionSize(%d) != allocBdySize(%d)", memInfo.RegionSize, allocBdySize));
					}

					if(frame.itr_count > 0)
					{
						// Should we allocate or simply use previously allocated memory
						if(dataFileRead.frames[i].itr_count <= 0)
						{
							// Allocate itrs for LF2
							Itr* itrAlloc = cast(Itr*)VirtualAllocEx(hProc, null, Itr.sizeof * frame.itr_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(itrAlloc == null)
								throw new IdlException("Could not allocate itr array for LF2");
							
							if(WriteProcessMemory(hProc, itrAlloc, frame.itrs, Itr.sizeof * frame.itr_count, null) == FALSE)
								throw new IdlException("Could not write process memory: frame.itrs");
							frame.itrs = itrAlloc;
						}
						else if(dataFileRead.frames[i].itr_count < frame.itr_count)
						{
							MEMORY_BASIC_INFORMATION memInfo;
							if(VirtualQueryEx(hProc, dataFileRead.frames[i].itrs, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
								throw new IdlException("Could not query process memory: itrs");
							
							if(memInfo.RegionSize == allocItrSize)
							{
								if(VirtualFreeEx(hProc, dataFileRead.frames[i].itrs, 0, MEM_RELEASE) == FALSE)
									throw new IdlException("Could not free process memory: itrs");
							}
							//else
							//	throw new IdlException(format("memInfo.RegionSize(%d) != allocItrSize(%d)", memInfo.RegionSize, allocItrSize));
							
							// Allocate itrs for LF2
							Itr* itrAlloc = cast(Itr*)VirtualAllocEx(hProc, null, Itr.sizeof * frame.itr_count, MEM_COMMIT, PAGE_READWRITE);
							
							if(itrAlloc == null)
								throw new IdlException("Could not allocate itr array for LF2");
							
							if(WriteProcessMemory(hProc, itrAlloc, frame.itrs, Itr.sizeof * frame.itr_count, null) == FALSE)
								throw new IdlException("Could not write process memory: frame.itrs");
							frame.itrs = itrAlloc;
						}
						else
						{
							if(WriteProcessMemory(hProc, dataFileRead.frames[i].itrs, frame.itrs, Itr.sizeof * frame.itr_count, null) == FALSE)
								throw new IdlException("Could not write process memory: DataFile");
							frame.itrs = dataFileRead.frames[i].itrs;
						}
					}
					else if(dataFileRead.frames[i].itr_count > 0)
					{
						MEMORY_BASIC_INFORMATION memInfo;
						if(VirtualQueryEx(hProc, dataFileRead.frames[i].itrs, &memInfo, MEMORY_BASIC_INFORMATION.sizeof) == 0)
							throw new IdlException("Could not query process memory: itrs");
						
						if(memInfo.RegionSize == allocItrSize)
						{
							if(VirtualFreeEx(hProc, dataFileRead.frames[i].itrs, 0, MEM_RELEASE) == FALSE)
								throw new IdlException("Could not free process memory: itrs");
						}
						//else
						//	throw new IdlException(format("memInfo.RegionSize(%d) != allocItrSize(%d)", memInfo.RegionSize, allocItrSize));
					}
				}

				if(WriteProcessMemory(hProc, addr, dataFile, DataFile.sizeof, null) == FALSE)
					throw new IdlException("Could not write process memory: DataFile");
			}
		}
		catch(IdlException ex)
		{
			if(logFunc != null)
				logFunc(toStringz(ex.msg), null, MsgType.Error);
			else
				MessageBoxA(hMainWindow, toStringz(ex.toString), "[IDL.dll] Data Loading Error", MB_SETFOREGROUND);
			return 2;
		}
		catch(Exception ex)
		{
			if(logFunc != null)
				logFunc(toStringz(ex.toString), toStringz("Unhandled Error"), MsgType.Error);
			else
				MessageBoxA(hMainWindow, toStringz(ex.toString), "[IDL.dll] Unhandled Error", MB_SETFOREGROUND);
			return -1;
		}
		catch(Error err)
		{
			if(logFunc != null)
				logFunc(toStringz(err.toString), toStringz("Fatal Error"), MsgType.Error);
			else
				MessageBoxA(hMainWindow, toStringz(err.toString), "[IDL.dll] Fatal Error", MB_SETFOREGROUND);
			return int.max;
		}
	}
	catch(Throwable t)
	{
		return int.min;
	}

	return warn > 0 ? 1 : 0;
}
