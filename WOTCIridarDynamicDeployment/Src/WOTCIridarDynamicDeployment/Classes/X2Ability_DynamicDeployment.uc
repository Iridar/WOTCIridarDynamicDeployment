class X2Ability_DynamicDeployment extends X2Ability;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(IRI_DynamicDeployment_Select());
	Templates.AddItem(IRI_DynamicDeployment_Deploy());

	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_SparkRetainConcealment', "img:///IRIDynamicDeployment_UI.UIPerk_SilentBoosters"));
	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_PrecisionDrop', "img:///IRIDynamicDeployment_UI.UIPerk_PrecisionDrop"));
	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_FastDrop', "img:///IRIDynamicDeployment_UI.UIPerk_FastDrop"));
	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_AerialScout', "img:///IRIDynamicDeployment_UI.UIPerk_AerialScout"));
	Templates.AddItem(IRI_DDUnlock_TakeAndHold());
	Templates.AddItem(IRI_DDUnlock_HitGroundRunning());
	
	//Templates.AddItem(IRI_DDUnlock_SparkOverdrive());
	//Templates.AddItem(IRI_DynamicDeployment_BlackOps());

	return Templates;
}

static private function X2AbilityTemplate IRI_DDUnlock_HitGroundRunning()
{
	local X2AbilityTemplate				Template;
	local X2Effect_PersistentStatChange	StatChange;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_DDUnlock_HitGroundRunning');

	// Icon Setup
	Template.IconImage = "img:///IRIDynamicDeployment_UI.UIPerk_HitGroundRunning";
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	SetHidden(Template);
	Template.bDontDisplayInAbilitySummary = false;

	// Targeting and Triggering
	SetSelfTarget_WithEventTrigger(Template, class'Help'.default.DDEventName, ELD_OnStateSubmitted, eFilter_Player, 50);

	// Shooter Conditions
	// Incase you get dead'ed by overwatch or something
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	
	// Effects
	StatChange = new class'X2Effect_PersistentStatChange';
	StatChange.BuildPersistentEffect(1, false, true, false, eGameRule_PlayerTurnBegin);
	StatChange.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,, Template.AbilitySourceName);
	StatChange.AddPersistentStatChange(eStat_Mobility, `GetConfigInt("IRI_DD_HitGroundRunning_MobilityBonus"));
	Template.AddShooterEffect(StatChange);

	// State and Vis
	Template.Hostility = eHostility_Neutral;
	Template.bSkipExitCoverWhenFiring = true;
	Template.bSkipFireAction = true;
	Template.bShowActivation = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
	
	return Template;
}

static private function X2AbilityTemplate IRI_DDUnlock_TakeAndHold()
{
	local X2AbilityTemplate		Template;
	local X2Effect_TakeAndHold	TakeAndHold;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_DDUnlock_TakeAndHold');

	// Icon Setup
	Template.IconImage = "img:///IRIDynamicDeployment_UI.UIPerk_TakeAndHold";
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	SetHidden(Template);
	Template.bDontDisplayInAbilitySummary = false;

	// Targeting and Triggering
	SetSelfTarget_WithEventTrigger(Template, class'Help'.default.DDEventName, ELD_OnStateSubmitted, eFilter_Player, 50);

	// Shooter Conditions
	// Incase you get dead'ed by overwatch or something
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	
	// Effects
	TakeAndHold = new class'X2Effect_TakeAndHold';
	TakeAndHold.BuildPersistentEffect(2, false, true, false, eGameRule_PlayerTurnBegin);
	TakeAndHold.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyLongDescription(), Template.IconImage, true,, Template.AbilitySourceName);
	TakeAndHold.AddPersistentStatChange(eStat_Offense, `GetConfigInt("IRI_DD_TakeAndHold_AimBonus")); 
	TakeAndHold.AddPersistentStatChange(eStat_Defense, `GetConfigInt("IRI_DD_TakeAndHold_DefenseBonus"));
	Template.AddShooterEffect(TakeAndHold);

	// State and Vis
	Template.Hostility = eHostility_Neutral;
	Template.bSkipExitCoverWhenFiring = true;
	Template.bSkipFireAction = true;
	Template.bShowActivation = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
	
	return Template;
}

static private function X2AbilityTemplate CreatePassiveDDUnlock(const name TemplateName, const string strImage)
{
	local X2AbilityTemplate Template;

	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);

	// Icon Setup
	Template.IconImage = strImage;
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;

	Template.bDisplayInUITacticalText = false;
	Template.bHideOnClassUnlock = true;
	Template.bDisplayInUITooltip = false;
	Template.bDontDisplayInAbilitySummary = false;

	// Targeting and Triggering
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(new class'X2AbilityTrigger_Placeholder');
	
	// State and Vis
	Template.Hostility = eHostility_Neutral;
	
	return Template;
}

static private function X2AbilityTemplate IRI_DynamicDeployment_Select()
{
	local X2AbilityTemplate				Template;
	local X2Condition_SoldierRank		SoldierRank;
	local X2AbilityCost_ActionPoints	ActionPointCost;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_DynamicDeployment_Select');

	// Icon Setup
	Template.IconImage = "img:///IRIDynamicDeployment_UI.UIPerk_DynamicSelect";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.PLACE_EVAC_PRIORITY + 5;
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.OverrideAbilityAvailabilityFn = DDSelect_OverrideAbilityAvailability;

	Template.bDisplayInUITacticalText = false;
	Template.bHideOnClassUnlock = true;
	Template.bDisplayInUITooltip = false;
	
	// Cost and Cooldown
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bFreeCost = `GETMCMVAR(DD_SOLDIER_SELECT_IS_FREE_ACTION);
	ActionPointCost.bConsumeAllPoints = `GETMCMVAR(DD_SOLDIER_SELECT_ENDS_TURN);
	Template.AbilityCosts.AddItem(ActionPointCost);

	// Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	SoldierRank = new class'X2Condition_SoldierRank';
	SoldierRank.MinRank = `GetConfigInt("IRI_DD_MinRank");
	Template.AbilityShooterConditions.AddItem(SoldierRank);

	// Targeting and Triggering
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	
	// State and Vis
	Template.Hostility = eHostility_Neutral;
	Template.bSkipExitCoverWhenFiring = true;
	Template.CustomFireAnim = 'HL_CallReinforcements';
	Template.CustomSelfFireAnim = 'HL_CallReinforcements';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = DynamicDeployment_Select_BuildVisualization;
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	Template.AdditionalAbilities.AddItem('IRI_DynamicDeployment_Deploy');
	
	return Template;
}

