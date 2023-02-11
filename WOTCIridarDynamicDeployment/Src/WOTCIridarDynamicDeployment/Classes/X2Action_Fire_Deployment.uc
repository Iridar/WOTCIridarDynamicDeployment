class X2Action_Fire_Deployment extends X2Action_Fire;

function Init()
{
	super.Init();

	// TODO: Or unit has digital uplink upgrade
	if (class'Help'.static.ShouldUseTeleportDeployment())
	{
		AnimParams.AnimName = 'HL_SignalPoint';
	}
	else if (class'Help'.static.IsUndergroundPlot())
	{
		if (class'Help'.static.IsCharTemplateSparkLike(SourceUnitState.GetMyTemplate()))
		{
			AnimParams.AnimName = 'HL_SignalPositivePost';
		}
		else
		{
			AnimParams.AnimName = 'HL_CallReinforcements';
		}
	}
	else
	{
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
	}
}