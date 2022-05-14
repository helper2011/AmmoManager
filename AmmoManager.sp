#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma newdecls required

Handle g_hGetMaxClip;

static const char Weapon[][] = {"glock", "usp", "p228", "deagle", "elite", "fiveseven", "m3", "xm1014", "mac10", "tmp", "mp5navy", "ump45", "p90", "galil", "famas", "ak47", "m4a1", "scout", "sg550", "aug", "awp", "g3sg1", "sg552", "m249"}

int AmmoSettings[sizeof(Weapon)];
int Ammo[2048];

public Plugin myinfo =
{
	name         = "AmmoManager [Edited]",
	author       = "zaCade",
	description  = "",
	version      = "1.0.0"
};

public void OnPluginStart()
{
	char szBuffer[256];
	BuildPath(Path_SM, szBuffer, 256, "configs/AmmoManager.cfg");
	KeyValues hKeyValues = new KeyValues("Weapons");
	
	if(hKeyValues.ImportFromFile(szBuffer))
	{
		for(int i; i < sizeof(Weapon); i++)
		{
			hKeyValues.Rewind();
			if(hKeyValues.JumpToKey(Weapon[i]))
			{
				AmmoSettings[i] = hKeyValues.GetNum("primary clip");
			}
		}
	}
	else
	{
		LogMessage("Config file doesn't exist: \"%s\"!", szBuffer);
	}
	
	delete hKeyValues;
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
		OnEntitySpawned(entity, "weapon_*");
	}

	delete hGameConf;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnEntitySpawned(int entity, const char[] classname)
{
	if (IsValidEntity(entity) && strlen(classname) > 8 && classname[0] == 'w' && classname[6] == '_')
	{
		int iIndex = GetWeaponIndex(classname[7]);
		if(iIndex != -1 && AmmoSettings[iIndex])
		{
			Ammo[entity] = AmmoSettings[iIndex];
			DHookEntity(g_hGetMaxClip, true, entity);
		}
	}
}

public MRESReturn OnGetMaxClip(int entity, Handle hReturn)
{
	if (!IsValidEntity(entity))
		return MRES_Ignored;

	DHookSetReturn(hReturn, Ammo[entity]);
	return MRES_Supercede;
}

stock int GetWeaponIndex(const char[] weapon)
{
	for(int i; i < sizeof(Weapon); i++)
	{
		if(!strcmp(weapon, Weapon[i], false))
		{
			return i;
		}
	}
	return -1;
}