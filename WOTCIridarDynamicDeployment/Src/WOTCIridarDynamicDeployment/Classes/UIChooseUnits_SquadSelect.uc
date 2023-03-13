class UIChooseUnits_SquadSelect extends UIChooseUnits;

var private XComGameStateHistory	History;
var private X2EventManager			EventMgr;

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
	
	super(UIPersonnel).InitScreen(InitController, InitMovie, InitName);

	//m_strButtonValues[ePersonnelSoldierSortType_Status] = class'UIUtilities_Text'.static.GetSizedText(class'UIChallengeMode_SquadSelect'.default.m_strLocationLabel, 12);

	SwitchTab(m_eListType);
	SetScreenHeader(`CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel")));
	CreateConfirmButton();
}

// Big green button at the bottom.
protected function CreateConfirmButton()
{
	super.CreateConfirmButton();

	ConfirmButton.SetText(class'UIMission'.default.m_strLaunchMission);
}	

protected function UpdateConfirmButtonVisibility()
{
	ConfirmButton.SetDisabled(false, "");
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

simulated function RefreshData()
{
	super(UIPersonnel).RefreshData();
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

// ================================= INTERACTION ==============================================

protected function OnSoldierClicked(StateObjectReference UnitRef)
{
	local XComGameState_Unit UnitState;
	local bool bMarked;
	
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (UnitState == none)
		return;

	bMarked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);

	class'Help'.static.MarkUnitForDynamicDeployment(UnitState, !bMarked);

	`XTACTICALSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
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
