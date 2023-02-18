class UIChooseUnits extends UIPersonnel;

// Displayed in tactical when using Dynamic Select.
// On the surface, identical to the similar screen in strategy.
// Click on the soldier to select them.

// Thanks to RustyDios for the idea to use UIPersonnel.

var XComGameState_Unit SourceUnit;

var private config(StrategyTuning) StrategyCost	FlatCost;
var private config(StrategyTuning) StrategyCost	PerUnitCost;

var private StrategyCost						TotalCost;
var private array<StrategyCostScalar>			DummyArray;
var private XComGameState_HeadquartersXCom		XComHQ;
var private array<XComGameState_Unit>			UnitStates;
var private XComGameState_DynamicDeployment		DDObject;

var private UILargeButton		ConfirmButton;
var private UITacticalHUD		TacticalHUD;
var private UIX2ResourceHeader	ResourceContainer;

// ================================= INIT DATA ==============================================

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	DDObject = class'XComGameState_DynamicDeployment'.static.GetOrCreate();
	DDObject.GetUnitStatesEligibleForDynamicDeployment(UnitStates);

	XComHQ = `XCOMHQ;

	super.InitScreen(InitController, InitMovie, InitName);

	SwitchTab(m_eListType);
	
	CreateConfirmButton();

	TacticalHUD = UITacticalHUD(Movie.Pres.ScreenStack.GetScreen(class'UITacticalHUD'));
	TacticalHUD.m_kMouseControls.Hide(); // Hide the mini-button panel in the upper right corner so we can put a resource panel there instead.
	TacticalHUD.m_kAbilityHUD.Hide();	 // Hide soldier's ability bar, so the Confirm button doesn't look ugly on top of it.

	ResourceContainer = TacticalHUD.Spawn(class'UIX2ResourceHeader', TacticalHUD).InitResourceHeader('IRI_DD_ResourceContainer');
	UpdateResources();
}

// Big green button at the bottom.
private function CreateConfirmButton()
{
	local int iconYOffset;

	ConfirmButton = Spawn(class'UILargeButton', self);
	ConfirmButton.LibID = 'X2ContinueButton';
	ConfirmButton.bHideUntilRealized = true;

	switch (GetLanguage()) 
	{
	case "JPN":
		iconYOffset = -10;
		break;
	case "KOR":
		iconYOffset = -20;
		break;
	default:
		iconYOffset = -15;
		break;
	}
	if(`IsControllerActive)
	{
		ConfirmButton.InitLargeButton('IRI_DD_ConfirmButton', 
		class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetAdvanceButtonIcon(), 
		28, 28, iconYOffset) @ `CAPS(class'UIInventory'.default.m_strConfirmButtonLabel));
	}
	else
	{
		ConfirmButton.InitLargeButton('IRI_DD_ConfirmButton', `CAPS(class'UIInventory'.default.m_strConfirmButtonLabel));
	}
	ConfirmButton.DisableNavigation();
	ConfirmButton.AnchorBottomCenter();
	ConfirmButton.OffsetY = -10;
	ConfirmButton.OnClickedDelegate = OnConfirmButtonClicked;
	ConfirmButton.Show();
	ConfirmButton.ShowBG(true);

	UpdateConfirmButtonVisibility();
}

// ================================= UPDATE DATA ==============================================

simulated function UpdateData()
{
	local XComGameState_Unit UnitState;

	// Destroy old data
	UnitStates.Length = 0;
	m_arrSoldiers.Length = 0;

	DDObject.GetUnitStatesEligibleForDynamicDeployment(UnitStates);

	// Fill the original data array so that base UIPersonnel functions can work properly.
	foreach UnitStates(UnitState)
	{
		m_arrSoldiers.AddItem(UnitState.GetReference());
	}
}

simulated function RefreshData()
{
	super.RefreshData();

	UpdateResources();
	UpdateConfirmButtonVisibility();

	// Somehow sometimes the ability bar becomes visible again if you click fast, so just re-hide it every time.
	TacticalHUD.m_kAbilityHUD.Hide();
}

