class X2Condition_SoldierRank extends X2Condition;

var int MinRank;

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return SourceUnit.GetSoldierRank() >= MinRank;
}