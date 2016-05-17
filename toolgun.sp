#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items>

#pragma newdecls required;

#define MDL_TOOLGUN			"models/custom/weapons/c_models/c_revolver/c_revolver.mdl"
#define SND_TOOLGUN_SHOOT	"weapons/toolgun_shoot.wav"
#define SND_TOOLGUN_SELECT	"buttons/button15.wav"

#define EF_BONEMERGE			(1 << 0)
#define EF_BONEMERGE_FASTCULL	(1 << 7)

Handle g_hSdkEquipWearable;

int g_hWearableOwner[2049];
int g_iTiedEntity[2049];
bool g_bIsToolgun[2049];

int g_iTool[MAXPLAYERS+1];
bool g_bPlayerPressedReload[MAXPLAYERS+1];
bool g_bAttackWasMouse2[MAXPLAYERS+1];

public void OnPluginStart()
{
	RegAdminCmd("sm_toolgun", Command_Toolgun, ADMFLAG_CUSTOM2);
}

public void OnMapStart()
{
	PrecacheModel(MDL_TOOLGUN);
	PrecacheSound(SND_TOOLGUN_SHOOT);
	PrecacheSound(SND_TOOLGUN_SELECT);
}

public Action Command_Toolgun(int client, int args)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		GiveToolgun(client);
	}

	return Plugin_Handled;
}

stock void GiveToolgun(int client)
{
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Primary);
	TF2_RemoveWeaponSlot(client, TFWeaponSlot_Building);

	Handle hWeapon = TF2Items_CreateItem(OVERRIDE_ALL|FORCE_GENERATION);
	if (hWeapon != INVALID_HANDLE)
	{
		TF2Items_SetClassname(hWeapon, "tf_weapon_revolver");
		TF2Items_SetItemIndex(hWeapon, 24);
		TF2Items_SetLevel(hWeapon, 100);
		TF2Items_SetQuality(hWeapon, 5);
		
		TF2Items_SetAttribute(hWeapon, 0, 305, 1.0);	//Fire tracer rounds
		TF2Items_SetAttribute(hWeapon, 1, 731, 1.0);	//Allow inspect
		TF2Items_SetAttribute(hWeapon, 2, 106, 0.0);	//Accuracy bonus
		TF2Items_SetAttribute(hWeapon, 3, 1, 0.0);		//Damage Penalty
		TF2Items_SetNumAttributes(hWeapon, 4);
		
		int weapon = TF2Items_GiveNamedItem(client, hWeapon);
		EquipPlayerWeapon(client, weapon);

		CloseHandle(hWeapon);
		
		EquipWearable(client, MDL_TOOLGUN, weapon);
		
		char arms[PLATFORM_MAX_PATH];
		switch(TF2_GetPlayerClass(client))
		{
			case TFClass_Scout:		Format(arms, sizeof(arms), "models/weapons/c_models/c_scout_arms.mdl");
			case TFClass_Soldier:	Format(arms, sizeof(arms), "models/weapons/c_models/c_soldier_arms.mdl");
			case TFClass_Pyro:		Format(arms, sizeof(arms), "models/weapons/c_models/c_pyro_arms.mdl");
			case TFClass_DemoMan: 	Format(arms, sizeof(arms), "models/weapons/c_models/c_demo_arms.mdl");
			case TFClass_Heavy: 	Format(arms, sizeof(arms), "models/weapons/c_models/c_heavy_arms.mdl");
			case TFClass_Engineer: 	Format(arms, sizeof(arms), "models/weapons/c_models/c_engineer_arms.mdl");
			case TFClass_Medic: 	Format(arms, sizeof(arms), "models/weapons/c_models/c_medic_arms.mdl");
			case TFClass_Sniper: 	Format(arms, sizeof(arms), "models/weapons/c_models/c_sniper_arms.mdl");
			case TFClass_Spy: 		Format(arms, sizeof(arms), "models/weapons/c_models/c_spy_arms.mdl");
		}
		if (strlen(arms) && FileExists(arms, true))
		{
			PrecacheModel(arms, true);
			EquipWearable(client, arms, weapon);
		}
		
		SetEntProp(weapon, Prop_Send, "m_iWorldModelIndex", PrecacheModel(MDL_TOOLGUN));
		SetEntProp(weapon, Prop_Send, "m_nModelIndexOverrides", PrecacheModel(MDL_TOOLGUN), _, 0);
		
		SetEntityRenderMode(weapon, RENDER_NONE);
		SetEntityRenderColor(weapon, 0, 0, 0, 0);
		
		g_bIsToolgun[weapon] = true;
		g_iTool[client] = 1;
		
		SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	}
}

