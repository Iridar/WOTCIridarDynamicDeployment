class X2Condition_AerialScout extends X2Condition;

// Checks if at least one deploying unit has the Aerial Scout unlock.

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState_DynamicDeployment	DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	UnitStates = DDObject.GetUnitsToDeploy();

	foreach UnitStates(UnitState)
	{
		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, 'IRI_DDUnlock_AerialScout'))
		{
			return 'AA_Success'; 
		}
	}
	
	return 'AA_AbilityUnavailable';
	
	
}
