module processaux;

import core.sys.windows.windows;

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
