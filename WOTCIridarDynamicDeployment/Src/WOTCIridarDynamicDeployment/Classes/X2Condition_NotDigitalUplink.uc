class X2Condition_NotDigitalUplink extends X2Condition;

event name CallMeetsCondition(XComGameState_BaseObject kTarget) 
{
	local XComGameState_Unit UnitState;
	
	UnitState = XComGameState_Unit(kTarget);
	
	if (UnitState != none)
	{
		if (class'Help'.static.ShouldUseDigitalUplink(UnitState))
		{
			return 'AA_AbilityUnavailable';
		}
	}
	else return 'AA_NotAUnit';
	
	return 'AA_Success'; 
}

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return !class'Help'.static.ShouldUseDigitalUplink(SourceUnit);
}