//-----------------------------------------------------------
//	Class:	WOTCIridarDynamicDeployment_MCMScreenListener
//	Author: Iridar
//	
//-----------------------------------------------------------

class WOTCIridarDynamicDeployment_MCMScreenListener extends UIScreenListener;

event OnInit(UIScreen Screen)
{
	local WOTCIridarDynamicDeployment_MCMScreen MCMScreen;

	if (ScreenClass==none)
	{
		if (MCM_API(Screen) != none)
			ScreenClass=Screen.Class;
		else return;
	}

	MCMScreen = new class'WOTCIridarDynamicDeployment_MCMScreen';
	MCMScreen.OnInit(Screen);
}

defaultproperties
{
    ScreenClass = none;
}
