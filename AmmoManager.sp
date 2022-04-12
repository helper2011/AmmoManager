#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#include <vip_core>

static const char g_sFeature[] = "AmmoExtended";

Handle g_hGetMaxClip;

static const char Weapon[][] = {"glock", "usp", "p228", "deagle", "elite", "fiveseven", "mac10", "tmp", "mp5navy", "ump45", "p90", "galil", "famas", "ak47", "m4a1", "scout", "sg550", "aug", "awp", "g3sg1", "sg552", "m249"}
static const int DefaultAmmo[] = {20, 12, 13, 7, 30, 20, 30, 30, 30, 25, 50, 35, 25, 30, 30, 10, 30, 30, 10, 20, 30, 100};

const int Weapons = sizeof(Weapon);

int ChangedAmmo[Weapons];
int FinalWeaponAmmo[2048];

float Multiplier[MAXPLAYERS];
float GlobalMultiplier;

ConVar cvarMultiplier;

public Plugin myinfo =
{
	name         = "AmmoManager + VIP",
	author       = "zaCade",
	description  = "",
	version      = "1.0.0"
};

public void OnPluginStart()
{
	cvarMultiplier = CreateConVar("sm_ammomanager_multiplier", "2.0");
	cvarMultiplier.AddChangeHook(OnConVarChange);
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
	
	LoadTranslations("vip_modules.phrases");

	// Late load.
	int entity = INVALID_ENT_REFERENCE;
	while ((entity = FindEntityByClassname(entity, "weapon_*")) != INVALID_ENT_REFERENCE)
	{
		OnEntityCreated(entity, "weapon_*");
	}

	delete hGameConf;
	
	
	if(VIP_IsVIPLoaded())
	{
		VIP_OnVIPLoaded();
	}
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && VIP_IsClientVIP(i))
		{
			GetClientMultiplier(i, VIP_IsClientFeatureUse(i, g_sFeature));
		}
	}
}

public void OnPluginEnd() 
{
	if(CanTestFeatures() && GetFeatureStatus(FeatureType_Native, "VIP_UnregisterFeature") == FeatureStatus_Available)
	{
		VIP_UnregisterFeature(g_sFeature);
	}
}

public void VIP_OnVIPLoaded() 
{
	VIP_RegisterFeature(g_sFeature, INT, TOGGLABLE, ItemSelect, ItemDisplay);
}

public void VIP_OnVIPClientLoaded(int iClient)
{
	GetClientMultiplier(iClient, VIP_IsClientFeatureUse(iClient, g_sFeature));
}

public Action ItemSelect(int iClient, const char[] szFeature, VIP_ToggleState eOldStatus, VIP_ToggleState &eNewStatus)
{
	GetClientMultiplier(iClient, (eNewStatus == ENABLED));
}

public bool ItemDisplay(int iClient, const char[] feature, char[] display, int maxlen)
{
	if(VIP_IsClientFeatureUse(iClient, feature))
	{
		FormatEx(display, maxlen, "%T [+%i %%]", feature, iClient, VIP_GetClientFeatureInt(iClient, feature));
		return true;
	}

	return false;
}

void GetClientMultiplier(int iClient, bool bToggle)
{
	Multiplier[iClient] = bToggle ? (1.0 + float(VIP_GetClientFeatureInt(iClient, g_sFeature)) / 100.0):(0.0);
}

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

	char sClassname[32];
	GetEntityClassname(entity, sClassname, 32);
	
	if(!sClassname[8])
		return MRES_Ignored;

	for(int i; i < Weapons; i++)
	{
		if(!strcmp(sClassname[7], Weapon[i], true))
		{
			int iAmmo = Ammo[i];
			if(i > 5)
			{
				int iClient = GetEntPropEnt(entity, Prop_Data, "m_hOwner");
				if(0 < iClient <= MaxClients && Multiplier[iClient] > 1.0)
				{
					if(iAmmo <= 0)
					{
						iAmmo = PAmmo[i];
					}
					iAmmo = RoundToNearest(float(iAmmo) * Multiplier[iClient]);
				}
			}
			if(iAmmo > 0)
			{
				DHookSetReturn(hReturn, iAmmo);
				return MRES_Supercede;
			}
			break;
		}
	}

	return MRES_Ignored;
}

public void OnClientDisconnect(int iClient)
{
	Multiplier[iClient] = 0.0;
}