static final function DynamicDeployment_Select_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateVisualizationMgr		VisMgr;
	local Actor								SourceVisualizer;
	local XComGameStateContext_Ability		Context;
	local VisualizationActionMetadata		ActionMetadata;
	local X2Action_Fire						FireAction;

	TypicalAbility_BuildVisualization(VisualizeGameState);

	VisMgr = `XCOMVISUALIZATIONMGR;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());
	SourceVisualizer = `XCOMHISTORY.GetVisualizer(Context.InputContext.SourceObject.ObjectID);

	FireAction = X2Action_Fire(VisMgr.GetNodeOfType(VisMgr.BuildVisTree, class'X2Action_Fire', SourceVisualizer));
	ActionMetadata = FireAction.Metadata;

	class'X2Action_SelectUnits'.static.AddToVisualizationTree(ActionMetadata, Context, false,, FireAction.ParentActions);
}


static private function X2AbilityTemplate IRI_DynamicDeployment_Deploy()
{
	local X2AbilityTemplate					Template;
	local X2AbilityCooldown_Global			GlobalCooldown;
	local X2AbilityCost_ActionPoints		ActionPointCost;
	local X2AbilityTarget_Cursor			CursorTarget;
	local X2AbilityMultiTarget_Radius		RadiusMultiTarget;
	local X2Condition_SoldierRank			SoldierRank;
	local X2Effect_AerialScout				AerialScout;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_DynamicDeployment_Deploy');

	// Icon Setup
	Template.IconImage = "img:///IRIDynamicDeployment_UI.UIPerk_DynamicDeploy";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.PLACE_EVAC_PRIORITY + 5;
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.OverrideAbilityAvailabilityFn = DDDeploy_OverrideAbilityAvailability;

	Template.bDisplayInUITacticalText = false;
	Template.bHideOnClassUnlock = true;
	Template.bDisplayInUITooltip = false;

	// Cost and Cooldown
	GlobalCooldown = new class'X2AbilityCooldown_Global';
	GlobalCooldown.iNumTurns = `GETMCMVAR(DD_AFTER_DEPLOY_COOLDOWN);
	Template.AbilityCooldown = GlobalCooldown;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bFreeCost = `GETMCMVAR(DD_DEPLOY_IS_FREE_ACTION);
	ActionPointCost.bConsumeAllPoints = `GETMCMVAR(DD_DEPLOY_ENDS_TURN);
	Template.AbilityCosts.AddItem(ActionPointCost);

	// Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	//Template.AbilityShooterConditions.AddItem(new class'X2Condition_SparkFall');
	Template.AddShooterEffectExclusions();

	SoldierRank = new class'X2Condition_SoldierRank';
	SoldierRank.MinRank = `GetConfigInt("IRI_DD_MinRank");
	Template.AbilityShooterConditions.AddItem(SoldierRank);

	// Targeting and Triggering
	Template.AbilityToHitCalc = default.DeadEye;

	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.FixedAbilityRange = `TILESTOMETERS(`GETMCMVAR(DEPLOY_CAST_RANGE_TILES));
	CursorTarget.bRestrictToSquadsightRange = `GETMCMVAR(SQUAD_MUST_SEE_TILE);
	Template.AbilityTargetStyle = CursorTarget;

	RadiusMultiTarget = new class'X2AbilityMultiTarget_Radius';
	RadiusMultiTarget.fTargetRadius = `GetConfigFloat("IRI_DD_DeploymentAreaRadius"); // Also used in GetSpawnLocations()
	RadiusMultiTarget.bIgnoreBlockingCover = false; 
	Template.AbilityMultiTargetStyle = RadiusMultiTarget;

	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	Template.TargetingMethod = class'X2TargetingMethod_DynamicDeployment';
	Template.SkipRenderOfTargetingTemplate = true;

	// Effects
	Template.AddShooterEffect(new class'X2Effect_DynamicDeployment');

	AerialScout = new class'X2Effect_AerialScout';
	AerialScout.BuildPersistentEffect(1, false, false, false, eGameRule_PlayerTurnEnd);
	AerialScout.TargetConditions.AddItem(new class'X2Condition_AerialScout');
	Template.AddShooterEffect(AerialScout);
	
	// State and Vis
	Template.Hostility = eHostility_Neutral;
	Template.bSkipExitCoverWhenFiring = false;
	Template.CustomFireAnim = 'HL_SignalPointA';
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.FrameAbilityCameraType = eCameraFraming_Never; // Using custom camera work in X2Effect_DD instead.
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
	
	return Template;
}

