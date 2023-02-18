class X2Action_Fire_Deployment extends X2Action_Fire;

function Init()
{
	local XComGameState_Ability AbilityState;	
	local XGUnit				FiringUnit;	
	local XComWeapon			WeaponEntity;

	super.Init();

	if (class'Help'.static.IsCharTemplateSparkLike(SourceUnitState.GetMyTemplate()))
	{
		if (AnimParams.AnimName == 'FF_GrenadeUnderhand')
		{
			AnimParams.AnimName = 'FF_Deploy_GrenadeUnderhand';
		}
		else
		{
			AnimParams.AnimName = 'FF_Deploy_Grenade';
		}
	}

	AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityContext.InputContext.AbilityRef.ObjectID));
	FiringUnit = XGUnit(History.GetVisualizer(AbilityState.OwnerStateObject.ObjectID));
	WeaponEntity = FiringUnit.CurrentPerkAction.GetPerkWeapon();
	
	switch (class'Help'.static.GetDeploymentType())
	{
		case `eDT_SeismicBeacon:
			SkeletalMeshComponent(WeaponEntity.Mesh).SetSkeletalMesh(SkeletalMesh(`CONTENT.RequestGameArchetype("UltrasonicLure.Meshes.SM_UltraSonicLure")));
			`AMLOG("Overriding mesh to seismic beacon");
			break;
		case `eDT_TeleportBeacon:
			SkeletalMeshComponent(WeaponEntity.Mesh).SetSkeletalMesh(SkeletalMesh(`CONTENT.RequestGameArchetype("IRIDynamicDeployment_Perks.Meshes.SM_Teleport_Beacon")));
			`AMLOG("Overriding mesh to teleport beacon");
			break;
		case `eDT_Flare:
		default:
			`AMLOG("Not overriding mesh");
			break;
	}
}


/*
function CompleteAction()
{
	local XComWeapon WeaponEntity;

	WeaponEntity = WeaponVisualizer.GetEntity();

	WeaponEntity.Destroy();
	WeaponVisualizer.Destroy();

	super.CompleteAction();
}*/