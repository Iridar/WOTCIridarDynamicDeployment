class X2TargetingMethod_DynamicDeployment extends X2TargetingMethod_VoidRift;

// A lot of magic in this class. Accomplishes two goals:
// 1. Allows clicking only on tiles that have clearanace to Max Z.
// 2. Handles selection of deployment locations for units with Precision Drop upgrade.
// When targeting method is activated, the player selects the deployment area.
// Array of marked tiles (AreaTiles) is constantly validated to display only tiles
// that have clearance to Max Z and are valid things for units to stand on.
// First click locks the targeted area. 
// Consecutive clicks pick deployment destinations for precision dropped units.
// Picking the location for the final precision drop unit activates the ability.

//var private X2Actor_InvalidTarget InvalidTileActor;
//var private XComActionIconManager IconManager;

var private UIPawnMgr						PawnMgr;
var private XComWorldData					World;
var private MaterialInstanceTimeVarying		HoloMITV;
var private ParticleSystem					BeamEmitterPS;
var private int								iNumSpawnedUnits;
var private bool							bAreaLocked;
var private XComPresentationLayer			Pres;
var private array<TTile>					AreaTiles;
var private int								MaxZ;

// Parallel arrays
var private array<XComGameState_Unit>		PrecisionDropUnitStates;
var private array<XComUnitPawn>				PrecisionDropPawns;
var private array<TTile>					PrecisionDropTiles;
var private transient array<XComEmitter>	BeamEmitters;

function Init(AvailableAction InAction, int NewTargetIndex)
{
	local XComGameState_DynamicDeployment DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none || !DDObject.bPendingDeployment)
	{
		super.Init(InAction, NewTargetIndex);
		return;
	}

	MaxZ = World.WORLD_FloorHeightsPerLevel * World.WORLD_TotalLevels * World.WORLD_FloorHeight;

	PrecisionDropUnitStates = DDObject.GetPrecisionDropUnits();
	if (PrecisionDropUnitStates.Length > 0)
	{
		PrecisionDropTiles.Length = PrecisionDropUnitStates.Length;
		World = `XWORLD;
		PawnMgr = `PRESBASE.GetUIPawnMgr();
		HoloMITV = MaterialInstanceTimeVarying(`CONTENT.RequestGameArchetype("FX_Mimic_Beacon_Hologram.M_Mimic_Activate_MITV"));
		BeamEmitterPS = ParticleSystem(`CONTENT.RequestGameArchetype("IRIDynamicDeployment.PS_BeamEmitter"));

		`AMLOG("Got this many unit states:" @ PrecisionDropUnitStates.Length @ "HoloMITV loaded:" @ HoloMITV != none @ "BeamEmitterPS loaded:" @ BeamEmitterPS != none);
		Pres = `PRES;
		Pres.m_kTacticalHUD.Movie.Stack.SubscribeToOnInputForScreen(Pres.m_kTacticalHUD, OnTacticalHUDInput);
	}
	super.Init(InAction, NewTargetIndex);
}

