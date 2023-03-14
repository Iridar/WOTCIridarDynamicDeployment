class UIMechaListItem_ClickToggleCheckbox extends UIMechaListItem;

var XComGameState_Unit UnitState;

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
