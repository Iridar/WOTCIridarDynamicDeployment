class UIChooseUnits extends UIPersonnel;

// Displayed in squad select when clicking the Launch Mission button. 
// Click on the soldier to select them.

// Thanks to RustyDios for the idea to use UIPersonnel.

var private XComGameState_HeadquartersXCom	XComHQ;
var private array<XComGameState_Unit>		UnitStates;
var private XComGameState_DynamicDeployment	DDObject;

var private UILargeButton					ConfirmButton;
var private UITacticalHUD					TacticalHUD;

var private XComGameStateHistory			History;
var private X2EventManager					EventMgr;
var private int								NumRepeatedClicks;

// ================================= INIT DATA ==============================================

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	local Object SelfObj;

	XComHQ = `XCOMHQ;
	History = `XCOMHISTORY;
	EventMgr = `XEVENTMGR;

	m_strButtonValues[ePersonnelSoldierSortType_Status] = "";
	m_strButtonLabels[ePersonnelSoldierSortType_Status] = "DEPLOYMENT";

	// Low priority to make sure we have the last word
	SelfObj = self;
	EventMgr.RegisterForEvent(SelfObj, 'OverridePersonnelStatus', OnOverridePersonnelStatus, ELD_Immediate, 10, ,, );
	
	super.InitScreen(InitController, InitMovie, InitName);

	//m_strButtonValues[ePersonnelSoldierSortType_Status] = class'UIUtilities_Text'.static.GetSizedText(class'UIChallengeMode_SquadSelect'.default.m_strLocationLabel, 12);

	SwitchTab(m_eListType);
	SetScreenHeader(`CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel")));
	CreateConfirmButton();
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
		ConfirmButton.InitLargeButton('IRI_DD_ConfirmButton', class'UIMission'.default.m_strLaunchMission);
	}
	ConfirmButton.DisableNavigation();
	ConfirmButton.AnchorBottomCenter();
	ConfirmButton.OffsetY = -10;
	ConfirmButton.OnClickedDelegate = OnConfirmButtonClicked;
	ConfirmButton.Show();
	ConfirmButton.ShowBG(true);
}

// ================================= UPDATE DATA ==============================================

simulated function UpdateData()
{
	local XComGameState_Unit UnitState;
	local StateObjectReference UnitRef;
	
	// Destroy old data
	UnitStates.Length = 0;
	m_arrSoldiers.Length = 0;

	foreach XComHQ.Squad(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));

		if (class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
		{
			UnitStates.AddItem(UnitState);
			m_arrSoldiers.AddItem(UnitRef);
		}
	}
}

// ================================= INTERACTION ==============================================

protected function OnSoldierClicked(StateObjectReference UnitRef)
{
	local XComGameState_Unit UnitState;
	local bool bMarked;
	
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (UnitState == none)
		return;

	bMarked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);

	// Don't allow marking the last unmarked unit
	if (class'Help'.static.GetNumUnmarkedSquadMembers() == 1 && !bMarked)
	{
		Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);

		ProcessRepeatedClicks();
		return;
	}

	class'Help'.static.MarkUnitForDynamicDeployment(UnitState, !bMarked);

	Movie.Pres.PlayUISound(eSUISound_MenuSelect);
	RefreshData();
}

// ================================= CONFIRM SELECTION ==============================================

protected function OnConfirmButtonClicked(UIButton Button)
{	
	local UILargeButton DummyButton;
	local UISquadSelect SquadSelect;

	CloseScreen();

	SquadSelect = UISquadSelect(Button.Movie.Pres.ScreenStack.GetFirstInstanceOf(class'UISquadSelect'));
	if (SquadSelect == none)
	{
		`LOG("CRITICAL ERROR :: FAILED TO FIND SQUAD SELECT! CANNOT LAUNCH MISSION!",, 'WOTCIridarDynamicDeployment');
		`LOG("Disable this mod and try again.",, 'WOTCIridarDynamicDeployment');
		return;
	}
	
	DummyButton = UILargeButton(SquadSelect.LaunchButton.GetChildByName('IRI_DD_DummyLaunchButton', true));
	if (DummyButton == none)
	{
		`LOG("CRITICAL ERROR :: FAILED TO FIND DUMMY BUTTON! CANNOT LAUNCH MISSION!",, 'WOTCIridarDynamicDeployment');
		`LOG("Disable this mod and try again.",, 'WOTCIridarDynamicDeployment');
		return;
	}
	DummyButton.OnClickedDelegate(Button);
}

// ================================= CANCEL ==============================================

simulated function OnCancel()
{
	CloseScreen();
}

// ================================= CLEANUP ==============================================

simulated function OnRemoved()
{
	local Object SelfObj;

	SelfObj = self;
	EventMgr.UnRegisterFromEvent(SelfObj, 'OverridePersonnelStatus');

	super(UIPersonnel).OnRemoved();
}


static private function EventListenerReturn OnOverridePersonnelStatus(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComLWTuple			OverrideTuple;
	local XComGameState_Unit	UnitState;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none) 
		return ELR_NoInterrupt;

	OverrideTuple = XComLWTuple(EventData);

	if (class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState))
	{
		OverrideTuple.Data[0].s = "DYNAMIC";
		OverrideTuple.Data[4].i = eUIState_Warning;
	}
	else
	{
		OverrideTuple.Data[0].s = `CAPS(class'UIUtilities_Strategy'.default.m_strNormal);
		OverrideTuple.Data[4].i = eUIState_Normal;
	}

	return ELR_NoInterrupt;
}

// If the player keeps clicking to try and DD the last soldier in squad who's not DD'd already, display a tutorial popup.
private function ProcessRepeatedClicks()
{
	local TDialogueBoxData kDialogData;

	if (NumRepeatedClicks == 0)
	{
		SetTimer(5.0, false, nameof(ResetRepeatedClicks), self);
	}
	NumRepeatedClicks++;
	
	if (NumRepeatedClicks > 5)
	{
		NumRepeatedClicks = 0;

		kDialogData.strTitle = class'UIMission'.default.m_strChosenWarning2;
		kDialogData.strText = `GetLocalizedString("IRI_DD_CannotDDEntireSquad_Text");
		kDialogData.eType = eDialog_Warning;
		kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericOK;

		Movie.Pres.UIRaiseDialog(kDialogData);
	}
}
function ResetRepeatedClicks()
{
	NumRepeatedClicks = 0;
}

// --------------------------------------------------------------------------------------------------

simulated function UpdateNavHelp() {} 
simulated function SpawnNavHelpIcons() {} // No need for NavHelp for this screen

defaultproperties
{
	m_eListType = eUIPersonnel_Soldiers
	m_bRemoveWhenUnitSelected = false
	bAutoSelectFirstNavigable = false
	onSelectedDelegate = OnSoldierClicked
	//m_iMaskHeight = 580 // 780 default // Doesn't work anyway
}
