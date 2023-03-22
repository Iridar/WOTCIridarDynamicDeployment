class UISL_DynamicDeployment extends UIScreenListener;

// This UISL for Squad Select handles:
// 1. Adding a checkbox under each soldier
// 2. Replacing the delegate for clicking on the Launch Mission button.
// This needs to be done in a UISL, there's no event to do it in time.

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

var private bool bRegistered;
var private bool bRJSS;
var private string PathToActor;

event OnInit(UIScreen Screen)
{
	local UISquadSelect SquadSelect;
	local Object SelfObj;

	SquadSelect = UISquadSelect(Screen);
	if (SquadSelect == none)
		return;

	if (!class'Help'.static.IsDynamicDeploymentUnlocked())
		return;

	// Don't add new UI elements if the DD can't be used on this mission anyway.
	if (!class'Help'.static.IsDynamicDeploymentAllowed())
		return;

	bRegistered = true;

	if (`GETMCMVAR(ENABLE_LAUNCH_MISSION_SCREEN))
	{
		PatchLaunchMissionButton(SquadSelect);
	}

	UpdateSquad();

	if (`GETMCMVAR(ENABLE_SOLDIER_LIST_CHECKBOX))
	{
		// Insert checkboxes immedaitely.
		UpdateSquadSelect();

		// If the player is using RJSS, we can just listen to its UpdateData event.
		if (class'Help'.static.IsModActive('robojumperSquadSelect_WotC'))
		{
			bRJSS = true;
			SelfObj = self;
			`XEVENTMGR.RegisterForEvent(SelfObj, 'rjSquadSelect_UpdateData', OnSquadSelectUpdate, ELD_OnStateSubmitted, 49);
		}
		else
		{
			// When not using RJSS, have to use an Actor to run updates regularly 
			// so that checkbox is removed when a soldier is removed from squad.
			`AMLOG("Creating Actor");
			GetOrCreateActor();
		}
	}
}

event OnRemoved(UIScreen Screen)
{
	local Object SelfObj;

	if (!bRegistered || UISquadSelect(Screen) == none)
		return;

	if (bRJSS)
	{
		SelfObj = self;
		`XEVENTMGR.UnregisterFromEvent(SelfObj, 'rjSquadSelect_UpdateData');
	}
	else 
	{	
		`AMLOG("Destroying Actor");
		GetOrCreateActor().Destroy();
	}
}

event OnLoseFocus(UIScreen Screen)
{
	if (!bRegistered || UISquadSelect(Screen) == none)
		return;

	if (!bRJSS)
	{
		`AMLOG("Pause Actor");
		GetOrCreateActor().SetTickIsDisabled(true);
	}
}

event OnReceiveFocus(UIScreen Screen)
{
	if (!bRegistered || UISquadSelect(Screen) == none)
		return;

	UpdateSquad();
	UpdateSquadSelect();

	if (!bRJSS)
	{
		`AMLOG("Resume Actor");
		GetOrCreateActor().SetTickIsDisabled(false);
	}
}

// One function for creating checkbox when the screen is initialized, 
// and, when screen receives focus, updating their status (in case soldier's DD status is changed elsewhere) 
// and position (in case soldier list item becomes taller e.g. due to unlocking more abilities and the ability panel becoming taller)
static private function EventListenerReturn OnSquadSelectUpdate(Object EventData, Object EventSource, XComGameState GameState, Name Event, Object CallbackData)
{
	UpdateSquad();
	UpdateSquadSelect();

	return ELR_NoInterrupt;
}

