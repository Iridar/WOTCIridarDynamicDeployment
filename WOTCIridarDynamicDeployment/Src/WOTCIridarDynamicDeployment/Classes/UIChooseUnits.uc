class UIChooseUnits extends UIPersonnel;

var private config(StrategyTuning) StrategyCost	FlatCost;
var private config(StrategyTuning) StrategyCost	PerUnitCost;

var private StrategyCost					TotalCost;
var private array<StrategyCostScalar>		DummyArray;
var private XComGameState_HeadquartersXCom	XComHQ;

// Thanks to RustyDios for the idea to use UIPersonnel.

var int SourcePlayerID;

var private array<XComGameState_Unit> UnitStates;
var private XComGameState_DynamicDeployment DDObject;
var private UILargeButton ConfirmButton;
var private UITacticalHUD TacticalHUD;
var private UIX2ResourceHeader ResourceContainer;

//`include(WOTCIridarSPARKFall\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	DDObject = class'XComGameState_DynamicDeployment'.static.GetOrCreate();

	DDObject.GetUnitStatesEligibleForDynamicDeployment(UnitStates);

	super.InitScreen(InitController, InitMovie, InitName);

	SwitchTab(m_eListType);
	CreateConfirmButton();
	XComHQ = `XCOMHQ;

	if (!IsDeploymentFree())
	{
		`AMLOG("Deployment isn't free, displaying resource bar");
		TacticalHUD = UITacticalHUD(Movie.Pres.ScreenStack.GetScreen(class'UITacticalHUD'));
		TacticalHUD.m_kMouseControls.Hide();
		ResourceContainer = TacticalHUD.Spawn(class'UIX2ResourceHeader', TacticalHUD).InitResourceHeader('IRI_DD_ResourceContainer');
		UpdateResources();
	}
}

simulated function UpdateData()
{
	local XComGameState_Unit UnitState;

	// Destroy old data
	UnitStates.Length = 0;
	DDObject.GetUnitStatesEligibleForDynamicDeployment(UnitStates);

	m_arrSoldiers.Length = 0;
	foreach UnitStates(UnitState)
	{
		m_arrSoldiers.AddItem(UnitState.GetReference());
	}

	if (!IsDeploymentFree())
	{
		UpdateResources();
	}
}


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

	//class'Help'.static.PreloadAssetsForUnit(UnitStates[ItemIndex]);
	`XTACTICALSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	RefreshData();
	UpdateConfirmButtonVisibility();
	UpdateResources();
}

simulated function OnCancel()
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Dynamic Deployment deselect all units");
	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
	DDObject.DeselectAllUnits();
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', 0, SourcePlayerID, NewGameState);
	`GAMERULES.SubmitGameState(NewGameState);

	CloseScreen();
}

function CreateConfirmButton()
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
		ConfirmButton.InitLargeButton('IRI_JP_ConfirmButton', 
		class'UIUtilities_Text'.static.InjectImage(class'UIUtilities_Input'.static.GetAdvanceButtonIcon(), 
		28, 28, iconYOffset) @ `CAPS(class'UIInventory'.default.m_strConfirmButtonLabel));
	}
	else
	{
		ConfirmButton.InitLargeButton('IRI_JP_ConfirmButton', `CAPS(class'UIInventory'.default.m_strConfirmButtonLabel));
	}
	ConfirmButton.DisableNavigation();
	ConfirmButton.AnchorBottomCenter();
	ConfirmButton.OffsetY = -10;
	ConfirmButton.OnClickedDelegate = OnConfirmButtonClicked;
	ConfirmButton.Show();
	ConfirmButton.ShowBG(true);

	UpdateConfirmButtonVisibility();
}

// Button should be disabled if there are no changes to apply to this unit,
// unless we want to copy parts of the soldier's original appearance to other units.
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


