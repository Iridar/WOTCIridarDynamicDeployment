class UIChooseUnits extends UIPersonnel;

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

	// This prevents the Deploy ability from being used until the specified number of turns passes
	//class'Help'.static.SetGlobalCooldown('IRI_SparkFall_Deploy', `GETMCMVAR(DEPLOY_DELAY_TUNRS), SourcePlayerID, NewGameState);

	`GAMERULES.SubmitGameState(NewGameState);

	//class'Help'.static.PreloadAssetsForUnit(UnitStates[ItemIndex]);
	`XTACTICALSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	RefreshData();
	UpdateConfirmButtonVisibility();
}

simulated function OnCancel()
{
	local XComGameState NewGameState;

	//class'Help'.static.SetGlobalCooldown('IRI_SparkFall', 0, SourcePlayerID);

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Dynamic Deployment deselect all units");
	DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
	DDObject.DeselectAllUnits();
	`GAMERULES.SubmitGameState(NewGameState);

	CloseScreen();
}

simulated function UpdateNavHelp() {} 
simulated function SpawnNavHelpIcons() {} // No nav help in tactical


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
	DDObject.PreloadAssets();
	CloseScreen();
}


defaultproperties
{
	m_eListType = eUIPersonnel_Soldiers
	m_bRemoveWhenUnitSelected = false
	bAutoSelectFirstNavigable = false
	onSelectedDelegate = OnSoldierClicked
	//m_iMaskHeight = 580 // 780 default // Doesn't work anyway
}
