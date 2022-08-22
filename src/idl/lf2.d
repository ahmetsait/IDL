module idl.lf2;

struct Opoint
{
	int kind = void;
	int x = void;
	int y = void;
	int action = void;
	int dvx = void;
	int dvy = void;
	int oid = void;
	int facing = void;
}

struct Bpoint
{
	int x = void;
	int y = void;
}

struct Cpoint
{
	int kind = void;
	int x = void;
	int y = void;
	union
	{
		int injury = void; // If its kind 2 this is fronthurtact
		int fronthurtact = void;
	}
	union
	{
		int cover = void; // If its kind 2 this is backhurtact
		int backhurtact = void;
	}
	int vaction = void;
	int aaction = void;
	int jaction = void;
	int daction = void;
	int throwvx = void;
	int throwvy = void;
	int hurtable = void;
	int decrease = void;
	int dircontrol = void;
	int taction = void;
	int throwinjury = void;
	int throwvz = void;
}

struct Wpoint
{
	int kind = void;
	int x = void;
	int y = void;
	int weaponact = void;
	int attacking = void;
	int cover = void;
	int dvx = void;
	int dvy = void;
	int dvz = void;
}

struct Itr
{
	int kind = void;
	int x = void;
	int y = void;
	int w = void;
	int h = void;
	int dvx = void;
	int dvy = void;
	int fall = void;
	int arest = void;
	int vrest = void;
	int unknown1 = void;
	int effect = void;
	int catchingact1 = void;
	int catchingact2 = void;
	int caughtact1 = void;
	int caughtact2 = void;
	int bdefend = void;
	int injury = void;
	int zwidth = void;
	int unknown2 = void;
}

struct Bdy
{
	int kind = void;
	int x = void;
	int y = void;
	int w = void;
	int h = void;
	int unknown1 = void;
	int unknown2 = void;
	int unknown3 = void;
	int unknown4 = void;
	int unknown5 = void;
}

struct Frame
{
	ubyte exists = void;
	int pic = void;
	int state = void;
	int wait = void;
	int next = void;
	int dvx = void;
	int dvy = void;
	int dvz = void;
	int unknown1 = void;
	int hit_a = void;
	int hit_d = void;
	int hit_j = void;
	int hit_Fa = void;
	int hit_Ua = void;
	int hit_Da = void;
	int hit_Fj = void;
	int hit_Uj = void;
	int hit_Dj = void;
	int hit_ja = void;
	int mp = void;
	int centerx = void;
	int centery = void;
	Opoint opoint = void;
	int unknown2 = void;
	int unknown3 = void;
	Bpoint bpoint = void;
	Cpoint cpoint = void;
	int unknown4 = void;
	int unknown5 = void;
	int unknown6 = void;
	Wpoint wpoint = void;
	int[11] unknown7 = void;
	int itr_count = void;
	int bdy_count = void;
	// These are pointers to arrays
	Itr* itrs = void;
	Bdy* bdys = void;
	// These values form a rectangle that holds all itrs/bdys within it
	int itr_x = void;
	int itr_y = void;
	int itr_w = void;
	int itr_h = void;
	int bdy_x = void;
	int bdy_y = void;
	int bdy_w = void;
	int bdy_h = void;
	//----------------------------------------
	int unknown8 = void;
	char[20] fname = void;
	/// Maximum sound path is unknown actually
	char[20]* sound = void;
	int unknown9 = void;
}

struct WeaponStrength
{
	int dvx = void;
	int dvy = void;
	int fall = void;
	int arest = void;
	int vrest = void;
	int unknown1 = void;
	int effect = void;
	int[4] unknown2 = void;
	int bdefend = void;
	int injury = void;
	ubyte[28] unknown3 = void;
}

struct DataFile
{
	int walking_frame_rate = void;
	int unknown1 = void;
	double walking_speed = void;
	double walking_speedz = void;
	int running_frame_rate = void;
	double running_speed = void;
	double running_speedz = void;
	double heavy_walking_speed = void;
	double heavy_walking_speedz = void;
	double heavy_running_speed = void;
	double heavy_running_speedz = void;
	double jump_height = void;
	double jump_distance = void;
	double jump_distancez = void;
	double dash_height = void;
	double dash_distance = void;
	double dash_distancez = void;
	double rowing_height = void;
	double rowing_distance = void;
	int weapon_hp = void;
	int weapon_drop_hurt = void;
	ubyte[124] unknown2 = void;
	WeaponStrength[4] weapon_strength_list = void;
	ubyte[410] unknown3 = void;
	char[30][4] entry_names = void;
	ubyte[50] unknown4 = void;
	int pic_count = void;
	char[40][10] pic_bmps = void;
	int[10] pic_index = void;
	int[10] pic_width = void;
	int[10] pic_height = void;
	int[10] pic_row = void;
	int[10] pic_col = void;
	int id = void;
	int type = void;
	int unknown5 = void;
	char[40] small_bmp = void;
	int unknown6 = void;
	char[40] face_bmp = void;
	int[20] unknown7 = void;
	Frame[400] frames = void;
	char[12] name = void; // Not actually certain that the length is 12, seems like voodoo magic
}