static private function DDSelect_OverrideAbilityAvailability(out AvailableAction Action, XComGameState_Ability AbilityState, XComGameState_Unit OwnerState)
{
	local XComGameState_DynamicDeployment DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none) // Special handle first deployment of the campaign.
	{
		`AMLOG("DDObject no exist, show");
		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
		return;
	}

	if (!DDObject.CanSelectMoreSoldiers() ||		// Can't deploy any more soldiers
		DDObject.IsAnyUnitSelected() && DDObject.bPendingDeployment) // Already have some soldiers selected for deployment
	{
		`AMLOG("Can't select more soldiers:" @ !DDObject.CanSelectMoreSoldiers());
		`AMLOG("Any unit selected:" @ DDObject.IsAnyUnitSelected());
		`AMLOG("Pending deployment:" @ DDObject.bPendingDeployment);

		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
		return;
	}

	// Display when on cooldown.
	if (Action.AvailableCode == 'AA_CoolingDown')
	{
		`AMLOG("Show when on cooldown");
		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	}
	else
	{	
		// Otherwise display when other condiitons succeed.
		`AMLOG("Other conditions");
		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_ShowIfAvailable;
	}
}

static private function DDDeploy_OverrideAbilityAvailability(out AvailableAction Action, XComGameState_Ability AbilityState, XComGameState_Unit OwnerState)
{
	local XComGameState_DynamicDeployment DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none ||						// Shouldn't happen
		!DDObject.IsAnyUnitSelected() || !DDObject.bPendingDeployment) // No unit selected for deployment
	{
		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
		return;
	}

	// Display when on cooldown.
	if (Action.AvailableCode == 'AA_CoolingDown')
	{
		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	}
	else
	{	
		// Otherwise display when other condiitons succeed.
		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_ShowIfAvailable;
	}
}

