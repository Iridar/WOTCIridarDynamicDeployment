class X2Effect_DynamicDeployment extends X2Effect config(DynamicDeployment);

var protected config array<name> AFTER_SPAWN_ACTION_POINTS;
var protected X2Condition_Visibility VisibilityCondition;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// TODO: Resolve reveal AI issue
// TODO: Replace matinee animations for soldiers
// TODO: Some skyranger intros appear to be broken (only with SPARKs-only DD?)
// TODO: SPARKs land feet halfway into the ground

simulated protected function OnEffectAdded(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState, XComGameState_Effect NewEffectState)
{
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local XComGameState_Unit				NewUnitState;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_DynamicDeployment	DDObject;
	local vector							SpawnLocation;
	local array<vector>						SpawnLocations;
	local int								iNumUnit;
	local XComGameState_Player				PlayerState;
	local X2EventManager					EventMgr;
	local XComGameState_Unit				CastingUnit;
	local XComGameStateHistory				History;

	`AMLOG("Running");

	CastingUnit = XComGameState_Unit(kNewTargetState);
	if (CastingUnit == none)
		return;

	History = `XCOMHISTORY;
	PlayerState = XComGameState_Player(NewGameState.GetGameStateForObjectID(CastingUnit.ControllingPlayer.ObjectID));
	if (PlayerState == none)
	{
		PlayerState = XComGameState_Player(History.GetGameStateForObjectID(CastingUnit.ControllingPlayer.ObjectID));
		PlayerState = XComGameState_Player(NewGameState.ModifyStateObject(PlayerState.Class, PlayerState.ObjectID));
	}
		
	// Put DD Soldier Select on cooldown.
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', `GETMCMVAR(DD_AFTER_DEPLOY_COOLDOWN), PlayerState.ObjectID, NewGameState);

	DDObject = XComGameState_DynamicDeployment(History.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none || !DDObject.bPendingDeployment)
		return;

	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
	UnitStates = DDObject.GetUnitsToDeploy();
	DDObject.bPendingDeployment = false; // Prevent SparkFall Deploy from being activated again.

	XComHQ = `XCOMHQ;
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));

	`AMLOG("Units to deploy:" @ UnitStates.Length);

	EventMgr = `XEVENTMGR;
	DDObject.GetSpawnLocations(ApplyEffectParameters.AbilityInputContext.TargetLocations[0], UnitStates, SpawnLocations);

	foreach UnitStates(UnitState, iNumUnit)
	{
		`AMLOG(iNumUnit @ "Deploying unit:" @ UnitState.GetFullName());

		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));

		SpawnLocation = SpawnLocations[iNumUnit];

		`AMLOG("SpawnLocation:" @ SpawnLocation);

		AddStrategyUnitToBoard(NewUnitState, NewGameState, SpawnLocation);

		NewUnitState.ActionPoints = default.AFTER_SPAWN_ACTION_POINTS;
		XComHQ.Squad.AddItem(NewUnitState.GetReference());

		if (class'Help'.static.IsCharTemplateSparkLike(NewUnitState.GetMyTemplate()))
		{
			if (!class'Help'.static.IsDDAbilityUnlocked(NewUnitState, 'IRI_DDUnlock_SparkRetainConcealment'))
			{
				EventMgr.TriggerEvent('EffectBreakUnitConcealment', NewUnitState, NewUnitState, NewGameState);
			}
		}
		else
		{
			// If unit has Phantom and is unseen during the landing, and the squad hasn't broken concealment yet, 
			// they will enter concealment.
			if (PlayerState.bSquadIsConcealed &&		
				VisibilityCondition.MeetsCondition(NewUnitState) == 'AA_Success' &&
				NewUnitState.HasAnyOfTheAbilitiesFromAnySource(class'X2AbilityTemplateManager'.default.AbilityProvidesStartOfMatchConcealment))
			{
				NewUnitState.EnterConcealmentNewGameState(NewGameState);
			}
		}
	
		EventMgr.TriggerEvent('ObjectMoved', NewUnitState, NewUnitState, NewGameState);
		EventMgr.TriggerEvent('UnitMoveFinished', NewUnitState, NewUnitState, NewGameState);
	}

	// If we spawned at least one unit
	if (NewUnitState != none)
	{
		//`AMLOG("Triggering Lightning Strike");
		//EventMgr.TriggerEvent('StartOfMatchConcealment', PlayerState, PlayerState, NewGameState);
	}

	EventMgr.TriggerEvent(class'Help'.default.DDEventName, PlayerState, PlayerState, NewGameState);

	// TODO: Make MCM configurable cooldown here
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', 3, PlayerState.ObjectID, NewGameState);
}


