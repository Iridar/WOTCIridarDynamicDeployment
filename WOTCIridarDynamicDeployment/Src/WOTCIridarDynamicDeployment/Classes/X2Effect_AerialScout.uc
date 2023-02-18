class X2Effect_AerialScout extends X2Effect_PersistentSquadViewer;

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local XComGameStateHistory				History;
	local XComGameState_SquadViewer			ViewerState;
	local Vector							ViewerLocation;
	local TTile								ViewerTile;
	local XComWorldData						World;

	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState_DynamicDeployment	DDObject;

	`AMLOG("X2Effect_AerialScout running");

	// #1. Calculate radius
	History = `XCOMHISTORY;

	ViewRadius = `GetConfigInt("IRI_DD_MinRank_AerialScout_InitialRadius_Tiles");

	DDObject = XComGameState_DynamicDeployment(History.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	UnitStates = DDObject.GetUnitsToDeploy();

	`AMLOG("-- Initial radius:" @ ViewRadius);

	foreach UnitStates(UnitState)
	{
		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, 'IRI_DDUnlock_AerialScout'))
		{
			ViewRadius += `GetConfigInt("IRI_DD_MinRank_AerialScout_PerUnitRadius_Tiles");
			`AMLOG(UnitState.GetFullName() @ "has unlock, increasing area by:" @ `GetConfigInt("IRI_DD_MinRank_AerialScout_PerUnitRadius_Tiles"));
		}
	}

	`AMLOG("-- Final radius:" @ ViewRadius);

	
	// # 2. Spawn the viewer. Same as original, but we put the viewer at Max Z.

	if (ApplyEffectParameters.AbilityInputContext.TargetLocations.Length == 0)
	{
		`Redscreen("Attempting to create X2Effect_PersistentSquadViewer without a target location! -jbouscher @gameplay");
		return;
	}
	
	ViewerLocation = ApplyEffectParameters.AbilityInputContext.TargetLocations[0];

	World = `XWORLD;
	ViewerLocation.Z = World.WORLD_FloorHeightsPerLevel * World.WORLD_TotalLevels * World.WORLD_FloorHeight;
	ViewerTile = World.GetTileCoordinatesFromPosition(ViewerLocation);
	
	// create the viewer state
	ViewerState = XComGameState_SquadViewer(NewGameState.CreateNewStateObject(class'XComGameState_SquadViewer'));
	ViewerState.AssociatedPlayer = ApplyEffectParameters.PlayerStateObjectRef;		
	ViewerState.SetVisibilityLocation(ViewerTile);
	ViewerState.ViewerRadius = ViewRadius;

	// save a reference to the object we just created, so that we can remove it later
	NewEffectState.CreatedObjectReference = ViewerState.GetReference();
}

