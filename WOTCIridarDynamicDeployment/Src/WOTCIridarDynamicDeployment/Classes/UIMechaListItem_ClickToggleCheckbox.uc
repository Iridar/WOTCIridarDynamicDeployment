class UIMechaListItem_ClickToggleCheckbox extends UIMechaListItem;

// Checkbox toggle under each soldier in Squad Select.
// For convenience, toggles the checkbox when clicking on the whole thing, not just when clicking on the checkbox itself.

var XComGameState_Unit UnitState;
var private int InitialListItemPosition;

var private int NumRepeatedClicks;

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
	// Don't allow marking the last unmarked unit
	if (class'Help'.static.GetNumUnmarkedSquadMembers() == 1 && CheckboxControl.bChecked)
	{
		Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);
		CheckboxControl.SetChecked(false, false);

		ProcessRepeatedClicks();
		return;
	}

	`AMLOG(UnitState.GetFullName() @ "is now marked for Dynamic Deployment:" @ CheckboxControl.bChecked);

	class'Help'.static.MarkUnitForDynamicDeployment(UnitState, CheckboxControl.bChecked);
}



private function OnMechaListItemClicked()
{
	`AMLOG("Running");

	// Don't allow marking the last unmarked unit
	if (class'Help'.static.GetNumUnmarkedSquadMembers() == 1 && !CheckBox.bChecked)
	{
		Movie.Pres.PlayUISound(eSUISound_MenuClickNegative);

		ProcessRepeatedClicks();
		return;
	}

	CheckBox.SetChecked(!CheckBox.bChecked, true);
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

// When this checkbox is added, we need to push the soldier list item upwards slightly to create space for the checkbox.
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
	//else 
	//{
	//	`AMLOG("Loadout manager bar is NOT present");
	//}

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