class UIMechaListItem_ClickToggleCheckbox extends UIMechaListItem;

var XComGameState_Unit UnitState;
var int InitialListItemPosition;

simulated function UIMechaListItem UpdateDataCheckbox(string _Desc,
									  String _CheckboxLabel,
									  bool bIsChecked,
									  delegate<OnCheckboxChangedCallback> _OnCheckboxChangedCallback = none,
									  optional delegate<OnClickDelegate> _OnClickDelegate = none)
{
	super.UpdateDataCheckbox(_Desc, _CheckboxLabel, bIsChecked, OnCheckboxChanged, OnMechaListItemClicked);

	return self;
}

private function OnCheckboxChanged(UICheckbox CheckboxControl)
{
	`AMLOG(UnitState.GetFullName() @ "is now marked for Dynamic Deployment:" @ CheckboxControl.bChecked);

	class'Help'.static.MarkUnitForDynamicDeployment(UnitState, CheckboxControl.bChecked);
}

private function OnMechaListItemClicked()
{
	`AMLOG("Running");

	CheckBox.SetChecked(!CheckBox.bChecked, true);
}

final function UpdatePosition(UISquadSelect_ListItem ListItem)
{
	local int		ExtraHeight;
	local UIPanel	SSChildPanel;

	// Cache initial position so we don't keep pushing the list item into the ceiling with repeated updates.
	if (InitialListItemPosition == 0)
	{
		InitialListItemPosition = ListItem.Y;
	}

	// Compatibility for my Loadout Manager mod that adds a similar UI element into the same spot.
	SSChildPanel = ListItem.GetChildByName('IRI_MLM_LoadLoadout_SquadSelect_Shortcut', false);
	if (SSChildPanel != none)
	{
		ExtraHeight += 36;
	}
	else 
	{
		`AMLOG("Loadout manager bar is NOT present");
	}

	// And they said I could never teach a llama to drive!
	if (ListItem.IsA('robojumper_UISquadSelect_ListItem'))
	{
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
		SetY(ListItem.Height + ExtraHeight);
		//ListItem.SetY(ListItem.Y - Height - 10);
		ListItem.SetY(InitialListItemPosition - Height);
	}
	else
	{
		//`AMLOG("Regular panel. Y:" @ ListItem.Y @ "Height:" @ ListItem.Height);
		SetY(362 + ExtraHeight);
		ListItem.SetY(InitialListItemPosition - Height);
	}
}