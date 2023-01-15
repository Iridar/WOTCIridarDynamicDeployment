class X2Action_SelectUnits extends X2Action;

// Adjusted copy of the X2Action_ShowTutorialPopup.

var XComPresentationLayerBase Pres;

simulated state Executing
{
	function DisplayScreen()
	{
		local UIChooseUnits Popup;
		local XComGameState_Unit SourceUnit;

		SourceUnit = XComGameState_Unit(Metadata.StateObject_OldState);
		if (SourceUnit == none)
			return;

		Popup = Pres.Spawn(class'UIChooseUnits', Pres);
		Popup.AllowShowDuringCinematic(true);
		Popup.SourcePlayerID = SourceUnit.ControllingPlayer.ObjectID;
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
