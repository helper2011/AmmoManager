#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

Handle g_hGetMaxClip;

static const char Weapon[][] = {"glock", "usp", "p228", "deagle", "elite", "fiveseven", "m3", "xm1014", "mac10", "tmp", "mp5navy", "ump45", "p90", "galil", "famas", "ak47", "m4a1", "scout", "sg550", "aug", "awp", "g3sg1", "sg552", "m249"}

const int Weapons = sizeof(Weapon);

int Ammo[Weapons];

public Plugin myinfo =
{
	name         = "AmmoManager",
	author       = "zaCade",
	description  = "",
	version      = "1.0.0"
};

public void OnPluginStart()
{
	Handle hGameConf;
	if ((hGameConf = LoadGameConfigFile("AmmoManager.games")) == INVALID_HANDLE)
	{
		SetFailState("Couldn't load \"AmmoManager.games\" game config!");
		return;
	}

	int iMaxClipOffset;
	if ((iMaxClipOffset = GameConfGetOffset(hGameConf, "GetMaxClip")) == -1)
	{
		delete hGameConf;
		SetFailState("GameConfGetOffset(hGameConf, \"GetMaxClip\") failed!");
		return;
	}

	if ((g_hGetMaxClip = DHookCreate(iMaxClipOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnGetMaxClip)) == INVALID_HANDLE)
	{
		delete hGameConf;
		SetFailState("DHookCreate(iMaxClipOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnGetMaxClip) failed!");
		return;
	}

	// Late load.
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "weapon_*")) != INVALID_ENT_REFERENCE)
	{
		OnEntityCreated(entity, "weapon_*");
	}

	delete hGameConf;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnMapStart()
{
	char szBuffer[256];
	BuildPath(Path_SM, szBuffer, 256, "configs/AmmoManager.cfg");
	KeyValues hKeyValues = new KeyValues("weapons");
	
	if(hKeyValues.ImportFromFile(szBuffer))
	{
		for(int i; i < Weapons; i++)
		{
			hKeyValues.Rewind();
			if(hKeyValues.JumpToKey(Weapon[i]))
			{
				Ammo[i] = hKeyValues.GetNum("primary clip");
			}
		}
	}
	else
	{
		LogMessage("Config file doesn't exist: \"%s\"!", szBuffer);
	}
	
	delete hKeyValues;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsValidEntity(entity) && strncmp(classname, "weapon_", 7, false) == 0)
	{
		DHookEntity(g_hGetMaxClip, true, entity);
	}
}

public MRESReturn OnGetMaxClip(int entity, Handle hReturn)
{
	if (!IsValidEntity(entity))
		return MRES_Ignored;

	static char sClassname[32];
	GetEntityClassname(entity, sClassname, 32);

	for(int i; i < Weapons; i++)
	{
		if(!strcmp(sClassname[7], Weapon[i], true))
		{
			if(Ammo[i] > 0)
			{
				DHookSetReturn(hReturn, Ammo[i]);
				return MRES_Supercede;
			}
			break;
			
		}
	}

	return MRES_Ignored;
}
