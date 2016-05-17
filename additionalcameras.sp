#include <sdkhooks>
#include <sdktools>
#include <tf2_stocks>

//Add cameras to sentries and halloween bosses

#pragma newdecls required;

public void OnPluginStart()
{
//	HookEvent("player_builtobject",		Event_PlayerBuiltObject);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "headless_hatman")
	|| StrEqual(classname, "merasmus")
	|| StrEqual(classname, "tf_zombie"))
	{
		SDKHook(entity, SDKHook_SpawnPost, OnBossSpawn);
	}
}

public void OnBossSpawn(int entity)
{
	int cam = CreateEntityByName("info_observer_point");
	if(IsValidEntity(cam))
	{
		DispatchKeyValue(cam, "TeamNum", "0");
		DispatchKeyValue(cam, "StartDisabled", "0");
		DispatchSpawn(cam);
		AcceptEntityInput(cam, "Enable");
		
		SetVariantString("!activator");
		AcceptEntityInput(cam, "SetParent", entity);
		
		SetVariantString("lefteye");
		AcceptEntityInput(cam, "SetParentAttachment", entity);
	}
}

public Action Event_PlayerBuiltObject(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int objectType = GetEventInt(event, "object");
	
	if(client >= 1 && client <= MaxClients && IsClientInGame(client))
	{
		int iBuilding = GetEventInt(event, "index");
		if(iBuilding > MaxClients && IsValidEntity(iBuilding))
		{
			if(!GetEntProp(iBuilding, Prop_Send, "m_bCarryDeploy"))
			{
				if(objectType == (view_as<int>TFObject_Sentry))
				{
					int cam = CreateEntityByName("info_observer_point");
					if(IsValidEntity(cam))
					{
						DispatchKeyValue(cam, "TeamNum", "0");
						DispatchKeyValue(cam, "StartDisabled", "0");
						DispatchSpawn(cam);
						AcceptEntityInput(cam, "Enable");
						
						SetVariantString("!activator");
						AcceptEntityInput(cam, "SetParent", iBuilding);
						
						SetVariantString("laser_origin");
						AcceptEntityInput(cam, "SetParentAttachment", iBuilding);
					}
				}
			}
		}
	}
}