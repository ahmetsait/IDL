module lf2;

public:

struct sOpoint
{
public:
    int kind = void;
    int x = void;
    int y = void;
    int action = void;
    int dvx = void;
    int dvy = void;
    int oid = void;
    int facing = void;
}

struct sBpoint
{
public:
    int x = void;
    int y = void;
}

struct sCpoint
{
public:
    int kind = void;
    int x = void;
    int y = void;
	union
	{
		int injury = void; /// if its kind 2 this is fronthurtact
		int fronthurtact = void;
	}
	union
	{
		int cover = void; /// if its kind 2 this is backhurtact
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

struct sWpoint
{
public:
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

struct sItr
{
public:
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
    int unkwn1 = void;
    int effect = void;
	int catchingact1 = void;
	int catchingact2 = void;
	int caughtact1 = void;
	int caughtact2 = void;
    int bdefend = void;
    int injury = void;
    int zwidth = void;
	int unkwn2 = void;
}

struct sBdy
{
public:
    int kind = void;
    int x = void;
    int y = void;
    int w = void;
    int h = void;
	int unkwn1 = void;
	int unkwn2 = void;
	int unkwn3 = void;
	int unkwn4 = void;
	int unkwn5 = void;
}

struct sFrame
{
public:
    ubyte exists = void;
    int pic = void;
    int state = void;
    int wait = void;
    int next = void;
    int dvx = void;
    int dvy = void;
    int dvz = void;
	int unkwn1 = void;
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
	sOpoint opoint = void;
	int unkwn2 = void;
	int unkwn3 = void;
	sBpoint bpoint = void;
	sCpoint cpoint = void;
	int unkwn4 = void;
	int unkwn5 = void;
	int unkwn6 = void;
	sWpoint wpoint = void;
	int[11] unkwn7 = void;
    int itr_count = void;
    int bdy_count = void;
    //vv these are pointers to arrays
    sItr* itrs = void;
    sBdy* bdys = void;
    //vv these values form a rectangle that holds all itrs/bdys within it
    int itr_x = void;
    int itr_y = void;
    int itr_w = void;
    int itr_h = void;
    int bdy_x = void;
    int bdy_y = void;
    int bdy_w = void;
    int bdy_h = void;
    //----------------------------------------
	int unkwn8 = void;
    char[20] fname = void;
	/// maximum sound path is unknown actually
    char[20]* sound = void;
    int unkwn9 = void;
}

struct sWeaponStrength
{
public:
	int dvx = void;
	int dvy = void;
	int fall = void;
	int arest = void;
	int vrest = void;
	int unkwn1 = void;
	int effect = void;
	int[4] unkwn2 = void;
	int bdefend = void;
	int injury = void;
	ubyte[28] unkwn3 = void;
}

struct sDataFile
{
public:
    int walking_frame_rate = void;
	int unkwn1 = void;
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
	ubyte[124] unkwn2 = void;
	sWeaponStrength[4] weapon_strength_list = void;
	ubyte[410] unkwn3 = void;
	char[30][4] entry_names = void;
	ubyte[50] unkwn4 = void;
    int pic_count = void;
	char[40][10] pic_bmps = void;
	int[10] pic_index = void;
	int[10] pic_width = void;
	int[10] pic_height = void;
	int[10] pic_row = void;
	int[10] pic_col = void;
	int id = void;
    int type = void;
	int unkwn5 = void;
    char[40] small_bmp = void;
	int unkwn6 = void;
    char[40] face_bmp = void;
	int[20] unkwn7 = void;
	sFrame[400] frames = void;
    char[12] name = void; /// not actually certain that the length is 12, seems like voodoo magic
}

struct sObject
{
public:
    int move_counter = void;
    int run_counter = void;
    int blink = void;
	int unkwn1 = void;
    int x = void;
    int y = void;
    int z = void;
	ubyte[12] unkwn2 = void;
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
	ubyte[15] unkwn3 = void;
    int ccatcher = void;
    int ctimer = void;
    int weapon_type = void;
    int weapon_held = void;
    int weapon_holder = void;
	int unkwn4 = void;
	ubyte[8] unkwn5 = void;
    int fall = void;
    int shake = void;
    int bdefend = void;
	ubyte[10] unkwn6 = void;
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
    ubyte DrA = void;
    ubyte DlA = void;
    ubyte DuA = void;
    ubyte DdA = void;
    ubyte DrJ = void;
    ubyte DlJ = void;
    ubyte DuJ = void;
    ubyte DdJ = void;
    ubyte DJA = void;
	ubyte[15] unkwn7 = void;
    int arest = void;
    int vrest = void;
	ubyte[396] unkwn8 = void;
    int attacked_object_num = void;
	ubyte[112] unkwn9 = void;
    int clone = void;
    int weapon_thrower = void;
    int hp = void;
    int dark_hp = void;
    int max_hp = void;
    int mp = void;
    int reserve = void;
	int unkwn10 = void;
	int unkwn11 = void;
    int pic_gain = void;
    int bottle_hp = void;
	ubyte[24] unkwn12 = void;
    int firzen_counter = void;
	int unkwn13 = void;
    int armour_multiplier = void;
	int unkwn14 = void;
    int total_attack = void;
    int hp_lost = void;
    int mp_usage = void;
	int unkwn15 = void;
    int kills = void;
    int weapon_picks = void;
    int enemy = void;
    int team = void;
    sDataFile *data = void;
}

struct sSpawn
{
public:
	int[43] unkwn1 = void; /// Seems to have something to do with bosses, is changed during game so I believe it keeps track of whether or not soldiers should respawn
    int id = void;
    int x = void;
    int hp = void;
    int times = void;
    int reserve = void;
    int join = void;
    int join_reserve = void;
    int act = void;
	int unkwn2 = void;
    double ratio = void;
    int role = void; /// soldier = 1, boss = 2
	int unkwn3 = void;
	