struct Object
{
	int move_counter = void;
	int run_counter = void;
	int blink = void;
	int unknown1 = void;
	int x = void;
	int y = void;
	int z = void;
	ubyte[12] unknown2 = void;
	double x_acceleration = void;
	double y_acceleration = void;
	double z_acceleration = void;
	double x_velocity = void;
	double y_velocity = void;
	double z_velocity = void;
	double x_real = void;
	double y_real = void;
	double z_real = void;
	int frame1 = void;
	int frame2 = void;
	int frame3 = void;
	int frame4 = void;
	ubyte facing = void;
	ubyte[15] unknown3 = void;
	int ccatcher = void;
	int ctimer = void;
	int weapon_type = void;
	int weapon_held = void;
	int weapon_holder = void;
	int unknown4 = void;
	ubyte[8] unknown5 = void;
	int fall = void;
	int shake = void;
	int bdefend = void;
	ubyte[10] unknown6 = void;
	ubyte holding_up = void;
	ubyte holding_down = void;
	ubyte holding_left = void;
	ubyte holding_right = void;
	ubyte holding_a = void;
	ubyte holding_j = void;
	ubyte holding_d = void;
	ubyte up = void;
	ubyte down = void;
	ubyte left = void;
	ubyte right = void;
	ubyte A = void;
	ubyte J = void;
	ubyte D = void;
	ubyte DrA = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DlA = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DuA = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DdA = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DrJ = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DlJ = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DuJ = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DdJ = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte DJA = void; // @suppress(dscanner.style.phobos_naming_convention)
	ubyte[15] unknown7 = void;
	int arest = void;
	int vrest = void;
	ubyte[396] unknown8 = void;
	int attacked_object_num = void;
	ubyte[112] unknown9 = void;
	int clone = void;
	int weapon_thrower = void;
	int hp = void;
	int dark_hp = void;
	int max_hp = void;
	int mp = void;
	int reserve = void;
	int unknown10 = void;
	int unknown11 = void;
	int pic_gain = void;
	int bottle_hp = void;
	ubyte[24] unknown12 = void;
	int firzen_counter = void;
	int unknown13 = void;
	int armour_multiplier = void;
	int unknown14 = void;
	int total_attack = void;
	int hp_lost = void;
	int mp_usage = void;
	int unknown15 = void;
	int kills = void;
	int weapon_picks = void;
	int enemy = void;
	int team = void;
	DataFile *data = void;
}

struct Spawn
{
	int[43] unknown1 = void; // Seems to have something to do with bosses, is changed during game so I believe it keeps track of whether or not soldiers should respawn
	int id = void;
	int x = void;
	int hp = void;
	int times = void;
	int reserve = void;
	int join = void;
	int join_reserve = void;
	int act = void;
	int y = void;
	double ratio = void;
	int role = void; // soldier = 1, boss = 2
	int unknown2 = void;
	
	//string toString(Phase* phase = null)
	//{
	//	import std.conv : text, to;
	//	return text("id: ", id, hp != 500 ? "  hp: " ~ hp.to!string : "", act != 9 ? "  act: " ~ act.to!string : "", phase != null ? (x != (phase.bound + 80) ? "  x: " ~ x.to!string : "") : "  x: " ~ x.to!string, y != 0 ? "  y: " ~ y.to!string : "", times != 1 ? "  times: " ~ times.to!string : "", ratio != 0 ? "  ratio: " ~ ratio.to!string : "", reserve != 0 ? "  reserve: " ~ reserve.to!string : "", join != 0 ? "  join: " ~ join.to!string : "", join_reserve != 0 ? "  join_reverse: " ~ join_reserve.to!string : "", role == 1 ? "\t<soldier>" : role == 2 ? "\t<boss>" : "");
	//}
}

