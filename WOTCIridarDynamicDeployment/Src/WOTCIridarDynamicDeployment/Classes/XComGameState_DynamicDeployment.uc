class XComGameState_DynamicDeployment extends XComGameState_BaseObject;

struct PrecisionDropTileStorageStruct
{
	var int		UnitObjectID;
	var TTile	DropTile;
};

var private array<int> SelectedUnitIDs;	// Holds the ID of the unit selected for deployment.
var bool bPendingDeployment;	// If true, a unit was selected for deployment, but was not deployed yet.	

var privatewrite array<PrecisionDropTileStorageStruct> PrecisionDropTileStorages;

final function bool IsUnitSelected(const int UnitObjectID)
{
	return SelectedUnitIDs.Find(UnitObjectID) != INDEX_NONE;
}

final function ToggleUnitSelection(const int UnitObjectID)
{
	// If we've already deployed units previously, clear the list so we're not offered to deploy the same units again.
	if (!bPendingDeployment)
	{
		SelectedUnitIDs.Length = 0;
		PrecisionDropTileStorages.Length = 0;
	}
	if (IsUnitSelected(UnitObjectID))
	{
		SelectedUnitIDs.RemoveItem(UnitObjectID);
	}
	else
	{
		SelectedUnitIDs.AddItem(UnitObjectID);
	}

	if (IsAnyUnitSelected())
	{
		bPendingDeployment = true;
	}
	else
	{
		bPendingDeployment = false;
	}
}

final function bool IsAnyUnitSelected()
{
	return SelectedUnitIDs.Length > 0;
}

final function DeselectAllUnits()
{
	SelectedUnitIDs.Length = 0;
	PrecisionDropTileStorages.Length = 0;
	bPendingDeployment = false;
}

final function int GetNumSelectedUnits()
{
	return SelectedUnitIDs.Length;
}

final function int GetDeployDelay()
{
	local array<XComGameState_Unit> UnitStates;
	local XComGameState_Unit		UnitState;
	local int						iDelay;

	UnitStates = GetUnitsToDeploy();
	foreach UnitStates(UnitState)
	{
		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, 'IRI_DDUnlock_FastDrop'))
		{
			continue;
		}
		iDelay++;
	}
	return iDelay;
}

// Not sure this even does anything though
final function PreloadAssets()
{
	local int SelectedUnitID;
	
	foreach SelectedUnitIDs(SelectedUnitID)
	{
		PreloadAssetsForUnit(SelectedUnitID);
	}
}


static private function PreloadAssetsForUnit(const int UnitObjectID)
{
	local XComGameState_Unit			SpawnUnit;
	local array<string>					Resources;
	local string						Resource;
	local XComContentManager			Content;
	local StateObjectReference			ItemReference;
	local XComGameState_Item			ItemState;
	local XComGameStateHistory			History;
	local X2CharacterTemplate			CharTemplate;
	local string						MapName;

	History = `XCOMHISTORY;
	SpawnUnit = XComGameState_Unit(History.GetGameStateForObjectID(UnitObjectID));
	if (SpawnUnit == none)
		return;

	Content = `CONTENT;

	SpawnUnit.RequestResources(Resources);
	foreach Resources(Resource)
	{
		Content.RequestGameArchetype(Resource,,, true);
	}

	foreach SpawnUnit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(History.GetGameStateForObjectID(ItemReference.ObjectID));
		ItemState.RequestResources(Resources);

		foreach Resources(Resource)
		{
			Content.RequestGameArchetype(Resource,,, true);
		}
	}

	CharTemplate = SpawnUnit.GetMyTemplate();
	if (CharTemplate != none)
	{
		foreach CharTemplate.strMatineePackages(MapName)
		{
			`MAPS.AddStreamingMap(MapName).bForceNoDupe = true;
		}
	}	
}

final function array<XComGameState_Unit> GetUnitsToDeploy(optional XComGameState UseGameState)
{
	local array<XComGameState_Unit>	UnitStates;
	local XComGameState_Unit		UnitState;
	local XComGameStateHistory		History;
	local int						SelectedUnitID;

	History = `XCOMHISTORY;

	foreach SelectedUnitIDs(SelectedUnitID)
	{
		if (UseGameState != none)
		{
			UnitState = XComGameState_Unit(UseGameState.GetGameStateForObjectID(SelectedUnitID));
		}
		else
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SelectedUnitID));
		}
		
		if (UnitState != none)
		{
			UnitStates.AddItem(UnitState);
		}
	}

	return UnitStates;
}

final function array<XComGameState_Unit> GetPrecisionDropUnits()
{
	local array<XComGameState_Unit>	UnitStates;
	local array<XComGameState_Unit> PrecisionDropUnits;
	local XComGameState_Unit		UnitState;

	UnitStates = GetUnitsToDeploy();

	foreach UnitStates(UnitState)
	{
		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, 'IRI_DDUnlock_PrecisionDrop'))
		{
			PrecisionDropUnits.AddItem(UnitState);
		}
	}
	return PrecisionDropUnits;
}

static final function IsUnitPrecisionDrop(const XComGameState_Unit UnitState)
{
}

