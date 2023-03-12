class UIChooseUnits extends UIPersonnel;

// Displayed in tactical when using Dynamic Select.
// On the surface, identical to the similar screen in strategy.
// Click on the soldier to select them.

// Thanks to RustyDios for the idea to use UIPersonnel.

var XComGameState_Unit SourceUnit;

var private XComGameState_HeadquartersXCom		XComHQ;
var private array<XComGameState_Unit>			UnitStates;
var private XComGameState_DynamicDeployment		DDObject;

var private UILargeButton		ConfirmButton;
var private UITacticalHUD		TacticalHUD;

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
	TacticalHUD.m_kAbilityHUD.Hide();	 // Hide soldier's ability bar, so the Confirm button doesn't look ugly on top of it.
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

	UpdateConfirmButtonVisibility();

	// Somehow sometimes the ability bar becomes visible again if you click fast, so just re-hide it every time.
	TacticalHUD.m_kAbilityHUD.Hide();
}

// The code around overriding unit's status display text, including override events, is a goddamn mess.
// To do what I wanted to do, which is to display an icon instead of the "X DAYS" status text,
// I had to copy the UpdateListItemData() from UIPersonnel_SoldierListItem and remove the bits that were interfering with it.
// The problem was that the override status text can be given only if the override to not show unit's mental status is enabled,
// which looks bad and doesn't make any sense, and I kinda want the mental status to be there.
//simulated function PopulateListInstantly()
//{
//	local UIPersonnel_SoldierListItem	kItem;
//	local StateObjectReference			SoldierRef;
//	local array<StateObjectReference>	CurrentData;
//	local XComGameState_Unit			UnitState;
//	local array<XComGameState_Unit>		LocUnitStates;
//	local XComGameStateHistory			History;
//
//	History = `XCOMHISTORY;
//	CurrentData = GetCurrentData();
//	foreach CurrentData(SoldierRef)
//	{
//		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(SoldierRef.ObjectID));
//		if (UnitState == none) continue;
//
//		LocUnitStates.AddItem(UnitState);
//	}
//
//	foreach LocUnitStates(UnitState)
//	{
//		kItem = Spawn(class'UIPersonnel_SoldierListItem', m_kList.itemContainer);
//		
//		kItem.InitListItem(UnitState.GetReference());
//	}
//
//	MC.FunctionString("SetEmptyLabel", CurrentData.Length == 0 ? m_strEmptyListLabels[m_eCurrentTab] : "");
//}


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

// ================================= INTERACTION ==============================================

private function OnSoldierClicked(StateObjectReference UnitRef)
{
	local XComGameState NewGameState;

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
	local XComGameState			NewGameState;
	local XGUnit				GameUnit;
	local XComGameState_Unit	UnitState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Set Global Cooldowns");
	
	// Then mark deploying units as in Skyranger. So that if the player calls for evac
	// before deploying the units, they still can deploy them on the evac zone.
	// Needs to be done in that order, because units in Skyranger do not impose a delay.
	UnitStates = DDObject.GetUnitsToDeploy();
	foreach UnitStates(UnitState)
	{
		class'Help'.static.MarkUnitInSkyranger(UnitState, NewGameState);
	}
	`GAMERULES.SubmitGameState(NewGameState);
	
	CloseScreen();

	GameUnit = XGUnit(SourceUnit.GetVisualizer());
	if (GameUnit != none)
	{
		// This line is in the banks, but basegame voices don't appear to have any cues for it, so this probably will never do anything.
		GameUnit.UnitSpeak('RequestReinforcements');
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
	TacticalHUD.m_kAbilityHUD.Show();
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
