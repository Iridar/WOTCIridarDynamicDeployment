class X2EventListener_DynamicDeployment extends X2EventListener;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

static function array<X2DataTemplate> CreateTemplates()
{
	local array<X2DataTemplate> Templates;

	Templates.AddItem(Create_ListenerTemplate_Strategy());
	Templates.AddItem(Create_ListenerTemplate_Tactical());

	return Templates;
}

/*
'AbilityActivated', AbilityState, SourceUnitState, NewGameState
'PlayerTurnBegun', PlayerState, PlayerState, NewGameState
'PlayerTurnEnded', PlayerState, PlayerState, NewGameState
'UnitDied', UnitState, UnitState, NewGameState
'KillMail', UnitState, Killer, NewGameState
'UnitTakeEffectDamage', UnitState, UnitState, NewGameState
'OnUnitBeginPlay', UnitState, UnitState, NewGameState
'OnTacticalBeginPlay', X2TacticalGameRuleset, none, NewGameState
*/

static private function CHEventListenerTemplate Create_ListenerTemplate_Strategy()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_DynamicDeployment_Strategy');

	Template.RegisterInTactical = false;
	Template.RegisterInStrategy = true;

	Template.AddCHEvent('OnArmoryMainMenuUpdate', UpdateArmoryMainMenu, ELD_Immediate);

	return Template;
}


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

	if (UnitState.IsRobotic())
	{
		strLabel = `CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel_Robotic"));
	}
	else
	{
		strLabel = `CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel"));
	}

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

	Template.AddCHEvent('OverridePersonnelStatus', OnOverridePersonnelStatus, ELD_Immediate);
	//Template.AddCHEvent('EvacZonePlaced', OnEvacZonePlaced, ELD_OnStateSubmitted);

	// This event probably isn't triggered by anything other Request Evac, but better safe than sorry,
	// since if the event is triggered, but Request Evac isn't present, we're gonna hard crash the game.
	if (class'Help'.static.IsModActive('RequestEvac'))
	{
		Template.AddCHEvent('EvacSpawnerCreated', OnEvacSpawnerCreated, ELD_OnStateSubmitted);
	}

	Template.AddCHEvent('PlayerTurnBegun', OnFirstTurn, ELD_OnStateSubmitted);

	return Template;
}

// Set DD on cooldown on mission start.
static private function EventListenerReturn OnFirstTurn(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_Player PlayerState;

	// If teleport is available, we're not tied to Skyranger.
	if (class'Help'.static.ShouldUseTeleportDeployment())
		return ELR_NoInterrupt;

	PlayerState = XComGameState_Player(EventSource);
	if (PlayerState == none || PlayerState.GetTeam() != eTeam_XCom)
		return ELR_NoInterrupt;
		
	if (IsFirstTurn())
	{
		class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', `GETMCMVAR(DD_MISSION_START_DELAY_TURNS), PlayerState.ObjectID);
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
static private function EventListenerReturn OnEvacSpawnerCreated(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local StateObjectReference PlayerStateRef;
	local XComGameState_RequestEvac RequestEvacState; // Requires building against Request Evac

	// If teleport is available, we're not tied to Skyranger.
	if (class'Help'.static.ShouldUseTeleportDeployment())
		return ELR_NoInterrupt;

	PlayerStateRef = class'X2TacticalVisibilityHelpers'.static.GetPlayerFromTeamEnum(eTeam_XCom);

	RequestEvacState = XComGameState_RequestEvac(EventSource);
	if (RequestEvacState == none)
		return ELR_NoInterrupt;

	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', RequestEvacState.Countdown + class'XComGameState_RequestEvac'.default.TurnsBeforeEvacExpires, PlayerStateRef.ObjectID);

	return ELR_NoInterrupt;
}

//static private function EventListenerReturn OnEvacZonePlaced(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
//{
//	local StateObjectReference PlayerStateRef;
//
//	PlayerStateRef = class'X2TacticalVisibilityHelpers'.static.GetPlayerFromTeamEnum(eTeam_XCom);
//
//	class'Help'.static.SetGlobalCooldown('IRI_DynamicDeployment_Select', 3, PlayerStateRef.ObjectID); 
//
//	return ELR_NoInterrupt;
//}


static private function EventListenerReturn OnOverridePersonnelStatus(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComLWTuple						OverrideTuple;
	local XComGameState_Unit				UnitState;
	local XComGameState_DynamicDeployment	DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);

	if (UnitState != none && DDObject.IsUnitSelected(UnitState.ObjectID))
	{
		OverrideTuple = XComLWTuple(EventData);
		OverrideTuple.Data[0].s = `GetLocalizedString("IRI_DynamicDeployment_DeployingStatus");
		OverrideTuple.Data[4].i = eUIState_Warning;
	}

	return ELR_NoInterrupt;
}
/*	eUIState_Normal,
	eUIState_Faded,
	eUIState_Header,
	eUIState_Disabled,
	eUIState_Good,
	eUIState_Bad,
	eUIState_Warning,
	eUIState_Highlight,
	eUIState_Cash,
	eUIState_Psyonic,
	eUIState_Warning2,
	eUIState_TheLost*/
