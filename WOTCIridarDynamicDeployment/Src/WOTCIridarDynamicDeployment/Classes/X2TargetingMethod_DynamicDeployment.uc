class X2TargetingMethod_DynamicDeployment extends X2TargetingMethod_VoidRift;

//var private X2Actor_InvalidTarget InvalidTileActor;
//var private XComActionIconManager IconManager;

// Icarus Jump
function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	local name AbilityAvailability;
	local XComWorldData World;
	local int MaxZ;
	
	AbilityAvailability = super.ValidateTargetLocations(TargetLocations);
	if (AbilityAvailability == 'AA_Success')
	{
		World = `XWORLD;

		MaxZ = class'XComWorldData'.const.WORLD_FloorHeightsPerLevel * class'XComWorldData'.const.WORLD_TotalLevels * class'XComWorldData'.const.WORLD_FloorHeight;
		if (!World.HasOverheadClearance(TargetLocations[0], MaxZ))
		{
			AbilityAvailability = 'AA_TileIsBlocked';
		}
	}
	return AbilityAvailability;
}

// Teleport
/*
function Init(AvailableAction InAction, int NewTargetIndex)
{
	local XGBattle Battle;

	super.Init(InAction, NewTargetIndex);

	Battle = `BATTLE;

	InvalidTileActor = Battle.Spawn(class'X2Actor_InvalidTarget');
	ExplosionEmitter.SetHidden(true);

	IconManager = `PRES.GetActionIconMgr();
	IconManager.UpdateCursorLocation(true);
}

function Canceled()
{
	super.Canceled();

	// clean up the ui
	InvalidTileActor.Destroy();

	IconManager.ShowIcons(false);
}

function Update(float DeltaTime)
{
	local vector NewTargetLocation;
	local array<vector> TargetLocations;
	local array<TTile> Tiles;
	local XComWorldData World;
	local TTile TeleportTile;
	
	NewTargetLocation = Cursor.GetCursorFeetLocation();

	if (NewTargetLocation != CachedTargetLocation)
	{
		TargetLocations.AddItem(Cursor.GetCursorFeetLocation());
		if( ValidateTargetLocations(TargetLocations) == 'AA_Success' )
		{
			// The current tile the cursor is on is a valid tile
			// Show the ExplosionEmitter
			ExplosionEmitter.ParticleSystemComponent.ActivateSystem();
			InvalidTileActor.SetHidden(true);

			World = `XWORLD;
		
			TeleportTile = World.GetTileCoordinatesFromPosition(TargetLocations[0]);
			Tiles.AddItem(TeleportTile);
			DrawAOETiles(Tiles);
			IconManager.UpdateCursorLocation(, true);
		}
		else
		{
			DrawInvalidTile();
		}
	}

	super.UpdateTargetLocation(DeltaTime);
}

simulated protected function DrawInvalidTile()
{
	local Vector Center;

	Center = GetSplashRadiusCenter();

	// Hide the ExplosionEmitter
	ExplosionEmitter.ParticleSystemComponent.DeactivateSystem();
	
	InvalidTileActor.SetHidden(false);
	InvalidTileActor.SetLocation(Center);
}

function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	local name AbilityAvailability;
	local TTile TeleportTile;
	local XComWorldData World;
	local bool bFoundFloorTile;

	AbilityAvailability = super.ValidateTargetLocations(TargetLocations);
	if( AbilityAvailability == 'AA_Success' )
	{
		// There is only one target location and visible by squadsight
		World = `XWORLD;
		
		`assert(TargetLocations.Length == 1);
		bFoundFloorTile = World.GetFloorTileForPosition(TargetLocations[0], TeleportTile);
		if( bFoundFloorTile && !World.CanUnitsEnterTile(TeleportTile) )
		{
			AbilityAvailability = 'AA_TileIsBlocked';
		}
	}

	return AbilityAvailability;
}*/

defaultproperties
{
	bRestrictToSquadsightRange = true;
}