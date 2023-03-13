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
	Template.AddCHEvent('UISquadSelect_NavHelpUpdate', OnSquadSelectNavHelpUpdate, ELD_Immediate, 50);

	return Template;
}


static private function EventListenerReturn OnSquadSelectNavHelpUpdate(Object EventData, Object EventSource, XComGameState GameState, Name EventID, Object CallbackObject)
{
	local UISquadSelect						SquadSelect;
	local UISquadSelect_ListItem			ListItem;
	local array<UIPanel>					ChildrenPanels;
	local UIPanel							ChildPanel;
	local UIPanel							SSChildPanel;
	local XComGameState_Unit				UnitState;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameStateHistory				History;
	local UIMechaListItem_ClickToggleCheckbox DDCheckbox;
	local int								ExtraHeight;
	local bool								bChecked;
	local UILargeButton						DummyButton;

	if (!`XCOMHQ.HasSoldierUnlockTemplate('IRI_DynamicDeployment_GTS_Unlock'))
		return ELR_NoInterrupt;

	SquadSelect = UISquadSelect(EventSource);
	if (SquadSelect == none)
		return ELR_NoInterrupt;

	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom', true));
	if (XComHQ == none)
		return ELR_NoInterrupt;

	// Add an intermediate step of showing a UIScreen with the squad so the player can select units that will remain in Skyranger.
	if (SquadSelect.LaunchButton.GetChildByName('IRI_DD_DummyLaunchButton', false) == none)
	{
		DummyButton = SquadSelect.LaunchButton.Spawn(class'UILargeButton', SquadSelect.LaunchButton);
		DummyButton.InitPanel('IRI_DD_DummyLaunchButton');
		DummyButton.OnClickedDelegate = SquadSelect.LaunchButton.OnClickedDelegate;
		SquadSelect.LaunchButton.OnClickedDelegate = OnLaunchMission;
		DummyButton.Hide();
		DummyButton.SetPosition(-100, -100);
	}

	// Add a checkbox under each soldier poster.
	SquadSelect.GetChildrenOfType(class'UISquadSelect_ListItem', ChildrenPanels);
	foreach ChildrenPanels(ChildPanel)
	{
		ListItem = UISquadSelect_ListItem(ChildPanel);
		//if (ListItem.SlotIndex < 0 || ListItem.SlotIndex > XComHQ.Squad.Length)
		//	continue;

		// TODO: Figure out why this gives the same unit with RJSS, maybe use a UISL, 
		// we need to update checkboxes when UISquadSelect gets focus anyway when closing the UISChooseUnits_SquadSelect
		// or do that in OnScreenClosed() in that screen.
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));
		if (UnitState == none || !class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
			continue;

		if (ListItem.GetChildByName('IRI_DD_SquadSelect_Checkbox', false) != none || ListItem.bDisabled)
			continue;

		bChecked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);

		`AMLOG("Looking at soldier:" @ UnitState.GetFullName() @ bChecked);

		DDCheckbox = ListItem.Spawn(class'UIMechaListItem_ClickToggleCheckbox', ListItem);
		DDCheckbox.bAnimateOnInit = false;
		DDCheckbox.InitListItem('IRI_DD_SquadSelect_Checkbox');
		DDCheckbox.UpdateDataCheckbox(`CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel")), "", bChecked, none, none);
		DDCheckbox.SetWidth(465);
		DDCheckbox.UnitState = UnitState;

		// And they said I could never teach a llama to drive!
		if (ListItem.IsA('robojumper_UISquadSelect_ListItem'))
		{
			ExtraHeight = 0;
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
			DDCheckbox.SetY(ListItem.Height + ExtraHeight);
			ListItem.SetY(ListItem.Y - DDCheckbox.Height - 10);
		}
		else
		{
			//`AMLOG("Regular panel. Y:" @ ListItem.Y @ "Height:" @ ListItem.Height);
			DDCheckbox.SetY(362);
			ListItem.SetY(ListItem.Y - DDCheckbox.Height);
		}
	}
	return ELR_NoInterrupt;
}
static private function OnLaunchMission(UIButton Button)
{
	local UIChooseUnits_SquadSelect ChooseUnits;
	local XComPresentationLayerBase Pres;

	Pres = Button.Movie.Pres;
	ChooseUnits = Pres.Spawn(class'UIChooseUnits_SquadSelect', Pres);
	Pres.ScreenStack.Push(ChooseUnits);
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

	// This event probably isn't triggered by anything other Request Evac, but better safe than sorry
	if (class'Help'.static.IsModActive('RequestEvac'))
	{
		// This event is triggered when evac is requested with Request Evac mod.
		Template.AddCHEvent('EvacRequested', OnEvacRequested, ELD_OnStateSubmitted); 
	}
	// This triggers when Skyranger arrives.
	Template.AddCHEvent('EvacZonePlaced', OnSpawnEvacZoneComplete, ELD_OnStateSubmitted); 

	Template.AddCHEvent('PlayerTurnBegun', OnPlayerTurnBegun, ELD_OnStateSubmitted);
	Template.AddCHEvent('UnitEvacuated', OnUnitEvacuated, ELD_OnStateSubmitted);
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
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Select', false, NewGameState);
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
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Select', true, NewGameState);
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy', true, NewGameState);
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy_Spark', true, NewGameState);
	class'XComGameState_BattleData'.static.SetGlobalAbilityEnabled('IRI_DynamicDeployment_Deploy_Uplink', true, NewGameState);

	// Skyranger just arrived for evac, can't request DD for a turn.
	class'Help'.static.PutSkyrangerOnCooldown(1, NewGameState, true);

	`GAMERULES.SubmitGameState(NewGameState);

	return ELR_NoInterrupt;
}



// Mark evacuated units with a unit value so that we know not to reinit their abilities if we're gonna redeploy them again in the same mission.
static private function EventListenerReturn OnUnitEvacuated(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit UnitState;

	UnitState = XComGameState_Unit(EventData);
	if (UnitState == none)
		return ELR_NoInterrupt;

	class'Help'.static.MarkUnitEvaced(UnitState);

	// Evacuating a unit puts DD abilities on 1 turn cooldown - skyranger is busy recieving a unit and cannot be used for deployment.
	class'Help'.static.PutSkyrangerOnCooldown(1,, true);

	return ELR_NoInterrupt;
}

// Rremove the "in skyranger" flag from all units
// as normally it would be removed only at the begin tactical play, which is too late for the purposes of deploying units.
static private function EventListenerReturn OnCleanupTacticalMission(Object EventData, Object EventSource, XComGameState NewGameState, Name Event, Object CallbackData)
{
	local XComGameState_Unit	UnitState;
	local XComGameState_Unit	NewUnitState;
	local XComGameStateHistory	History;

	History = `XCOMHISTORY;

	foreach History.IterateByClassType(class'XComGameState_Unit', UnitState)
	{
		NewUnitState = XComGameState_Unit(NewGameState.GetGameStateForObjectID(UnitState.ObjectID));
		if (NewUnitState == none)
		{
			NewUnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
		}
		NewUnitState.ClearUnitValue(class'Help'.default.DynamicDeploymentValue);
		NewUnitState.ClearUnitValue(class'Help'.default.UnitEvacedValue);

		`AMLOG(NewUnitState.GetFullName() @ "is no longer in Skyranger");
	}

	return ELR_NoInterrupt;
}