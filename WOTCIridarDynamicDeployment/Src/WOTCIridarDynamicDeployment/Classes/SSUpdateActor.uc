class SSUpdateActor extends Actor;

// Used when the mod is used without robojumper's Squad Select to run regular updates on the squad select interface
// so that when a soldier is removed from squad, their DD checkbox is removed as well.

var UISL_DynamicDeployment UISL;

event Tick( float DeltaTime )
{
	if (UISL != none)
	{
		UISL.UpdateSquad();
		UISL.UpdateSquadSelect();
	}
}


defaultproperties
{
	LOD_TickRate = 0.5f
}
