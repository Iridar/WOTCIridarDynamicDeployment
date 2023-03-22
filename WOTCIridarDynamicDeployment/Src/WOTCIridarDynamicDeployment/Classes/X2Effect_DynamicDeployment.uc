class X2Effect_DynamicDeployment extends X2Effect_Persistent config(DynamicDeployment);

var private config array<name> OVERRIDE_AFTER_SPAWN_ACTION_POINTS;
var private X2Condition_Visibility VisibilityCondition;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

// ============================ STATE CHANGES ==============================================================

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

	DDObject = XComGameState_DynamicDeployment(History.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none || !DDObject.bPendingDeployment)
		return;

	// Issue async requests to load soldier assets
	//DDObject.PreloadAssets(); // Done on turn start.

	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
	UnitStates = DDObject.GetUnitsToDeploy();
	DDObject.bPendingDeployment = false; // Prevent Deploy from being activated again.

	XComHQ = `XCOMHQ;
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));

	`AMLOG("Units to deploy:" @ UnitStates.Length);

	EventMgr = `XEVENTMGR;
	DDObject.GenerateSpawnLocations(ApplyEffectParameters.AbilityInputContext.TargetLocations[0], UnitStates, SpawnLocations);

	foreach UnitStates(UnitState, iNumUnit)
	{
		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
		`AMLOG(iNumUnit @ "Deploying unit:" @ UnitState.GetFullName());

		SpawnLocation = SpawnLocations[iNumUnit];
		`AMLOG("SpawnLocation:" @ SpawnLocation);

		DeployUnit(NewUnitState, NewGameState, SpawnLocation);

		// Add unit to squad, if they're not there already - 
		// might be the case for redeploying units evaced this mission
		if (XComHQ.Squad.Find('ObjectID', NewUnitState.ObjectID) == INDEX_NONE)
		{
			XComHQ.Squad.AddItem(NewUnitState.GetReference());
		}

		// If unit has Phantom and is unseen during the landing, /*and the squad hasn't broken concealment yet, */
		// they will enter concealment.
		if (/*PlayerState.bSquadIsConcealed &&	*/	
			/*class'Help'.static.ShouldUseDigitalUplink(CastingUnit) &&*/
			VisibilityCondition.MeetsCondition(NewUnitState) == 'AA_Success' &&
			NewUnitState.HasAnyOfTheAbilitiesFromAnySource(class'X2AbilityTemplateManager'.default.AbilityProvidesStartOfMatchConcealment))
		{
			NewUnitState.EnterConcealmentNewGameState(NewGameState);
		}
	
		EventMgr.TriggerEvent('ObjectMoved', NewUnitState, NewUnitState, NewGameState);
		EventMgr.TriggerEvent('UnitMoveFinished', NewUnitState, NewUnitState, NewGameState);
	}

	class'Help'.static.PutSkyrangerOnCooldown(`GetConfigInt("IRI_DD_Skyranger_Shared_Cooldown"), NewGameState);

	EventMgr.TriggerEvent(class'Help'.default.DDEventName, PlayerState, PlayerState, NewGameState);

	`AMLOG("Deployment complete");
}

static private function XComGameState_Unit DeployUnit(XComGameState_Unit Unit, XComGameState NewGameState, const vector SpawnLocation)
{
	local XComGameStateHistory			History;
	local XComGameState_Player			PlayerState;
	local StateObjectReference			ItemReference;
	local XComGameState_Item			ItemState;
	local XComGameState_Unit			CosmeticUnit;
	local XComGameState_AIGroup			Group, PreviousGroupState;
	local TTile							CosmeticUnitTile;

	History = `XCOMHISTORY;

	//tell the game that the new unit is part of your squad so the mission wont just end if others retreat -LEB
	Unit.bSpawnedFromAvenger = true; 

	// This causes redscreens about having to clamp the tile location, but I'm pretty sure it's schitzofrenic
	// I've copied the clamping code and there was no difference between tiles.
	Unit.SetVisibilityLocationFromVector(SpawnLocation);
	
	// No need to do this stuff if the unit was already on this mission.

	// assign the new unit to the human team -LEB
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

	Unit.BeginTacticalPlay(NewGameState); 

	if (default.OVERRIDE_AFTER_SPAWN_ACTION_POINTS.Length > 0)
	{
		Unit.ActionPoints = default.OVERRIDE_AFTER_SPAWN_ACTION_POINTS;
	}
	else 
	{
		Unit.GiveStandardActionPoints();
	}

	return Unit;
}

