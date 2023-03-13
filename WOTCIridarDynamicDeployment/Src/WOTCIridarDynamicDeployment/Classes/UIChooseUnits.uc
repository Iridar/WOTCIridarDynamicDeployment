class UIChooseUnits extends UIPersonnel;

// Displayed in tactical when using Dynamic Select.
// On the surface, identical to the similar screen in strategy.
// Click on the soldier to select them.

// Thanks to RustyDios for the idea to use UIPersonnel.

var protected XComGameState_HeadquartersXCom	XComHQ;
var protected array<XComGameState_Unit>			UnitStates;
var protected XComGameState_DynamicDeployment	DDObject;

var protected UILargeButton		ConfirmButton;
var protected UITacticalHUD		TacticalHUD;

// ================================= INIT DATA ==============================================

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	DDObject = class'XComGameState_DynamicDeployment'.static.GetOrCreate();
	DDObject.GetUnitStatesEligibleForDynamicDeployment(UnitStates);

	TacticalHUD = UITacticalHUD(Movie.Pres.ScreenStack.GetScreen(class'UITacticalHUD'));

	// There's no good time for us to deselect units at any point after deployment,
	// so do it before entering screen instead.
	DeselectAllUnits();
	XComHQ = `XCOMHQ;

	//m_strButtonValues[ePersonnelSoldierSortType_Status] = class'UIUtilities_Text'.static.GetSizedText(class'UIChallengeMode_SquadSelect'.default.m_strLocationLabel, 12);
	
	super.InitScreen(InitController, InitMovie, InitName);

	SwitchTab(m_eListType);
	
	CreateConfirmButton();

	TacticalHUD.m_kAbilityHUD.Hide();	 // Hide soldier's ability bar, so the Confirm button doesn't look ugly on top of it.
}

// Big green button at the bottom.
protected function CreateConfirmButton()
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

protected function UpdateConfirmButtonVisibility()
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

protected function OnSoldierClicked(StateObjectReference UnitRef)
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

protected function OnConfirmButtonClicked(UIButton Button)
{	
	CloseScreen();
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