// Hijack left click or other ways to confirm ability activation if there are any precision drop units.
// Consecutive clicks will lock the location of the last spawned pawn, and spawn a new one,
// if there are any remaining.
// If 
function bool VerifyTargetableFromIndividualMethod(delegate<ConfirmAbilityCallback> fnCallback)
{
	local vector	SpawnLocation;
	local TTile		SpawnTile;
	
	if (PrecisionDropUnitStates.Length == 0)
		return true;

	// First click locks the targeted area.
	if (!bAreaLocked)
	{
		bAreaLocked = true;
	}

	// TODO: Continue polishing from here.
	// Lock the targeted tile for last spawned pawn.
	if (iNumSpawnedUnits > 0)
	{
		SpawnLocation = PrecisionDropPawns[iNumSpawnedUnits - 1].Location;
		SpawnLocation.Z -= World.WORLD_FloorHeight;
		SpawnTile = World.GetTileCoordinatesFromPosition(SpawnLocation);
		PrecisionDropTiles[iNumSpawnedUnits - 1] = SpawnTile;
	}

	// Then see if we need to spawn more units.
	if (iNumSpawnedUnits < PrecisionDropUnitStates.Length)
	{
		`AMLOG("Area locked, spawning new pawn");
		SpawnLocation = CachedTargetLocation;
		SpawnTile = World.GetTileCoordinatesFromPosition(SpawnLocation);

		// If the player clicked outside the designated area, spawn the pawn on the closest tile in the area.
		if (class'Helpers'.static.FindTileInList(SpawnTile, AreaTiles) == INDEX_NONE ||
			class'Helpers'.static.FindTileInList(SpawnTile, PrecisionDropTiles) != INDEX_NONE)
		{
			SpawnTile = FindClosestTileInArea(SpawnTile);
			SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);
		}
		
		SpawnPawnForUnit(PrecisionDropUnitStates[iNumSpawnedUnits], SpawnLocation);
		PrecisionDropTiles[iNumSpawnedUnits - 1] = SpawnTile;

		return false;
	}

	`AMLOG("All pawns are spawned, final commit.");
	return true;
}

// Hijack right click and other "cancel targeting" keys to use our own staged cancel function instead,
// which removes the last placed precision drop pawn.
// When there are no more pawns, the targeting area is unlocked and can be moved.
// If it's alreay unlocked, the normal logic is allowed to take place, cancelling the targeting.
simulated protected function bool OnTacticalHUDInput(UIScreen Screen, int iInput, int ActionMask)
{
    if (!Screen.CheckInputIsReleaseOrDirectionRepeat(iInput, ActionMask))
    {
		`AMLOG("Blah blah early exit");
        return false;
    }

    switch (iInput)
    {
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
	
	// washing_hands.jpg
    case class'UIUtilities_Input'.static.GetBackButtonInputCode():
	case (class'UIUtilities_Input'.const.FXS_BUTTON_START):
	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
	case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER:
        return StagedCancel();
        break;
    }

    return false;
}

function Update(float DeltaTime)
{
	local array<Actor>	CurrentlyMarkedTargets;
	local vector		NewTargetLocation;
	local TTile			SelectedTile;

	NewTargetLocation = GetSplashRadiusCenter();

	if (NewTargetLocation != CachedTargetLocation)
	{			
		if (!bAreaLocked)
		{
			AreaTiles.Length = 0;
			GetTargetedActors(NewTargetLocation, CurrentlyMarkedTargets, AreaTiles);
			ValidateAreaTiles();
			//CheckForFriendlyUnit(CurrentlyMarkedTargets);	
			//MarkTargetedActors(CurrentlyMarkedTargets, (!AbilityIsOffensive) ? FiringUnit.GetTeam() : eTeam_None );
			DrawAOETiles(AreaTiles);
		}
		else
		{
			// Move the pawn with the cursor, but keep it within bounds of the selected tile area,
			// And not on top of previously selected tiles for other units
			SelectedTile = World.GetTileCoordinatesFromPosition(NewTargetLocation);
			if (class'Helpers'.static.FindTileInList(SelectedTile, AreaTiles) != INDEX_NONE &&
				class'Helpers'.static.FindTileInList(SelectedTile, PrecisionDropTiles) == INDEX_NONE)
			{
				NewTargetLocation.Z += World.WORLD_FloorHeight;
				MoveLastSpawnedPawn(NewTargetLocation);
			}
		}
	}
	//DrawSplashRadius( );

	super(X2TargetingMethod).Update(DeltaTime);
}






private function SpawnPawnForUnit(const XComGameState_Unit SpawnUnit, vector PawnLocation)
{
	local rotator PawnRotation;
	local XComUnitPawn UnitPawn;
	local XComEmitter BeamEmitter;

	// Raise the location a bit so that pawn stands on feet rather than halfway into the ground.
	PawnLocation.Z += World.WORLD_FloorHeight;

	UnitPawn = PawnMgr.RequestCinematicPawn(FiringUnit, SpawnUnit.ObjectID, PawnLocation, PawnRotation);
	UnitPawn.CreateVisualInventoryAttachments(PawnMgr, SpawnUnit);
	UnitPawn.ApplyMITV(HoloMITV);
	
	UnitPawn.HQIdleAnim = "NO_IdleGunUp";
	UnitPawn.GotoState('Onscreen');			// This will play HQIdleAnim
	UnitPawn.Mesh.GlobalAnimRateScale = 0;	// Freeze the pawn at the first frame of the animation.
	PrecisionDropPawns.AddItem(UnitPawn);

	BeamEmitter = `BATTLE.spawn(class'XComEmitter');
	BeamEmitter.SetTemplate(BeamEmitterPS);
	BeamEmitter.LifeSpan = 60 * 60 * 24 * 7; // never die (or at least take a week to do so)
	BeamEmitter.SetDrawScale(1);
	BeamEmitter.SetRotation( rot(0,0,1) );
	if (!BeamEmitter.ParticleSystemComponent.bIsActive)
	{
		BeamEmitter.ParticleSystemComponent.ActivateSystem();			
	}
	BeamEmitters.AddItem(BeamEmitter);

	iNumSpawnedUnits++;
}


private function ValidateAreaTiles()
{
	local TTile TestTile;
	local int i;

	for (i = AreaTiles.Length - 1; i >= 0; i--)
	{
		TestTile = AreaTiles[i];
		if (!IsTileValid(TestTile))
		{
			AreaTiles.Remove(i, 1);
		}
	}
}


private function bool IsTileValid(const TTile TestTile)
{
	local TTile		SelectedTile;
	local vector	SelectedLocation;
	
	// Only tiles with clearance to MaxZ are valid.
	SelectedLocation = World.GetPositionFromTileCoordinates(TestTile);
	if (!World.HasOverheadClearance(SelectedLocation, MaxZ))
	{
		return false;
	}

	if (!World.IsFloorTileAndValidDestination(SelectedTile))
	{
		return false;
	}

	if (!World.CanUnitsEnterTile(SelectedTile))
	{
		return false;
	}

	return true;
}


private function TTile FindClosestTileInArea(const TTile InputTile)
{
	local TTile TestTile;
	local TTile ClosestTile;
	local float Distance;
	local float ShortestDistance;

	ShortestDistance = MaxInt;
	foreach AreaTiles(TestTile)
	{
		if (class'Helpers'.static.FindTileInList(TestTile, PrecisionDropTiles) != INDEX_NONE)
			continue;

		Distance = GetTileDistanceBetweenTiles(InputTile, TestTile);
		if (Distance < ShortestDistance)
		{
			ShortestDistance = Distance;
			ClosestTile = TestTile;
		}
	}

	return ClosestTile;
}

private function float GetTileDistanceBetweenTiles(const TTile TileA, const TTile TileB) 
{
	local vector	LocA;
	local vector	LocB; 
	local float		Dist; 
	local float		TileDistance;

	LocA = World.GetPositionFromTileCoordinates(TileA);
	LocB = World.GetPositionFromTileCoordinates(TileB);

	Dist = VSize(LocA - LocB);
	TileDistance = Dist / World.WORLD_StepSize;

	return TileDistance;
}

// Returns true if we handled the right click and there's no need to kill the targeting method yet.
private function bool StagedCancel()
{
	`AMLOG("Running. iNumSpawnedUnits:" @ iNumSpawnedUnits);
	if (iNumSpawnedUnits != 0)
	{
		`AMLOG("There are still pawns, releasing last one");
		ReleaseLastSpawnedPawn();
		return true;
	}
	
	if (bAreaLocked)
	{
		`AMLOG("There are no pawns left, unlocking area");
		bAreaLocked = false;
		return true;
	}

	`AMLOG("There are no pawns left, area unlocked, final cancel.");
	return false;
}
// Called by Comitted() too.
function Canceled()
{
	AreaTiles.Length = 0;
	DrawAOETiles(AreaTiles);
	ReleaseAllPawns();
	Pres.m_kTacticalHUD.Movie.Stack.UnsubscribeFromOnInputForScreen(Pres.m_kTacticalHUD, OnTacticalHUDInput);
	super.Canceled();
}

function Committed()
{
	// Save selected tiles to be used later by the deployment effect
	class'XComGameState_DynamicDeployment'.static.SavePrecisionDropTiles_SubmitGameState(PrecisionDropUnitStates, PrecisionDropTiles);
	super.Committed();
}


private function ReleaseLastSpawnedPawn()
{
	local XComGameState_Unit	SpawnUnit;
	local XComEmitter			BeamEmitter;

	PrecisionDropPawns.Remove(iNumSpawnedUnits - 1, 1);

	SpawnUnit = PrecisionDropUnitStates[iNumSpawnedUnits - 1];
	PawnMgr.ReleaseCinematicPawn(FiringUnit, SpawnUnit.ObjectID, true);

	BeamEmitter = BeamEmitters[iNumSpawnedUnits - 1];
	BeamEmitter.Destroy();

	PrecisionDropTiles[iNumSpawnedUnits - 1].X = 0;
	PrecisionDropTiles[iNumSpawnedUnits - 1].Y = 0;
	PrecisionDropTiles[iNumSpawnedUnits - 1].Z = 0;
	
	iNumSpawnedUnits--;

	`AMLOG("Released pawn for:" @ SpawnUnit.GetFullName());
}

private function MoveLastSpawnedPawn(const vector MoveLocation)
{
	PrecisionDropPawns[iNumSpawnedUnits - 1].SetLocationNoCollisionCheck(MoveLocation);
	BeamEmitters[iNumSpawnedUnits - 1].SetLocation(MoveLocation);
}

private function ReleaseAllPawns()
{
	local XComGameState_Unit SpawnUnit;
	local XComEmitter BeamEmitter;

	foreach PrecisionDropUnitStates(SpawnUnit)
	{
		PawnMgr.ReleaseCinematicPawn(FiringUnit, SpawnUnit.ObjectID, true);
	}
	foreach BeamEmitters(BeamEmitter)
	{
		BeamEmitter.Destroy();
	}
}

// Icarus Jump


// Icarus Jump
function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	local TTile		SelectedTile;
	local vector	SelectedLocation;
	local name		AbilityAvailability;
	
	AbilityAvailability = super.ValidateTargetLocations(TargetLocations);
	if (AbilityAvailability == 'AA_Success')
	{
		// Only tiles with clearance to MaxZ are valid.
		SelectedLocation = TargetLocations[0];
		//if (!World.HasOverheadClearance(SelectedLocation, MaxZ))
		//{
		//	AbilityAvailability = 'AA_TileIsBlocked';
		//}
		
		// Only tiles within the bounds of designated area are valid.
		SelectedTile = World.GetTileCoordinatesFromPosition(SelectedLocation);
		if (class'Helpers'.static.FindTileInList(SelectedTile, AreaTiles) == INDEX_NONE)
		{
			AbilityAvailability = 'AA_TileIsBlocked';
		}

		// Only tiles that were not previously selected for other units are valid.
		if (class'Helpers'.static.FindTileInList(SelectedTile, PrecisionDropTiles) != INDEX_NONE)
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