private function OnConfirmButtonClicked(UIButton Button)
{	
	local StrategyCost	EmptyCost;	
	local XComGameState	NewGameState;

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
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Global Cooldowns");
		SetGlobalCooldowns(NewGameState);
		`GAMERULES.SubmitGameState(NewGameState);
		//DisplayBanners();
		CloseScreen();
	}
}

private function bool IsDeploymentFree()
{
	local StrategyCost EmptyCost;	

	return FlatCost == EmptyCost && PerUnitCost == EmptyCost;
}

// Displaying too many banners at once makes the whole lot of them bug out and not display properly.
//private function DisplayBanners()
//{
//	local XComGameState_Unit UnitState;
//
//	foreach UnitStates(UnitState)
//	{
//		`PRES.NotifyBanner(`GetLocalizedString("IRI_DD_UnitPreparingForDeployment"), "img:///UILibrary_StrategyImages.X2StrategyMap.MapPin_Landing", UnitState.GetFullName(), "", eUIState_Good);
//	}
//}

private function SetGlobalCooldowns(XComGameState NewGameState)
{
	local int DeployDelay;

	DeployDelay = DDObject.GetDeployDelay();

	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', 99, SourcePlayerID, NewGameState); // Set huge cooldown for now, actual cooldown will be set by the deploy abiltiy
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy', DeployDelay, SourcePlayerID, NewGameState);

	// Put Call Evac ability on cooldown too, cuz Skyranger is busy getting the soldiers for deployment.
	if (class'Help'.static.IsModActive('RequestEvac'))
	{
		class'Help'.static.SetGlobalCooldown(class'CHHelpers'.static.GetPlaceEvacZoneAbilityName(), DeployDelay, SourcePlayerID, NewGameState);
	}
}

private function CalculateTotalCost()
{	
	local int UnitCostMultiplier;
	local int NumSelectedUnits;

	NumSelectedUnits = DDObject.GetNumSelectedUnits();

	`AMLOG("Num selected units:" @ NumSelectedUnits);

	UnitCostMultiplier = -100 * (NumSelectedUnits - 1);

	TotalCost = XComHQ.GetScaledStrategyCost(PerUnitCost, DummyArray, UnitCostMultiplier);

	class'X2StrategyGameRulesetDataStructures'.static.AddCosts(FlatCost, TotalCost);

	`AMLOG("Total cost:" @ TotalCost.ResourceCosts[0].ItemTemplateName @ TotalCost.ResourceCosts[0].Quantity);
	`AMLOG("Total cost:" @ TotalCost.ResourceCosts[1].ItemTemplateName @ TotalCost.ResourceCosts[1].Quantity);
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

	// `XTACTICALSOUNDMGR.PlaySoundEvent("Play_MenuClickNegative");

	if (eAction == 'eUIAction_Accept')
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Pay dynamic deployment cost");
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
		XComHQ.PayStrategyCost(NewGameState, TotalCost, DummyArray);

		SetGlobalCooldowns(NewGameState);

		`GAMERULES.SubmitGameState(NewGameState);

		//DisplayBanners();
		
		CloseScreen();
	}
}

simulated function OnRemoved()
{
	if (ResourceContainer != none)
	{
		TacticalHUD.m_kMouseControls.Show();
		ResourceContainer.Remove();
	}
	super.OnRemoved();
}

simulated function UpdateNavHelp() {} 
simulated function SpawnNavHelpIcons() {} // No nav help in tactical

// --------------------------------------------------------------------------------------------------


//Updated the resources based on the current screen context.
private function UpdateResources()
{
	local ArtifactCost	Cost;
	local string		Label;
	local int			CurrentResource;
	local int			CostResource;
	local string		ResourceString;

	CalculateTotalCost();
	
	ResourceContainer.ClearResources();
	ResourceContainer.Show();
	ResourceContainer.AnimateIn(0);

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

private function UpdateMonthlySupplies()
{
	local int iMonthly;
	local string Monthly, Prefix;

	iMonthly = class'UIUtilities_Strategy'.static.GetResistanceHQ().GetSuppliesReward();
	Prefix = (iMonthly < 0) ? "-" : "+";
	Monthly = class'UIUtilities_Text'.static.GetColoredText("(" $Prefix $ class'UIUtilities_Strategy'.default.m_strCreditsPrefix $ String(int(Abs(iMonthly))) $")", (iMonthly > 0) ? eUIState_Cash : eUIState_Bad);

	AddResource(class'UIAvengerHUD'.default.MonthlyLabel, Monthly);
}

private function UpdateSupplies()
{
	local int iSupplies; 
	local string Supplies, Prefix; 
	
	iSupplies = class'UIUtilities_Strategy'.static.GetResource('Supplies');
	Prefix = (iSupplies < 0) ? "-" : ""; 
	Supplies = class'UIUtilities_Text'.static.GetColoredText(Prefix $ class'UIUtilities_Strategy'.default.m_strCreditsPrefix $ String(iSupplies), (iSupplies > 0) ? eUIState_Cash : eUIState_Bad);

	AddResource(Caps(class'UIUtilities_Strategy'.static.GetResourceDisplayName('Supplies', iSupplies)), Supplies);
}

private function UpdateIntel()
{
	local int iIntel;
	
	iIntel = class'UIUtilities_Strategy'.static.GetResource('Intel');
	AddResource(Caps(class'UIUtilities_Strategy'.static.GetResourceDisplayName('Intel', iIntel)), class'UIUtilities_Text'.static.GetColoredText(String(iIntel), (iIntel > 0) ? eUIState_Normal : eUIState_Bad));
}

private function UpdateEleriumCrystals()
{
	local int iEleriumCrystals;

	iEleriumCrystals = class'UIUtilities_Strategy'.static.GetResource('EleriumDust');
	AddResource(class'UIAvengerHUD'.default.EleriumLabel, class'UIUtilities_Text'.static.GetColoredText(String(iEleriumCrystals), (iEleriumCrystals > 0) ? eUIState_Normal : eUIState_Bad));
}

private function UpdateAlienAlloys()
{
	local int iAlloys;

	iAlloys = class'UIUtilities_Strategy'.static.GetResource('AlienAlloy');
	AddResource(class'UIAvengerHUD'.default.AlloysLabel, class'UIUtilities_Text'.static.GetColoredText(String(iAlloys), (iAlloys > 0) ? eUIState_Normal : eUIState_Bad));
}

private function UpdateEleriumCores()
{
	local int iCores;

	iCores = class'UIUtilities_Strategy'.static.GetResource('EleriumCore');
	AddResource(class'UIAvengerHUD'.default.CoresLabel, class'UIUtilities_Text'.static.GetColoredText(String(iCores), (iCores > 0) ? eUIState_Normal : eUIState_Bad));
}
private function AddResource(string label, string data)
{
	ResourceContainer.AddResource(label, data);
}

defaultproperties
{
	m_eListType = eUIPersonnel_Soldiers
	m_bRemoveWhenUnitSelected = false
	bAutoSelectFirstNavigable = false
	onSelectedDelegate = OnSoldierClicked
	//m_iMaskHeight = 580 // 780 default // Doesn't work anyway
}
