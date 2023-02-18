class X2Condition_AerialScout extends X2Condition;

// Checks if at least one deploying unit has the Aerial Scout unlock.

event name CallAbilityMeetsCondition(XComGameState_Ability kAbility, XComGameState_BaseObject kTarget)
{
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState_DynamicDeployment	DDObject;

	`AMLOG("Running");

	// No scouting when we're not deploying via parachute.
	if (class'Help'.static.GetDeploymentType() == `eDT_Flare)
	{
		`AMLOG("Underground or teleporting, condition fails.");
		return 'AA_AbilityUnavailable';
	}

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	UnitStates = DDObject.GetUnitsToDeploy();

	foreach UnitStates(UnitState)
	{	
		`AMLOG("Checking deploying unit:" @ UnitState.GetFullName());
		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, 'IRI_DDUnlock_AerialScout'))
		{
			`AMLOG("Unit has Aerial Scout unlock, condition succeeds");
			return 'AA_Success'; 
		}
	}

	`AMLOG("No Unit has Aerial Scout unlock, condition fails");
	
	return 'AA_AbilityUnavailable';
}