public Action TF2_CalcIsAttackCritical(int client, int weapon, char[] weaponname, bool &result)
{
	if(IsValidEntity(weapon) && g_bIsToolgun[weapon])
	{
		float flStartPos[3], flEyeAng[3], flHitPos[3];
		GetClientEyePosition(client, flStartPos);
		GetClientEyeAngles(client, flEyeAng);
			
		Handle hTrace = TR_TraceRayFilterEx(flStartPos, flEyeAng, MASK_SHOT, RayType_Infinite, TraceRayDontHitEntity, client);
		TR_GetEndPosition(flHitPos, hTrace);
		int iHitEntity = TR_GetEntityIndex(hTrace);
		delete hTrace;
		
	//	if(TF2_GetClientTeam(client) == TFTeam_Blue)
	//		ShootLaser(weapon, "dxhr_sniper_rail_blue", flStartPos, flHitPos);
	//	else
	//		ShootLaser(weapon, "dxhr_sniper_rail_red", flStartPos, flHitPos);
			
		switch(g_iTool[client])
		{
			case 1:	
			{
				if(iHitEntity > 0 && IsValidEntity(iHitEntity))
					AcceptEntityInput(iHitEntity, "Kill");
			}
			case 2:	
			{
				if(iHitEntity > 0)
				{
					if(iHitEntity <= MaxClients && IsClientInGame(iHitEntity) && IsPlayerAlive(iHitEntity))
						FakeClientCommandEx(iHitEntity, "explode");
					else
						AcceptEntityInput(iHitEntity, "explode");
				}
			}
			case 3:
			{
				if(iHitEntity > 0)
				{
					float flModelScale = GetEntPropFloat(iHitEntity, Prop_Send, "m_flModelScale");
					
					if(g_bAttackWasMouse2[client])
					{
						float flNewScale = flModelScale - 0.1;
						
						if(flNewScale > 0.0)
						{
							char strScale[8];
							FloatToString(flNewScale, strScale, sizeof(strScale));
							
							SetVariantString(strScale);
							AcceptEntityInput(iHitEntity, "SetModelScale");
						}
					}
					else
					{
						float flNewScale = flModelScale + 0.1;
						if(flNewScale > 0.0)
						{
							char strScale[8];
							FloatToString(flNewScale, strScale, sizeof(strScale));
							
							SetVariantString(strScale);
							AcceptEntityInput(iHitEntity, "SetModelScale");
						}
					}
				}
			}
			case 4:
			{
				int Drum = CreateEntityByName("prop_physics_override");
				DispatchKeyValueVector(Drum, "origin", flHitPos);
				DispatchKeyValue(Drum, "model", "models/props_c17/oildrum001_explosive.mdl");
				DispatchKeyValue(Drum, "health", "20");
				DispatchKeyValue(Drum, "ExplodeDamage","120");
				DispatchKeyValue(Drum, "ExplodeRadius","256");
				DispatchKeyValue(Drum, "spawnflags","8192");
				DispatchSpawn(Drum);
				ActivateEntity(Drum);
			}
			case 5:
			{
				flEyeAng[0] = 0.0;
				TF2_BuildSentry(client, flHitPos, flEyeAng, 1);
			}
			case 6:
			{
				flEyeAng[0] = 0.0;
				SpawnDispenser(client, flHitPos, flEyeAng, 1);
			}
			case 7:
			{
				flEyeAng[0] = 0.0;
				int HHH = CreateEntityByName("headless_hatman");
				DispatchKeyValueVector(HHH, "origin", flHitPos);
				DispatchKeyValueVector(HHH, "angles", flEyeAng);
				DispatchSpawn(HHH);
			}
		}
		
		EmitSoundToAll(SND_TOOLGUN_SHOOT, weapon, SNDCHAN_WEAPON, SNDLEVEL_RAIDSIREN);
		EmitSoundToClient(client, SND_TOOLGUN_SHOOT);
		
		SetEntProp(weapon, Prop_Send, "m_iClip1", 7);
	}
}

