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

// If an evac zone exists, targeting is force locked to it.

//var private X2Actor_InvalidTarget InvalidTileActor;
//var private XComActionIconManager IconManager;

var private UIPawnMgr						PawnMgr;
var private XComWorldData					World;
var private MaterialInstanceTimeVarying		HoloMITV;
var private MaterialInstanceTimeVarying		YeloMITV;
var private ParticleSystem					BeamEmitterPS;
var private int								iNumSpawnedUnits;
var privatewrite bool						bAreaLocked;
var private bool							bFinalClickReady;
var private vector							LockedAreaLocation;
var private XComPresentationLayer			Pres;
var private array<TTile>					AreaTiles;
var private int								MaxZ;

//var private XComGameState_EvacZone			EvacZone;
var private X2Camera_LookAtLocation			LookatCamera;

// Parallel arrays
var private array<XComGameState_Unit>		PrecisionDropUnitStates;
var private array<XComUnitPawn>				PrecisionDropPawns;
var private array<TTile>					PrecisionDropTiles;
var private transient array<XComEmitter>	BeamEmitters;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

function Init(AvailableAction InAction, int NewTargetIndex)
{
	local XComGameState_DynamicDeployment	DDObject;
	local XComContentManager				ContentMgr;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none || !DDObject.bPendingDeployment)
	{
		super.Init(InAction, NewTargetIndex);
		return;
	}

	World = `XWORLD;

	//EvacZone = class'XComGameState_EvacZone'.static.GetEvacZone();
	//if (EvacZone != none)
	//{
	//	LookatCamera = new class'X2Camera_LookAtLocation';
	//	LookatCamera.UseTether = false;
	//	LookatCamera.LookAtLocation = World.GetPositionFromTileCoordinates(EvacZone.CenterLocation);
	//	`CAMERASTACK.AddCamera(LookatCamera);
	//
	//	bRestrictToSquadsightRange = false;
	//}

	
	MaxZ = World.WORLD_FloorHeightsPerLevel * World.WORLD_TotalLevels * World.WORLD_FloorHeight;

	PrecisionDropUnitStates = DDObject.GetPrecisionDropUnits();
	if (PrecisionDropUnitStates.Length > 0)
	{
		PrecisionDropTiles.Length = PrecisionDropUnitStates.Length;
		PawnMgr = `PRESBASE.GetUIPawnMgr();
		ContentMgr = `CONTENT;
		HoloMITV = MaterialInstanceTimeVarying(ContentMgr.RequestGameArchetype("FX_Mimic_Beacon_Hologram.M_Mimic_Activate_MITV"));
		YeloMITV = MaterialInstanceTimeVarying(ContentMgr.RequestGameArchetype("IRIDynamicDeployment.Materials.PlacingTarget_MITV"));
		BeamEmitterPS = ParticleSystem(ContentMgr.RequestGameArchetype("IRIDynamicDeployment.PS_BeamEmitter"));

		`AMLOG("Got this many unit states:" @ PrecisionDropUnitStates.Length @ "HoloMITV loaded:" @ HoloMITV != none @ "BeamEmitterPS loaded:" @ BeamEmitterPS != none);
		Pres = `PRES;
		Pres.m_kTacticalHUD.Movie.Stack.SubscribeToOnInputForScreen(Pres.m_kTacticalHUD, OnTacticalHUDInput);
	}

	super.Init(InAction, NewTargetIndex);
}

// #1. This runs first
function GetTargetLocations(out array<Vector> TargetLocations)
{
	TargetLocations.Length = 0;
	if (bFinalClickReady)
	{
		TargetLocations.AddItem(LockedAreaLocation);
		return;
	}
	TargetLocations.AddItem(GetSplashRadiusCenter());
}