//	========================================
//				COMMON CODE
//	========================================

static function AddCooldown(out X2AbilityTemplate Template, int Cooldown)
{
	local X2AbilityCooldown AbilityCooldown;

	if (Cooldown > 0)
	{
		AbilityCooldown = new class'X2AbilityCooldown';
		AbilityCooldown.iNumTurns = Cooldown;
		Template.AbilityCooldown = AbilityCooldown;
	}
}

static function AddCharges(out X2AbilityTemplate Template, int InitialCharges)
{
	local X2AbilityCharges		Charges;
	local X2AbilityCost_Charges	ChargeCost;

	if (InitialCharges > 0)
	{
		Charges = new class'X2AbilityCharges';
		Charges.InitialCharges = InitialCharges;
		Template.AbilityCharges = Charges;

		ChargeCost = new class'X2AbilityCost_Charges';
		ChargeCost.NumCharges = 1;
		Template.AbilityCosts.AddItem(ChargeCost);
	}
}

static function AddFreeCost(out X2AbilityTemplate Template)
{
	local X2AbilityCost_ActionPoints ActionPointCost;

	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bFreeCost = true;
	Template.AbilityCosts.AddItem(ActionPointCost);
}

static function RemoveVoiceLines(out X2AbilityTemplate Template)
{
	Template.ActivationSpeech = '';
	Template.SourceHitSpeech = '';
	Template.TargetHitSpeech = '';
	Template.SourceMissSpeech = '';
	Template.TargetMissSpeech = '';
	Template.TargetKilledByAlienSpeech = '';
	Template.TargetKilledByXComSpeech = '';
	Template.MultiTargetsKilledByAlienSpeech = '';
	Template.MultiTargetsKilledByXComSpeech = '';
	Template.TargetWingedSpeech = '';
	Template.TargetArmorHitSpeech = '';
	Template.TargetMissedSpeech = '';
}

static function SetFireAnim(out X2AbilityTemplate Template, name Anim)
{
	Template.CustomFireAnim = Anim;
	Template.CustomFireKillAnim = Anim;
	Template.CustomMovingFireAnim = Anim;
	Template.CustomMovingFireKillAnim = Anim;
	Template.CustomMovingTurnLeftFireAnim = Anim;
	Template.CustomMovingTurnLeftFireKillAnim = Anim;
	Template.CustomMovingTurnRightFireAnim = Anim;
	Template.CustomMovingTurnRightFireKillAnim = Anim;
}

static function SetHidden(out X2AbilityTemplate Template)
{
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	
	//TacticalText is for mainly for item-granted abilities (e.g. to hide the ability that gives the armour stats)
	Template.bDisplayInUITacticalText = false;
	
	//	bDisplayInUITooltip isn't actually used in the base game, it should be for whether to show it in the enemy tooltip, 
	//	but showing enemy abilities didn't make it into the final game. Extended Information resurrected the feature  in its enhanced enemy tooltip, 
	//	and uses that flag as part of it's heuristic for what abilities to show, but doesn't rely solely on it since it's not set consistently even on base game abilities. 
	//	Anyway, the most sane setting for it is to match 'bDisplayInUITacticalText'. (c) MrNice
	Template.bDisplayInUITooltip = false;
	
	//Ability Summary is the list in the armoury when you're looking at a soldier.
	Template.bDontDisplayInAbilitySummary = true;
	Template.bHideOnClassUnlock = true;
}