struct Phase
{
	int bound = void;
	char[52] music = void;
	Spawn[60] spawns = void;
	int when_clear_goto_phase = void;
	
	//string toString()
	//{
	//	import std.conv : to;
	//	char[] str;
	//	str.reserve(1024);
	//	str ~= "        <phase> bound: ";
	//	str ~= bound.to!string;
	//	str ~= "\n";
	//	size_t mn = 0;
	//	for(size_t i = 0; i < music.length; i++)
	//	{
	//		if(music[i] == '\0')
	//		{
	//			mn = i;
	//			break;
	//		}
	//	}
	//	if(mn > 0)
	//	{
	//		str ~= "                music: ";
	//		str ~= music[0 .. mn];
	//		str ~= "\n";
	//	}
	//	for(size_t i = 0; i < spawns.length; i++)
	//	{
	//		if(spawns[i].id > 0)
	//		{
	//			str ~= "                ";
	//			str ~= spawns[i].toString(&this);
	//			str ~= "\n";
	//		}
	//	}
	//	str ~= "        <phase_end>\n";
	//	return str.idup;
	//}
}

struct Stage
{
	int phase_count = void;
	Phase[100] phases = void;

	//string toString(int id = -1)
	//{
	//	import std.conv : to;
	//	bool b = false;
	//	for(size_t i = 0; i < phase_count && i < phases.length; i++)
	//	{
	//		if(phases[i].bound != 0)
	//		{
	//			b = true;
	//			break;
	//		}
	//	}
	//	if(b == false)
	//		return "";
	//	char[] str;
	//	str ~= "<stage>";
	//	str.reserve(1024 * 16);
	//	if(id >= 0)
	//	{
	//		str ~= " id: ";
	//		str ~= id.to!string;
	//	}
	//	str ~= "\n";
	//	size_t i;
	//	for(i = 0; i < phase_count - 1 && i < phases.length - 1; i++)
	//	{
	//		str ~= phases[i].toString();
	//		str ~= "\n";
	//	}
	//	str ~= phases[i].toString();
	//	str ~= "<stage_end>\n\n\n";
	//	return str.idup;
	//}
}

struct Background
{
	int bg_width = void; //0x0
	int zboundary1 = void; //0x4
	int zboundary2 = void; // 0x8
	int perspective1 = void; //0xC
	int perspective2 = void; //0x10
	int shadowsize1 = void; //0x14
	int shadowsize2 = void; //0x18
	int layer_count = void; //0x1c
	char[30][30] layer_bmps = void; //0x20
	char[40] shadow_bmp = void; //0x3a4
	char[32] name = void;
	int[30] transparency = void; //0x3e0
	int[30] layer_width = void; // 0x458
	int[30] layer_x = void; // 0x4d0
	int[30] layer_y = void; // 0x548
	int[30] layer_height = void; // 0x5c0
	int[30] layer_loop = void;
	int[30] layer_c1 = void;
	int[30] layer_c2 = void;
	int[30] layer_cc = void;
	int[91] unknown = void;
}

struct FileManager
{
	DataFile*[500] datas = void;
	StageProxy stages = void;
	Background[50] backgrounds = void;
}

const void* gameAddr = cast(void*)0x458B00;

struct Game
{
	int state = void; // 0x4
	ubyte[400] exists = void; // 0x194
	Object*[400] objects = void; // 0x7d4
	FileManager* files = void; // 0xFA4
}

/// Because DMD sucks.
struct StageProxy
{
	Stage[12] s0 = void;
	Stage[12] s1 = void;
	Stage[12] s2 = void;
	Stage[12] s3 = void;
	Stage[12] s4 = void;
	
	//ref Stage opIndex(size_t i)
	//	in(i < this.sizeof)
	//{
	//	return s0.ptr[i];
	//}
	//
	//ref Stage opIndexAssign(ref Stage r, size_t i)
	//	in(i < this.sizeof)
	//{
	//	return s0.ptr[i] = r;
	//}
	//
	//ref Stage opIndexOpAssign(string op)(ref Stage r, size_t i)
	//	in(i < this.sizeof)
	//{
	//	return mixin(`s0.ptr[i] `~op~`= r`);
	//}
}

enum ObjectType : int
{
	Char = 0,
	Weapon = 1,
	HeavyWeapon = 2,
	SpecialAttack = 3,
	ThrowWeapon = 4,
	Criminal = 5,
	Drink = 6,
}

enum DataType : int
{
	Object = 0,
	Stage = 1,
	Background = 2,
}
