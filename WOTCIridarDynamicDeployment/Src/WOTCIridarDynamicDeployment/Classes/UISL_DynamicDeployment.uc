class UISL_DynamicDeployment extends UIScreenListener;

// This needs to be done in a UISL, there's no event to do it in time.
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

	//ScreenClass = Screen.Class;

	PatchLaunchMissionButton(SquadSelect);
	OnSquadSelectNavHelpUpdate(none, none, none, '', none);

	SelfObj = self;

	// TODO: This does not actually run when adding or removing soldiers. Figure out how to do that.
	// This triggers when adding or removing a soldier from squad select, and in OnReceiveFocus too.
	`XEVENTMGR.RegisterForEvent(SelfObj, 'UISquadSelect_NavHelpUpdate', OnSquadSelectNavHelpUpdate, ELD_Immediate);
	`XEVENTMGR.RegisterForEvent(SelfObj, 'rjSquadSelect_UpdateData', OnSquadSelectNavHelpUpdate, ELD_Immediate);
	bRegistered = true;
}

event OnRemoved(UIScreen Screen)
{
	local Object SelfObj;

	if (!bRegistered || UISquadSelect(Screen) == none)
		return;

	SelfObj = self;

	`XEVENTMGR.UnregisterFromEvent(SelfObj, 'UISquadSelect_NavHelpUpdate');
	`XEVENTMGR.UnregisterFromEvent(SelfObj, 'rjSquadSelect_UpdateData');
}

static private function EventListenerReturn OnSquadSelectNavHelpUpdate(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local UISquadSelect						SquadSelect;
	local UISquadSelect_ListItem			ListItem;
	local array<UIPanel>					ChildrenPanels;
	local UIPanel							ChildPanel;
	local UIPanel							SSChildPanel;
	local XComGameState_Unit				UnitState;
	local XComGameStateHistory				History;
	local UIMechaListItem_ClickToggleCheckbox DDCheckbox;
	local int								ExtraHeight;
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

		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));
		if (UnitState != none && class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
		{	
			bChecked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);
			bShouldHaveCheckbox = true;

			`AMLOG("Looking at soldier:" @ UnitState.GetFullName() @ bChecked);
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

				// And they said I could never teach a llama to drive!
				if (ListItem.IsA('robojumper_UISquadSelect_ListItem'))
				{
					ExtraHeight = 0;
					foreach ListItem.ChildPanels(SSChildPanel)
					{
						if (SSChildPanel.IsA('robojumper_UISquadSelect_StatsPanel'))
						{
							ExtraHeight += SSChildPanel.Height;
						}
						if (SSChildPanel.IsA('robojumper_UISquadSelect_SkillsPanel'))
						{
							ExtraHeight += SSChildPanel.Height;
						}
					}
					DDCheckbox.SetY(ListItem.Height + ExtraHeight);
					ListItem.SetY(ListItem.Y - DDCheckbox.Height - 10);
				}
				else
				{
					//`AMLOG("Regular panel. Y:" @ ListItem.Y @ "Height:" @ ListItem.Height);
					DDCheckbox.SetY(362);
					ListItem.SetY(ListItem.Y - DDCheckbox.Height);
				}
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
