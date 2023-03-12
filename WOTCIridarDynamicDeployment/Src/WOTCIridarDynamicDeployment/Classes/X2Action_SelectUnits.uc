class X2Action_SelectUnits extends X2Action;

// Adjusted copy of the X2Action_ShowTutorialPopup.
// Just displays the specified screen as X2Action.

var XComPresentationLayerBase Pres;

simulated state Executing
{
	function DisplayScreen()
	{
		local UIChooseUnits Popup;

		Popup = Pres.Spawn(class'UIChooseUnits', Pres);
		Popup.AllowShowDuringCinematic(true);
		Pres.ScreenStack.Push(Popup);
	}

Begin:

	Pres = `PRESBASE;

	DisplayScreen();

	while (Pres.ScreenStack != none && Pres.ScreenStack.GetScreen(class'UIChooseUnits') != none)
	{
		Sleep(0.1);
	}
	
	CompleteAction();
}

defaultproperties
{
	TimeoutSeconds=-1
}
