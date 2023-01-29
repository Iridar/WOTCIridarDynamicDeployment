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

//`include(WOTCIridarSPARKFall\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	DDObject = class'XComGameState_DynamicDeployment'.static.GetOrCreate();

	DDObject.GetUnitStatesEligibleForDynamicDeployment(UnitStates);

	super.InitScreen(InitController, InitMovie, InitName);

	SwitchTab(m_eListType);
	CreateConfirmButton();
	XComHQ = `XCOMHQ;
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
	local StrategyCost EmptyCost;	
	local int DeployDelay;

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
		DeployDelay = DDObject.GetDeployDelay();

		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', 99, SourcePlayerID); // Set huge cooldown for now, actual cooldown will be set by the deploy abiltiy
		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy', DeployDelay, SourcePlayerID);
		class'Help'.static.SetGlobalCooldown(class'CHHelpers'.static.GetPlaceEvacZoneAbilityName(), DeployDelay, SourcePlayerID);
		CloseScreen();
	}
}

private function CalculateTotalCost()
{	
	local int UnitCostMultiplier;

	UnitCostMultiplier = -100 * DDObject.GetNumSelectedUnits();

	TotalCost = XComHQ.GetScaledStrategyCost(PerUnitCost, DummyArray, UnitCostMultiplier);

	class'X2StrategyGameRulesetDataStructures'.static.AddCosts(FlatCost, TotalCost);
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
	local int DeployDelay;

	// `XTACTICALSOUNDMGR.PlaySoundEvent("Play_MenuClickNegative");

	if (eAction == 'eUIAction_Accept')
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Pay dynamic deployment cost");
		XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
		XComHQ.PayStrategyCost(NewGameState, TotalCost, DummyArray);

		DeployDelay = DDObject.GetDeployDelay();

		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', 99, SourcePlayerID, NewGameState);
		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy', DeployDelay, SourcePlayerID, NewGameState);
		class'Help'.static.SetGlobalCooldown(class'CHHelpers'.static.GetPlaceEvacZoneAbilityName(), DeployDelay, SourcePlayerID, NewGameState);

		`GAMERULES.SubmitGameState(NewGameState);

		CloseScreen();
	}
}

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