// #2. Then this
function name ValidateTargetLocations(const array<Vector> TargetLocations)
{
	local TTile		SelectedTile;
	local vector	SelectedLocation;
	local name		AbilityAvailability;

	if (bFinalClickReady)
		return 'AA_Success';
	
	AbilityAvailability = super.ValidateTargetLocations(TargetLocations);
	if (AbilityAvailability == 'AA_Success')
	{
		// Only tiles with clearance to MaxZ are valid.
		SelectedLocation = TargetLocations[0];
		if (!World.HasOverheadClearance(SelectedLocation, MaxZ))
		{
			AbilityAvailability = 'AA_TileIsBlocked';
		}
		
		if (bAreaLocked) // If area is locked, then it means we're clicking to place a pawn.
		{
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
	}
	return AbilityAvailability;
}

// #3. Finally this
// Hijack left click or other ways to confirm ability activation if there are any precision drop units.
// Consecutive clicks will lock the location of the last spawned pawn, and spawn a new one,
// if there are any remaining.
function bool VerifyTargetableFromIndividualMethod(delegate<ConfirmAbilityCallback> fnCallback)
{
	if (PrecisionDropUnitStates.Length == 0)
		return true;

	if (bFinalClickReady)
		return true;

	// First click locks the targeted area.
	if (!bAreaLocked)
	{
		// And spawns a pawn that will move with the cursor.
		SpawnPawnForUnit(PrecisionDropUnitStates[iNumSpawnedUnits], CachedTargetLocation);
		LockedAreaLocation = CachedTargetLocation;
		Cursor.m_fMaxChainedDistance *= 2;	// Double the Cursor's targeting range so that when the center of the area is at max throw range 
											// you can still designate precision drop tiles at range further than throw range
		bAreaLocked = true;
		return false;
	}

	// Following clicks will lock the last spawned pawn
	if (iNumSpawnedUnits > 0)
	{
		LockLastSpawnedPawn();
	}
	
	// Then see if we need to spawn more units.
	if (iNumSpawnedUnits < PrecisionDropUnitStates.Length)
	{
		SpawnNextPawn();
		return false;
	}

	`AMLOG("All pawns are spawned, final commit.");

	// Save selected tiles to be used later by the deployment effect
	class'XComGameState_DynamicDeployment'.static.SavePrecisionDropTiles_SubmitGameState(PrecisionDropUnitStates, PrecisionDropTiles);

	bFinalClickReady = true;

	return false;
}

private function LockLastSpawnedPawn()
{
	local vector SpawnLocation;
	local TTile	 SpawnTile;
	local XComUnitPawn LastPawn;
	local XComEmitter BeamEmitter;

	LastPawn = PrecisionDropPawns[iNumSpawnedUnits - 1];
	LastPawn.CleanUpMITV();
	LastPawn.ApplyMITV(HoloMITV);

	// Activate the beam for this pawn.
	BeamEmitter = BeamEmitters[iNumSpawnedUnits - 1];
	BeamEmitter.ParticleSystemComponent.ActivateSystem();	

	SpawnLocation = LastPawn.Location;
	SpawnLocation.Z -= World.WORLD_FloorHeight;
	SpawnTile = World.GetTileCoordinatesFromPosition(SpawnLocation);
	PrecisionDropTiles[iNumSpawnedUnits - 1] = SpawnTile;
}

private function SpawnNextPawn()
{
	local vector	SpawnLocation;
	local TTile		SpawnTile;

	`AMLOG("Area locked, spawning new pawn");
	SpawnTile = World.GetTileCoordinatesFromPosition(CachedTargetLocation);
	SpawnTile = FindClosestTileInArea(SpawnTile);
	SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);
	SpawnPawnForUnit(PrecisionDropUnitStates[iNumSpawnedUnits], SpawnLocation);
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
	UnitPawn.ApplyMITV(YeloMITV);
	
	UnitPawn.HQIdleAnim = "NO_IdleGunUp";
	UnitPawn.GotoState('Onscreen');			// This will play HQIdleAnim
	UnitPawn.Mesh.GlobalAnimRateScale = 0;	// Freeze the pawn at the first frame of the animation.
	PrecisionDropPawns.AddItem(UnitPawn);
	
	// For the sake of simplicity, the number of pawns and beams is always the same
	BeamEmitter = `BATTLE.spawn(class'XComEmitter');
	BeamEmitter.SetTemplate(BeamEmitterPS);
	BeamEmitter.LifeSpan = 60 * 60 * 24 * 7; // never die (or at least take a week to do so)
	BeamEmitter.SetDrawScale(1);
	BeamEmitter.SetRotation( rot(0,0,1) );
	BeamEmitter.ParticleSystemComponent.DeactivateSystem(); // But the beam is deactivated after creation, so it's not visible initially.
	BeamEmitters.AddItem(BeamEmitter);

	iNumSpawnedUnits++;
}

private function ReleaseLastSpawnedPawn()
{
	local XComGameState_Unit	SpawnUnit;
	local XComEmitter			BeamEmitter;

	if (iNumSpawnedUnits > 0)
	{
		PrecisionDropPawns.Remove(iNumSpawnedUnits - 1, 1);

		SpawnUnit = PrecisionDropUnitStates[iNumSpawnedUnits - 1];
		PawnMgr.ReleaseCinematicPawn(FiringUnit, SpawnUnit.ObjectID, true);

		BeamEmitter = BeamEmitters[iNumSpawnedUnits - 1];
		BeamEmitters.Remove(iNumSpawnedUnits - 1, 1);
		BeamEmitter.Destroy();

		PrecisionDropTiles[iNumSpawnedUnits - 1].X = 0;
		PrecisionDropTiles[iNumSpawnedUnits - 1].Y = 0;
		PrecisionDropTiles[iNumSpawnedUnits - 1].Z = 0;
	
		iNumSpawnedUnits--;

		`AMLOG("Released pawn for:" @ SpawnUnit.GetFullName());
	}
}