function UpdateConfirmButtonVisibility()
{
	if (DDObject.IsAnyUnitSelected())
	{
		ConfirmButton.SetDisabled(false, "");
	}
	else
	{
		ConfirmButton.SetDisabled(true, "");  // Disabled reason doesn't seem to be working. Oh well.
	}
}

//Updated the resources based on the current screen context.
private function UpdateResources()
{
	local ArtifactCost	Cost;
	local string		Label;
	local int			CurrentResource;
	local int			CostResource;
	local string		ResourceString;	
	local int			TurnsUntilArrival;
	
	ResourceContainer.ClearResources();
	ResourceContainer.Show(); // ClearResources() uses Hide()
	ResourceContainer.AnimateIn(0);

	// Display number of soldiers for deployment
	ResourceString = DDObject.GetNumSelectedUnits() $ " / " $ DDObject.GetMaxNumSoldiersToSelect();
	ResourceString = class'UIUtilities_Text'.static.GetColoredText(ResourceString, eUIState_Cash);
	ResourceContainer.AddResource(class'XLocalizedData'.default.FacilityGridEngineering_SoldiersLabel, ResourceString);

	// Display "Turns until arrival"
	TurnsUntilArrival = DDObject.GetDeployDelay();
	if (TurnsUntilArrival > 0)
	{
		// class MissionTimers doesn't exist, but localization is there, so use that.
		ResourceContainer.AddResource(Localize("MissionTimers", "NeutralizeFieldCommanderSubtitle", "XComGame"), string(TurnsUntilArrival));
	}

	// Display deployment cost, if any
	CalculateTotalCost();
	foreach TotalCost.ResourceCosts(Cost)
	{
		CostResource = Cost.Quantity;
		if (CostResource == 0) // Cost can be zero if there are no units selected, so the CalculateTotalCost()'s "discount" neuters the per unit cost.
			continue;

		CurrentResource = XComHQ.GetResourceAmount(Cost.ItemTemplateName);

		Label = class'UIUtilities_Strategy'.static.GetResourceDisplayName(Cost.ItemTemplateName, CurrentResource);

		if (CurrentResource > CostResource)
		{
			ResourceString = class'UIUtilities_Text'.static.GetColoredText(string(CurrentResource), eUIState_Cash);
		}
		else
		{
			ResourceString = class'UIUtilities_Text'.static.GetColoredText(string(CurrentResource), eUIState_Bad);
		}

		ResourceString = CurrentResource $ " - " $ class'UIUtilities_Text'.static.GetColoredText(string(CostResource), eUIState_Bad);
		
		ResourceContainer.AddResource(Label, ResourceString);
	}

	foreach TotalCost.ArtifactCosts(Cost)
	{
		CostResource = Cost.Quantity;
		if (CostResource == 0)
			continue;

		CurrentResource = XComHQ.GetResourceAmount(Cost.ItemTemplateName);

		Label = class'UIUtilities_Strategy'.static.GetResourceDisplayName(Cost.ItemTemplateName, CurrentResource);

		if (CurrentResource > CostResource)
		{
			ResourceString = class'UIUtilities_Text'.static.GetColoredText(string(CurrentResource), eUIState_Cash);
		}
		else
		{
			ResourceString = class'UIUtilities_Text'.static.GetColoredText(string(CurrentResource), eUIState_Bad);
		}

		ResourceString = CurrentResource $ " - " $ class'UIUtilities_Text'.static.GetColoredText(string(CostResource), eUIState_Bad);
		
		ResourceContainer.AddResource(Label, ResourceString);
	}
}

// ================================= INTERACTION ==============================================