static function X2AbilityTemplate Create_AnimSet_Passive(name TemplateName, string AnimSetPath)
{
	local X2AbilityTemplate                 Template;
	local X2Effect_AdditionalAnimSets		AnimSetEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);

	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.bDisplayInUITooltip = false;
	Template.bDisplayInUITacticalText = false;
	Template.bDontDisplayInAbilitySummary = true;
	Template.Hostility = eHostility_Neutral;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);
	
	AnimSetEffect = new class'X2Effect_AdditionalAnimSets';
	AnimSetEffect.AddAnimSetWithPath(AnimSetPath);
	AnimSetEffect.BuildPersistentEffect(1, true, false, false);
	Template.AddTargetEffect(AnimSetEffect);

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;

	return Template;
}

static function SetPassive(out X2AbilityTemplate Template)
{
	Template.bIsPassive = true;

	Template.eAbilityIconBehaviorHUD = EAbilityIconBehavior_NeverShow;
	Template.bDisplayInUITacticalText = true;
	Template.bDisplayInUITooltip = true;
	Template.bDontDisplayInAbilitySummary = false;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.UnitPostBeginPlayTrigger);

	Template.Hostility = eHostility_Neutral;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
}

static function X2AbilityTemplate HiddenPurePassive(name TemplateName, optional string TemplateIconImage="img:///UILibrary_PerkIcons.UIPerk_standard", optional bool bCrossClassEligible=false, optional Name AbilitySourceName='eAbilitySource_Perk', optional bool bDisplayInUI=true)
{
	local X2AbilityTemplate	Template;
	
	Template = PurePassive(TemplateName, TemplateIconImage, bCrossClassEligible, AbilitySourceName, bDisplayInUI);
	SetHidden(Template);
	
	return Template;
}

//	Use: SetSelfTarget_WithEventTrigger(Template, 'PlayerTurnBegun',, eFilter_Player);
static function	SetSelfTarget_WithEventTrigger(out X2AbilityTemplate Template, name EventID, optional EventListenerDeferral Deferral = ELD_OnStateSubmitted, optional AbilityEventFilter Filter = eFilter_None, optional int Priority = 50)
{
	local X2AbilityTrigger_EventListener Trigger;

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	
	Trigger = new class'X2AbilityTrigger_EventListener';	
	Trigger.ListenerData.EventID = EventID;
	Trigger.ListenerData.Deferral = Deferral;
	Trigger.ListenerData.Filter = Filter;
	Trigger.ListenerData.Priority = Priority;
	Trigger.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_Self;
	Template.AbilityTriggers.AddItem(Trigger);
}

