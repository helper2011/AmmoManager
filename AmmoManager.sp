#define VIP

#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#if defined VIP
#undef REQUIRE_PLUGIN
#include <vip_core>
#define REQUIRE_PLUGIN
#endif

#pragma newdecls required

Handle g_hGetMaxClip;

static const char Weapon[][] = {"glock", "usp", "p228", "deagle", "elite", "fiveseven", "m3", "xm1014", "mac10", "tmp", "mp5navy", "ump45", "p90", "galil", "famas", "ak47", "m4a1", "scout", "sg550", "aug", "awp", "g3sg1", "sg552", "m249"}

#if defined VIP
static const char g_sFeature[] = "AmmoMultiplier";
bool LibraryVIP;
float Multiplier[MAXPLAYERS + 1] = {1.0, ...};
#endif

int AmmoSettings[sizeof(Weapon)] = {20, 12, 13, 7, 30,  20, 8, 7, 30, 30, 30, 25, 50, 35, 25, 30, 30, 10, 30, 30, 10, 20, 30, 100};
int Ammo[2048];

public Plugin myinfo =
{
	name         = "AmmoManager [Edited]",
	author       = "zaCade",
	description  = "",
	version      = "1.0.0"
};


#if defined VIP
public void OnLibraryAdded(const char[] name)
{
	if(strcmp(name, "vip_core", false) == 0)
	{
		LibraryVIP = true;
	}
}

public void OnLibraryRemoved(const char[] name)
{
	if(strcmp(name, "vip_core", false) == 0)
	{
		LibraryVIP = false;
	}

}
#endif

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

	#if defined VIP
	LoadTranslations("vip_modules.phrases")
	LibraryVIP = LibraryExists("vip_core");

	if(LibraryVIP && VIP_IsVIPLoaded())
	{
		VIP_OnVIPLoaded();

		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && VIP_IsClientVIP(i))
			{
				VIP_OnVIPClientLoaded(i);
			}
		}
	}
	#endif
}

#if defined VIP
public void OnPluginEnd()
{
	if(LibraryVIP && CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") == FeatureStatus_Available)
	{
		VIP_UnregisterFeature(g_sFeature);
	}
}

public void VIP_OnVIPLoaded()
{
	VIP_RegisterFeature(g_sFeature, FLOAT, TOGGLABLE, OnItemSelect, OnItemDisplay);
}

public void VIP_OnVIPClientLoaded(int iClient)
{
	if(VIP_GetClientFeatureStatus(iClient, g_sFeature) < NO_ACCESS && VIP_IsClientFeatureUse(iClient, g_sFeature))
	{
		Multiplier[iClient] = VIP_GetClientFeatureFloat(iClient, g_sFeature);
	}
}

public Action OnItemSelect(int iClient, const char[] szFeature, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus)
{
	switch(eNewStatus)
	{
		case ENABLED:
		{
			Multiplier[iClient] = VIP_GetClientFeatureFloat(iClient, g_sFeature);
		}
		case DISABLED, NO_ACCESS:
		{
			Multiplier[iClient] = 1.0;
		}
	}
}

public bool OnItemDisplay(int iClient, const char[] szFeature, char[] szDisplay, int iMaxLength)
{
	if(VIP_IsClientFeatureUse(iClient, g_sFeature))
	{
		FormatEx(szDisplay, iMaxLength, "%T [%.0f%%]", g_sFeature, iClient, Multiplier[iClient] * 100.0);
		return true;
	}

	return false;
}

public void OnClientPutInServer(int iClient)
{
	Multiplier[iClient] = 1.0;
}

public void OnClientDisconnect(int iClient)
{
	Multiplier[iClient] = 1.0;
}
#endif
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


#if defined VIP
public MRESReturn OnGetMaxClip(int entity, Handle hReturn)
{
	if (!IsValidEntity(entity))
		return MRES_Ignored;
	
	static float fAmmo;
	static int iClient;
	fAmmo = float(Ammo[entity]);
	iClient = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
	if(0 < iClient <= MaxClients)
	{
		fAmmo *= Multiplier[iClient];
	}
	DHookSetReturn(hReturn, RoundToNearest(fAmmo));
	return MRES_Supercede;
}
#else
public MRESReturn OnGetMaxClip(int entity, Handle hReturn)
{
	if (!IsValidEntity(entity))
		return MRES_Ignored;
		
	DHookSetReturn(hReturn, Ammo[entity]);
	return MRES_Supercede;
}
#endif
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