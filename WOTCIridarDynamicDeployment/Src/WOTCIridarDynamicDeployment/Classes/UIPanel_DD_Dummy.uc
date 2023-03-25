class UIPanel_DD_Dummy extends UIPanel;

var delegate<OnClickedDelegate> OnClickedOriginal;

delegate OnClickedDelegate(UIButton Button);

final function OnLaunchMissionClicked(UIButton Button)
{
	local UIChooseUnits ChooseUnits;
	local XComPresentationLayerBase Pres;

	Pres = Button.Movie.Pres;
	ChooseUnits = Pres.Spawn(class'UIChooseUnits', Pres);
	Pres.ScreenStack.Push(ChooseUnits);
	ChooseUnits.OnLaunchMissionClickedOriginal = OnClickedOriginal;
}
