class X2Condition_SparkLike extends X2Condition;

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	return class'Help'.static.IsCharTemplateSparkLike(SourceUnit.GetMyTemplate());
}