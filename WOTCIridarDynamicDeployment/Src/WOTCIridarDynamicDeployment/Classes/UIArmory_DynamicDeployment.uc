class UIArmory_DynamicDeployment extends UISimpleCommodityScreen;
/*
struct native SoldierClassAbilityType
{
	var name AbilityName;
	var EInventorySlot ApplyToWeaponSlot;
	var name UtilityCat;
};
*/
struct DDUnlockStruct
{
	var SoldierClassAbilityType	Ability;
	var int						RequiredRank;
	var int						APCost;
	var bool					bRequireSparkLike;
	var StrategyRequirement		Requirements;
	var StrategyCost			Cost;
	var array<name>				RequiredUnlocks;
	var array<name>				MutuallyExclusiveUnlocks;
};

var privatewrite config(DynamicDeployment) array<DDUnlockStruct> DDUnlocks;

var private X2AbilityTemplateManager	AbilityMgr;
var private XComGameState_Unit			UnitState;
var StateObjectReference				m_UnitRef;
var private string						m_strUnlockedLabel;

private function bool ShouldDisplayDDUnlock(const DDUnlockStruct DDUnlock)
{
	if (DDUnlock.bRequireSparkLike && !class'Help'.static.IsCharTemplateSparkLike(UnitState.GetMyTemplate()))
	{
		return false;
	}
	return XComHQ.MeetsEnoughRequirementsToBeVisible(DDUnlock.Requirements);
}

simulated function bool IsItemPurchased(int ItemIndex)
{
	local UIInventory_DynamicDeploymentUnlock ListItem;
	
	ListItem = UIInventory_DynamicDeploymentUnlock(List.GetItem(ItemIndex));
	if (ListItem == none)
		return false;

	return class'Help'.static.IsDDAbilityUnlocked(UnitState, ListItem.DDUnlock.Ability.AbilityName);
}

simulated function bool CanAffordItem(int ItemIndex)
{
	local UIInventory_DynamicDeploymentUnlock ListItem;
	
	ListItem = UIInventory_DynamicDeploymentUnlock(List.GetItem(ItemIndex));
	if (ListItem == none)
		return false;

	return GetDisabledReason(ListItem.DDUnlock) == "";
}


//-------------- GAME DATA HOOKUP --------------------------------------------------------

