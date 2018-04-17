#include <sdktools>

#pragma newdecls required;

public Plugin myinfo = 
{
	name = "[TF2] CTFPlayerShared::GetHealerByIndex",
	author = "Pelipoika",
	description = "",
	version = "",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_getmyhealers", Command_Get, ADMFLAG_BAN);
}

#define Pointer Address
#define nullptr Address_Null

#define Address(%1) view_as<Address>(%1)
#define int(%1) view_as<int>(%1)

public Action Command_Get(int client, int argc)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;
		
	/*
	class healers_t
	{
	public:
		__int32 pPlayer; //0x0000 
		char pad_0x0004[0x4]; //0x0004
		float flAmount; //0x0008 
		char pad_0x000C[0x8]; //0x000C
		__int32 bDispenserHeal; //0x0014 
		char pad_0x0018[0xC]; //0x0018
	
	}; //Size=0x0024
	*/		

	for (int i = 0; i < GetEntProp(client, Prop_Send, "m_nNumHealers"); i++)
	{
		int iHealerIndex = GetHealerByIndex(client, i);
		
		bool bIsClient = (iHealerIndex <= MaxClients);
		
		if(bIsClient)
		{
			PrintToServer("\"%N\" <- healed by player \"%N\" [%i]", client, iHealerIndex, iHealerIndex);
		}
		else
		{
			char class[64];
			GetEntityClassname(iHealerIndex, class, sizeof(class));
			
			PrintToServer("\"%N\" <- healed by entity \"%s\" [%i]", client, class, iHealerIndex);
		}
	}
	
	/*
	"Pelipoika" <- healed by entity "obj_dispenser" [56]
	"Pelipoika" <- healed by player "Chell" [2]
	"Pelipoika" <- healed by player "Totally Not A Bot" [4]
	*/
	
	return Plugin_Handled;
}

/*
stock int GetHealerByIndex(int client, int index)
{
	int m_aHealers = FindSendPropInfo("CTFPlayer", "m_nNumHealers") + 12;
	
	Address m_Shared = GetEntityAddress(client) + view_as<Address>(m_aHealers);
	Address aHealers = view_as<Address>(LoadFromAddress(m_Shared, NumberType_Int32));
	
	return (LoadFromAddress(aHealers + view_as<Address>(index * 0x24), NumberType_Int32) & 0xFFF);
}
*/

stock int GetHealerByIndex(int client, int index)
{
	int m_aHealers = FindSendPropInfo("CTFPlayer", "m_nNumHealers") + 12;
	
	Address m_Shared = GetEntityAddress(client) + Address(m_aHealers);
	Address aHealers = Address(ReadInt(m_Shared));

	return ReadInt(Transpose(aHealers, (index * 0x24))) & 0xFFF;
}

stock Pointer Transpose(Pointer pAddr, int iOffset)
{
	return Address(int(pAddr) + iOffset);
}
stock int Dereference(Pointer pAddr, int iOffset = 0)
{
	if(pAddr == nullptr)
	{
		return -1;
	}
	
	return ReadInt(Transpose(pAddr, iOffset));
}
stock int ReadInt(Pointer pAddr)
{
	if(pAddr == nullptr)
	{
		return -1;
	}
	
	return LoadFromAddress(pAddr, NumberType_Int32);
}
