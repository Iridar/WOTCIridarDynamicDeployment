class UISL_DynamicDeployment extends UIScreenListener config(whatever);

// 
// This needs to be done in a UISL, there's no event to do it in time.

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

var private bool bRegistered;

event OnInit(UIScreen Screen)
{
	local UISquadSelect SquadSelect;
	local Object SelfObj;

	SquadSelect = UISquadSelect(Screen);
	if (SquadSelect == none)
		return;

	if (!`XCOMHQ.HasSoldierUnlockTemplate('IRI_DynamicDeployment_GTS_Unlock'))
		return;

	if (`GETMCMVAR(ENABLE_LAUNCH_MISSION_SCREEN))
	{
		PatchLaunchMissionButton(SquadSelect);
	}

	if (`GETMCMVAR(ENABLE_SOLDIER_LIST_CHECKBOX))
	{
		OnSquadSelectUpdate(none, none, none, '', none);

		// TODO: Figure out how to update the checkboxes when soldier is removed from normal squad select.

		SelfObj = self;
		`XEVENTMGR.RegisterForEvent(SelfObj, 'rjSquadSelect_UpdateData', OnSquadSelectUpdate, ELD_Immediate, 49);
		bRegistered = true;
	}
}

event OnRemoved(UIScreen Screen)
{
	local Object SelfObj;

	if (!bRegistered || UISquadSelect(Screen) == none)
		return;

	SelfObj = self;

	`XEVENTMGR.UnregisterFromEvent(SelfObj, 'rjSquadSelect_UpdateData');
}

event OnReceiveFocus(UIScreen Screen)
{
	if (!bRegistered || UISquadSelect(Screen) == none)
		return;

	OnSquadSelectUpdate(none, none, none, '', none);
}

static private function EventListenerReturn OnSquadSelectUpdate(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local UISquadSelect						SquadSelect;
	local UISquadSelect_ListItem			ListItem;
	local array<UIPanel>					ChildrenPanels;
	local UIPanel							ChildPanel;
	
	local XComGameState_Unit				UnitState;
	local XComGameStateHistory				History;
	local UIMechaListItem_ClickToggleCheckbox DDCheckbox;
	
	local bool								bChecked;
	local bool								bShouldHaveCheckbox;

	SquadSelect = UISquadSelect(`HQPRES.ScreenStack.GetFirstInstanceOf(class'UISquadSelect'));
	if (SquadSelect == none)
		return ELR_NoInterrupt;

		`AMLOG("Running:" @ Event);

	History = `XCOMHISTORY;

	// Add a checkbox under each soldier poster.
	SquadSelect.GetChildrenOfType(class'UISquadSelect_ListItem', ChildrenPanels);
	foreach ChildrenPanels(ChildPanel)
	{	
		ListItem = UISquadSelect_ListItem(ChildPanel);
		if (ListItem == none)
			continue;

		bShouldHaveCheckbox = false;

		if (!ListItem.bDisabled)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));
			if (UnitState != none && class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
			{	
				bChecked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);
				bShouldHaveCheckbox = true;

				`AMLOG("Looking at soldier:" @ UnitState.GetFullName() @ bChecked);
			}
		}

		DDCheckbox = UIMechaListItem_ClickToggleCheckbox(ListItem.GetChildByName('IRI_DD_SquadSelect_Checkbox', false));
		if (DDCheckbox == none)
		{
			if (bShouldHaveCheckbox)
			{
				// Checkbox should be there, but it's not there. Create it.
				DDCheckbox = ListItem.Spawn(class'UIMechaListItem_ClickToggleCheckbox', ListItem);
				DDCheckbox.bAnimateOnInit = false;
				DDCheckbox.InitListItem('IRI_DD_SquadSelect_Checkbox');
				DDCheckbox.UpdateDataCheckbox(`CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel")), "", bChecked, none, none);
				DDCheckbox.SetWidth(465);
				DDCheckbox.UnitState = UnitState;
				DDCheckbox.UpdatePosition(ListItem);
			}
			else
			{
				// Checkbox should not be there, and is not there, go to the next squad member.
				continue;
			}
		}
		else
		{
			if (bShouldHaveCheckbox)
			{
				// Checkbox should be there and is there, just update the value.
				// Have to update position too in case player returns to squad select from armory where they unlocked more perks
				// and soldier list item became taller
				DDCheckbox.UpdatePosition(ListItem);
				DDCheckbox.Show();
				DDCheckbox.Checkbox.SetChecked(bChecked, false);
			}
			else
			{
				DDCheckbox.Hide();
			}
		}
	}
	return ELR_NoInterrupt;
}


// Add an intermediate step of showing a UIScreen with the squad so the player can select units that will remain in Skyranger.
static private function PatchLaunchMissionButton(UISquadSelect SquadSelect)
{	
	local UILargeButton DummyButton;

	if (SquadSelect.LaunchButton.GetChildByName('IRI_DD_DummyLaunchButton', false) != none)
		return;
		
	DummyButton = SquadSelect.LaunchButton.Spawn(class'UILargeButton', SquadSelect.LaunchButton);
	DummyButton.InitPanel('IRI_DD_DummyLaunchButton');
	DummyButton.OnClickedDelegate = SquadSelect.LaunchButton.OnClickedDelegate;
	SquadSelect.LaunchButton.OnClickedDelegate = OnLaunchMission;
	DummyButton.Hide();
	DummyButton.SetPosition(-100, -100);
}
static private function OnLaunchMission(UIButton Button)
{
	local UIChooseUnits_SquadSelect ChooseUnits;
	local XComPresentationLayerBase Pres;

	Pres = Button.Movie.Pres;
	ChooseUnits = Pres.Spawn(class'UIChooseUnits_SquadSelect', Pres);
	Pres.ScreenStack.Push(ChooseUnits);
}