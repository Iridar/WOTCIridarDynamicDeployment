class UIInventory_DynamicDeploymentUnlock extends UIInventory_ClassListItem;

// List Item in the UIArmory_DynamicDeployment list of DD Unlocks in the Armory.

var DDUnlockStruct DDUnlock;

var bool bUnlocked;
var string strDisabledReason;
var string strUnlockedLabel;

var private UIIcon AbilityIcon;
var private UIText DisabledText;

simulated function UIPanel InitPanel(optional name InitName, optional name InitLibID)
{
	super.InitPanel(InitName, InitLibID);

	AbilityIcon = Spawn(class'UIIcon', self);
	AbilityIcon.InitIcon('IconMC',, false, true, 54); // 'IconMC' matches instance name of control in Flash's 'AbilityItem' Symbol // 36 default
	AbilityIcon.SetPosition(20, 20); // offset because we scale the icon

	//Icon.MC.FunctionVoid("hideSelectionBrackets");
	//Icon.LoadIcon("");
	//Icon.EnableMouseAutomaticColor(class'UIUtilities_Colors'.const.NORMAL_HTML_COLOR, class'UIUtilities_Colors'.const.BLACK_HTML_COLOR);
	//Icon.SetAlpha(0.08f);

	return self;
}

simulated function PopulateData(optional bool bRealizeDisabled)
{
	local array<StrategyCostScalar> DummyArray;
	local string strCostLabel;
	local string strStrategyCostLabel;

	DummyArray.Length = 0;

	AbilityIcon.LoadIcon(ItemComodity.Image);
	AbilityIcon.SetScale(2.0f);
	AbilityIcon.EnableMouseAutomaticColor(class'UIUtilities_Colors'.const.NORMAL_HTML_COLOR, class'UIUtilities_Colors'.const.BLACK_HTML_COLOR);
	
	MC.BeginFunctionOp("populateData");
	MC.QueueString("");
	MC.QueueString(ItemComodity.Title);

	if (bUnlocked)
	{
		MC.QueueString(strUnlockedLabel);
	}
	else
	{
		if (DDUnlock.APCost > 0)
		{
			strCostLabel = DDUnlock.APCost @ class'UIArmory_PromotionHero'.default.m_strAPLabel;
			strStrategyCostLabel = class'UIUtilities_Strategy'.static.GetStrategyCostString(DDUnlock.Cost, DummyArray);
			if (strStrategyCostLabel != "")
			{
				strCostLabel $= ", " $ strStrategyCostLabel;
			}
		}
		else 
		{
			strCostLabel = class'UIUtilities_Strategy'.static.GetStrategyCostString(DDUnlock.Cost, DummyArray);
		}
		MC.QueueString(strCostLabel);
	}

	MC.QueueString(ItemComodity.Desc);
	MC.EndOp();

	if (bRealizeDisabled || bUnlocked)
	{
		RealizeDisabledState();
	}
	else if (strDisabledReason != "")
	{
		RealizeBadState();

		DisabledText = Spawn(class'UIText', self);
		DisabledText.InitText('', strDisabledReason);
		DisabledText.SetPosition(20, 130); // offset because we scale the icon
	}
}

