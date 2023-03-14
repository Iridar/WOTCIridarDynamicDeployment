class UISL_DynamicDeployment extends UIScreenListener;

// This needs to be done in a UISL, there's no event to do it in time.

event OnInit(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	SquadSelect = UISquadSelect(Screen);
	if (SquadSelect == none)
		return;

	if (!`XCOMHQ.HasSoldierUnlockTemplate('IRI_DynamicDeployment_GTS_Unlock'))
		return;

	//ScreenClass = Screen.Class;

	PatchLaunchMissionButton(SquadSelect);
	PatchSoldierListItems(SquadSelect);
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

static private function PatchSoldierListItems(UISquadSelect SquadSelect)
{
	local UISquadSelect_ListItem			ListItem;
	local array<UIPanel>					ChildrenPanels;
	local UIPanel							ChildPanel;
	local UIPanel							SSChildPanel;
	local XComGameState_Unit				UnitState;
	local XComGameStateHistory				History;
	local UIMechaListItem_ClickToggleCheckbox DDCheckbox;
	local int								ExtraHeight;
	local bool								bChecked;

	History = `XCOMHISTORY;

	// Add a checkbox under each soldier poster.
	SquadSelect.GetChildrenOfType(class'UISquadSelect_ListItem', ChildrenPanels);
	foreach ChildrenPanels(ChildPanel)
	{
		ListItem = UISquadSelect_ListItem(ChildPanel);
		if (ListItem == none || ListItem.bDisabled)
			continue;

		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));
		if (UnitState == none || !class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
			continue;

		if (ListItem.GetChildByName('IRI_DD_SquadSelect_Checkbox', false) != none)
			continue;

		bChecked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);

		`AMLOG("Looking at soldier:" @ UnitState.GetFullName() @ bChecked);

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
}


event OnReceiveFocus(UIScreen Screen)
{
	local UISquadSelect SquadSelect;

	SquadSelect = UISquadSelect(Screen);
	if (SquadSelect == none)
		return;

	if (!`XCOMHQ.HasSoldierUnlockTemplate('IRI_DynamicDeployment_GTS_Unlock'))
		return;

	UpdateSoldierListItems(SquadSelect);
}


static private function UpdateSoldierListItems(UISquadSelect SquadSelect)
{
	local UISquadSelect_ListItem			ListItem;
	local array<UIPanel>					ChildrenPanels;
	local UIPanel							ChildPanel;
	local XComGameState_Unit				UnitState;
	local XComGameStateHistory				History;
	local UIMechaListItem_ClickToggleCheckbox DDCheckbox;
	local bool								bChecked;

	History = `XCOMHISTORY;
	// Add a checkbox under each soldier poster.
	SquadSelect.GetChildrenOfType(class'UISquadSelect_ListItem', ChildrenPanels);
	foreach ChildrenPanels(ChildPanel)
	{
		ListItem = UISquadSelect_ListItem(ChildPanel);
		if (ListItem == none || ListItem.bDisabled)
			continue;

		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));
		if (UnitState == none || !class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
			continue;

		DDCheckbox = UIMechaListItem_ClickToggleCheckbox(ListItem.GetChildByName('IRI_DD_SquadSelect_Checkbox', false));
		if (DDCheckbox == none)
			continue;

		bChecked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);
		`AMLOG("Looking at soldier:" @ UnitState.GetFullName() @ bChecked);
		
		DDCheckbox.Checkbox.SetChecked(bChecked, false);
	}
}