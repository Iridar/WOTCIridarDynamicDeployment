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

	return Template;
}


// Insert the Dynamic Deployment button into Armory main menu.
static private function EventListenerReturn UpdateArmoryMainMenu(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local UIList				Menu;
	local UIMechaListItem		DDButton;
	local UIArmory_MainMenu		MainMenu;
	local XComGameState_Unit	UnitState;
	local string				strLabel;
	local bool					bChecked;

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
	
	DDButton = Menu.Spawn(class'UIMechaListItem', Menu.ItemContainer).InitListItem('ArmoryMainMenu_DDButton'); 

	if (`GETMCMVAR(ENABLE_ARMORY_CHECKBOX))
	{
		bChecked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);
		DDButton.UpdateDataCheckbox(strLabel, "", bChecked, OnDDCheckboxChanged, OnDDButtonClicked);
	}
	else
	{
		DDButton.UpdateDataDescription(strLabel, OnDDButtonClicked);
	}

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
static private function OnDDButtonClicked()
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
static private function OnDDCheckboxChanged(UICheckbox CheckboxControl)
{
	local UIArmory_MainMenu		ArmoryScreen;
	local XComGameState_Unit	UnitState;
	local bool					bMarked;
	
	ArmoryScreen = UIArmory_MainMenu(CheckboxControl.Movie.Pres.ScreenStack.GetFirstInstanceOf(class'UIArmory_MainMenu'));
	if (ArmoryScreen == none)
		return;

	UnitState = ArmoryScreen.GetUnit();
	if (UnitState == none)
		return;

	bMarked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);

	class'Help'.static.MarkUnitForDynamicDeployment(UnitState, !bMarked);
}


static private function CHEventListenerTemplate Create_ListenerTemplate_Tactical()
{
	local CHEventListenerTemplate Template;

	`CREATE_X2TEMPLATE(class'CHEventListenerTemplate', Template, 'IRI_X2EventListener_DynamicDeployment_Tactical');

	Template.RegisterInTactical = true;
	Template.RegisterInStrategy = false;

	// This event probably isn't triggered by anything other Request Evac, but better safe than sorry
	if (class'Help'.static.IsModActive('RequestEvac'))
	{
		// This event is triggered when evac is requested with Request Evac mod.
		Template.AddCHEvent('EvacRequested', OnEvacRequested, ELD_OnStateSubmitted); 
	}
	// This triggers when Skyranger arrives.
	Template.AddCHEvent('EvacZonePlaced', OnSpawnEvacZoneComplete, ELD_OnStateSubmitted); 

	Template.AddCHEvent('PlayerTurnBegun', OnPlayerTurnBegun, ELD_OnStateSubmitted);
	Template.AddCHEvent('CleanupTacticalMission', OnCleanupTacticalMission, ELD_Immediate);
	Template.AddCHEvent('OverridePersonnelStatus', OnOverridePersonnelStatus, ELD_Immediate);
	
	return Template;
}

static private function EventListenerReturn OnOverridePersonnelStatus(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComLWTuple						OverrideTuple;
	local XComGameState_Unit				UnitState;
	local XComGameState_DynamicDeployment	DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	if (DDObject == none)
		return ELR_NoInterrupt;

	UnitState = XComGameState_Unit(EventSource);
	if (UnitState == none) 
		return ELR_NoInterrupt;

	OverrideTuple = XComLWTuple(EventData);

	if (DDObject.IsUnitSelected(UnitState.ObjectID))
	{
		OverrideTuple.Data[0].s = `GetLocalizedString("IRI_DynamicDeployment_DeployingStatus");
		OverrideTuple.Data[4].i = eUIState_Warning;
	}

	return ELR_NoInterrupt;
}

// Preload assets if deployment is ready.
static private function EventListenerReturn OnPlayerTurnBegun(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackData)
{
	local XComGameState_Player				PlayerState;
	local XComGameState_DynamicDeployment	DDObject;

	PlayerState = XComGameState_Player(EventSource);
	if (PlayerState == none || PlayerState.GetTeam() != eTeam_XCom)
		return ELR_NoInterrupt;
	
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
static private function EventListenerReturn OnEvacRequested(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Disabling DD abilities");
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy', false, NewGameState);
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy_Spark', false, NewGameState);
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy_Uplink', false, NewGameState);
	`GAMERULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}
static private function EventListenerReturn OnSpawnEvacZoneComplete(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState NewGameState;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Enabling DD abilities");
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy', true, NewGameState);
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy_Spark', true, NewGameState);
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy_Uplink', true, NewGameState);

	// Skyranger just arrived for evac, can't request DD for a turn.
	class'Help'.static.PutSkyrangerOnCooldown(1, NewGameState, true);

	`GAMERULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}

static private function EventListenerReturn OnCleanupTacticalMission(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	//local XComGameState_Unit	UnitState;
	//local XComGameState_Unit	NewUnitState;
	local XComGameStateHistory	History;
	local XComGameState_DynamicDeployment DDObject;

	History = `XCOMHISTORY;

	// Wipe all data from DDObject on mission end so it doesn't leak into the next mission.
	foreach NewGameState.IterateByClassType(class'XComGameState_DynamicDeployment', DDObject)
	{
		break;
	}
	if (DDObject == none)
	{
		DDObject = XComGameState_DynamicDeployment(History.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment', true));
		if (DDObject != none)
		{
			DDObject = XComGameState_DynamicDeployment(NewGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
		}
	}
	if (DDObject != none)
	{
		DDObject.FullReset();
	}

	//foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	//{
	//	NewUnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
	//	if (NewUnitState == none)
	//	{
	//		NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
	//	}
	//	NewUnitState.ClearUnitValue(class'Help'.default.DynamicDeploymentValue);
	//
	//	`AMLOG(NewUnitState.GetFullName() @ "is no longer in Skyranger");
	//}

	return ELR_NoInterrupt;
}