simulated function InitScreen(XComPlayerController InitController, UIMovie InitMovie, optional name InitName)
{
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(m_UnitRef.ObjectID));
	if (UnitState == none)
		CloseScreen();

	if (UnitState.IsRobotic())
	{
		m_strTitle = `GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel_Robotic");
		m_strBuy = class'UIChooseUpgrade'.default.m_strUpgradeButton; // "Upgrade"
	}
	else
	{
		m_strTitle = `GetLocalizedString("IRI_DynamicDeployment_ArmoryLabel");
		m_strBuy = `GetLocalizedString("IRI_DynamicDeployment_UnlockLabel"); // "Unlock"
	}
	m_strSubTitleTitle = "";
	m_strConfirmButtonLabel = m_strBuy;

	AbilityMgr = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();

	super.InitScreen(InitController, InitMovie, InitName);

	ItemCard.Hide();
	Navigator.SetSelected(List);
	List.SetSelectedIndex(0);
}

private function string GetAbilityPointsString()
{
	return class'UIArmory_PromotionHero'.default.m_strSoldierAPLabel $ ": " $ UnitState.AbilityPoints @ class'UIArmory_PromotionHero'.default.m_strSharedAPLabel $ ": " $ XComHQ.GetAbilityPoints();
}

private function string GetDisabledReason(const DDUnlockStruct DDUnlock)
{	
	local X2AbilityTemplate				Template;
	local array<StrategyCostScalar>		DummyArray;
	local name UnlockName;

	DummyArray.Length = 0; // settle down, compiler

	// Mutually Exclusive Unlocks
	foreach DDUnlock.MutuallyExclusiveUnlocks(UnlockName)
	{
		Template = AbilityMgr.FindAbilityTemplate(UnlockName);
		if (Template == none)
			continue;

		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, UnlockName))
		{
			`AMLOG(UnitState.GetFullName() @ "has:" @ UnlockName @ "Unlocked, which is mutually exclusive with:" @ DDUnlock.Ability.AbilityName);
			return `YELLOW(`GetLocalizedString("IRI_DynamicDeployment_MutuallyExclusiveUnlock") @ GetListOfMutuallyExclusiveUnlocks(DDUnlock.MutuallyExclusiveUnlocks));
		}
	}
	// Strategy Requirements
	if (!XComHQ.MeetsAllStrategyRequirements(DDUnlock.Requirements))
	{
		return `YELLOW(class'UIUtilities_Strategy'.static.GetStrategyReqString(DDUnlock.Requirements));
	}
	// Strategy Cost
	if (!XComHQ.CanAffordAllStrategyCosts(DDUnlock.Cost, DummyArray))
	{
		return `YELLOW(class'UIUtilities_Strategy'.static.GetStrategyCostString(DDUnlock.Cost, DummyArray));
	}
	// Soldier Rank
	if (UnitState.GetSoldierRank() < DDUnlock.RequiredRank)
	{
		return `YELLOW(class'UIUtilities_Strategy'.default.m_strSoldierRank @ `GET_RANK_STR(DDUnlock.RequiredRank, UnitState.GetSoldierClassTemplateName()));
	}
	// Required Jet Pack Unlocks
	foreach DDUnlock.RequiredUnlocks(UnlockName)
	{
		Template = AbilityMgr.FindAbilityTemplate(UnlockName);
		if (Template == none)
			continue;

		if (!class'Help'.static.IsDDAbilityUnlocked(UnitState, UnlockName))
		{
			return `YELLOW(class'UIUtilities_Strategy'.default.m_strRequiredLabel $ ": " $ Template.LocFriendlyName);
		}
	}
	// Ability Point Cost
	if (DDUnlock.APCost > UnitState.AbilityPoints + XComHQ.GetAbilityPoints())
	{
		return `YELLOW(`GetLocalizedString("IRI_DynamicDeployment_NotEnoughAP"));
	}
	return "";
}

private function string GetListOfMutuallyExclusiveUnlocks(array<name> UnlockNames)
{
	local X2AbilityTemplate	Template;
	local name UnlockName;
	local string ReturnString;

	foreach UnlockNames(UnlockName)
	{
		Template = AbilityMgr.FindAbilityTemplate(UnlockName);
		if (Template == none)
			continue;

		if (ReturnString == "")
		{
			ReturnString = Template.LocFriendlyName;
		}
		else
		{
			ReturnString $= ", " $ Template.LocFriendlyName;
		}
	}
	return class'UIUtilities_Text'.static.FormatCommaSeparatedNouns(ReturnString);
}

simulated function PopulateData()
{
	local UIInventory_DynamicDeploymentUnlock	ListItem;
	local DDUnlockStruct						DDUnlock;
	local Commodity								AbilityCommodity;
	local X2AbilityTemplate						Template;
	local array<DDUnlockStruct>					UnlockedUpgrades;

	`AMLOG("Populating data");

	arrItems.Length = 0;
	List.ClearItems();
	List.bSelectFirstAvailable = false;

	m_strInventoryLabel = GetAbilityPointsString();
	`AMLOG("Setting category label:" @ m_strInventoryLabel);
	SetCategory(m_strInventoryLabel);

	foreach DDUnlocks(DDUnlock)
	{	
		if (!ShouldDisplayDDUnlock(DDUnlock))
			continue;

		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, DDUnlock.Ability.AbilityName))
		{	
			UnlockedUpgrades.AddItem(DDUnlock);
			continue;
		}

		`AMLOG("Looking for ability template:" @ DDUnlock.Ability.AbilityName);
		Template = AbilityMgr.FindAbilityTemplate(DDUnlock.Ability.AbilityName);
		if (Template == none)
			continue;

		`AMLOG("Found it. Disabled Reason:" @ GetDisabledReason(DDUnlock));


		AbilityCommodity.Title = Template.LocFriendlyName;
		AbilityCommodity.Image = Template.IconImage;
		AbilityCommodity.Desc = Template.GetMyLongDescription(, UnitState);
		if (DDUnlock.MutuallyExclusiveUnlocks.Length > 0)
		{
			AbilityCommodity.Desc @= `GetLocalizedString("IRI_DynamicDeployment_MutuallyExclusiveUnlock") @ GetListOfMutuallyExclusiveUnlocks(DDUnlock.MutuallyExclusiveUnlocks);
		}
		arrItems.AddItem(AbilityCommodity);

		ListItem = Spawn(class'UIInventory_DynamicDeploymentUnlock', List.itemContainer);
		ListItem.DDUnlock = DDUnlock;
		ListItem.strDisabledReason = GetDisabledReason(DDUnlock);
		ListItem.InitInventoryListCommodity(AbilityCommodity, , m_strBuy, m_eStyle, , 126);
	}

	foreach UnlockedUpgrades(DDUnlock)
	{	
		`AMLOG("Looking for ability template:" @ DDUnlock.Ability.AbilityName);
		Template = AbilityMgr.FindAbilityTemplate(DDUnlock.Ability.AbilityName);
		if (Template == none)
			continue;

		`AMLOG("Found it");

		AbilityCommodity.Title = Template.LocFriendlyName;
		AbilityCommodity.Image = Template.IconImage;
		AbilityCommodity.Desc = Template.GetMyLongDescription(, UnitState);
		if (DDUnlock.MutuallyExclusiveUnlocks.Length > 0)
		{
			AbilityCommodity.Desc @= `GetLocalizedString("IRI_DynamicDeployment_MutuallyExclusiveUnlock") @ GetListOfMutuallyExclusiveUnlocks(DDUnlock.MutuallyExclusiveUnlocks);
		}
		arrItems.AddItem(AbilityCommodity);

		ListItem = Spawn(class'UIInventory_DynamicDeploymentUnlock', List.itemContainer);
		ListItem.DDUnlock = DDUnlock;
		ListItem.bUnlocked = true;

		if (UnitState.IsRobotic())
		{
			ListItem.strUnlockedLabel = `GetLocalizedString("IRI_DynamicDeployment_UnlockedLabel_Robotic");
		}
		else
		{
			ListItem.strUnlockedLabel = `GetLocalizedString("IRI_DynamicDeployment_UnlockedLabel");
		}

		ListItem.InitInventoryListCommodity(AbilityCommodity, , "", m_eStyle, , 126);
	}
}


private function bool UnlockAbility(UIList kList, int itemIndex)
{
	local XComGameState NewGameState;
	local UIInventory_DynamicDeploymentUnlock ListItem;
	local int AbilityPointCost;
	local array<StrategyCostScalar> DummyArray;

	ListItem = UIInventory_DynamicDeploymentUnlock(kList.GetItem(itemIndex));
	if (ListItem == none)
		return false;

	DummyArray.Length = 0; 
	AbilityPointCost = ListItem.DDUnlock.APCost;

	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Unlock Jet Pack Ability");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
	UnitState.SetUnitFloatValue(class'Help'.static.GetAbilityUnitValue(ListItem.DDUnlock.Ability.AbilityName), 1.0f, eCleanup_Never);
	XComHQ = XComGameState_HeadquartersXCom(NewGameState.ModifyStateObject(XComHQ.Class, XComHQ.ObjectID));
	XComHQ.PayStrategyCost(NewGameState, ListItem.DDUnlock.Cost, DummyArray);

	UnitState.AbilityPoints -= AbilityPointCost;
	if (UnitState.AbilityPoints < 0)
	{
		XComHQ.AddResource(NewGameState, 'AbilityPoint', UnitState.AbilityPoints);
		UnitState.AbilityPoints = 0;
	}

	`GAMERULES.SubmitGameState(NewGameState);

	`XEVENTMGR.TriggerEvent('AbilityPointsChange', UnitState, , NewGameState);
	
	`AMLOG(UnitState.GetFullName() @ "Unlocked ability:" @ ListItem.DDUnlock.Ability.AbilityName);

	return true;
}


//-----------------------------------------------------------------------------

simulated function RefreshFacility() {}
simulated function PopulateResearchCard(optional Commodity ItemCommodity, optional StateObjectReference ItemRef) {}
simulated function GetItems() {}
simulated function OnCancelButton(UIButton kButton) { OnCancel(); }
simulated function OnCancel()
{
	CloseScreen();
}

simulated function OnLoseFocus()
{
	super.OnLoseFocus();
	`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();
}

simulated function OnReceiveFocus()
{
	super.OnReceiveFocus();
	`HQPRES.m_kAvengerHUD.NavHelp.ClearButtonHelp();
	`HQPRES.m_kAvengerHUD.NavHelp.AddBackButton(OnCancel);
}

//-------------- EVENT HANDLING --------------------------------------------------------

simulated function OnPurchaseClicked(UIList kList, int itemIndex)
{
	if (itemIndex != iSelectedItem)
	{
		iSelectedItem = itemIndex;
	}

	if (CanAffordItem(iSelectedItem))
	{
		if (UnlockAbility(kList, iSelectedItem))
		{
			`XSTRATEGYSOUNDMGR.PlaySoundEvent("StrategyUI_Staff_Assign");
			PopulateData();
		}
	}
	else
	{
		PlayNegativeSound(); // bsg-jrebar (4/20/17): New PlayNegativeSound Function in Parent Class
	}
}

defaultproperties
{
	InputState = eInputState_Consume;

	bHideOnLoseFocus = true;
	//bConsumeMouseEvents = true;

	//DisplayTag="UIDisplay_Academy"
	//CameraTag="UIDisplay_Academy"

	DisplayTag = "UIBlueprint_Promotion";
	CameraTag = "UIBlueprint_Promotion";
}
