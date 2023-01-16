class X2TargetingMethod_DynamicDeployment extends X2TargetingMethod_VoidRift;

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
		return;

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

// Hijack right click and other "cancel targeting" keys to use our own staged cancel function instead,
// which cancels targeting only when there are no more units to remove.
// Otherwise it will remove the last added unit.
simulated protected function bool OnTacticalHUDInput(UIScreen Screen, int iInput, int ActionMask)
{
	`AMLOG("Running:" @ `ShowVar(iInput) @ `ShowVar(ActionMask));

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
			//CheckForFriendlyUnit(CurrentlyMarkedTargets);	
			//MarkTargetedActors(CurrentlyMarkedTargets, (!AbilityIsOffensive) ? FiringUnit.GetTeam() : eTeam_None );
			DrawAOETiles(AreaTiles);
		}
		else
		{
			// Move the pawn with the cursor, but keep it within bounds of the selected tile area
			SelectedTile = World.GetTileCoordinatesFromPosition(NewTargetLocation);
			if (class'Helpers'.static.FindTileInList(SelectedTile, AreaTiles) != INDEX_NONE)
			{
				PrecisionDropTiles[iNumSpawnedUnits - 1] = SelectedTile;
				NewTargetLocation.Z += World.WORLD_FloorHeight;
				MoveLastSpawnedPawn(NewTargetLocation);
			}
		}
	}
	//DrawSplashRadius( );

	super(X2TargetingMethod).Update(DeltaTime);
}


function bool VerifyTargetableFromIndividualMethod(delegate<ConfirmAbilityCallback> fnCallback)
{
	`AMLOG("Running. iNumSpawnedUnits:" @ iNumSpawnedUnits);

	if (!bAreaLocked)
	{
		`AMLOG("No pawns yet, area is unlocked. Locking.");
		bAreaLocked = true;
	}

	if (iNumSpawnedUnits < PrecisionDropUnitStates.Length)
	{
		`AMLOG("Area locked, spawning new pawn");
		SpawnPawnForUnit(PrecisionDropUnitStates[iNumSpawnedUnits], CachedTargetLocation);
		return false;
	}

	`AMLOG("All pawns are spawned, final commit.");
	return true;
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
function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	local name AbilityAvailability;
	local int MaxZ;
	
	AbilityAvailability = super.ValidateTargetLocations(TargetLocations);
	if (AbilityAvailability == 'AA_Success')
	{
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