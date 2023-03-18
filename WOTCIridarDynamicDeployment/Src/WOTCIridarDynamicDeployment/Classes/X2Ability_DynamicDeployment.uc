class X2Ability_DynamicDeployment extends X2Ability;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(IRI_DynamicDeployment_Select());
	Templates.AddItem(IRI_DynamicDeployment_Deploy());
	Templates.AddItem(IRI_DynamicDeployment_Deploy_Spark());
	Templates.AddItem(IRI_DynamicDeployment_Deploy_Uplink());

	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_PrecisionDrop', "img:///IRIDynamicDeployment_UI.UIPerk_PrecisionDrop"));
	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_FirstAid', "img:///IRIDynamicDeployment_UI.UIPerk_PrecisionDrop")); // TODO: Icon //TODO: THis needs to be a pure passive for the icon
	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_AerialScout', "img:///IRIDynamicDeployment_UI.UIPerk_AerialScout"));
	Templates.AddItem(CreatePassiveDDUnlock('IRI_DDUnlock_DigitalUplink', "img:///IRIDynamicDeployment_UI.UIPerk_DigitalUplink"));
	Templates.AddItem(IRI_DDUnlock_TakeAndHold());
	Templates.AddItem(PurePassive('IRI_DDUnlock_TakeAndHold_Passive', "img:///IRIDynamicDeployment_UI.UIPerk_TakeAndHold",, 'eAbilitySource_Commander'));
	Templates.AddItem(IRI_DDUnlock_HitGroundRunning());
	Templates.AddItem(PurePassive('IRI_DDUnlock_HitGroundRunning_Passive', "img:///IRIDynamicDeployment_UI.UIPerk_HitGroundRunning",, 'eAbilitySource_Commander'));

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
	// In case you get dead'ed by overwatch or something
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

	Template.AdditionalAbilities.AddItem('IRI_DDUnlock_HitGroundRunning_Passive');
	
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
	// In case you get dead'ed by overwatch or something
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	
	// Effects
	TakeAndHold = new class'X2Effect_TakeAndHold';
	TakeAndHold.BuildPersistentEffect(`GetConfigInt("IRI_DD_TakeAndHold_DurationTurns"), false, true, false, eGameRule_PlayerTurnBegin);
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

	Template.AdditionalAbilities.AddItem('IRI_DDUnlock_TakeAndHold_Passive');
	
	return Template;
}

static private function X2AbilityTemplate CreatePassiveDDUnlock(const name TemplateName, const string strImage)
{
	local X2AbilityTemplate Template;
	local X2Effect_Persistent PersistentEffect;

	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);

	// Icon Setup
	Template.IconImage = strImage;
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_NeverShow;

	Template.bDisplayInUITacticalText = false;
	Template.bHideOnClassUnlock = true;
	Template.bDisplayInUITooltip = false;
	Template.bDontDisplayInAbilitySummary = false;

	// Dummy effect for the UI icon
	PersistentEffect = new class'X2Effect_Persistent';
	PersistentEffect.BuildPersistentEffect(1, true, false);
	PersistentEffect.SetDisplayInfo(ePerkBuff_Passive, Template.LocFriendlyName, Template.LocLongDescription, strImage, true,, Template.AbilitySourceName);
	Template.AddTargetEffect(PersistentEffect);

	// Targeting and Triggering
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(new class'X2AbilityTrigger_Placeholder');
	
	// State and Vis
	Template.Hostility = eHostility_Neutral;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	
	return Template;
}

static private function X2AbilityTemplate IRI_DynamicDeployment_Select()
{
	local X2AbilityTemplate				Template;
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
	
	// Cost
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bFreeCost = `GETMCMVAR(DD_SOLDIER_SELECT_IS_FREE_ACTION);
	ActionPointCost.bConsumeAllPoints = `GETMCMVAR(DD_SOLDIER_SELECT_ENDS_TURN);
	Template.AbilityCosts.AddItem(ActionPointCost);

	// Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	Template.AbilityShooterConditions.AddItem(new class'X2Condition_DynamicDeployment');

	// Targeting and Triggering
	Template.AbilityToHitCalc = default.DeadEye;
	Template.AbilityTargetStyle = default.SelfTarget;
	Template.AbilityTriggers.AddItem(default.PlayerInputTrigger);
	
	// State and Vis
	Template.Hostility = eHostility_Neutral;
	Template.bSkipExitCoverWhenFiring = true;
	Template.bSkipFireAction = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = DynamicDeployment_Select_BuildVisualization;
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;

	Template.AdditionalAbilities.AddItem('IRI_DynamicDeployment_Deploy');
	Template.AdditionalAbilities.AddItem('IRI_DynamicDeployment_Deploy_Spark');
	Template.AdditionalAbilities.AddItem('IRI_DynamicDeployment_Deploy_Uplink');
	
	return Template;
}

static final function DynamicDeployment_Select_BuildVisualization(XComGameState VisualizeGameState)
{
	local XComGameStateHistory			History;
	local XComGameStateContext_Ability  Context;
	local StateObjectReference          ShootingUnitRef;	
	local X2Action_PlayAnimation		PlayAnimation;
	local VisualizationActionMetadata	ActionMetadata;
	local X2Action_TimedWait			TimedWait;
	local X2Action						CommonParent;
	local XComGameState_Unit			UnitState;

	History = `XCOMHISTORY;
	Context = XComGameStateContext_Ability(VisualizeGameState.GetContext());

	ShootingUnitRef = Context.InputContext.SourceObject;
	UnitState = XComGameState_Unit(VisualizeGameState.GetGameStateForObjectID(ShootingUnitRef.ObjectID));

	ActionMetadata.StateObject_OldState = History.GetGameStateForObjectID(ShootingUnitRef.ObjectID, eReturnType_Reference, VisualizeGameState.HistoryIndex - 1);
	ActionMetadata.StateObject_NewState = UnitState;
	ActionMetadata.VisualizeActor = History.GetVisualizer(ShootingUnitRef.ObjectID);

	CommonParent = class'X2Action_MarkerTreeInsertBegin'.static.AddToVisualizationTree(ActionMetadata, Context);

	PlayAnimation = X2Action_PlayAnimation(class'X2Action_PlayAnimation'.static.AddToVisualizationTree(ActionMetadata, Context, false, CommonParent));

	if (UnitState != none && class'Help'.static.IsCharTemplateSparkLike(UnitState.GetMyTemplate()))
	{
		PlayAnimation.Params.AnimName = 'HL_SignalPositivePost';
	}
	else
	{
		PlayAnimation.Params.AnimName = 'HL_CallReinforcements';
	}
		
	// Use a delay to display the screen some time into the animation, but don't wait for it to complete fully.
	TimedWait = X2Action_TimedWait(class'X2Action_TimedWait'.static.AddToVisualizationTree(ActionMetadata, Context, false, CommonParent));
	TimedWait.DelayTimeSec = 1.5f;

	class'X2Action_SelectUnits'.static.AddToVisualizationTree(ActionMetadata, Context, false, TimedWait);
}