// Hijack right click and other "cancel targeting" keys to use our own staged cancel function instead,
// which removes the last placed precision drop pawn.
// When there are no more pawns, the targeting area is unlocked and can be moved.
// If it's alreay unlocked, the normal logic is allowed to take place, cancelling the targeting.
simulated protected function bool OnTacticalHUDInput(UIScreen Screen, int iInput, int ActionMask)
{
    if (!Screen.CheckInputIsReleaseOrDirectionRepeat(iInput, ActionMask))
    {
        return false;
    }

    switch (iInput)
    {
	case class'UIUtilities_Input'.const.FXS_R_MOUSE_DOWN:
	case class'UIUtilities_Input'.const.FXS_KEY_ESCAPE:
	
	// washing_hands.jpg
    case class'UIUtilities_Input'.static.GetBackButtonInputCode():
	case class'UIUtilities_Input'.const.FXS_BUTTON_START:
	case class'UIUtilities_Input'.const.FXS_BUTTON_B:
	case class'UIUtilities_Input'.const.FXS_BUTTON_RTRIGGER:
        return StagedCancel();
        break;
    }

    return false;
}
// Returns true if we handled the right click and there's no need to kill the targeting method yet.
private function bool StagedCancel()
{
	`AMLOG("Running. iNumSpawnedUnits:" @ iNumSpawnedUnits);

	bFinalClickReady = false;

	if (iNumSpawnedUnits > 1)
	{
		ReleaseLastSpawnedPawn();	// This will nuke the pawn the player is currently placing
		ReleaseLastSpawnedPawn();	// This will nuke the pawn whose position was locked previously
		SpawnNextPawn();			// This will respawn the last nuked pawn.
		return true;
	}
	else if (iNumSpawnedUnits == 1)
	{
		ReleaseLastSpawnedPawn();
		return true; // after deleting the last pawn you still have to cancel one additional time to unlock the area.
	}
	
	if (bAreaLocked)
	{
		`AMLOG("There are no pawns left, unlocking area");
		PrecisionDropTiles.Length = 0; // Reset tile array so that we don't trip on it when placing pawns in a newly locked area later.
		PrecisionDropTiles.Length = PrecisionDropUnitStates.Length;
		if (UseGrenadePath())
		{
			GrenadePath.bUseOverrideTargetLocation = false;
		}
		Cursor.m_fMaxChainedDistance /= 2;
		bAreaLocked = false;
		return true;
	}

	`AMLOG("There are no pawns left, area unlocked, final cancel.");
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
			GetTargetedActors(NewTargetLocation, CurrentlyMarkedTargets, AreaTiles); // This fills the AreaTiles, presumably
			ValidateAreaTiles();
			//CheckForFriendlyUnit(CurrentlyMarkedTargets);	
			//MarkTargetedActors(CurrentlyMarkedTargets, (!AbilityIsOffensive) ? FiringUnit.GetTeam() : eTeam_None );
			DrawAOETiles(AreaTiles);
		}
		else if (!bFinalClickReady)
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

	if (bAreaLocked && UseGrenadePath())
	{
		UpdateGrenadePath();
	}
}

private function UpdateGrenadePath()
{	
	GrenadePath.bUseOverrideTargetLocation = true;
	GrenadePath.OverrideTargetLocation = LockedAreaLocation;
}

private function MoveLastSpawnedPawn(const vector MoveLocation)
{
	PrecisionDropPawns[iNumSpawnedUnits - 1].SetLocationNoCollisionCheck(MoveLocation);
	BeamEmitters[iNumSpawnedUnits - 1].SetLocation(MoveLocation);
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
	local vector TestLocation;
	
	TestLocation = World.GetPositionFromTileCoordinates(TestTile);
	if (!World.HasOverheadClearance(TestLocation, MaxZ))
	{
		return false;
	}

	if (!World.IsFloorTileAndValidDestination(TestTile))
	{
		return false;
	}

	if (!World.CanUnitsEnterTile(TestTile))
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


// Called by Comitted() too.
function Canceled()
{
	AreaTiles.Length = 0;
	DrawAOETiles(AreaTiles);
	ReleaseAllPawns(); // In case some hotkey isn't caught by StagedCancel(), such as switching to another ability or something.
	if (Pres != none)
	{
		Pres.m_kTacticalHUD.Movie.Stack.UnsubscribeFromOnInputForScreen(Pres.m_kTacticalHUD, OnTacticalHUDInput);
	}
	if (LookatCamera != none)
	{
		`CAMERASTACK.RemoveCamera(LookatCamera);
	}
	super.Canceled();
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