public bool TraceRayDontHitEntity(int entity, int mask, any data)
{
	if (entity == data) 
		return false;
	
	return true;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVel[3], float fAng[3], int &iWeapon)
{
	if(IsPlayerAlive(client))
	{
		int aw = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
		if(IsValidEntity(aw) && g_bIsToolgun[aw])
		{
			SetHudTextParams(0.0, 0.25, 0.1, 150, 150, 0, 150, 0, 0.0, 0.0, 0.0);
	
			switch(g_iTool[client])
			{
				case 1:	ShowHudText(client, -1, "TOOL:\nREMOVER");
				case 2:	ShowHudText(client, -1, "TOOL:\nEXPLODE TARGET");
				case 3:	ShowHudText(client, -1, "TOOL:\nRESIZE TOOL");
				case 4:	ShowHudText(client, -1, "TOOL:\nEXPLOSIVE BARREL");
				case 5:	ShowHudText(client, -1, "TOOL:\nSPAWN SENTRY");
				case 6:	ShowHudText(client, -1, "TOOL:\nSPAWN DISPENSER");
				case 7:	ShowHudText(client, -1, "TOOL:\nSPAWN HORSEMANN");
			}
			
			if(iButtons & IN_ATTACK2)
			{
				g_bAttackWasMouse2[client] = true;
				iButtons &= ~IN_ATTACK2;
				iButtons |= IN_ATTACK;
			}
			else
				g_bAttackWasMouse2[client] = false;

			if(iButtons & IN_RELOAD && !g_bPlayerPressedReload[client])
			{
				if(g_iTool[client] < 7)
					g_iTool[client]++;
				else
					g_iTool[client] = 1;
				
				EmitSoundToClient(client, SND_TOOLGUN_SELECT);
				
				g_bPlayerPressedReload[client] = true;
			}
			else if (!(iButtons & IN_RELOAD) && g_bPlayerPressedReload[client])
				g_bPlayerPressedReload[client] = false;
		}
	}
	
	return Plugin_Continue;
}

public void OnWeaponSwitch(int client, int iWep)
{
	if(IsValidEntity(iWep))
	{
		int i = -1;
		while ((i = FindEntityByClassname(i, "tf_wearable*")) != -1)
		{
			if (client == g_hWearableOwner[i])
			{
				int effects = GetEntProp(i, Prop_Send, "m_fEffects");
				if (iWep == g_iTiedEntity[i]) 
					SetEntProp(i, Prop_Send, "m_fEffects", effects & ~32);
				else 
					SetEntProp(i, Prop_Send, "m_fEffects", effects |= 32);
			}
		}
	}
}

public void OnEntityDestroyed(int ent)
{
	if (ent <= 0 || ent > 2048) 
		return;
	
	g_bIsToolgun[ent] = false;
	g_iTiedEntity[ent] = 0;
	g_hWearableOwner[ent] = 0;
}

stock int EquipWearable(int client, char[] Mdl, int weapon = 0)
{
	int wearable = CreateWearable(client, Mdl);
	if (wearable == -1)
		return -1;

	g_hWearableOwner[wearable] = client;

	if (weapon > MaxClients)
	{
		g_iTiedEntity[wearable] = weapon;
	
		int effects = GetEntProp(wearable, Prop_Send, "m_fEffects");
		if (weapon == GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon")) 
			SetEntProp(wearable, Prop_Send, "m_fEffects", effects & ~32);
		else 
			SetEntProp(wearable, Prop_Send, "m_fEffects", effects |= 32);
	}
	return wearable;
}

stock int CreateWearable(int client, char[] model)
{
	int ent = CreateEntityByName("tf_wearable_vm");
	SetEntProp(ent, Prop_Send, "m_nModelIndex", PrecacheModel(model));
	SetEntProp(ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_BONEMERGE_FASTCULL);
	SetEntProp(ent, Prop_Send, "m_iTeamNum", GetClientTeam(client));
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(ent);
	
	SetVariantString("!activator");
	ActivateEntity(ent);
	
	TF2_EquipWearable(client, ent);
	return ent;
}

stock void TF2_EquipWearable(int client, int entity)
{
	if (g_hSdkEquipWearable == INVALID_HANDLE)
	{
		Handle hGameConf = LoadGameConfigFile("tf2items.randomizer");
		if (hGameConf == INVALID_HANDLE)
		{
			SetFailState("Couldn't load SDK functions. Could not locate tf2items.randomizer.txt in the gamedata folder.");
			return;
		}
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Virtual, "CTFPlayer::EquipWearable");
		PrepSDKCall_AddParameter(SDKType_CBaseEntity, SDKPass_Pointer);
		g_hSdkEquipWearable = EndPrepSDKCall();
		if (g_hSdkEquipWearable == INVALID_HANDLE)
		{
			SetFailState("Could not initialize call for CTFPlayer::EquipWearable");
			CloseHandle(hGameConf);
			return;
		}
	}
	if (g_hSdkEquipWearable != INVALID_HANDLE) SDKCall(g_hSdkEquipWearable, client, entity);
}