//static function UnitResumeTacticalPlay(XComGameState_Unit UnitState)
//{
//	local X2EventManager EventManager;
//	local XComGameState_BattleData BattleDataState;
//	local XComGameStateHistory History;
//	local XComGameState_HeadquartersXCom XComHQ;
//
//	EventManager = `XEVENTMGR;
//	History = `XCOMHISTORY;
//
//	//EventManager.TriggerEvent('OnUnitBeginPlay', UnitState, UnitState, NewGameState);
//
//	UnitState.RegisterForEvents();
//
//	`XWORLD.SetTileBlockedByUnitFlag(UnitState);
//}


static private protected function XComGameState_AIGroup GetPlayerGroup()
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

// ============================ VISUALIZATION ==============================================================

simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	switch (class'Help'.static.GetDeploymentType())
	{
		case `eDT_SeismicBeacon:
			UndergroundDeploymentVisualization(VisualizeGameState, ActionMetadata);
			break;
		case `eDT_Flare:
		default:
			SkyrangerDeploymentVisualization(VisualizeGameState, ActionMetadata);
			break;
	}
}


private function UndergroundDeploymentVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata)
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
	local X2Action_TimedWait				CameraArrive;
	local XComGameState_Unit				CastingUnit;
	local X2Action_CameraRemove				RemoveCamera;
	local X2Action_PlayNarrative			NarrativeAction;

	World = `XWORLD;
	MaxZ = World.WORLD_FloorHeightsPerLevel * World.WORLD_TotalLevels * World.WORLD_FloorHeight;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none)
		return;

	UnitStates = DDObject.GetUnitsToDeploy(VisualizeGameState);
	if (UnitStates.Length == 0)
		return;

	CastingUnit = XComGameState_Unit(ActionMetadata.StateObject_NewState);


	`AMLOG("Got this many units to visualize:" @ UnitStates.Length);

	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	RemoveCamera = X2Action_CameraRemove(class'X2Action_CameraRemove'.static.AddToVisualizationTree(ActionMetadata, AbilityContext));
	RemoveCamera.CameraTagToRemove = 'AbilityFraming';

	// Move camera to deployment location
	LookAtTargetAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, ActionMetadata.LastActionAdded));
	LookAtTargetAction.LookAtLocation = AbilityContext.InputContext.TargetLocations[0];
	LookAtTargetAction.LookAtDuration = 2.0f + UnitStates.Length;
	//LookAtTargetAction.BlockUntilFinished = true;
	LookAtTargetAction.BlockUntilActorOnScreen = true;

	//LookAtTargetAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, ActionMetadata.LastActionAdded));
	//LookAtTargetAction.LookAtLocation = AbilityContext.InputContext.TargetLocations[0];
	//LookAtTargetAction.LookAtDuration = 2.0f + UnitStates.Length;
	//LookAtTargetAction.BlockUntilFinished = false;

	`AMLOG("Camera looks at location:" @ LookAtTargetAction.LookAtLocation);

	// Firebrand voiceline
	NarrativeAction = X2Action_PlayNarrative(class'X2Action_PlayNarrative'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, LookAtTargetAction));
	NarrativeAction.Moment = XComNarrativeMoment(`CONTENT.RequestGameArchetype("X2NarrativeMoments.T_In_Drop_Position_Firebrande_O" $ Rand(5))); // [0;4]
		
	CameraArrive = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, LookAtTargetAction));
	CameraArrive.DelayTimeSec = 1.5f;

	foreach UnitStates(UnitState, iNumUnit)
	{
		`AMLOG("Visualizing unit spawn:" @ UnitState.GetFullName());

		SpawnedUnitMetadata = EmptyMetadata;
		SpawnedUnitMetadata.StateObject_OldState = UnitState;
		SpawnedUnitMetadata.StateObject_NewState = UnitState;

		SpawnTile = UnitState.TileLocation;
		SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);

		//	insert a random time delay for each unit spawn so they don't all drop down at exactly the same time
		WaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, CameraArrive));
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
			if (class'Help'.static.ShouldUseDigitalUplink(CastingUnit))
			{
				AnimationAction.Params.AnimName = 'HL_DynamicDeploymentSilent_Underground';
			}
			else
			{
				AnimationAction.Params.AnimName = 'HL_DynamicDeployment_Underground';
			}
		}
		else
		{
			AnimationAction.Params.AnimName = 'HL_DynamicDeployment_Underground';
		}
		
		AnimationAction.Params.BlendTime = 0.0f;

		HideUnitFlag = X2Action_HideUIUnitFlag(class'X2Action_HideUIUnitFlag'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		HideUnitFlag.bHideUIUnitFlag = false;
		
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

	UnitState = UnitStates[0];
	if (UnitState.ActionPoints.Length > 0)
	{
		SelectUnitAction = X2Action_SelectNextActiveUnit(class'X2Action_SelectNextActiveUnit'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		SelectUnitAction.TargetID = UnitState.ObjectID;
	}
}


private function SkyrangerDeploymentVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata)
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
	local X2Action_UnstreamMap				UnstreamMap;
	local array<X2Action>					StreamActions;
	local X2Action							WaitForEffect;
	local XComGameState_Unit				CastingUnit;
	local X2Action_CameraLookAt				LookAtTargetAction;
	local X2Action_CameraRemove				RemoveCamera;
	local X2Action_PlayNarrative			NarrativeAction;

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
	CastingUnit = XComGameState_Unit(ActionMetadata.StateObject_NewState);
	AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	// Get rid of the normal ability framing camera that focuses on the midpoint between the shooter and target location.
	// It's done its job at this point.
	RemoveCamera = X2Action_CameraRemove(class'X2Action_CameraRemove'.static.AddToVisualizationTree(ActionMetadata, AbilityContext));
	RemoveCamera.CameraTagToRemove = 'AbilityFraming';

	// Move camera to deployment location
	LookAtTargetAction = X2Action_CameraLookAt(class'X2Action_CameraLookAt'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, ActionMetadata.LastActionAdded));
	LookAtTargetAction.LookAtLocation = AbilityContext.InputContext.TargetLocations[0];
	LookAtTargetAction.LookAtDuration = 2.0f + UnitStates.Length;

	`AMLOG("Camera looks at location:" @ LookAtTargetAction.LookAtLocation);
	
	WaitForEffect = class'X2Action_WaitForAbilityEffect'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, ActionMetadata.LastActionAdded);

	// Wait for the deploy flare to pout a bit of smoke
	WaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, WaitForEffect));
	WaitAction.DelayTimeSec = 1.5f;

	// Only then begin streaming maps, cuz it messes with lighting, really wanna start playing matinee ASAP once maps load.
	StreamMap = X2Action_StreamMap(class'X2Action_StreamMap'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, WaitAction));
	StreamMap.MapToStream = "DDCIN_SkyrangerIntros";
	StreamMap.MapLocation = AbilityContext.InputContext.TargetLocations[0];
	StreamActions.AddItem(StreamMap);

	if (bAtLeastOneUnitIsSparkLike)
	{
		StreamMap = X2Action_StreamMap(class'X2Action_StreamMap'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, WaitAction));
		StreamMap.MapToStream = "DDCIN_SkyrangerIntros_Spark";
		StreamMap.MapLocation = AbilityContext.InputContext.TargetLocations[0];
		StreamActions.AddItem(StreamMap);
	}

	// Make Firebrand play the "In the drop position" voiceline.
	NarrativeAction = X2Action_PlayNarrative(class'X2Action_PlayNarrative'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false,, StreamActions));
	NarrativeAction.Moment = XComNarrativeMoment(`CONTENT.RequestGameArchetype("X2NarrativeMoments.T_In_Drop_Position_Firebrande_O" $ Rand(5))); // [0;4]
		
	// Begin playing once camera arrives
	SkyrangerIntro = X2Action_DynamicDeployment(class'X2Action_DynamicDeployment'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false,, StreamActions));
	SkyrangerIntro.UnitStates = UnitStates;

	foreach UnitStates(UnitState, iNumUnit)
	{
		`AMLOG("Visualizing unit spawn:" @ UnitState.GetFullName());

		SpawnedUnitMetadata = EmptyMetadata;
		SpawnedUnitMetadata.StateObject_OldState = UnitState;
		SpawnedUnitMetadata.StateObject_NewState = UnitState;

		SpawnTile = UnitState.TileLocation;
		SpawnLocation = World.GetPositionFromTileCoordinates(SpawnTile);

		//	insert a random time delay for each unit spawn so they don't all drop down at exactly the same time
		WaitAction = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SkyrangerIntro));
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
			if (class'Help'.static.ShouldUseDigitalUplink(CastingUnit))
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
			AnimationAction.Params.AnimName = 'HL_DynamicDeployment';
		}

		AnimationAction.Params.BlendTime = 0.0f;

		// Apparently this isn't neccessary and it only makes SPARKs land halfway into the ground.
		//AnimationAction.Params.DesiredEndingAtoms.Add(1);
		//AnimationAction.Params.DesiredEndingAtoms[0].Scale = 1.0f;
		//AnimationAction.Params.DesiredEndingAtoms[0].Translation = SpawnLocation;

		HideUnitFlag = X2Action_HideUIUnitFlag(class'X2Action_HideUIUnitFlag'.static.AddToVisualizationTree(SpawnedUnitMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		HideUnitFlag.bHideUIUnitFlag = false;

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

	UnitState = UnitStates[0];
	if (UnitState.ActionPoints.Length > 0)
	{
		SelectUnitAction = X2Action_SelectNextActiveUnit(class'X2Action_SelectNextActiveUnit'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		SelectUnitAction.TargetID = UnitState.ObjectID;
	}

	UnstreamMap = X2Action_UnstreamMap(class'X2Action_UnstreamMap'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
	UnstreamMap.MapToUnstream = "DDCIN_SkyrangerIntros";

	if (bAtLeastOneUnitIsSparkLike)
	{
		UnstreamMap = X2Action_UnstreamMap(class'X2Action_UnstreamMap'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, SpawnedUnitMetadata.LastActionAdded));
		UnstreamMap.MapToUnstream = "DDCIN_SkyrangerIntros_Spark";
	}
}

// ============================ EVENTS ==============================================================

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager	EventMgr;
	local Object			EffectObj;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;

	// When set up this way, we'll nuke scamper visualization caused by any unit that was deployed this turn, 
	// even if they pull pods by moving after deployment.
	// Unfortunate, but I don't know how else to handle this.
	// For some reason X2Action_RevealAIBegin just times out in PlayMatinee(), which is native, so no good way to figure it out.
	EventMgr.RegisterForEvent(EffectObj, 'ScamperBegin', OnScamperBegin, ELD_OnStateSubmitted,, ,, );	
}

static private function EventListenerReturn OnScamperBegin(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_AIGroup GroupState;
	local XComGameState_DynamicDeployment DDObject;

	GroupState = XComGameState_AIGroup(EventSource);
	if (GroupState == none)
		return ELR_NoInterrupt;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none || !DDObject.IsUnitSelected(GroupState.RevealInstigatorUnitObjectID))
		return ELR_NoInterrupt;
		
	// If we're here, it means scamper was caused by a soldier dropped via DD. 
	`AMLOG("Adding post build vis");
	GameState.GetContext().PostBuildVisualizationFn.AddItem(RemovePodReveal_PostBuildVisualization);

	return ELR_NoInterrupt;
}
// Pod reveal cinematic for some reason doesn't play properly after DD, so nuke it.
static private function RemovePodReveal_PostBuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateVisualizationMgr		VisMgr;	
	local X2Action_MarkerNamed				ReplaceAction;	
	local array<X2Action>					FindActions;
	local X2Action							FindAction;

	`AMLOG("Running");

	VisMgr = `XCOMVISUALIZATIONMGR;

	VisMgr.GetNodesOfType(VisMgr.BuildVisTree, class'X2Action_RevealAIBegin', FindActions);

	`AMLOG("Found Reveal AI Begin actions in Build Vis Tree:" @ FindActions.Length);
	foreach FindActions(FindAction)
	{
		ReplaceAction = X2Action_MarkerNamed(class'X2Action'.static.CreateVisualizationActionClass(class'X2Action_MarkerNamed', FindAction.StateChangeContext));
		ReplaceAction.SetName("ReplaceActionStub1");
		VisMgr.ReplaceNode(ReplaceAction, FindAction);

		`AMLOG("Nuking Reveal AI Begin action");
	}

	VisMgr.GetNodesOfType(VisMgr.BuildVisTree, class'X2Action_RevealAIEnd', FindActions);

	`AMLOG("Found Reveal AI End actions in Build Vis Tree:" @ FindActions.Length);
	foreach FindActions(FindAction)
	{
		ReplaceAction = X2Action_MarkerNamed(class'X2Action'.static.CreateVisualizationActionClass(class'X2Action_MarkerNamed', FindAction.StateChangeContext));
		ReplaceAction.SetName("ReplaceActionStub2");
		VisMgr.ReplaceNode(ReplaceAction, FindAction);

		`AMLOG("Nuking Reveal AI End action");
	}
}

// -----------------------------------------------------------------------------------

defaultproperties
{
	iNumTurns = 1
	bInfiniteDuration = false
	bRemoveWhenSourceDies = false
	bIgnorePlayerCheckOnTick = false
	WatchRule = eGameRule_PlayerTurnEnd
	EffectName = "IRI_DD_X2Effect_DynamicDeployment"
	DuplicateResponse = eDupe_Allow

    Begin Object Class=X2Condition_Visibility Name=DefaultVisibilityCondition
        bNoEnemyViewers = true
    End Object
    VisibilityCondition = DefaultVisibilityCondition;
}