// Grenade targeting

//static function bool UseGrenadePath() { return class'XComGameState_EvacZone'.static.GetEvacZone() == none; }
static function bool UseGrenadePath() { return true; }

function GetGrenadeWeaponInfo(out XComWeapon WeaponEntity, out PrecomputedPathData WeaponPrecomputedPathData)
{
	local array<XComPerkContent> Perks;
	local int i;
	local XComWeapon Weapon;

	class'XComPerkContent'.static.GetAssociatedPerkDefinitions(Perks, FiringUnit.GetPawn(), Ability.GetMyTemplateName());

	for (i = 0; i < Perks.Length; ++i)
	{
		Weapon = Perks[i].PerkSpecificWeapon;
		if (Weapon != none)
		{
			WeaponEntity = FiringUnit.GetPawn().Spawn(class'XComWeapon', FiringUnit.GetPawn(), , , , Weapon);
			//WeaponEntity.Mesh.SetHidden(false);
			`AMLOG("Spawning perk weapon:" @ PathName(WeaponEntity));
			break;
		}
	}	
	if (WeaponEntity == none)
	{
		`RedScreen("Unable to find a perk weapon for" @ Ability.GetMyTemplateName());
	}

	// WeaponPrecomputedPathData kept to default values, common for all grenades.
}

simulated protected function Vector GetSplashRadiusCenter( bool SkipTileSnap = false )
{
	local vector Center;
	local TTile SnapTile;

	//if (EvacZone != none)
	//{
	//	return World.GetPositionFromTileCoordinates(EvacZone.CenterLocation);
	//}

	if (UseGrenadePath() && !bAreaLocked)
	{
		Center = GrenadePath.GetEndPosition();
	}
	else
	{
		Center = Cursor.GetCursorFeetLocation();
	}

	if (SnapToTile && !SkipTileSnap)
	{
		SnapTile = `XWORLD.GetTileCoordinatesFromPosition( Center );
		
		// keep moving down until we find a floor tile.
		while ((SnapTile.Z >= 0) && !`XWORLD.GetFloorPositionForTile( SnapTile, Center ))
		{
			--SnapTile.Z;
		}
	}

	return Center;
}
