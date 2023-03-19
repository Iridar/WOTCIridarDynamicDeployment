class X2Condition_DynamicDeployment extends X2Condition;

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{	
	if (!IsAnyUnitSelected())
	{
		return 'AA_AbilityUnavailable';
	}

	return 'AA_Success'; 
}

static private function bool IsAnyUnitMarked()
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	local XComGameStateHistory				History;

	History = `XCOMHISTORY;

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	foreach XComHQ.Squad(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState == none)
			continue;

		// This will check if the unit can be deployed on the current mission.
		if (class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState, XComHQ.MissionRef.ObjectID))
		{
			return true;
		}
	}
	return false;
}

static private function bool IsAnyUnitSelected()
{
	local XComGameState_DynamicDeployment DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment', true));

	return DDObject != none && DDObject.IsAnyUnitSelected();
}

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return IsAnyUnitMarked() && SourceUnit.GetSoldierRank() >= `GetConfigInt("IRI_DD_MinRank");
}
