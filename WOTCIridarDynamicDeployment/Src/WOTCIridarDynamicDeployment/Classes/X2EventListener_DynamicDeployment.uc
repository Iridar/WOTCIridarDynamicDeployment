class X2EventListener_DynamicDeployment extends X2EventListener;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ListenerTemplate_Strategy());
	Templates.AddItem(Create_ListenerTemplate_Tactical());

	return Templates;
}

static private function CHEventListenerTemplate Create_ListenerTemplate_Strategy()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_DynamicDeployment_Strategy');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('OnArmoryMainMenuUpdate', UpdateArmoryMainMenu, ELD_Immediate);
	Template.AddCHEvent('OnResearchReport', OnOnResearchReport, ELD_Immediate);

	return Template;
}

// Display a popup that Teleportation Deployment is available when requisite research is complete.
static private function EventListenerReturn OnOnResearchReport(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Tech	TechState;
	local TDialogueBoxData		kDialogData;

	TechState = XComGameState_Tech(EventData);
	if (TechState != none && TechState.GetMyTemplateName() == `GetConfigName("IRI_DD_TechRequiredToUnlockTeleport") && `XCOMHQ.HasSoldierUnlockTemplate('IRI_DynamicDeployment_GTS_Unlock'))
	{
		kDialogData.strTitle = `GetLocalizedString("IRI_DD_TeleportDeployment_Title");
		kDialogData.strText = `GetLocalizedString("IRI_DD_TeleportDeployment_Text");
		kDialogData.eType = eDialog_Normal;
		kDialogData.strAccept = class'UIUtilities_Text'.default.m_strGenericOK;

		`PRESBASE.UIRaiseDialog(kDialogData);
	}

	return ELR_NoInterrupt;
}

// Insert the Dynamic Deployment button into Armory main menu.
static private function EventListenerReturn UpdateArmoryMainMenu(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local UIList				Menu;
	local UIListItemString		DDButton;
	local UIArmory_MainMenu		MainMenu;
	local XComGameState_Unit	UnitState;
	local string				strLabel;

	if (!`XCOMHQ.HasSoldierUnlockTemplate('IRI_DynamicDeployment_GTS_Unlock'))
		return ELR_NoInterrupt;

	MainMenu = UIArmory_MainMenu(EventSource);
	if (MainMenu == none) 
		return ELR_NoInterrupt;

	UnitState = MainMenu.GetUnit();
	if (UnitState == none || !class'Help'.static.IsUnitEligibleForDDAbilities(UnitState)) 
		return ELR_NoInterrupt;

	Menu = UIList(EventData);
	if (Menu == none) 
		return ELR_NoInterrupt;

	strLabel = `CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel"));

	DDButton = Menu.Spawn(class'UIListItemString', Menu.ItemContainer).InitListItem(strLabel); 
	DDButton.MCName = 'ArmoryMainMenu_DDButton';
	DDButton.ButtonBG.OnClickedDelegate = OnDDButtonClicked;

	MoveMenuItemIntoPosition(Menu, DDButton, 7); // Above "dismiss" button

	return ELR_NoInterrupt;
}
static private function MoveMenuItemIntoPosition(UIList Menu, UIPanel Item, int iPosition)
{
	local int StartingIndex, ItemIndex;

	StartingIndex = Menu.GetItemIndex(Item);

	if (StartingIndex != INDEX_NONE)
	{
		if(Menu.SelectedIndex > INDEX_NONE && Menu.SelectedIndex < Menu.ItemCount)
			Menu.GetSelectedItem().OnLoseFocus();

		ItemIndex = StartingIndex;
		while(ItemIndex > iPosition)
		{
			Menu.ItemContainer.SwapChildren(ItemIndex, ItemIndex - 1);
			ItemIndex--;
		}

		Menu.RealizeItems();

		if (Menu.SelectedIndex > INDEX_NONE && Menu.SelectedIndex < Menu.ItemCount)
			Menu.GetSelectedItem().OnReceiveFocus();
	}

	if (StartingIndex == Menu.SelectedIndex && Menu.OnSelectionChanged != none)
		Menu.OnSelectionChanged(Menu, Menu.SelectedIndex);
}
static private function OnDDButtonClicked(UIButton kButton)
{
	local XComHQPresentationLayer		HQPres;
	local UIArmory_MainMenu				MainMenu;
	local UIArmory_DynamicDeployment	DDScreen;

	MainMenu = UIArmory_MainMenu(`SCREENSTACK.GetCurrentScreen());
	HQPres = XComHQPresentationLayer(MainMenu.Movie.Pres);	
	if (HQPres != none) 
	{
		DDScreen = HQPres.Spawn(class'UIArmory_DynamicDeployment', HQPres);
		DDScreen.m_UnitRef = MainMenu.GetUnitRef();
		HQPres.ScreenStack.Push(DDScreen, HQPres.Get2DMovie());

		`XSTRATEGYSOUNDMGR.PlaySoundEvent("Play_MenuSelect");
	}
}



static private function CHEventListenerTemplate Create_ListenerTemplate_Tactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_DynamicDeployment_Tactical');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;

	// This event probably isn't triggered by anything other Request Evac, but better safe than sorry,
	// since if the event is triggered, but Request Evac isn't present, we're gonna hard crash the game.
	if (class'Help'.static.IsModActive('RequestEvac'))
	{
		Template.AddCHEvent('EvacSpawnerCreated', OnEvacSpawnerCreated, ELD_OnStateSubmitted);
	}

	Template.AddCHEvent('PlayerTurnBegun', OnPlayerTurnBegun, ELD_OnStateSubmitted);
	Template.AddCHEvent('UnitEvacuated', OnUnitEvacuated, ELD_OnStateSubmitted);
	

	return Template;
}

// Set DD on cooldown on mission start and preload assets if deployment is ready.
static private function EventListenerReturn OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_Player				PlayerState;
	local XComGameState_DynamicDeployment	DDObject;

	PlayerState = XComGameState_Player(EventSource);
	if (PlayerState == none || PlayerState.GetTeam() != eTeam_XCom)
		return ELR_NoInterrupt;
		
	// If teleport is available, we're not tied to Skyranger.
	if (IsFirstTurn() && class'Help'.static.GetDeploymentType() != `eDT_TeleportBeacon)
	{
		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', `GETMCMVAR(DD_MISSION_START_DELAY_TURNS), PlayerState.ObjectID);
	}
	
	if (PlayerState.GetCooldown('IRI_DynamicDeployment_Deploy') <= 0)
	{
		// Preload soldier assets at the beginning of the turn when Deploy is available.
		DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment', true));
		if (DDObject != none && DDObject.bPendingDeployment)
		{
			DDObject.PreloadAssets();
		}
	}

	return ELR_NoInterrupt;
}
static private function bool IsFirstTurn()
{
	local XComGameStateHistory		History;
	local XComGameState_BattleData	BattleData;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	if (BattleData == none)
	{
		`AMLOG("WARNING :: No Battle Data!" @ GetScriptTrace());
		return false;
	}

    return BattleData.TacticalTurnCount == 1;
}

// Set DD on cooldown when Evac is requested via Request Evac mod.
static private function EventListenerReturn OnEvacSpawnerCreated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local StateObjectReference PlayerStateRef;
	local XComGameState_RequestEvac RequestEvacState; // Requires building against Request Evac
	local XComGameState_DynamicDeployment	DDObject;

	// If teleport is available, we're not tied to Skyranger.
	if (class'Help'.static.GetDeploymentType() == `eDT_TeleportBeacon)
		return ELR_NoInterrupt;

	PlayerStateRef = class'X2TacticalVisibilityHelpers'.static.GetPlayerFromTeamEnum(eTeam_XCom);

	RequestEvacState = XComGameState_RequestEvac(EventSource);
	if (RequestEvacState == none)
		return ELR_NoInterrupt;

	// Can't select more soldiers until the Skyranger arrives, then leaves, then returns to Avenger.
	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', RequestEvacState.Countdown + class'XComGameState_RequestEvac'.default.TurnsBeforeEvacExpires + `GETMCMVAR(DD_MISSION_START_DELAY_TURNS), PlayerStateRef.ObjectID);

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none)
		return ELR_NoInterrupt;

	// Can't deploy previously selected soldiers until Skyranger arrives.
	// TODO: This may actually REDUCE the deployment delay if you selected more soldiers than the delay for skyranger to arrive via RequestEvac
	if (DDObject.bPendingDeployment)
	{
		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy', RequestEvacState.Countdown, PlayerStateRef.ObjectID);
		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy_Spark', RequestEvacState.Countdown, PlayerStateRef.ObjectID);
		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Deploy_Uplink', RequestEvacState.Countdown, PlayerStateRef.ObjectID);
	}


	return ELR_NoInterrupt;
}

// Mark evacuated units with a unit value so that we know not to reinit their abilities if we're gonna redeploy them again in the same mission.
static private function EventListenerReturn OnUnitEvacuated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit	UnitState;
	local XComGameState			NewGameState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none)
		return ELR_NoInterrupt;

	class'Help'.static.MarkUnitInSkyranger(UnitState);

	return ELR_NoInterrupt;
}
	