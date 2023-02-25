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

	// There's no good time for us to deselect units at any point after deployment,
	// so do it before entering screen instead.
	DeselectAllUnits();
	XComHQ = `XCOMHQ;

	m_strButtonValues[ePersonnelSoldierSortType_Status] = class'UIUtilities_Text'.static.GetSizedText(class'UIChallengeMode_SquadSelect'.default.m_strLocationLabel, 12);
	
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

// The code around overriding unit's status display text, including override events, is a goddamn mess.
// To do what I wanted to do, which is to display an icon instead of the "X DAYS" status text,
// I had to copy the UpdateListItemData() from UIPersonnel_SoldierListItem and remove the bits that were interfering with it.
// The problem was that the override status text can be given only if the override to not show unit's mental status is enabled,
// which looks bad and doesn't make any sense, and I kinda want the mental status to be there.
simulated function PopulateListInstantly()
{
	local UIPersonnel_SoldierListItem	kItem;
	local StateObjectReference			SoldierRef;
	local array<StateObjectReference>	CurrentData;
	local XComGameState_Unit			UnitState;
	local array<XComGameState_Unit>		LocUnitStates;
	local XComGameStateHistory			History;

	History = `XCOMHISTORY;
	CurrentData = GetCurrentData();
	foreach CurrentData(SoldierRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SoldierRef.ObjectID));
		if (UnitState == none) continue;

		LocUnitStates.AddItem(UnitState);
	}
	LocUnitStates.Sort(SortUnitsByLocation); // Put units in Skyranger at the start of the list.

	foreach LocUnitStates(UnitState)
	{
		kItem = Spawn(class'UIPersonnel_SoldierListItem', m_kList.itemContainer);
		
		kItem.InitListItem(UnitState.GetReference());
		UpdateListItemData(kItem);
	}

	MC.FunctionString("SetEmptyLabel", CurrentData.Length == 0 ? m_strEmptyListLabels[m_eCurrentTab] : "");
}

static private function int SortUnitsByLocation(XComGameState_Unit UnitStateA, XComGameState_Unit UnitStateB)
{
	local bool bInSkyrangerA;
	local bool bInSkyrangerB;

	bInSkyrangerA = class'Help'.static.IsUnitInSkyranger(UnitStateA);
	bInSkyrangerB = class'Help'.static.IsUnitInSkyranger(UnitStateB);

	if (bInSkyrangerA && !bInSkyrangerB)
	{
		return 1;
	}
	if (!bInSkyrangerA && bInSkyrangerB)
	{
		return -1;
	}
	return 0;
}