private function OnSoldierClicked(StateObjectReference UnitRef)
{
	local XComGameState NewGameState;

	if (!DDObject.IsUnitSelected(UnitRef.ObjectID) && !DDObject.CanSelectMoreSoldiers())
	{
		`XTACTICALSOUNDMGR.PlaySoundEvent("Play_MenuClickNegative");
		return;
	}

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Clicked Unit for Dynamic Deployment");

	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
	DDObject.ToggleUnitSelection(UnitRef.ObjectID);
	`GAMERULES.SubmitGameState(NewGameState);

	`XTACTICALSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	RefreshData();
}

// ================================= CONFIRM SELECTION ==============================================

private function OnConfirmButtonClicked(UIButton Button)
{	
	local StrategyCost EmptyCost;	
	
	CalculateTotalCost();

	if (TotalCost != EmptyCost)
	{
		if (XComHQ.CanAffordAllStrategyCosts(TotalCost, DummyArray))
		{
			RaiseConfirmPayCostDialog();
		}
		else
		{	
			RaiseCannotAffordCostDialog();
		}
	}
	else
	{
		FinalizeSelectionAndClose();
	}
}

private function FinalizeSelectionAndClose()
{
	local XComGameState	NewGameState;
	local XGUnit		GameUnit;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Global Cooldowns");
	SetGlobalCooldowns(NewGameState);
	`GAMERULES.SubmitGameState(NewGameState);
	
	CloseScreen();

	MaybeDisplayBanner();

	GameUnit = XGUnit(SourceUnit.GetVisualizer());
	if (GameUnit != none)
	{
		// This line is in the banks, but basegame voices don't appear to have any cues for it, so this probably will never do anything.
		GameUnit.UnitSpeak('RequestReinforcements');
	}
}

// Wanted to display an individual banner for each soldier, 
// but displaying too many banners at once makes the whole lot of them bug out and not display properly. Even with a timer/delay between them.
// Displaying one banner works fine, though.
private function MaybeDisplayBanner()
{
	local string strBannerTitle;
	local string strBannerBody;
	//local string strBannerThirdLine;

	if (DDObject.GetDeployDelay() == 0)
		return;

	// "reinforcements incoming"
	strBannerTitle = class'UITacticalHUD_Countdown'.default.m_strReinforcementsTitle @ class'UITacticalHUD_Countdown'.default.m_strReinforcementsBody;
	
	// "Turns until arrival: "
	strBannerBody = Localize("MissionTimers", "NeutralizeFieldCommanderSubtitle", "XComGame") $ ": " $ DDObject.GetDeployDelay();
	
	`PRES.NotifyBanner(strBannerTitle, "img:///IRIDynamicDeployment_UI.MapPin_DynamicDeployment", strBannerBody, /*strBannerThirdLine*/, eUIState_Good);

	`SOUNDMGR.PlayPersistentSoundEvent("UI_Blade_Positive");
}

private function SetGlobalCooldowns(XComGameState NewGameState)
{
	local int DeployDelay;

	DeployDelay = DDObject.GetDeployDelay();

	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', 99, SourceUnit.ControllingPlayer.ObjectID, NewGameState); // Set huge cooldown for now, actual cooldown will be set by the deploy abiltiy
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy', DeployDelay, SourceUnit.ControllingPlayer.ObjectID, NewGameState);
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy_Spark', DeployDelay, SourceUnit.ControllingPlayer.ObjectID, NewGameState);
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy_Uplink', DeployDelay, SourceUnit.ControllingPlayer.ObjectID, NewGameState);
	

	// Put Request Evac ability on cooldown too, cuz Skyranger is busy getting the soldiers for deployment.
	if (class'Help'.static.IsModActive('RequestEvac'))
	{
		class'Help'.static.SetGlobalCooldown(class'CHHelpers'.static.GetPlaceEvacZoneAbilityName(), DeployDelay, SourceUnit.ControllingPlayer.ObjectID, NewGameState);
	}
}

private function CalculateTotalCost()
{	
	local int UnitCostMultiplier;
	local int NumSelectedUnits;

	NumSelectedUnits = DDObject.GetNumSelectedUnits();

	`AMLOG("Num selected units:" @ NumSelectedUnits);

	// Increase cost by giving a "negative discount" equal to -100% * number of deploying units.
	UnitCostMultiplier = -100 * (NumSelectedUnits - 1);

	TotalCost = XComHQ.GetScaledStrategyCost(PerUnitCost, DummyArray, UnitCostMultiplier);

	class'X2StrategyGameRulesetDataStructures'.static.AddCosts(FlatCost, TotalCost);

	//`AMLOG("Total cost:" @ TotalCost.ResourceCosts[0].ItemTemplateName @ TotalCost.ResourceCosts[0].Quantity);
	//`AMLOG("Total cost:" @ TotalCost.ResourceCosts[1].ItemTemplateName @ TotalCost.ResourceCosts[1].Quantity);
}

private function RaiseCannotAffordCostDialog()
{
	local TDialogueBoxData	kDialogData;
	local string			strText;

	strText = `GetLocalizedString("IRI_DynamicDeployment_CannotAffordDeployment");
	strText = Repl(strText, "%Cost%", class'UIUtilities_Strategy'.static.GetStrategyCostString(TotalCost, DummyArray));

	kDialogData.strTitle = `GetLocalizedString("IRI_DynamicDeployment_CannotAffordDeployment_Title");
	kDialogData.strText = strText;
	kDialogData.eType = eDialog_Alert;
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericOK;

	`PRESBASE.UIRaiseDialog(kDialogData);
}
 
private function RaiseConfirmPayCostDialog()
{
	local TDialogueBoxData kDialogData;
	local string			strText;

	strText = `GetLocalizedString("IRI_DynamicDeployment_ConfirmDeploymentCost");
	strText = Repl(strText, "%Cost%", class'UIUtilities_Strategy'.static.GetStrategyCostString(TotalCost, DummyArray));

	`AMLOG("Strategy cost string:" @ class'UIUtilities_Strategy'.static.GetStrategyCostString(TotalCost, DummyArray));

	kDialogData.strTitle = `GetLocalizedString("IRI_DynamicDeployment_ConfirmDeploymentCost_Title");
	kDialogData.strText = strText;
	kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericConfirm;
	kDialogData.strCancel = class'UISimpleScreen'.default.m_strCancel;
	kDialogData.fnCallback = OnConfirmPayCostDialogCallback;
	kDialogData.eType = eDialog_Normal;
	`PRESBASE.UIRaiseDialog(kDialogData);
}

private function OnConfirmPayCostDialogCallback(Name eAction)
{
	local XComGameState NewGameState;

	if (eAction == 'eUIAction_Accept')
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Pay dynamic deployment cost");
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
		XComHQ.PayStrategyCost(NewGameState, TotalCost, DummyArray);
		`GAMERULES.SubmitGameState(NewGameState);

		FinalizeSelectionAndClose();
	}
}

// ================================= CANCEL ==============================================

simulated function OnCancel()
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Dynamic Deployment deselect all units");
	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
	DDObject.DeselectAllUnits();
	`GAMERULES.SubmitGameState(NewGameState);

	CloseScreen();
}

// ================================= CLEANUP ==============================================

simulated function OnRemoved()
{
	if (ResourceContainer != none)
	{
		TacticalHUD.m_kMouseControls.Show();
		TacticalHUD.m_kAbilityHUD.Show();
		ResourceContainer.Remove();
	}
	super.OnRemoved();
}

// --------------------------------------------------------------------------------------------------

simulated function UpdateNavHelp() {} 
simulated function SpawnNavHelpIcons() {} // No nav help in tactical

defaultproperties
{
	m_eListType = eUIPersonnel_Soldiers
	m_bRemoveWhenUnitSelected = false
	bAutoSelectFirstNavigable = false
	onSelectedDelegate = OnSoldierClicked
	//m_iMaskHeight = 580 // 780 default // Doesn't work anyway
}