static final function SavePrecisionDropTiles_SubmitGameState(const out array<XComGameState_Unit> PrecisionDropUnits, const out array<TTile> NewTiles)
{
	local XComGameState						NewGameState;
	local XComGameState_DynamicDeployment	DDObject;
	local PrecisionDropTileStorageStruct	PrecisionDropTileStorage;
	local XComGameState_Unit				PrecisionDropUnit;
	local int								Index;

	DDObject = GetOrCreate();
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("SavePrecisionDropTiles:" @ NewTiles.Length);
	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));

	foreach PrecisionDropUnits(PrecisionDropUnit, Index)
	{
		PrecisionDropTileStorage.UnitObjectID = PrecisionDropUnit.ObjectID;
		PrecisionDropTileStorage.DropTile = NewTiles[Index];
		DDObject.PrecisionDropTileStorages.AddItem(PrecisionDropTileStorage);
	}

	`GAMERULES.SubmitGameState(NewGameState);
}


final function GetSpawnLocations(const vector DesiredLocation, const out array<XComGameState_Unit> DeployingUnits, out array<vector> SpawnLocations)
{
	local array<TTile>	TilePossibilities;
	local array<TTile>	TilePossibilitiesClearedMaxZ;
	local vector		SpawnLocation;
	local TTile			SpawnTile;
	local XComWorldData	World;
	local int			MaxZ;
	local int			Width;
	local float			NumUnitsDeploying;
	local XComGameState_Unit DeployingUnit;
	local int			Index;
	local PrecisionDropTileStorageStruct PrecisionDropTileStorage;

	`AMLOG("Desired location:" @ DesiredLocation);

	World = `XWORLD;
	MaxZ = World.WORLD_FloorHeightsPerLevel * World.WORLD_TotalLevels * World.WORLD_FloorHeight;
	SpawnLocation = DesiredLocation;
	SpawnTile = World.GetTileCoordinatesFromPosition(SpawnLocation);
	NumUnitsDeploying = DeployingUnits.Length;
	Width = Max(5, FCeil(Sqrt(NumUnitsDeploying))); // TODO: Replace 5 with configured value
	SpawnTile.X -= FFloor(float(Width) / 2.0f); // GetSpawnTilePossibilities treats the given tile as upper left corner, not as center. Apply offset equal to half width.
	SpawnTile.Y -= FFloor(float(Width) / 2.0f);

	`AMLOG(`ShowVar(NumUnitsDeploying) @ "Calculated width:" @ FCeil(Sqrt(NumUnitsDeploying)) @ "Final width:" @ Width);

	World.GetSpawnTilePossibilities(SpawnTile, Width, Width, 1, TilePossibilities);
	`AMLOG("Got this many tile possibilities:" @ TilePossibilities.Length);
	foreach TilePossibilities(SpawnTile)
	{
		SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);
		if (World.HasOverheadClearance(SpawnLocation, MaxZ))
		{
			TilePossibilitiesClearedMaxZ.AddItem(SpawnTile);
		}
	}
	TilePossibilities = TilePossibilitiesClearedMaxZ;
	TilePossibilities.RandomizeOrder();

	foreach DeployingUnits(DeployingUnit)
	{
		Index = PrecisionDropTileStorages.Find('UnitObjectID', DeployingUnit.ObjectID);
		if (Index != INDEX_NONE)
		{
			PrecisionDropTileStorage = PrecisionDropTileStorages[Index];
			SpawnTile = PrecisionDropTileStorage.DropTile;
			SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);
			SpawnLocations.AddItem(SpawnLocation);
			TilePossibilities.RemoveItem(SpawnTile);
		}
		else if (TilePossibilities.Length > 0)
		{
			SpawnTile = TilePossibilities[0];
			TilePossibilities.Remove(0, 1);
			SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);
			SpawnLocations.AddItem(SpawnLocation);
		}
		else
		{
			`AMLOG("WARNING :: Ran out of Tile Possibilities!");
		}
	}

	`AMLOG("Got this many spawn locations:" @ SpawnLocations.Length);

	// Failsafe
	while (SpawnLocations.Length < NumUnitsDeploying)
	{
		SpawnLocations.AddItem(DesiredLocation);
	}
}

static final function XComGameState_DynamicDeployment GetOrCreate()
{
	local XComGameState_DynamicDeployment	DDObject;
	local XComGameState						NewGameState;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment', true));
	if (DDObject != none)
		return DDObject;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Creating Dynamic Deployment Object");
	DDObject = XComGameState_DynamicDeployment(NewGameState.CreateNewStateObject(class'XComGameState_DynamicDeployment'));
	`GAMERULES.SubmitGameState(NewGameState);

	return DDObject;
}


final function GetUnitStatesEligibleForDynamicDeployment(out array<XComGameState_Unit> EligbleUnits)
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameStateHistory				History;
	local StateObjectReference				UnitReference;
	local XComGameState_Unit				UnitState;
	
	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));

	foreach XComHQ.Crew(UnitReference)
	{
		//if (IsUnitSelected(UnitReference.ObjectID))
		//	continue;

		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitReference.ObjectID));

		if (UnitState == none || !class'Help'.static.IsUnitEligibleForDynamicDeployment(UnitState)) continue;

		//	If we're still in the cycle then this unit has passed all checks and is eligible to be spawned
		EligbleUnits.AddItem(UnitState);
	}
}

final function bool CanSelectMoreSoldiers()
{
	local XComGameState_MissionSite			MissionState;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameStateHistory				History;
	local int CurrentSquadSize;
	local int i;

	//if (`GETMCMVAR(ALLOW_SPARKFALL_AT_FULL_SQUAD))
	//{
	//	return true;
	//}
	
	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	MissionState = XComGameState_MissionSite(History.GetGameStateForObjectID(XComHQ.MissionRef.ObjectID));

	CurrentSquadSize = 0;
	for (i=0; i < XComHQ.Squad.Length; i++)
	{
		if (XComHQ.Squad[i].ObjectID != 0) CurrentSquadSize++;
	}
	return CurrentSquadSize + SelectedUnitIDs.Length < class'X2StrategyGameRulesetDataStructures'.static.GetMaxSoldiersAllowedOnMission(MissionState);
}

DefaultProperties
{
	// Nuke this state object during tactical -> strategy transition.
	bTacticalTransient = true

	bSingletonStateType = true
}