static private function X2AbilityTemplate CreateDeploymentAbility(const name TemplateName)
{
	local X2AbilityTemplate					Template;
	local X2AbilityCost_ActionPoints		ActionPointCost;
	local X2AbilityTarget_Cursor			CursorTarget;
	local X2AbilityMultiTarget_Radius		RadiusMultiTarget;
	local X2Effect_AerialScout				AerialScout;

	`CREATE_X2ABILITY_TEMPLATE(Template, TemplateName);

	// Icon Setup
	Template.IconImage = "img:///IRIDynamicDeployment_UI.UIPerk_DynamicDeploy";
	Template.ShotHUDPriority = class'UIUtilities_Tactical'.const.PLACE_EVAC_PRIORITY + 5;
	Template.AbilitySourceName = 'eAbilitySource_Commander';
	Template.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
	Template.OverrideAbilityAvailabilityFn = DDDeploy_OverrideAbilityAvailability;

	Template.bDisplayInUITacticalText = false;
	Template.bHideOnClassUnlock = true;
	Template.bDisplayInUITooltip = false;

	// Cost
	ActionPointCost = new class'X2AbilityCost_ActionPoints';
	ActionPointCost.iNumPoints = 1;
	ActionPointCost.bFreeCost = `GETMCMVAR(DD_DEPLOY_IS_FREE_ACTION);
	ActionPointCost.bConsumeAllPoints = `GETMCMVAR(DD_DEPLOY_ENDS_TURN);
	Template.AbilityCosts.AddItem(ActionPointCost);

	// Shooter Conditions
	Template.AbilityShooterConditions.AddItem(default.LivingShooterProperty);
	Template.AddShooterEffectExclusions();

	Template.AbilityShooterConditions.AddItem(new class'X2Condition_DynamicDeployment');

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
	Template.bAllowUnderhandAnim = true;
	Template.Hostility = eHostility_Neutral;
	Template.bSkipExitCoverWhenFiring = false;
	Template.ActivationSpeech = 'InDropPosition';
	Template.bHideWeaponDuringFire = true;
	Template.BuildNewGameStateFn = TypicalAbility_BuildGameState;
	Template.BuildVisualizationFn = TypicalAbility_BuildVisualization;
	//Template.FrameAbilityCameraType = eCameraFraming_Never; // Using custom camera work in X2Effect_DD instead.
	
	Template.ChosenActivationIncreasePerUse = class'X2AbilityTemplateManager'.default.NonAggressiveChosenActivationIncreasePerUse;
	Template.LostSpawnIncreasePerUse = class'X2AbilityTemplateManager'.default.StandardShotLostSpawnIncreasePerUse;
	
	return Template;
}

// Fancy abilities set up in a complicated way.
// Perk Content adds perk weapon XComWeapon to this ability.
// Depending on deployment method,
// The visible mesh of the weapon during the fire animation is swapped by the custom fire action
// while the projectile mesh is covered by the custom projectile archetype.

static private function X2AbilityTemplate IRI_DynamicDeployment_Deploy()
{
	local X2AbilityTemplate Template;

	Template = CreateDeploymentAbility('IRI_DynamicDeployment_Deploy');

	Template.AbilityShooterConditions.AddItem(new class'X2Condition_NotSparkLike');
	Template.AbilityShooterConditions.AddItem(new class'X2Condition_NotDigitalUplink');

	Template.ActionFireClass = class'X2Action_Fire_Deployment';
	Template.CustomFireAnim = 'FF_Grenade';
	Template.CinescriptCameraType = "StandardGrenadeFiring";

	Template.ConcealmentRule = eConceal_Never;
	Template.SuperConcealmentLoss = 100;

	return Template;
}


// Separate version for SPARKs so they can use a different version of PerkContent with a different PerkWeapon
// for the sake of different shooter animations, otherwise identical.
static private function X2AbilityTemplate IRI_DynamicDeployment_Deploy_Spark()
{
	local X2AbilityTemplate Template;

	Template = CreateDeploymentAbility('IRI_DynamicDeployment_Deploy_Spark');

	Template.AbilityShooterConditions.AddItem(new class'X2Condition_SparkLike');
	Template.AbilityShooterConditions.AddItem(new class'X2Condition_NotDigitalUplink');

	Template.ActionFireClass = class'X2Action_Fire_Deployment';
	Template.CustomFireAnim = 'FF_Grenade';

	Template.ConcealmentRule = eConceal_Never;
	Template.SuperConcealmentLoss = 100;

	return Template;
}

// Separate version with no perk content, used by both sparks and soldiers.
static private function X2AbilityTemplate IRI_DynamicDeployment_Deploy_Uplink()
{
	local X2AbilityTemplate Template;
	local X2AbilityTarget_Cursor CursorTarget;

	Template = CreateDeploymentAbility('IRI_DynamicDeployment_Deploy_Uplink');

	Template.AbilityShooterConditions.AddItem(new class'X2Condition_DigitalUplink');

	// Anywhere within squad's vision
	CursorTarget = new class'X2AbilityTarget_Cursor';
	CursorTarget.bRestrictToSquadsightRange = `GETMCMVAR(SQUAD_MUST_SEE_TILE);
	Template.AbilityTargetStyle = CursorTarget;

	Template.TargetingMethod = class'X2TargetingMethod_DigitalUplink';

	Template.AbilityShooterEffects.InsertItem(0, new class'X2Effect_ParticleEffect');

	Template.CustomFireAnim = 'FF_Deploy_Uplink';

	return Template;
}

static private function DDSelect_OverrideAbilityAvailability(out AvailableAction Action, XComGameState_Ability AbilityState, XComGameState_Unit OwnerState)
{
	local XComGameState_DynamicDeployment DDObject;

	`AMLOG("Running");

	// Special handle first deployment of the mission.
	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment', true));
	if (DDObject == none) 
	{
		Action.eAbilityIconBehaviorHUD = eAbilityIconBehavior_AlwaysShow;
		return;
	}

	// Hide jf already have some soldiers selected for deployment
	if (DDObject.bPendingDeployment) 
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

static private function DDDeploy_OverrideAbilityAvailability(out AvailableAction Action, XComGameState_Ability AbilityState, XComGameState_Unit OwnerState)
{
	local XComGameState_DynamicDeployment DDObject;

	// Hide if no unit selected for deployment
	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment', true));
	if (DDObject == none || !DDObject.IsAnyUnitSelected() || !DDObject.bPendingDeployment) 
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


// Scrapped, because I didn't want DD to mess with the action economy.
// You wanna overdrive - do it yourself after deployment.
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