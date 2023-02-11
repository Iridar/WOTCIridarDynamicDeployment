class X2Effect_TakeAndHold extends X2Effect_PersistentStatChange;

// Persistent stat change effect that's set up to remove itself if the unit dashes.

function RegisterForEvents(XComGameState_Effect EffectGameState)
{
	local X2EventManager		EventMgr;
	local XComGameState_Unit	UnitState;
	local Object				EffectObj;

	EventMgr = `XEVENTMGR;
	EffectObj = EffectGameState;
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(EffectGameState.ApplyEffectParameters.SourceStateObjectRef.ObjectID));

	EventMgr.RegisterForEvent(EffectObj, 'AbilityActivated', AbilityActivated_Listener, ELD_OnStateSubmitted,, UnitState,, EffectObj);	

	super.RegisterForEvents(EffectGameState);
}

static final function EventListenerReturn AbilityActivated_Listener(Object EventData, Object EventSource, XComGameState GameState, name InEventID, Object CallbackData)
{
	local XComGameState_Effect			EffectState;
	local XComGameState					NewGameState;
	local XComGameStateContext_Ability	AbilityContext;
	local int							PathIndex;
		
	AbilityContext = XComGameStateContext_Ability(GameState.GetContext());
	if (AbilityContext == none || AbilityContext.InterruptionStatus == eInterruptionStatus_Interrupt)
		return ELR_NoInterrupt;
		
	PathIndex = AbilityContext.GetMovePathIndex(AbilityContext.InputContext.SourceObject.ObjectID); // Did we move?

	If (PathIndex == INDEX_NONE || AbilityContext.InputContext.MovementPaths[PathIndex].CostIncreases.Length == 0) // Dash check
		return ELR_NoInterrupt;

	EffectState = XComGameState_Effect(CallbackData);
	if (EffectState == none)
		return ELR_NoInterrupt;

	AbilityContext.PostBuildVisualizationFn.AddItem(TakeAndHold_Removed_Flyover_PostBuildVisualization);

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Remove Take and Hold due to unit movement");
	EffectState = XComGameState_Effect(NewGameState.ModifyStateObject(EffectState.Class, EffectState.ObjectID));
	EffectState.RemoveEffect(NewGameState, NewGameState, true);
	`GAMERULES.SubmitGameState(NewGameState);
	
    return ELR_NoInterrupt;
}


static final function TakeAndHold_Removed_Flyover_PostBuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateVisualizationMgr		VisMgr;
	local XComGameStateContext_Ability		Context;
	local VisualizationActionMetadata		ActionMetadata;
	local X2Action_MoveEnd					MoveEnd;
	local X2Action_PlaySoundAndFlyOver		SoundAndFlyover;
	local X2AbilityTemplate					Template;

	VisMgr = `XCOMVISUALIZATIONMGR;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	Template = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('IRI_DDUnlock_TakeAndHold');
	if (Template == none)
		return;

	MoveEnd = X2Action_MoveEnd(VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_MoveEnd',, Context.InputContext.SourceObject.ObjectID));
	if (MoveEnd != none)
	{
		ActionMetadata = MoveEnd.Metadata;
		
		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, Context, false, MoveEnd));
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, Template.LocFriendlyName, '', eColor_Bad, "img:///IRIDynamicDeployment_UI.UIPerk_TakeAndHold");
	}
	else
	{
		ActionMetadata.StateObject_OldState = `XCOMHISTORY.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID);
		ActionMetadata.StateObject_NewState = VisualizeGameState.GetGameStateForObjectID(Context.InputContext.SourceObject.ObjectID);
		ActionMetadata.VisualizeActor = `XCOMHISTORY.GetVisualizer(Context.InputContext.SourceObject.ObjectID);

		SoundAndFlyOver = X2Action_PlaySoundAndFlyOver(class'X2Action_PlaySoundAndFlyover'.static.AddToVisualizationTree(ActionMetadata, Context, false));
		SoundAndFlyOver.SetSoundAndFlyOverParameters(None, Template.LocFriendlyName, '', eColor_Bad, "img:///IRIDynamicDeployment_UI.UIPerk_TakeAndHold");
	}
}


defaultproperties
{
	DuplicateResponse = eDupe_Ignore
	EffectName = "X2Effect_TakeAndHold_Effect"
}