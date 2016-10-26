#include <sdktools>
#include <sdkhooks>
#include <utilsext>
#include <dhooks>

#pragma newdecls required

#define EF_BONEMERGE                (1 << 0)
#define EF_PARENT_ANIMATES          (1 << 9)

int stringTable;

Handle g_hPrimaryAttack;

public Plugin myinfo = 
{
	name = "[TF2] Muzzle Flash",
	author = "Pelipoika",
	description = "Pew! Pew!",
	version = "1.0",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	stringTable = FindStringTable("modelprecache");
	
	//CTFWeaponBase::OnBulletFire(int) 443 l	436	w
	g_hPrimaryAttack = DHookCreate(436, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CTFWeaponBase_PrimaryAttack);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "tf_weapon_", false) != -1)
	{
		DHookEntity(g_hPrimaryAttack, false, entity);
	}
}

public MRESReturn CTFWeaponBase_PrimaryAttack(int pThis, Handle hReturn, Handle hParams)
{
	int iWeapon = pThis;
	int iShooter = GetEntPropEnt(iWeapon, Prop_Data, "m_hOwnerEntity");
	
	float pPos[3], pAng[3];
	GetClientAbsOrigin(iShooter, pPos);
	GetClientAbsAngles(iShooter, pAng);
	
	char strModelPath[PLATFORM_MAX_PATH];
	ReadStringTable(stringTable, GetEntProp(iWeapon, Prop_Send, "m_iWorldModelIndex"), strModelPath, PLATFORM_MAX_PATH);  
	
	int dummy = CreateEntityByName("prop_dynamic_override");
	DispatchKeyValue(dummy, "model", strModelPath);
	DispatchSpawn(dummy);
	
	SetEntProp(dummy, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_PARENT_ANIMATES);
	
	SetVariantString("!activator");
	AcceptEntityInput(dummy, "SetParent", iShooter);
	
	SetVariantString("head");
	AcceptEntityInput(dummy, "SetParentAttachmentMaintainOffset"); 
	
	float vecPos[3], vecAng[3];
	utils_EntityGetAttachment(dummy, utils_EntityLookupAttachment(dummy, "muzzle"), vecPos, vecAng);
	
	AcceptEntityInput(dummy, "Kill");
	
	TE_Start("Dynamic Light");
	TE_WriteVector("m_vecOrigin", vecPos);
	TE_WriteNum("r", 252);
	TE_WriteNum("g", 238);
	TE_WriteNum("b", 128);
	TE_WriteNum("exponent", 5);
	
	float flRadius = GetRandomFloat(122.5, 128.0);
	
	TE_WriteFloat("m_fRadius", flRadius);
	TE_WriteFloat("m_fTime",  0.1);
	TE_WriteFloat("m_fDecay", 512.0);
	TE_SendToAll();
	
	return MRES_Ignored;
}