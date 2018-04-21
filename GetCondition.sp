#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>

#pragma newdecls required;

public Plugin myinfo = 
{
	name = "[TF2] CTFPlayerShared::GetConditionDuration & GetConditionProvider",
	author = "Pelipoika",
	description = "",
	version = "",
	url = "http://www.sourcemod.net/plugins.php?author=Pelipoika&search=1"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_getmyconds", Command_Get, ADMFLAG_BAN);
}

#define Pointer Address
#define nullptr Address_Null

#define Address(%1) view_as<Address>(%1)
#define int(%1) view_as<int>(%1)

public Action Command_Get(int client, int argc)
{
	if(client <= 0 || client > MaxClients || !IsClientInGame(client))
		return Plugin_Handled;
		
	PrintToServer("( Server ) Conditions for player ( %N )", client);
	
	bool bAnyCondActive = false;
	
	for (TFCond cond = TFCond_Zoomed; cond <= TFCond_CompetitiveWinner; cond++)
	{
		if(!TF2_IsPlayerInCondition(client, cond))
			continue;
		
		bAnyCondActive = true;
		
		float flDuration = GetConditionDuration(client, cond);
		int iProvider    = GetConditionProvider(client, cond);
		
		if (flDuration == TFCondDuration_Infinite)
		{
			if(iProvider == 0)
			{
				PrintToServer("( Server ) Condition %d - ( permanent cond )", cond);
			}
			else
			{
				PrintToServer("( Server ) Condition %d - ( permanent cond ) - ( provided by %d )", cond, iProvider);
			}
		}
		else
		{
			if(iProvider == 0)
			{
				PrintToServer("( Server ) Condition %d - ( %.1f left )", cond, flDuration);
			}
			else
			{
				PrintToServer("( Server ) Condition %d - ( %.1f left ) - ( provided by %d )", cond, flDuration, iProvider);
			}
		}
	}
	
	if(!bAnyCondActive)
		PrintToServer("( Server ) No active conditions");
	
	return Plugin_Handled;
}

stock float GetConditionDuration(int client, TFCond cond)
{
	int m_Shared = FindSendPropInfo("CTFPlayer", "m_Shared");
	
	Address aCondSource   = Address(ReadInt(GetEntityAddress(client) + Address(m_Shared + 8)));
	Address aCondDuration = Address(int(aCondSource) + (int(cond) * 20) + (2 * 4));
	
	float flDuration = 0.0;
	if(TF2_IsPlayerInCondition(client, cond))
	{
		flDuration = view_as<float>(ReadInt(aCondDuration));
	}
	
	return flDuration;
}

stock int GetConditionProvider(int client, TFCond cond)
{
	int m_Shared = FindSendPropInfo("CTFPlayer", "m_Shared");
	
	Address aCondSource   = Address(ReadInt(GetEntityAddress(client) + Address(m_Shared + 8)));
	Address aCondProvider = Address(int(aCondSource) + (int(cond) * 20) + (3 * 4));
	
	int iProvider = 0;
	if(TF2_IsPlayerInCondition(client, cond))
	{
		iProvider = (ReadInt(aCondProvider) & 0xFFF);
	}
	
	return iProvider;
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
