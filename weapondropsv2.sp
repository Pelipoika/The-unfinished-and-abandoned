#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <tf2items>
#include <tf2attributes>

#pragma newdecls required;

Handle g_hSDKGetWorldModel;
Handle g_hSDKGetSkin;

public void OnPluginStart()
{
	RegConsoleCmd("sm_drop", Command_Drop);	
	RegConsoleCmd("sm_attribs", Command_ListAttributes);
	AddCommandListener(Listener_Voice, "voicemenu");
	
	Handle hConfig = LoadGameConfigFile("getweaponid"); 
	if (hConfig == INVALID_HANDLE) SetFailState("Couldn't find plugin gamedata!"); 
	
	StartPrepSDKCall(SDKCall_Entity); 
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "GetWorldModel"); 
	PrepSDKCall_SetReturnInfo(SDKType_String, SDKPass_Pointer); 
	if ((g_hSDKGetWorldModel = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetWorldModel offset!"); 

	StartPrepSDKCall(SDKCall_Entity); 
	PrepSDKCall_SetFromConf(hConfig, SDKConf_Virtual, "GetSkin"); 
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); 
	if ((g_hSDKGetSkin = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for GetSkin offset!"); 
	
	CloseHandle(hConfig); 
}

public Action Command_Drop(int client, int args)
{
	int aWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(aWeapon))
		DropWeapon(client, aWeapon);
	
	return Plugin_Handled;
}

public Action Command_ListAttributes(int client, int args)
{
	int aWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(IsValidEntity(aWeapon))
	{
		if(args != 1)
		{
			ReplyToCommand(client, "sm_attribs <method>\n1 = Returns arrays containing the static attributes and their values present on an item definition.\n2 = Returns arrays containing the item server (SOC) attributes and their values present on an item definition.");
			return Plugin_Handled;
		}
		
		char arg1[4];
		GetCmdArg(1, arg1, sizeof(arg1));
		int method = StringToInt(arg1);
		
		int iDefIndices[16];
		float flAttribValues[16];

		switch(method)
		{
			case 1: 
			{
				int iItemDefinitionIndex = GetEntProp(aWeapon, Prop_Send, "m_iItemDefinitionIndex");		
				TF2Attrib_GetStaticAttribs(iItemDefinitionIndex, iDefIndices, flAttribValues);
			}
			case 2:
			{
				TF2Attrib_GetSOCAttribs(aWeapon, iDefIndices, flAttribValues);
			}
		}
		
		char strName[PLATFORM_MAX_PATH];
		
		for(int i = 0; i < 16; i++)
		{
			if(iDefIndices[i] != 0 && flAttribValues[i] != 0.0)
				Format(strName, PLATFORM_MAX_PATH, "%i:%.1f:%s", iDefIndices[i], flAttribValues[i], strName);
		}

		PrintToChat(client, "%s", strName);
	}
	
	return Plugin_Handled;
}

stock void DropWeapon(int client, int weapon)
{
	int iItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");		
	int iQuality = GetEntProp(weapon, Prop_Send, "m_iEntityQuality");
	int iSkin = SDKCall(g_hSDKGetSkin, weapon);
	
	char WorldModel[PLATFORM_MAX_PATH], classname[64];
	GetEntityClassname(weapon, classname, sizeof(classname));
	SDKCall(g_hSDKGetWorldModel, weapon, WorldModel, PLATFORM_MAX_PATH); 

	if(CanDropWeapon(client, weapon))
	{
		char strName[PLATFORM_MAX_PATH];
		int iDefIndices[16];
		float flAttribValues[16];
		TF2Attrib_GetSOCAttribs(weapon, iDefIndices, flAttribValues);
		
		char attribs[PLATFORM_MAX_PATH];
		
		for(int i = 0; i < 16; i++)
		{
			if(iDefIndices[i] != 0 && flAttribValues[i] != 0.0)
				Format(attribs, PLATFORM_MAX_PATH, "%i:%.1f:%s", iDefIndices[i], flAttribValues[i], attribs);
		}
		
		Format(strName, sizeof(strName), "TF2Drop:%i:%s:%i:%i,-,%s", iItemDefinitionIndex, classname, GetWeaponSlot(client, weapon), iQuality, attribs);
		
		float flStartPos[3], flEyeAng[3], flForw[3];
		GetClientEyePosition(client, flStartPos);
		GetClientEyeAngles(client, flEyeAng);
		
		GetAngleVectors(flEyeAng, flForw, NULL_VECTOR, NULL_VECTOR) 
		
		flStartPos[0] += flForw[0] * 20.0;
		flStartPos[1] += flForw[1] * 20.0;
		flStartPos[2] += flForw[2] - 10.0;
			
		Handle hTrace = TR_TraceRayFilterEx(flStartPos, flEyeAng, MASK_SHOT, RayType_Infinite, TraceRayDontHitEntity, client);
		float flHitPos[3];
		TR_GetEndPosition(flHitPos, hTrace);
		
		float flResult[3];
		SubtractVectors(flStartPos, flHitPos, flResult);
		NegateVector(flResult);
		NormalizeVector(flResult, flResult);
		ScaleVector(flResult, 300.0);
		
		flResult[2] += 300.0;
		
		int ent = CreateEntityByName("tf_ammo_pack");
		if (IsValidEntity(ent))
		{
			DispatchKeyValue(ent, "targetname", strName);
			DispatchKeyValueVector(ent, "origin", flStartPos);
			DispatchKeyValueVector(ent, "angles", flEyeAng);
			DispatchKeyValue(ent, "model", WorldModel);
			DispatchKeyValue(ent, "OnPlayerTouch", "!self,Kill,,0,-1"); 		
			DispatchSpawn(ent);
			
			SetEntityMoveType(ent, MOVETYPE_VPHYSICS);
			TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, flResult);
			
			SetEntProp(ent, Prop_Send, "m_nSkin", iSkin);
			
			char addoutput[64];
			Format(addoutput, sizeof(addoutput), "OnUser1 !self:kill::60:1");
			SetVariantString(addoutput);
			
			AcceptEntityInput(ent, "AddOutput");
			AcceptEntityInput(ent, "FireUser1");
		}
		
		TF2_SwitchToIdealSlot(client);
		delete hTrace;
	}
}

