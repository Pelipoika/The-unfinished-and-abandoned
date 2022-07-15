#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma newdecls required

#define EF_BONEMERGE       (1 << 0)
#define EF_PARENT_ANIMATES (1 << 9)

public Plugin myinfo = 
{
	name = "[CSGO] Player Clone",
	author = "Pelipoika",
	description = "",
	version = "2.0",
	url = ""
};

Handle g_hResetSequence;
Handle g_hStudioFrameAdvance;
Handle g_hAllocateLayer;

/*
monster_generic

class CAnimationLayer
{
public:
	__int32 m_fFlags; //0x0000 
	char pad_0x0004[0x4]; //0x0004
	__int32 m_nSequence; //0x0008 
	float m_flCycle; //0x000C 
	float m_flPlaybackRate; //0x0010 
	float m_flPrevCycle; //0x0014 
	float m_flWeight; //0x0018 
	char pad_0x001C[0x40]; //0x001C

}; //Size=0x005C
*/

const int CAnimationLayer_Size = 0x5C;

#define NUM_LAYERS 12

public void OnPluginStart()
{
	Handle hConf = LoadGameConfigFile("csgo.sentry");

	//ResetSequence(int nSequence);
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::ResetSequence");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if ((g_hResetSequence = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::ResetSequence signature!"); 

	//int CBaseAnimatingOverlay::AllocateLayer( int iPriority )
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimatingOverlay::AllocateLayer");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);	//priority
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); //return iOpenLayer
	if((g_hAllocateLayer = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create Call for CBaseAnimatingOverlay::AllocateLayer");
	
	
	//=========================================================
	// StudioFrameAdvance - advance the animation frame up some interval (default 0.1) into the future
	//=========================================================
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, "CBaseAnimating::StudioFrameAdvance");
	if ((g_hStudioFrameAdvance = EndPrepSDKCall()) == INVALID_HANDLE) SetFailState("Failed to create SDKCall for CBaseAnimating::StudioFrameAdvance signature!");
	
	delete hConf;
	
	RegAdminCmd("sm_clone", Command_Sentry, ADMFLAG_ROOT);
}

methodmap CBaseAnimating
{
	public CBaseAnimating(int entity) {
		return view_as<CBaseAnimating>(entity);
	}
	
	property int index {
		public get() { 
			return view_as<int>(this); 
		}
	}
	public Address CBaseAnimatingOverlay() {
		int iOffset = (view_as<int>(GetEntityAddress(this.index)) + FindDataMapInfo(this.index, "m_AnimOverlay"));
		return view_as<Address>(LoadFromAddress(view_as<Address>(iOffset), NumberType_Int32));
	}
}

public Action Command_Sentry(int client, int argc)
{
	if(client < 0 || client > MaxClients && !IsClientInGame(client))
		return Plugin_Handled;

	char strModel[PLATFORM_MAX_PATH];
	GetEntPropString(client, Prop_Data, "m_ModelName", strModel, PLATFORM_MAX_PATH);
	
	int ent = CreateEntityByName("monster_generic");
	DispatchKeyValueVector(ent, "origin", GetAbsOrigin(client));
	DispatchKeyValueVector(ent, "angles", GetAbsAngles(client));
	DispatchKeyValue(ent, "model", strModel);
	DispatchKeyValue(ent, "spawnflags", "5000");
	DispatchSpawn(ent);
	
	SetEntProp(ent, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
	SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity", client);
	
	
	
	////////////////////////////
	//Copy weapon
	//Not nescessary
	////////////////////////////
	int table = FindStringTable("modelprecache");
	ReadStringTable(table, GetEntProp(GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon"), Prop_Send, "m_iWorldModelIndex"), strModel, PLATFORM_MAX_PATH);  
	
	if(!StrEqual(strModel, ""))
	{	
		int item = CreateEntityByName("prop_dynamic");
		DispatchKeyValue(item, "model", strModel);
		DispatchSpawn(item);
		
		SetEntProp(item, Prop_Send, "m_nSkin", GetEntProp(client, Prop_Send, "m_nSkin"));
		SetEntProp(item, Prop_Send, "m_hOwnerEntity", ent);
		SetEntProp(item, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES);
		
		SetEntProp(ent, Prop_Send, "m_hActiveWeapon", item);
		
		SetVariantString("!activator");
		AcceptEntityInput(item, "SetParent", ent);
		
		SetVariantString("weapon_hand_r");
		AcceptEntityInput(item, "SetParentAttachmentMaintainOffset"); 
	}
	////////////////////////////
	
	
	
	//Uncomment this to constantly set anims to match player
	//SDKHook(ent, SDKHook_SetTransmit, OnSentryThink);
	
	//Gotta wait a bit
	RequestFrame(SetupLayers, ent);
	RequestFrame(SetupAnimations, ent);
	
	return Plugin_Handled;
}

public void SetupLayers(int iEntity)
{
	//Allocate n layers for max copycat
	for (int i = 0; i <= NUM_LAYERS; i++)
		SDKCall(g_hAllocateLayer, iEntity, 0);
}

public void SetupAnimations(int iEntity)
{
	int client = GetEntPropEnt(iEntity, Prop_Data, "m_hOwnerEntity");
	if(client <= 0)
		return;

	SDKCall(g_hResetSequence, iEntity, GetEntProp(client, Prop_Send, "m_nSequence"));
	
	Address overlayP = CBaseAnimating(client).CBaseAnimatingOverlay();
	Address overlay = CBaseAnimating(iEntity).CBaseAnimatingOverlay();
	
	//The magic maker
	for (int i = 0; i <= NUM_LAYERS; i++)
	{
		Address layerP = (overlayP + view_as<Address>(i * CAnimationLayer_Size));
		Address layer  = (overlay  + view_as<Address>(i * CAnimationLayer_Size));
			
		//Copy all 
		for (int x = 0; x < (CAnimationLayer_Size / 4); x++)
		{
			if(x == 4)
			{
				//Playback rate to 0
				StoreToAddress(layer + view_as<Address>(x * 4), 0, NumberType_Int32);
			}
			else
			{
				any iData = LoadFromAddress(layerP + view_as<Address>(x * 4), NumberType_Int32);
				
				//PrintToServer("%i 0x%X - %i %i from 0x%X", i, layer, x, iData, layerP);
				StoreToAddress(layer + view_as<Address>(x * 4), iData, NumberType_Int32);
			}
		}
	}
	
	for (int i = 0; i < 24; i++)
	{
		float flValue = GetEntPropFloat(client, Prop_Send, "m_flPoseParameter", i);
		SetEntPropFloat(iEntity, Prop_Send, "m_flPoseParameter", flValue, i);
	}
	
	//Play anims a bit so they get played to their set values
	//SDKCall(g_hStudioFrameAdvance, iEntity);
}

//bind l "ent_remove monster_generic;say !clone"

public void OnSentryThink(int entity, int client)
{
	static int iThinkWhenClient = 1;
	
	//This bad code ensures that we don't think any more than we should
	if(!IsClientInGame(iThinkWhenClient)) {
		iThinkWhenClient = client;
	}
	
	if(iThinkWhenClient != client) {
		return;
	}

	TeleportEntity(entity, NULL_VECTOR, GetAbsAngles(iThinkWhenClient), NULL_VECTOR);	
	
	SetupAnimations(entity);
}

stock float[] GetAbsOrigin(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", v);
	return v;
}

stock float[] GetAbsAngles(int client)
{
	float v[3];
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", v);
	
	return v;
}

stock float[] GetEyeAngles(int client)
{
	float v[3];
	GetClientEyeAngles(client, v);
	return v;
}