stock void ShootLaser(int weapon, const char[] strParticle, float flStartPos[3], float flEndPos[3])
{
	int tblidx = FindStringTable("ParticleEffectNames");
	if (tblidx == INVALID_STRING_TABLE) 
	{
		LogError("Could not find string table: ParticleEffectNames");
		return;
	}
	
	char tmp[256];
	int count = GetStringTableNumStrings(tblidx);
	int stridx = INVALID_STRING_INDEX;
	int i;
	
	for (i = 0; i < count; i++)
	{
		ReadStringTable(tblidx, i, tmp, sizeof(tmp));
		if (StrEqual(tmp, strParticle, false))
		{
			stridx = i;
			break;
		}
	}
	
	if (stridx == INVALID_STRING_INDEX)
	{
		LogError("Could not find particle: %s", strParticle);
		return;
	}

	TE_Start("TFParticleEffect");
	TE_WriteFloat("m_vecOrigin[0]", flStartPos[0]);
	TE_WriteFloat("m_vecOrigin[1]", flStartPos[1]);
	TE_WriteFloat("m_vecOrigin[2]", flStartPos[2] -= 32.0);
	TE_WriteNum("m_iParticleSystemIndex", stridx);
	TE_WriteNum("entindex", weapon);
	TE_WriteNum("m_iAttachType", 2);
	TE_WriteNum("m_iAttachmentPointIndex", 0);
	TE_WriteNum("m_bResetParticles", 0);    
	TE_WriteNum("m_bControlPoint1", 1);    
	TE_WriteNum("m_ControlPoint1.m_eParticleAttachment", 5);  
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[0]", flEndPos[0]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[1]", flEndPos[1]);
	TE_WriteFloat("m_ControlPoint1.m_vecOffset[2]", flEndPos[2]);
	TE_SendToAll();
}

stock void TF2_BuildSentry(int builder, float fOrigin[3], float fAngle[3], int level, bool mini = false, bool disposable = false, int flags=4)
{
	static const float m_vecMinsMini[3] = {-15.0, -15.0, 0.0}, m_vecMaxsMini[3] = {15.0, 15.0, 49.5};
	static const float m_vecMinsDisp[3] = {-13.0, -13.0, 0.0}, m_vecMaxsDisp[3] = {13.0, 13.0, 42.9};
	
	int sentry = CreateEntityByName("obj_sentrygun");
	
	if(IsValidEntity(sentry))
	{
		AcceptEntityInput(sentry, "SetBuilder", builder);

		DispatchKeyValueVector(sentry, "origin", fOrigin);
		DispatchKeyValueVector(sentry, "angles", fAngle);
		
		if(mini)
		{
			SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
			SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
			SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_nSkin", level == 1 ? GetClientTeam(builder) : GetClientTeam(builder) - 2);
			DispatchSpawn(sentry);
			
			SetVariantInt(100);
			AcceptEntityInput(sentry, "SetHealth");
			
			SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.75);
			SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsMini);
			SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsMini);
		}
		else if(disposable)
		{
			SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_bDisposableBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
			SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
			SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_nSkin", level == 1 ? GetClientTeam(builder) : GetClientTeam(builder) - 2);
			DispatchSpawn(sentry);
			
			SetVariantInt(100);
			AcceptEntityInput(sentry, "SetHealth");
			
			SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.60);
			SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsDisp);
			SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsDisp);
		}
		else
		{
			SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
			SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
			SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
			DispatchSpawn(sentry);
		}
	}
}

stock void SpawnDispenser(int builder, float Position[3], float Angle[3], int level, int flags=4)
{
	int dispenser = CreateEntityByName("obj_dispenser");
	
	if(IsValidEntity(dispenser))
	{
		DispatchKeyValueVector(dispenser, "origin", Position);
		DispatchKeyValueVector(dispenser, "angles", Angle);
		SetEntProp(dispenser, Prop_Send, "m_iHighestUpgradeLevel", level);
		SetEntProp(dispenser, Prop_Data, "m_spawnflags", flags);
		SetEntProp(dispenser, Prop_Send, "m_bBuilding", 1);
		DispatchSpawn(dispenser);

		SetVariantInt(GetClientTeam(builder));
		AcceptEntityInput(dispenser, "SetTeam");
		SetEntProp(dispenser, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
		
		ActivateEntity(dispenser);
		
		AcceptEntityInput(dispenser, "SetBuilder", builder);
	}
}