private function UpdateListItemData(UIPersonnel_SoldierListItem kItem)
{
	local XComGameState_Unit Unit;
	local string UnitLoc, status, statusTimeLabel, statusTimeValue, classIcon, rankIcon, flagIcon, mentalStatus;	
	local X2SoldierClassTemplate SoldierClass;
	//local XComGameState_ResistanceFaction FactionState; //Issue #1134, not needed
	local SoldierBond BondData;
	local StateObjectReference BondmateRef;
	local int BondLevel; 

	Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(kItem.UnitRef.ObjectID));
	
	SoldierClass = Unit.GetSoldierClassTemplate();
	//FactionState = Unit.GetResistanceFaction(); //Issue #1134, not needed

	class'UIUtilities_Strategy'.static.GetPersonnelStatusSeparate(Unit, status, statusTimeLabel, statusTimeValue);
	mentalStatus = "";

	// Go fox yourself, issue 651
	//if(ShouldDisplayMentalStatus(Unit)) // Issue #651
	//{
	//	Unit.GetMentalStateStringsSeparate(mentalStatus, statusTimeLabel, iTimeNum);
	//	statusTimeLabel = class'UIUtilities_Text'.static.GetColoredText(statusTimeLabel, Unit.GetMentalStateUIState());
	//
	//	if(iTimeNum == 0)
	//	{
	//		statusTimeValue = "";
	//	}
	//	else
	//	{
	//		statusTimeValue = class'UIUtilities_Text'.static.GetColoredText(string(iTimeNum), Unit.GetMentalStateUIState());
	//	}
	//}


	if( statusTimeValue == "" )
		statusTimeValue = "---";

	flagIcon = Unit.GetCountryTemplate().FlagImage;
	rankIcon = Unit.GetSoldierRankIcon(); // Issue #408
	// Start Issue #106
	classIcon = Unit.GetSoldierClassIcon();
	// End Issue #106

	// if personnel is not staffed, don't show location
	if( class'UIUtilities_Strategy'.static.DisplayLocation(Unit) )
		UnitLoc = class'UIUtilities_Strategy'.static.GetPersonnelLocation(Unit);
	else
		UnitLoc = "";

	//if( kItem.BondIcon == none )
	//{
	//	kItem.BondIcon = kItem.Spawn(class'UIBondIcon', kItem);
	//	if( `ISCONTROLLERACTIVE ) 
	//		kItem.BondIcon.bIsNavigable = false; 
	//}
	//
	//if( Unit.HasSoldierBond(BondmateRef, BondData) )
	//{
	//	Bondmate = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(BondmateRef.ObjectID));
	//	BondLevel = BondData.BondLevel;
	//	if( !kItem.BondIcon.bIsInited )
	//	{
	//		BondIcon.InitBondIcon('UnitBondIcon', BondData.BondLevel, , BondData.Bondmate);
	//	}
	//	BondIcon.Show();
	//	SetTooltipText(Repl(BondmateTooltip, "%SOLDIERNAME", Caps(Bondmate.GetName(eNameType_RankFull))));
	//	Movie.Pres.m_kTooltipMgr.TextTooltip.SetUsePartialPath(CachedTooltipID, true);
	//}
	//else if( Unit.ShowBondAvailableIcon(BondmateRef, BondData) )
	//{
	//	BondLevel = BondData.BondLevel;
	//	if( !BondIcon.bIsInited )
	//	{
	//		BondIcon.InitBondIcon('UnitBondIcon', BondData.BondLevel, , BondmateRef);
	//	}
	//	BondIcon.Show();
	//	BondIcon.AnimateCohesion(true);
	//	SetTooltipText(class'XComHQPresentationLayer'.default.m_strBannerBondAvailable);
	//	Movie.Pres.m_kTooltipMgr.TextTooltip.SetUsePartialPath(CachedTooltipID, true);
	//}
	//else
	//{
	//	if( !BondIcon.bIsInited )
	//	{
	//		BondIcon.InitBondIcon('UnitBondIcon', BondData.BondLevel, , BondData.Bondmate);
	//	}
	//	BondIcon.Hide();
	//	BondLevel = -1; 
	//}

	if( Unit.HasSoldierBond(BondmateRef, BondData) )
	{
		BondLevel = BondData.BondLevel;
	}

	if (DDObject.IsUnitSelected(Unit.ObjectID))
	{
		status = class'UIUtilities_Text'.static.GetColoredText(`GetLocalizedString("IRI_DynamicDeployment_DeployingStatus"), eUIState_Warning);
	}

	
	if (class'Help'.static.IsUnitInSkyranger(Unit))
	{
		//statusTimeValue = "<img src='img:///IRIDynamicDeployment_UI.Skyranger' width='48' height='32' vspace='-24'>";
		statusTimeValue = "\n" $ `CAPS(class'UIControllerMap'.default.m_sSkyranger);
		statusTimeValue = class'UIUtilities_Text'.static.GetSizedText(statusTimeValue, 14);
		//statusTimeValue = class'UIUtilities_Text'.static.GetColoredText(statusTimeValue, eUIState_Highlight);
	}
	else
	{
		//statusTimeValue = "<img src='img:///IRIDynamicDeployment_UI.Avenger' width='48' height='48' vspace='-12'>";
		statusTimeValue = "\n" $ `CAPS(class'UIControllerMap'.default.m_sAvenger);
		statusTimeValue = class'UIUtilities_Text'.static.GetSizedText(statusTimeValue, 14);
		//statusTimeValue = class'UIUtilities_Text'.static.GetColoredText(statusTimeValue, eUIState_Normal);
	}
	 

	// Start Issue #106, #408
	kItem.AS_UpdateDataSoldier(Caps(Unit.GetName(eNameType_Full)),
					Caps(Unit.GetName(eNameType_Nick)),
					Caps(Unit.GetSoldierShortRankName()),
					rankIcon,
					Caps(SoldierClass != None ? Unit.GetSoldierClassDisplayName() : ""),
					classIcon,
					status,
					statusTimeValue /*statusTimeValue $"\n" $ Class'UIUtilities_Text'.static.CapsCheckForGermanScharfesS(Class'UIUtilities_Text'.static.GetSizedText( statusTimeLabel, 12))*/,
					UnitLoc,
					flagIcon,
					false, //todo: is disabled 
					Unit.ShowPromoteIcon(),
					false, // psi soldiers can't rank up via missions
					mentalStatus,
					BondLevel);
	// End Issue #106, #408

	// Would be done already by this point. --Iridar
	//Issue #295 - Add a 'none' check before accessing FactionState --> Issue #1134 replaces this fix
	// Start Issue #1134
	//StackedClassIcon = Unit.GetStackedClassIcon();
	//if (StackedClassIcon.Images.Length > 0)
	//{
	//	AS_SetFactionIcon(StackedClassIcon);
	//}
	//else
	//{
	//	// Preserve backwards compatibility in case AS_SetFactionIcon() is overridden via an MCO.
	//	AS_SetFactionIcon(EmptyIconInfo);
	//}
	// End Issue #1134
}

/*	eUIState_Normal,
	eUIState_Faded,
	eUIState_Header,
	eUIState_Disabled,
	eUIState_Good,
	eUIState_Bad,
	eUIState_Warning,
	eUIState_Highlight,
	eUIState_Cash,
	eUIState_Psyonic,
	eUIState_Warning2,
	eUIState_TheLost*/

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
	local XComGameState			NewGameState;
	local XGUnit				GameUnit;
	local XComGameState_Unit	UnitState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Global Cooldowns");

	// Put the deploy ability on cooldown
	SetGlobalCooldowns(NewGameState);
	
	// Then mark deploying units as in Skyranger. So that if the player calls for evac
	// before deploying the units, they still can deploy them on the evac zone.
	// Needs to be done in that order, because units in Skyranger do not impose a delay.
	UnitStates = DDObject.GetUnitsToDeploy();
	foreach UnitStates(UnitState)
	{
		class'Help'.static.MarkUnitInSkyranger(UnitState);
	}
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

	class'Help'.static.SetDynamicDeploymentCooldown(DeployDelay, SourceUnit.ControllingPlayer.ObjectID, NewGameState);
	
	// Put Request Evac ability on cooldown too, cuz Skyranger is busy getting the soldiers for deployment.
	class'Help'.static.SetGlobalCooldown(class'CHHelpers'.static.GetPlaceEvacZoneAbilityName(), DeployDelay, SourceUnit.ControllingPlayer.ObjectID, NewGameState);
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
	DeselectAllUnits();
	CloseScreen();
}

private function DeselectAllUnits()
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Dynamic Deployment deselect all units");
	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
	DDObject.DeselectAllUnits();
	`GAMERULES.SubmitGameState(NewGameState);
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
