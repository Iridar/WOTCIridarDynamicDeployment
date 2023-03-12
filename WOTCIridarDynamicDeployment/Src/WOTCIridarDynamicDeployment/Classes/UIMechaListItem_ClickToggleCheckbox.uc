class UIMechaListItem_ClickToggleCheckbox extends UIMechaListItem;

var XComGameState_Unit UnitState;

simulated function UIMechaListItem UpdateDataCheckbox(string _Desc,
									  String _CheckboxLabel,
									  bool bIsChecked,
									  delegate<OnCheckboxChangedCallback> _OnCheckboxChangedCallback = none,
									  optional delegate<OnClickDelegate> _OnClickDelegate = none)
{
	return super.UpdateDataCheckbox(_Desc, _CheckboxLabel, bIsChecked, none, OnMechaListItemClicked);
}

private function OnMechaListItemClicked()
{
	CheckBox.SetChecked(!CheckBox.bChecked, false);

	`AMLOG(UnitState.GetFullName() @ "is now marked for Dynamic Deployment:" @ CheckBox.bChecked);

	class'Help'.static.MarkUnitForDynamicDeployment(UnitState, CheckBox.bChecked);
}