static function PrintActionRecursive(X2Action Action, int iLayer)
{
	local X2Action ChildAction;

	`LOG("Action layer: " @ iLayer @ ": " @ Action.Class.Name @ Action.StateChangeContext.AssociatedState.HistoryIndex,, 'IRIPISTOLVIZ'); 
	foreach Action.ChildActions(ChildAction)
	{
		PrintActionRecursive(ChildAction, iLayer + 1);
	}
}



/*
static function X2AbilityTemplate IRI_DDUnlock_SparkOverdrive()
{
	local X2AbilityTemplate						Template;
	local X2Effect_GrantActionPoints            PointEffect;
	local X2Effect_Persistent			        ActionPointPersistEffect;
	local X2Effect_DLC_3Overdrive               OverdriveEffect;
	local X2Condition_AbilityProperty           AbilityCondition;
	local X2Effect_PersistentTraversalChange    WallbreakEffect;
	local X2Effect_PerkAttachForFX              PerkAttachEffect;
	local X2AbilityTrigger_EventListener		EventListenerTrigger;
	local X2AbilityCost_Charges					ChargeCost;
	local X2AbilityCharges                      Charges;

	`CREATE_X2ABILITY_TEMPLATE(Template, 'IRI_DDUnlock_SparkOverdrive');

	ChargeCost = new class'X2AbilityCost_Charges';
	ChargeCost.NumCharges = 1;
	Template.AbilityCosts.AddItem(ChargeCost);

	Charges = new class'X2AbilityCharges';
	Charges.InitialCharges = 1;
	Template.AbilityCharges = Charges;

	Template.AbilitySourceName = 'eAbilitySource_Perk';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;
	Template.Hostility = eHostility_Neutral;
	Template.IconImage = "img:///UILibrary_DLC3Images.UIPerk_spark_overdrive";

	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	
	EventListenerTrigger = new class'X2AbilityTrigger_EventListener';
	EventListenerTrigger.ListenerData.Deferral = ELD_OnStateSubmitted;
	EventListenerTrigger.ListenerData.EventID = class'Help'.default.DDEventName;
	EventListenerTrigger.ListenerData.Filter = eFilter_Player;
	EventListenerTrigger.ListenerData.EventFn = class'XComGameState_Ability'.static.AbilityTriggerEventListener_Self;
	Template.AbilityTriggers.AddItem(EventListenerTrigger);

	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);

	PointEffect = new class'X2Effect_GrantActionPoints';
	PointEffect.NumActionPoints = 1;
	PointEffect.PointType = class'X2CharacterTemplateManager'.default.StandardActionPoint;
	Template.AddTargetEffect(PointEffect);

	// A persistent effect for the effects code to attach a duration to
	ActionPointPersistEffect = new class'X2Effect_Persistent';
	ActionPointPersistEffect.EffectName = 'OverdrivePerk';
	ActionPointPersistEffect.BuildPersistentEffect( 1, false, true, false, eGameRule_PlayerTurnEnd );
	Template.AddTargetEffect(ActionPointPersistEffect);

	OverdriveEffect = new class'X2Effect_DLC_3Overdrive';
	OverdriveEffect.BuildPersistentEffect(1, false, true, false, eGameRule_PlayerTurnBegin);
	OverdriveEffect.SetDisplayInfo(ePerkBuff_Bonus, Template.LocFriendlyName, Template.GetMyHelpText(), Template.IconImage, , , Template.AbilitySourceName);
	Template.AddTargetEffect(OverdriveEffect);

	// A persistent effect for the effects code to attach a duration to
	PerkAttachEffect = new class'X2Effect_PerkAttachForFX';
	PerkAttachEffect.EffectName = 'AdaptiveAimPerk';
	PerkAttachEffect.BuildPersistentEffect(1, false, true, false, eGameRule_PlayerTurnEnd );
	AbilityCondition = new class'X2Condition_AbilityProperty';
	AbilityCondition.OwnerHasSoldierAbilities.AddItem('AdaptiveAim');
	PerkAttachEffect.TargetConditions.AddItem(AbilityCondition);
	Template.AddTargetEffect(PerkAttachEffect);

	AbilityCondition = new class'X2Condition_AbilityProperty';
	AbilityCondition.OwnerHasSoldierAbilities.AddItem('WreckingBall');
	WallbreakEffect = new class'X2Effect_PersistentTraversalChange';
	WallbreakEffect.AddTraversalChange(eTraversal_BreakWall, true);
	WallbreakEffect.EffectName = 'WreckingBallTraversal';
	WallbreakEffect.DuplicateResponse = eDupe_Ignore;
	WallbreakEffect.BuildPersistentEffect(1, false, true, false, eGameRule_PlayerTurnEnd);
	WallbreakEffect.TargetConditions.AddItem(AbilityCondition);
	Template.AddTargetEffect(WallbreakEffect);

	Template.CustomFireAnim = 'IRI_DD_Overdrive'; // Purely for perk activation
	Template.bShowActivation = false;
	Template.bSkipFireAction = false;
	Template.bSkipExitCoverWhenFiring = true;

	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	Template.FrameAbilityCameraType = eCameraFraming_Never; 

	Template.PostActivationEvents.AddItem('OverdriveActivated');

	Template.AssociatedPlayTiming = SPT_BeforeSequential;
	
	return Template;
}*/