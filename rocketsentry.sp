#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

public void OnPluginStart()
{
	AddNormalSoundHook(NormalSoundHook);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(IsValidEntity(inflictor))
	{
		char strClass[64];
		GetEntityClassname(inflictor, strClass, sizeof(strClass));
		if(StrEqual(strClass, "obj_sentrygun") && (damagetype & DMG_BULLET))
		{
			damage = 0.0;
			return Plugin_Changed;
		}
	}
	
	return Plugin_Continue;
}

public Action NormalSoundHook(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags, char soundEntry[PLATFORM_MAX_PATH], int &seed)
{
	if(IsValidEntity(entity))
	{
		if(StrContains(sample, "sentry", false) != -1 && StrContains(sample, "shoot", false) != -1)
		{
			if(GetEntProp(entity, Prop_Send, "m_iUpgradeLevel") != 1)
			{
				CreateLauncher(entity, "muzzle_l");
				CreateLauncher(entity, "muzzle_r");
			}
			else
			{
				CreateLauncher(entity, "muzzle");
			}
		}
	}
	
	return Plugin_Continue;
}

stock void CreateLauncher(int iEntity, char[] strAttachment)
{
	int ent = CreateEntityByName("tf_point_weapon_mimic");
	DispatchKeyValue(ent, "ModelOverride", "models/weapons/w_models/w_rocket_airstrike/w_rocket_airstrike.mdl");
	DispatchKeyValue(ent, "WeaponType", "0");
	DispatchKeyValue(ent, "SpeedMin", "1100");
	DispatchKeyValue(ent, "SpeedMax", "1100");
	DispatchKeyValue(ent, "Damage", "18");
	DispatchKeyValue(ent, "SplashRadius", "50");
	DispatchSpawn(ent);
	
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", iEntity);
	
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", iEntity);
	
	SetVariantString(strAttachment);
	AcceptEntityInput(ent, "SetParentAttachment", iEntity);
	
	float vecPos[3]; float angRot[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", vecPos);
	GetEntPropVector(ent, Prop_Send, "m_angRotation", angRot);
	
	vecPos[0] += 40.0;
	
	TeleportEntity(ent, vecPos, angRot, NULL_VECTOR);
	
	AcceptEntityInput(ent, "FireOnce");
	
	SetVariantString("OnUser1 !self:ClearParent::5.0:1");
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser1");
	
	SetVariantString("OnUser2 !self:Kill::5.1:1");
	AcceptEntityInput(ent, "AddOutput");
	AcceptEntityInput(ent, "FireUser2");
}