module idl.util;

import core.stdc.stdlib;
import core.exception : OutOfMemoryError;

import std.algorithm;
import std.conv;
import std.format;
import std.string;

enum phi = 1.61803398874989484820458683436563811772;

/// Unmanaged array backed by malloc and friends. Automatically grows its
/// capacity, but does NOT automatically free its memory.
struct MallocArray(T)
{
	private T* _data;
	private size_t _length;
	private size_t _capacity;
	
	invariant
	{
		assert(_length <= _capacity);
	}
	
	@disable this();
	
	this(size_t capacity)
	{
		this._data = cast(T*)malloc(T.sizeof * capacity);
		if (this._data == null)
			throw new OutOfMemoryError();
		this._capacity = capacity;
	}
	
	@property inout(T)[] data() inout
	{
		return this._data ? this._data[0 .. this._length] : null;
	}
	
	@property inout(T)* ptr() inout
	{
		return this._data;
	}
	
	@property size_t length()
	{
		return this._data ? this._length : 0;
	}
	
	@property size_t capacity()
	{
		return this._data ? this._capacity : 0;
	}
	
	alias opDollar = length;
	
	MallocArray!T put(T value)
	{
		if (this._length == this._capacity)
		{
			size_t newCapacity = max(cast(size_t)(this._capacity * phi), 4);
			this._data = cast(T*)realloc(this._data, T.sizeof * newCapacity);
			if (this._data == null)
				throw new OutOfMemoryError();
		}
		this._data[this._length++] = value;
		return this;
	}
	
	alias opOpAssign(string op : "~") = put;
	
	ref inout(T) opIndex(size_t index) inout
	{
		return this.data[index];
	}
}

/+
/// Reference counted CoTaskMem array
struct CoArray(T)
{
	pragma(lib, "ole32");
	import core.sys.windows.objbase : CoTaskMemAlloc, CoTaskMemFree, CoTaskMemRealloc;
	import std.typecons : RefCounted, RefCountedAutoInitialize;
	
	invariant
	{
		assert(p.length <= p.capacity);
	}
	
	static struct Payload
	{
		T* data;
		size_t length;
		size_t capacity;
		
		~this()
		{
			CoTaskMemFree(data);
			data = null;
			this.length = 0;
			this.capacity = 0;
		}
	}
	
	RefCounted!(Payload, RefCountedAutoInitialize.no) p;
	
	@disable this();
	
	this(size_t capacity)
	{
		T* data = cast(T*)CoTaskMemAlloc(T.sizeof * capacity);
		if (data == null)
			throw new OutOfMemoryError();
		p = Payload(data, 0, capacity);
	}
	
	@property size_t length()
	{
		return p.data ? p.length : 0;
	}
	
	CoArray!T put(T value)
	{
		if (p.length == p.capacity)
		{
			size_t newCapacity = max(cast(size_t)(p.capacity * phi), 4);
			T* data = cast(T*)CoTaskMemRealloc(p.data, T.sizeof * newCapacity);
			if (data == null)
				throw new OutOfMemoryError();
		}
		p.data[p.length++] = value;
		return this;
	}
	
	alias opOpAssign(string op : "~") = put;
	
	ref T opIndex(size_t index)
	{
		return p.data[0 .. p.length][index];
	}
	
	ref T opIndexAssign(T value, size_t index)
	{
		return p.data[0 .. p.length][index] = value;
	}
}

DWORD getPidByName(wstring processName)
{
	PROCESSENTRY32 processInfo;
	processInfo.dwSize = PROCESSENTRY32.sizeof;
	
	HANDLE processesSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
	if (processesSnapshot == INVALID_HANDLE_VALUE)
		return 0;
	scope(exit)
		CloseHandle(processesSnapshot);
	
	if (Process32First(processesSnapshot, &processInfo) == 0)
		return 0;
	do
	{
		if (processName == fromStringz(processInfo.szExeFile.ptr))
			return processInfo.th32ProcessID;
	}
	while (Process32Next(processesSnapshot, &processInfo));
	
	return 0;
}
+/

char* emplaceString(size_t N)(const(char)[] src, ref char[N] dst)
{
	import std.algorithm.comparison : min;
	size_t l = min(N - 1, src.length);
	dst[0 .. l] = src[0 .. l];
	dst[l] = 0;
	return dst.ptr;
}