stock void EquipWeapon(int client, char[] classname, int iItemIndex, int iQuality, char[] attributes)
{
	Handle item = TF2Items_CreateItem(OVERRIDE_ALL|PRESERVE_ATTRIBUTES);
	TF2Items_SetClassname(item, classname);
	TF2Items_SetItemIndex(item, iItemIndex);
	TF2Items_SetQuality(item, iQuality);
	TF2Items_SetLevel(item, 5);
	
	PrintToChat(client, "%s", attributes);
	
	char weaponAttribsArray[32][32];
	int attribCount = ExplodeString(attributes, ":", weaponAttribsArray, 32, 32);
	if (attribCount > 0) 
	{
		int i2 = 0;
		for (int i = 0; i < attribCount; i += 2) 
		{
			TF2Items_SetNumAttributes(item, attribCount/2);
			
			if(StringToInt(weaponAttribsArray[i]) != 0)
			{
				TF2Items_SetAttribute(item, i2, StringToInt(weaponAttribsArray[i]), StringToFloat(weaponAttribsArray[i+1]));
				i2++;
			}
		}
	} 
	else
	{
		TF2Items_SetNumAttributes(item, 0);
	}
	
	int WeaponEntity = TF2Items_GiveNamedItem(client, item);
	EquipPlayerWeapon(client, WeaponEntity);
	
	CloseHandle(item); 
}

public Action Listener_Voice(int client, char[] command, int args) 
{
	char arguments[4];
	GetCmdArgString(arguments, sizeof(arguments));
	
	if (StrEqual(arguments, "0 0"))
	{
		int target = GetClientAimTarget(client, false);
		if(IsValidEntity(target))
		{
			char sTargetName[256], s2Data[2][PLATFORM_MAX_PATH];
			GetEntPropString(target, Prop_Data, "m_iName", sTargetName, sizeof(sTargetName));
			
			if(StrContains(sTargetName, "TF2Drop", true) != -1)
			{
				ExplodeString(sTargetName, ",-,", s2Data, 2, PLATFORM_MAX_PATH);

				float vecTPos[3], vecPPos[3];
				GetEntPropVector(target, Prop_Send, "m_vecOrigin", vecTPos);
				GetClientAbsOrigin(client, vecPPos);
				
				if(GetVectorDistance(vecPPos, vecTPos) <= 200.0)
				{	
					AcceptEntityInput(target, "Kill");
					
					char leftData[5][64];
					ExplodeString(s2Data[0], ":", leftData, 5, 64);
					
					int aWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
					int weapon = GetPlayerWeaponSlot(client, StringToInt(leftData[3]));
					if(IsValidEntity(weapon) && IsValidEntity(aWeapon))
					{
						if(StringToInt(leftData[3]) == GetWeaponSlot(client, aWeapon))
							DropWeapon(client, weapon);
					}
					
					EquipWeapon(client, leftData[2], StringToInt(leftData[1]), StringToInt(leftData[4]), s2Data[1]);

					return Plugin_Handled;
				}
			}
		}
	}

	return Plugin_Continue;
}

stock void TF2_SwitchToIdealSlot(int client)
{
	int activeweapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");
	if(IsValidEntity(activeweapon))
	{
		int slot = GetSlotFromPlayerWeapon(client, activeweapon);
		if(slot != -1)
		{
			TF2_RemoveWeaponSlot(client, slot);
			
			char classname[64];
			int primary = GetPlayerWeaponSlot(client, TFWeaponSlot_Primary);
			int melee = GetPlayerWeaponSlot(client, TFWeaponSlot_Melee);
			if (primary > MaxClients && IsValidEntity(primary) && GetEntityClassname(primary, classname, sizeof(classname)))
			{
				FakeClientCommandEx(client, "use %s", classname);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", primary);
			}
			else if (melee > MaxClients && IsValidEntity(melee) && GetEntityClassname(melee, classname, sizeof(classname)))
			{
				FakeClientCommandEx(client, "use %s", classname);
				SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", melee);
			}
		}
	}
}

stock int GetSlotFromPlayerWeapon(int iClient, int iWeapon)
{
    for (int i = 0; i <= 5; i++)
    {
        if (iWeapon == GetPlayerWeaponSlot(iClient, i))
        {
            return i;
        }
    }
    
    return -1;
}  

stock bool CanDropWeapon(int client, int iWeapon)	//We don't want the player be able to drop a weapon if that would result in the player ending up with no weapons
{
	for (int i = 0; i <= 5; i++)
	{
		int weapon = GetPlayerWeaponSlot(client, i);
		if(IsValidEntity(weapon) && iWeapon != weapon)
		{
			return true;
		}
	}
	
	return false;
}

stock int GetWeaponSlot(int iClient, int iWeapon)
{
    for (int i = 0; i <= 5; i++)
    {
        if (iWeapon == GetPlayerWeaponSlot(iClient, i))
        {
            return i;
        }
    }
    return -1;
}  

public bool TraceRayDontHitEntity(int entity, int mask, any data)
{
	if (entity == data) 
		return false;
	
	return true;
}