/*
static private function bool NoEnemySeesUnit(const out XComGameState_Unit UnitState)
{
	return default.VisibilityCondition.MeetsCondition(UnitState) == 'AA_Success';
}*/


//	Used in Step 5 to spawn the specified unit into tactical mission
static final protected function XComGameState_Unit AddStrategyUnitToBoard(XComGameState_Unit Unit, XComGameState NewGameState, Vector SpawnLocation)
{
	local XComGameStateHistory			History;
	local XComGameState_Player			PlayerState;
	local StateObjectReference			ItemReference;
	local XComGameState_Item			ItemState;
	local XComGameState_Unit			CosmeticUnit;
	local XComGameState_AIGroup			Group, PreviousGroupState;
	local TTile							CosmeticUnitTile;
	
	Unit.bSpawnedFromAvenger = true; //tell the game that the new unit is part of your squad so the mission wont just end if others retreat -LEB
	
	// assign the new unit to the human team -LEB
	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
	{
		if (PlayerState.GetTeam() == eTeam_XCom)
		{
			Unit.SetControllingPlayer(PlayerState.GetReference());
			break;
		}
	}
	//	set AI Group for the new unit so it can be controlled by the player properly
	Group = GetPlayerGroup();
	if (Unit != none && Group != none)
	{
		PreviousGroupState = Unit.GetGroupMembership(NewGameState);
		if (PreviousGroupState != none) 
		{
			PreviousGroupState = XComGameState_AIGroup(NewGameState.ModifyStateObject(PreviousGroupState.Class, PreviousGroupState.ObjectID));
			PreviousGroupState.RemoveUnitFromGroup(Unit.ObjectID, NewGameState);
		}

		Group = XComGameState_AIGroup(NewGameState.ModifyStateObject(Group.Class, Group.ObjectID));
		Group.AddUnitToGroup(Unit.ObjectID, NewGameState);
	}

	Unit.SetVisibilityLocationFromVector(SpawnLocation);

	// add item states. This needs to be done so that the visualizer sync picks up the IDs and creates their visualizers -LEB
	foreach Unit.InventoryItems(ItemReference)
	{
		ItemState = XComGameState_Item(NewGameState.ModifyStateObject(class'XComGameState_Item', ItemReference.ObjectID));
		ItemState.BeginTacticalPlay(NewGameState);   // this needs to be called explicitly since we're adding an existing state directly into tactical

		// add any cosmetic items that might exists
		ItemState.CreateCosmeticItemUnit(NewGameState);
		CosmeticUnit = XComGameState_Unit(NewGameState.GetGameStateForObjectID(ItemState.CosmeticUnitRef.ObjectID));
		if (CosmeticUnit != none)
		{
			CosmeticUnitTile = Unit.GetDesiredTileForAttachedCosmeticUnit();
			CosmeticUnitTile.Z += Unit.UnitHeight - 2;
			CosmeticUnit.SetVisibilityLocation(CosmeticUnitTile);
		}
	}

	// add abilities -LEB
	// Must happen after items are added, to do ammo merging properly. -LEB
	`TACTICALRULES.InitializeUnitAbilities(NewGameState, Unit);

	//	I assume this triggers the unit's abilities that activate at "UnitPostBeginPlay"
	Unit.BeginTacticalPlay(NewGameState); 

	return Unit;
}

static final protected function XComGameState_AIGroup GetPlayerGroup()
{
	local XComGameStateHistory History;
	local XComGameState_AIGroup AIGroupState;

	History = `XCOMHISTORY;
	foreach History.IterateByClassType(class'XComGameState_AIGroup', AIGroupState)
	{
		if (AIGroupState.TeamName == eTeam_XCom)
		{
			return AIGroupState;
		}
	}

	return none;
}


simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local XComGameStateContext_Ability		AbilityContext;
	local X2Action_ShowSpawnedUnit			ShowUnitAction;
	local X2Action_PlayAnimation			AnimationAction;
	local VisualizationActionMetadata		SpawnedUnitMetadata;
	local VisualizationActionMetadata		EmptyMetadata;
	local XComGameState_Unit				CosmeticUnit;
	local VisualizationActionMetadata		CosmeticUnitMetadata;
	local XComGameState_Item				ItemIterator;
	local X2Action_HideUIUnitFlag			HideUnitFlag;
	local X2Action_DeployGremlin			DeployGremlin;
	local TTile								GremlinTile;
	local X2Action_CameraLookAt				LookAtTargetAction;
	local X2Action_SelectNextActiveUnit		SelectUnitAction;
	local X2Action_StreamMap				StreamMap;
	local X2Action_DynamicDeployment		SkyrangerIntro;
	local XComGameState_DynamicDeployment	DDObject;
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_Unit				UnitState;
	local int								iNumUnit;
	local X2Action_TimedWait				WaitAction;
	local X2Action_TimedWait				GremlinWaitAction;
	local vector							SpawnLocation;
	local XComWorldData						World;
	local TTile								SpawnTile;
	local int								MaxZ;
	local bool								bAtLeastOneUnitIsSparkLike;
	local X2Action							CommonParent;
	local X2Action_UnstreamMap				UnstreamMap;
	local bool								bStreamedMaps;
	local bool								bUndergroundPlot;
	local X2Action_TimedWait				CameraArrive;

	World = `XWORLD;
	MaxZ = World.WORLD_FloorHeightsPerLevel * World.WORLD_TotalLevels * World.WORLD_FloorHeight;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none)
		return;

	UnitStates = DDObject.GetUnitsToDeploy(VisualizeGameState);
	if (UnitStates.Length == 0)
		return;

	foreach UnitStates(UnitState)
	{
		if (class'Help'.static.IsCharTemplateSparkLike(UnitState.GetMyTemplate()))
		{
			bAtLeastOneUnitIsSparkLike = true;
			break;
		}
	}

	`AMLOG("Got this many units to visualize:" @ UnitStates.Length);

	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	// Move camera to deployment location
	LookAtTargetAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, AbilityContext));
	LookAtTargetAction.LookAtLocation = AbilityContext.InputContext.TargetLocations[0];
	LookAtTargetAction.LookAtDuration = 2.0f + UnitStates.Length;

	CameraArrive = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, LookAtTargetAction));
	CameraArrive.DelayTimeSec = 1.5f;

	CommonParent = CameraArrive;

	bUndergroundPlot = class'Help'.static.IsUndergroundPlot();
	if (!bUndergroundPlot) // Play the "running off skyranger" matinee here
	{	
		bStreamedMaps = true;

		StreamMap = X2Action_StreamMap(class'X2Action_StreamMap'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, LookAtTargetAction));
		StreamMap.MapToStream = "DDCIN_SkyrangerIntros";
		StreamMap.MapLocation = AbilityContext.InputContext.TargetLocations[0];

		if (bAtLeastOneUnitIsSparkLike)
		{
			StreamMap = X2Action_StreamMap(class'X2Action_StreamMap'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, LookAtTargetAction));
			StreamMap.MapToStream = "DDCIN_SkyrangerIntros_Spark";
			StreamMap.MapLocation = AbilityContext.InputContext.TargetLocations[0];
		}
		
		// Begin playing once camera arrives
		SkyrangerIntro = X2Action_DynamicDeployment(class'X2Action_DynamicDeployment'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, CameraArrive));
		SkyrangerIntro.UnitStates = UnitStates;

		CommonParent = SkyrangerIntro;
	}


	foreach UnitStates(UnitState, iNumUnit)
	{
		`AMLOG("Visualizing unit spawn:" @ UnitState.GetFullName());

		SpawnedUnitMetadata = EmptyMetadata;
		SpawnedUnitMetadata.StateObject_OldState = UnitState;
		SpawnedUnitMetadata.StateObject_NewState = UnitState;

		SpawnTile = UnitState.TileLocation;
		SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);

		//	insert a random time delay for each unit spawn so they don't all drop down at exactly the same time
		WaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, CommonParent));
		WaitAction.DelayTimeSec = iNumUnit + FRand();

		// Normally, Show Unit -> Play Animation makes the unit appear for split second at the spawn location, and then DD animation plays.
		// Stroke of genius: show the unit at the ceiling, and use DesiredEndingAtoms to rubberband the unit into the intended spot.
		ShowUnitAction = X2Action_ShowSpawnedUnit(class'X2Action_ShowSpawnedUnit'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		ShowUnitAction.ChangeTimeoutLength(10.0f);
		ShowUnitAction.bUseOverride = true;
		ShowUnitAction.OverrideVisualizationLocation = SpawnLocation;
		ShowUnitAction.OverrideVisualizationLocation.Z = MaxZ;

		// Hide the unit flag while the DD animation is playing.
		HideUnitFlag = X2Action_HideUIUnitFlag(class'X2Action_HideUIUnitFlag'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		HideUnitFlag.bHideUIUnitFlag = true;
		
		AnimationAction = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));

		if (class'Help'.static.IsCharTemplateSparkLike(UnitState.GetMyTemplate()))
		{
			if (class'Help'.static.IsDDAbilityUnlocked(UnitState, 'IRI_DDUnlock_SparkRetainConcealment'))
			{
				AnimationAction.Params.AnimName = 'HL_DynamicDeploymentSilent';
			}
			else
			{
				AnimationAction.Params.AnimName = 'HL_DynamicDeployment';
			}
		}
		else
		{
			if (bUndergroundPlot)
			{
				AnimationAction.Params.AnimName = 'HL_DynamicDeployment_Underground';
			}
			else
			{
				AnimationAction.Params.AnimName = 'HL_DynamicDeployment';
			}
		}
		

		AnimationAction.Params.BlendTime = 0.0f;

		// Apparently this isn't neccessary and it only makes SPARKs land halfway into the ground.
		//AnimationAction.Params.DesiredEndingAtoms.Add(1);
		//AnimationAction.Params.DesiredEndingAtoms[0].Scale = 1.0f;
		//AnimationAction.Params.DesiredEndingAtoms[0].Translation = SpawnLocation;

		HideUnitFlag = X2Action_HideUIUnitFlag(class'X2Action_HideUIUnitFlag'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		HideUnitFlag.bHideUIUnitFlag = false;

		if (iNumUnit == 0 && UnitState.ActionPoints.Length > 0)
		{
			SelectUnitAction = X2Action_SelectNextActiveUnit(class'X2Action_SelectNextActiveUnit'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
			SelectUnitAction.TargetID = UnitState.ObjectID;
		}
		
		// Deploy unit's Gremlin/Bit, if any.
		CosmeticUnit = none;
		foreach VisualizeGameState.IterateByClassType(class'XComGameState_Item', ItemIterator)
		{
			if (UnitState.ObjectID == ItemIterator.AttachedUnitRef.ObjectID && ItemIterator.CosmeticUnitRef.ObjectID > 0)
			{
				CosmeticUnit = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(ItemIterator.CosmeticUnitRef.ObjectID));
				if (CosmeticUnit != none)
				{
					break;
				}
			}
		}
		if (CosmeticUnit == none)
			continue;

		CosmeticUnitMetadata = EmptyMetadata;
		CosmeticUnitMetadata.StateObject_OldState = CosmeticUnit;
		CosmeticUnitMetadata.StateObject_NewState = CosmeticUnit;
		
		// Add a 0.5-1.0 sec delay before spawning the gremlin so it doesn't clip through the deploying unit
		GremlinWaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, WaitAction));
		GremlinWaitAction.DelayTimeSec = 0.5f + FRand() / 2.0f;
		
		ShowUnitAction = X2Action_ShowSpawnedUnit(class'X2Action_ShowSpawnedUnit'.static.AddToVisualizationTree(CosmeticUnitMetadata, AbilityContext, false, GremlinWaitAction));
		ShowUnitAction.ChangeTimeoutLength(10.0f);
		ShowUnitAction.bUseOverride = true;
		ShowUnitAction.OverrideVisualizationLocation = SpawnLocation;
		ShowUnitAction.OverrideVisualizationLocation.Z = MaxZ;

		GremlinTile = UnitState.GetDesiredTileForAttachedCosmeticUnit();
		GremlinTile.Z += UnitState.UnitHeight - 2;

		DeployGremlin = X2Action_DeployGremlin(class'X2Action_DeployGremlin'.static.AddToVisualizationTree(CosmeticUnitMetadata, VisualizeGameState.GetContext(), false, ShowUnitAction));
		DeployGremlin.MoveLocation = World.GetPositionFromTileCoordinates(GremlinTile);
	}

	if (bStreamedMaps)
	{
		UnstreamMap = X2Action_UnstreamMap(class'X2Action_UnstreamMap'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		UnstreamMap.MapToUnstream = "DDCIN_SkyrangerIntros";

		if (bAtLeastOneUnitIsSparkLike)
		{
			UnstreamMap = X2Action_UnstreamMap(class'X2Action_UnstreamMap'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
			UnstreamMap.MapToUnstream = "DDCIN_SkyrangerIntros_Spark";
		}

		
	}
}


defaultproperties
{
    Begin Object Class=X2Condition_Visibility Name=DefaultVisibilityCondition
        bNoEnemyViewers = true
    End Object
    VisibilityCondition = DefaultVisibilityCondition;
}