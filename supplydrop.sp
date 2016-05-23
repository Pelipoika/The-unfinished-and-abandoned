#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#define MDL_PARACHUTE	"models/workshop/weapons/c_models/c_paratooper_pack/c_paratrooper_parachute.mdl"
#define MDL_CRATE		"models/props_urban/urban_crate002.mdl"

#pragma newdecls required

public Plugin myinfo = 
{
	name = "[TF2] Supply Crate Drop",
	author = "Pelipoika",
	description = "",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_drop", Command_Drop, ADMFLAG_ROOT);
}

public void OnMapStart()
{
	PrecacheModel("models/props_junk/wood_crate001a.mdl", true);
	
	PrecacheModel(MDL_PARACHUTE);
	PrecacheModel(MDL_CRATE);
}

public Action Command_Drop(int client, int argc)
{
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && IsPlayerAlive(client))
	{
		float flPos[3];
		if(!SetTeleportEndPoint(client, flPos))
		{
			PrintToChat(client, "Could not find place.");
			return Plugin_Handled;
		}
		
		float flHit[3];
		TR_TraceRay(flPos, view_as<float>({-90.0, 0.0, 0.0}), MASK_PLAYERSOLID, RayType_Infinite);
		TR_GetEndPosition(flHit);
		
		float flDistance = GetVectorDistance(flPos, flHit);
		if(flDistance >= 200.0)
		{
			float flAng[3];
			flAng[1] = GetRandomFloat(0.0, 360.0);
			
			flHit[2] -= 100.0;
			
			CreateSupplyDrop(flHit, flAng);
			
			ShowParticle(flPos, "smoke_marker", 15.0);
		}
	}
	
	return Plugin_Handled;
}

stock void CreateSupplyDrop(float flPos[3], float flAng[3])
{
	flPos[2] += 20.0;
	int Parent = CreateEntityByName("prop_physics_multiplayer");
	char strName[64];
	Format(strName, sizeof(strName), "SupplyDrop%i", Parent);
	DispatchKeyValue(Parent, "targetname", strName);
	DispatchKeyValueVector(Parent, "origin", flPos);
	DispatchKeyValueVector(Parent, "angles", flAng);
	DispatchKeyValue(Parent, "model", "models/props_junk/wood_crate001a.mdl");
	DispatchKeyValue(Parent, "massScale", "0.01");
	DispatchKeyValue(Parent, "gravity", "0.0");
	DispatchSpawn(Parent);
	SetEntityRenderMode(Parent, RENDER_TRANSCOLOR);
	SetEntityRenderColor(Parent, 0, 0, 0, 0);
	flPos[2] -= 20.0;
	
	SDKHook(Parent, SDKHook_VPhysicsUpdatePost, OnCrateLanded);
	
	int iCrate = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValueVector(iCrate, "origin", flPos);
	DispatchKeyValueVector(iCrate, "angles", flAng);
	DispatchKeyValue(iCrate, "model", MDL_CRATE);
	DispatchSpawn(iCrate);
	
	flPos[2] -= 55.0;
	flPos[0] += 30.0;
	
	int iChute = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValueVector(iChute, "origin", flPos);
	DispatchKeyValue(iChute, "modelscale", "2.0");
	DispatchKeyValue(iChute, "model", MDL_PARACHUTE);
	DispatchSpawn(iChute);
	
	int iUpright = CreateEntityByName("phys_keepupright");
	DispatchKeyValueVector(iUpright, "origin", flPos);
	DispatchKeyValue(iUpright, "attach1", strName);
	DispatchKeyValue(iUpright, "angularlimit", "45");
	DispatchSpawn(iUpright);
	
	SetEntPropEnt(Parent, Prop_Send, "m_hEffectEntity", iChute);
	SetEntPropEnt(iChute, Prop_Send, "m_hEffectEntity", iCrate);
	
	SetVariantString("!activator");
	AcceptEntityInput(iUpright, "SetParent", Parent);
	
	ActivateEntity(iUpright);
	
	SetVariantString("!activator");
	AcceptEntityInput(iChute, "SetParent", Parent);
	
	SetVariantString("!activator");
	AcceptEntityInput(iCrate, "SetParent", Parent);
	
	SetVariantString("deploy");
	AcceptEntityInput(iChute, "SetAnimation");
	
	SetVariantString("OnUser1 !self:SetAnimation:deploy_idle:0.5:1");
	AcceptEntityInput(iChute, "AddOutput");
	AcceptEntityInput(iChute, "FireUser1");
}

public void OnCrateLanded(int iCrate)
{
	float m_vecMins[3], m_vecMaxs[3], endpos[3], position[3];
	GetEntPropVector(iCrate, Prop_Send, "m_vecMins", m_vecMins);
	GetEntPropVector(iCrate, Prop_Send, "m_vecMaxs", m_vecMaxs);
	m_vecMaxs[2] += 5.0;
	GetEntPropVector(iCrate, Prop_Send, "m_vecOrigin", position);

	TR_TraceHullFilter(endpos, position, m_vecMins, m_vecMaxs, MASK_SOLID, TraceFilterClients, iCrate);
	if(TR_DidHit())
	{		
		int iChute = GetEntPropEnt(iCrate, Prop_Send, "m_hEffectEntity");
		if(IsValidEntity(iChute))
		{			
			SetVariantString("retract");
			AcceptEntityInput(iChute, "SetAnimation");
			
			SetVariantString("OnUser2 !self:SetAnimation:retract_idle:0.5:1");
			AcceptEntityInput(iChute, "AddOutput");
			AcceptEntityInput(iChute, "FireUser2");
		}
		
		DispatchKeyValue(iCrate, "massScale", "0.0");
		DispatchKeyValue(iCrate, "gravity", "0.0");
		
		SDKUnhook(iCrate, SDKHook_VPhysicsUpdatePost, OnCrateLanded);
	}
}

public void ShowParticle(float pos[3], char[] particlename, float time)
{
	int particle = CreateEntityByName("info_particle_system");
	DispatchKeyValueVector(particle, "origin", pos);
	DispatchKeyValue(particle, "effect_name", particlename);
	AcceptEntityInput(particle, "start");
	ActivateEntity(particle);
	
	char strUser1[PLATFORM_MAX_PATH];
	Format(strUser1, PLATFORM_MAX_PATH, "OnUser1 !self:Kill::%f:1", time);
	SetVariantString(strUser1);
	AcceptEntityInput(particle, "AddOutput");
	AcceptEntityInput(particle, "FireUser1");
}

public bool TraceFilterClients(int entity, int contentsMask, any data) 
{
	return entity == 0;
}

bool SetTeleportEndPoint(int client, float Position[3])
{
	float vAngles[3];
	float vOrigin[3];
	float vBuffer[3];
	float vStart[3];
	float Distance;
	
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	
    //get endpoint for teleport
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer2);

	if(TR_DidHit(trace))
	{
   	 	TR_GetEndPosition(vStart, trace);
		GetVectorDistance(vOrigin, vStart, false);
		Distance = -35.0;
   	 	GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
		Position[0] = vStart[0] + (vBuffer[0]*Distance);
		Position[1] = vStart[1] + (vBuffer[1]*Distance);
		Position[2] = vStart[2] + (vBuffer[2]*Distance);
	}
	else
	{
		CloseHandle(trace);
		return false;
	}
	
	CloseHandle(trace);
	return true;
}

public bool TraceEntityFilterPlayer2(int entity, int contentsMask)
{
	return entity > GetMaxClients() || !entity;
}