	string toString(sPhase* phase = null)
	{
		import std.conv : text, to;
		return text("id: ", id, hp != 500 ? "  hp: " ~ hp.to!string : "", act != 9 ? "  act: " ~ act.to!string : "", phase != null ? (x != (phase.bound + 80) ? "  x: " ~ x.to!string : "") : "  x: " ~ x.to!string, times != 1 ? "  times: " ~ times.to!string : "", ratio != 0 ? "  ratio: " ~ ratio.to!string : "", reserve != 0 ? "  reserve: " ~ reserve.to!string : "", join != 0 ? "  join: " ~ join.to!string : "", join_reserve != 0 ? "  join_reverse: " ~ join_reserve.to!string : "", role == 1 ? "\t<soldier>" : role == 2 ? "\t<boss>" : "");
	}
}

struct sPhase
{
public:
    int bound = void;
    char[52] music = void;
	sSpawn[60] spawns = void;
    int when_clear_goto_phase = void;
	
	string toString()
	{
		import std.conv : to;
		char[] str;
		str.reserve(1024);
		str ~= "        <phase> bound: ";
		str ~= bound.to!string;
		str ~= "\n";
		size_t mn = 0;
		for(size_t i = 0; i < music.length; i++)
		{
			if(music[i] == '\0')
			{
				mn = i;
				break;
			}
		}
		if(mn > 0)
		{
			str ~= "                music: ";
			str ~= music[0 .. mn];
			str ~= "\n";
		}
		for(size_t i = 0; i < spawns.length; i++)
		{
			if(spawns[i].id > 0)
			{
				str ~= "                ";
				str ~= spawns[i].toString(&this);
				str ~= "\n";
			}
		}
		str ~= "        <phase_end>\n";
		return str.idup;
	}
}

struct sStage
{
public:
    int phase_count = void;
	sPhase[100] phases = void;

	string toString(int id = -1)
	{
		import std.conv : to;
		bool b = false;
		for(size_t i = 0; i < phase_count && i < phases.length; i++)
		{
			if(phases[i].bound != 0)
			{
				b = true;
				break;
			}
		}
		if(b == false)
			return "";
		char[] str;
		str ~= "<stage>";
		str.reserve(1024 * 16);
		if(id >= 0)
		{
			str ~= " id: ";
			str ~= id.to!string;
		}
		str ~= "\n";
		size_t i;
		for(i = 0; i < phase_count - 1 && i < phases.length - 1; i++)
		{
			str ~= phases[i].toString();
			str ~= "\n";
		}
		str ~= phases[i].toString();
		str ~= "<stage_end>\n\n\n";
		return str.idup;
	}
}

struct sBackground
{
public:
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
	ubyte[364] unkwn = void;
}

struct sFileManager
{
public:
	sDataFile*[500] datas = void;
	sStageProxy stages = void;
	sBackground[50] backgrounds = void;
}

const void* sGameAddr = cast(void*)0x458B00;

struct sGame
{
public:
    int state = void; // 0x4
	ubyte[400] exists = void; // 0x194
	sObject*[400] objects = void; // 0x7d4
	sFileManager* files = void; // 0xFA4
}

/// Because DMD sucks.
struct sStageProxy
{
public:
	align(1)
	{
		ubyte[sStage.sizeof * 12] s1 = void;
		ubyte[sStage.sizeof * 12] s2 = void;
		ubyte[sStage.sizeof * 12] s3 = void;
		ubyte[sStage.sizeof * 12] s4 = void;
		ubyte[sStage.sizeof * 12] s5 = void;
	}

	private enum size_t size = sStage.sizeof * 60;

	ref sStage opIndex(size_t i)
	{
		if(i < size)
			return (cast(sStage*)s1.ptr)[i];
		else
			assert(0);
	}

	ref sStage opIndexAssign(ref sStage r, size_t i)
	{
		if(i < size)
			return (cast(sStage*)s1.ptr)[i] = r;
		else
			assert(0);
	}
}

enum ObjectType : ubyte
{
	Char = 0,
	Weapon = 1,
	HeavyWeapon = 2,
	SpecialAttack = 3,
	ThrowWeapon = 4,
	Criminal = 5,
	Drink = 6
}

enum DataType : ubyte
{
	Object = 0,
	Stage = 1,
	Background = 2
}

struct ObjectData
{
public:
	int id;
	ObjectType type;
	wchar* file;
}

struct BackgroundData
{
public:
	int id;
	wchar* file;
}

struct DataTxt
{
public:
	ObjectData* objects;
	BackgroundData* backgrounds;
	size_t objCount;
	size_t bgCount;
}
