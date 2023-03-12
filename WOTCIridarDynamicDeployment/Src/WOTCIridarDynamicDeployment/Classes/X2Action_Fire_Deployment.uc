class X2Action_Fire_Deployment extends X2Action_Fire;

function Init()
{
	local XComGameState_Ability AbilityState;	
	local XGUnit				FiringUnit;	
	local XComWeapon			WeaponEntity;

	super.Init();

	// Pick different firing animation for SPARKs
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

	// Override the weapon mesh for the duration of the throw animation dependiong on the deployment type	
	switch (class'Help'.static.GetDeploymentType())
	{
		case `eDT_SeismicBeacon:
			AbilityState = XComGameState_Ability(History.GetGameStateForObjectID(AbilityContext.InputContext.AbilityRef.ObjectID));
			FiringUnit = XGUnit(History.GetVisualizer(AbilityState.OwnerStateObject.ObjectID));
			WeaponEntity = FiringUnit.CurrentPerkAction.GetPerkWeapon();
			SkeletalMeshComponent(WeaponEntity.Mesh).SetSkeletalMesh(SkeletalMesh(`CONTENT.RequestGameArchetype("UltrasonicLure.Meshes.SM_UltraSonicLure")));
			`AMLOG("Overriding mesh to seismic beacon");
			break;

		case `eDT_Flare:
		default:
			`AMLOG("Not overriding mesh");
			break;
	}
}