static final function UpdateSquadSelect()
{
	local UISquadSelect						  SquadSelect;
	local UISquadSelect_ListItem			  ListItem;
	local array<UIPanel>					  ChildrenPanels;
	local UIPanel							  ChildPanel;
	local XComGameState_Unit				  UnitState;
	local XComGameStateHistory				  History;
	local bool								  bChecked;
	local bool								  bShouldHaveCheckbox;
	local UIMechaListItem_ClickToggleCheckbox DDCheckbox;

	SquadSelect = UISquadSelect(`HQPRES.ScreenStack.GetFirstInstanceOf(class'UISquadSelect'));
	if (SquadSelect == none)
		return;

	`AMLOG("Running");

	History = `XCOMHISTORY;

	// Add a checkbox under each soldier poster.
	SquadSelect.GetChildrenOfType(class'UISquadSelect_ListItem', ChildrenPanels);
	foreach ChildrenPanels(ChildPanel)
	{	
		ListItem = UISquadSelect_ListItem(ChildPanel);
		if (ListItem == none)
			continue;

		bShouldHaveCheckbox = false;
		bChecked = false;

		if (!ListItem.bDisabled)
		{
			UnitState = XComGameState_Unit(History.GetGameStateForObjectID(ListItem.GetUnitRef().ObjectID));
			if (UnitState != none && class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
			{	
				bChecked = class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState);
				bShouldHaveCheckbox = true;

				`AMLOG("Looking at soldier:" @ UnitState.GetFullName() @ class'Help'.static.IsUnitMarkedForDynamicDeploymentDefault(UnitState) @ `ShowVar(bChecked));
			}
		}

		DDCheckbox = UIMechaListItem_ClickToggleCheckbox(ListItem.GetChildByName('IRI_DD_SquadSelect_Checkbox', false));
		if (DDCheckbox == none)
		{
			if (bShouldHaveCheckbox)
			{
				// Checkbox should be there, but it's not there. Create it.
				DDCheckbox = ListItem.Spawn(class'UIMechaListItem_ClickToggleCheckbox', ListItem);
				DDCheckbox.bAnimateOnInit = false;
				DDCheckbox.InitListItem('IRI_DD_SquadSelect_Checkbox');
				DDCheckbox.UpdateDataCheckbox(`CAPS(`GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel")), "", bChecked, none, none);
				DDCheckbox.SetWidth(465);
				DDCheckbox.UnitState = UnitState;
				DDCheckbox.UpdatePosition(ListItem);
			}
			else
			{
				// Checkbox should not be there, and is not there, go to the next squad member.
				continue;
			}
		}
		else
		{
			if (bShouldHaveCheckbox)
			{
				// Checkbox should be there and is there, just update the value.
				// Have to update position too in case player returns to squad select from armory where they unlocked more perks
				// and soldier list item became taller
				DDCheckbox.UpdatePosition(ListItem);
				DDCheckbox.Show();
				DDCheckbox.Checkbox.SetChecked(bChecked, false);
			}
			else
			{
				DDCheckbox.Hide();
			}
		}
	}
	`AMLOG("Done");
}

static final function UpdateSquad()
{
	local XComGameState_Unit				UnitState;
	local XComGameStateHistory				History;
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				UnitRef;

	// When adding soldiers to squad select, ensure that at least one is not marked for DD.
	// This also technically runs if there are no soldiers at all in squad select but eh
	if (class'Help'.static.GetNumUnmarkedSquadMembers() == 0)
	{
		UnmarkOneSoldier();
	}

	// Handle DD mark for soldiers that have DD enabled on their Armory screen,
	// which means DD should be used for them whenever possible.
	History = `XCOMHISTORY;
	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	foreach XComHQ.Squad(UnitRef)
	{	
		if (class'Help'.static.GetNumUnmarkedSquadMembers() == 1)
			break;

		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState == none || !class'Help'.static.IsUnitEligibleForDDAbilities(UnitState))
			continue;

		if (class'Help'.static.IsUnitMarkedForDynamicDeploymentDefault(UnitState))
		{
			class'Help'.static.MarkUnitForDynamicDeployment(UnitState, true);
		}
	}
}

static final function UnmarkOneSoldier()
{
	local XComGameState_HeadquartersXCom	XComHQ;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	local XComGameStateHistory				History;

	`AMLOG("Running" @ class'Help'.static.GetNumUnmarkedSquadMembers());

	History = `XCOMHISTORY;

	XComHQ = XComGameState_HeadquartersXCom(History.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersXCom'));
	foreach XComHQ.Squad(UnitRef)
	{
		UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
		if (UnitState == none)
			continue;

		`AMLOG("Unmarking" @ UnitState.GetFullName());

		class'Help'.static.MarkUnitForDynamicDeployment(UnitState, false);
		break;
	}
}


// Add an intermediate step of showing a UIScreen with the squad so the player can select units that will remain in Skyranger for DD.
static private function PatchLaunchMissionButton(UISquadSelect SquadSelect)
{	
	local UILargeButton DummyButton;

	if (SquadSelect.LaunchButton.GetChildByName('IRI_DD_DummyLaunchButton', false) != none)
		return;
		
	DummyButton = SquadSelect.LaunchButton.Spawn(class'UILargeButton', SquadSelect.LaunchButton);
	DummyButton.InitPanel('IRI_DD_DummyLaunchButton');
	DummyButton.OnClickedDelegate = SquadSelect.LaunchButton.OnClickedDelegate;
	SquadSelect.LaunchButton.OnClickedDelegate = OnLaunchMissionClicked;
	DummyButton.Hide();
	DummyButton.SetPosition(-100, -100);
}
static private function OnLaunchMissionClicked(UIButton Button)
{
	local UIChooseUnits ChooseUnits;
	local XComPresentationLayerBase Pres;

	Pres = Button.Movie.Pres;
	ChooseUnits = Pres.Spawn(class'UIChooseUnits', Pres);
	Pres.ScreenStack.Push(ChooseUnits);
}


private function SSUpdateActor GetOrCreateActor()
{	
	local SSUpdateActor TheActor;

	if (PathToActor != "")
	{
		TheActor = SSUpdateActor(FindObject(PathToActor, class'SSUpdateActor'));
		if (TheActor != none)
		{
			return TheActor;
		}
	}

	TheActor = `XCOMGRI.Spawn(class'SSUpdateActor');
	TheActor.UISL = self;
	PathToActor = PathName(TheActor);
	return TheActor;
}