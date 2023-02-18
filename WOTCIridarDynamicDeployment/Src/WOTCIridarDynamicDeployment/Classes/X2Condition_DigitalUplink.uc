class X2Condition_DigitalUplink extends X2Condition;

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{
	local XComGameState_Unit UnitState;
	
	UnitState = XComGameState_Unit(kTarget);
	
	if (UnitState != none)
	{
		if (class'Help'.static.ShouldUseDigitalUplink(UnitState))
		{
			return 'AA_Success'; 
		}
	}
	else return 'AA_NotAUnit';
	
	return 'AA_AbilityUnavailable';
}

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return class'Help'.static.ShouldUseDigitalUplink(SourceUnit);
}