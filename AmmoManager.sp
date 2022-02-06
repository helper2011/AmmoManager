#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

Handle g_hGetMaxClip;
Handle g_hGetMaxReserve;

KeyValues g_aKeyValues;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name         = "AmmoManager",
	author       = "zaCade",
	description  = "",
	version      = "1.0.0"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	Handle hGameConf;
	if ((hGameConf = LoadGameConfigFile("AmmoManager.games")) == INVALID_HANDLE)
	{
		SetFailState("Couldn't load \"AmmoManager.games\" game config!");
		return;
	}

	// CBaseCombatWeapon::GetMaxClip1() const
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

	// CBaseCombatWeapon::GetMaxReserve1() const
	if (GetEngineVersion() == Engine_CSGO)
	{
		int iMaxReserveOffset;
		if ((iMaxReserveOffset = GameConfGetOffset(hGameConf, "GetMaxReserve")) == -1)
		{
			delete hGameConf;
			SetFailState("GameConfGetOffset(hGameConf, \"GetMaxReserve\") failed!");
			return;
		}

		if ((g_hGetMaxReserve = DHookCreate(iMaxReserveOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnGetMaxReserve)) == INVALID_HANDLE)
		{
			delete hGameConf;
			SetFailState("DHookCreate(iMaxReserveOffset, HookType_Entity, ReturnType_Int, ThisPointer_CBaseEntity, OnGetMaxReserve) failed!");
			return;
		}
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
	char sFilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFilePath, sizeof(sFilePath), "configs/AmmoManager.cfg");

	if (!FileExists(sFilePath))
	{
		LogMessage("Config file doesn't exist: \"%s\"!", sFilePath);
		return;
	}
	delete g_aKeyValues;
	g_aKeyValues = new KeyValues("weapons");

	if (!g_aKeyValues.ImportFromFile(sFilePath))
	{
		LogMessage("Couldn't load config file: \"%s\"!", sFilePath);
		delete g_aKeyValues;
		return;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnEntityCreated(int entity, const char[] classname)
{
	if (strncmp(classname, "weapon_", 7, false) == 0)
	{
		if (g_hGetMaxClip != INVALID_HANDLE)
			DHookEntity(g_hGetMaxClip, true, entity);

		if (g_hGetMaxReserve != INVALID_HANDLE)
			DHookEntity(g_hGetMaxReserve, true, entity);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public MRESReturn OnGetMaxClip(int entity, Handle hReturn)
{
	if (!IsValidEntity(entity))
		return MRES_Ignored;

	bool bChanged;
	char sClassname[128];
	GetEntityClassname(entity, sClassname, sizeof(sClassname))

	if (g_aKeyValues && g_aKeyValues.JumpToKey(sClassname, false))
	{
		int iClip;
		if ((iClip = g_aKeyValues.GetNum("primary clip", -1)) != -1)
		{
			DHookSetReturn(hReturn, iClip);
			bChanged = true;
		}

		g_aKeyValues.Rewind();
	}

	return (bChanged) ? MRES_Supercede : MRES_Ignored;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public MRESReturn OnGetMaxReserve(int entity, Handle hReturn)
{
	if (!IsValidEntity(entity))
		return MRES_Ignored;

	bool bChanged;
	char sClassname[128];
	GetEntityClassname(entity, sClassname, sizeof(sClassname))

	if (g_aKeyValues && g_aKeyValues.JumpToKey(sClassname, false))
	{
		int iReserve;
		if ((iReserve = g_aKeyValues.GetNum("primary reserve", -1)) != -1)
		{
			DHookSetReturn(hReturn, iReserve);
			bChanged = true;
		}

		g_aKeyValues.Rewind();
	}

	return (bChanged) ? MRES_Supercede : MRES_Ignored;
}