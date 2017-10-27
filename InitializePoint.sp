#pragma semicolon 1

#include <dhooks>

Handle g_hInitializePoint;

public void OnPluginStart()
{
	/*
	CTFFlameManager::InitializePoint
	*/
	g_hInitializePoint = DHookCreate(192, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CTFFlameManager_InitializePoint);
	DHookAddParam(g_hInitializePoint, HookParamType_ObjectPtr, -1);
	DHookAddParam(g_hInitializePoint, HookParamType_Int);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrEqual(classname, "tf_flame_manager"))
	{
		DHookEntity(g_hInitializePoint, true, entity);
		
		PrintToServer("Hooked CTFFlameManager::InitializePoint on tf_flame_manager %i", entity);
	}
}

public MRESReturn CTFFlameManager_InitializePoint(int pThis, Handle hParams)
{
	/*
	CTFFlameManager::InitializePoint @ (40.296852 -150.358459 -132.557815) vel (1379.987182 -1798.679809 -396.164093) seed 0 lifetime 0.517885 gametime 891.989990
	CTFFlameManager::InitializePoint @ (40.296852 -150.358459 -132.557815) vel (1404.413330 -1778.986694 -397.125122) seed 1 lifetime 0.687542 gametime 892.019958
	CTFFlameManager::InitializePoint @ (40.296852 -150.358459 -132.557815) vel (1383.478637 -1812.721557 -305.252166) seed 2 lifetime 0.699721 gametime 892.049987
	CTFFlameManager::InitializePoint @ (40.296852 -150.358459 -132.557815) vel (1443.273925 -1772.890258 -262.350708) seed 3 lifetime 0.512817 gametime 892.079956
	CTFFlameManager::InitializePoint @ (40.296852 -150.358459 -132.557815) vel (1466.293212 -1740.187744 -339.652008) seed 4 lifetime 0.541388 gametime 892.109985
	CTFFlameManager::InitializePoint @ (40.296852 -150.358459 -132.557815) vel (1458.359497 -1738.543212 -382.771759) seed 5 lifetime 0.523758 gametime 892.139953
	CTFFlameManager::InitializePoint @ (40.296852 -150.358459 -132.557815) vel (1369.047729 -1817.329589 -342.638122) seed 6 lifetime 0.697839 gametime 892.169982
	*/

	//CTFPointManager::GetInitialPosition()
	float x = DHookGetParamObjectPtrVar(hParams, 1, 4, ObjectValueType_Float);
	float y = DHookGetParamObjectPtrVar(hParams, 1, 8, ObjectValueType_Float);
	float z = DHookGetParamObjectPtrVar(hParams, 1, 12, ObjectValueType_Float);
	
	//CTFPointManager::GetInitialVelocity()
	float velX = DHookGetParamObjectPtrVar(hParams, 1, 16, ObjectValueType_Float);
	float velY = DHookGetParamObjectPtrVar(hParams, 1, 20, ObjectValueType_Float);
	float velZ = DHookGetParamObjectPtrVar(hParams, 1, 24, ObjectValueType_Float);
	
	//GetGameTime()
	float gameTime = DHookGetParamObjectPtrVar(hParams, 1, 28, ObjectValueType_Float);
	
	//CTFPointManager::GetLifeTime()
	float flLifeTime = DHookGetParamObjectPtrVar(hParams, 1, 32, ObjectValueType_Float);
	
	//seed
	int seed = DHookGetParamObjectPtrVar(hParams, 1, 36, ObjectValueType_Int);
	
	PrintToServer("CTFFlameManager::InitializePoint @ (%f %f %f) vel (%f %f %f) seed %i lifetime %f gametime %f", x, y, z, velX, velY, velZ, seed, flLifeTime, gameTime);

	return MRES_Ignored;
}