class WOTCIridarDynamicDeployment_MCMScreen extends Object config(WOTCIridarDynamicDeployment);

var config int VERSION_CFG;

var localized string ModName;
var localized string PageTitle;
var localized string GroupHeader;
var localized string GroupHeader2;
var localized string GroupHeader3;
var localized string EndLabel;
var localized string EndLabel_Tip;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

`MCM_API_AutoSliderVars(DD_OVER_SQUAD_SIZE_OFFSET);
`MCM_API_AutoSliderVars(DD_SOLDIER_SELECT_DELAY_TURNS_FLAT);
`MCM_API_AutoSliderVars(DD_SOLDIER_SELECT_DELAY_TURNS_PER_UNIT);
`MCM_API_AutoSliderVars(DD_AFTER_DEPLOY_COOLDOWN);
`MCM_API_AutoSliderVars(DD_MISSION_START_DELAY_TURNS);
`MCM_API_AutoSliderVars(DEPLOY_CAST_RANGE_TILES);
`MCM_API_AutoCheckBoxVars(SQUAD_MUST_SEE_TILE);
`MCM_API_AutoCheckBoxVars(DD_SOLDIER_SELECT_IS_FREE_ACTION);
`MCM_API_AutoCheckBoxVars(DD_SOLDIER_SELECT_ENDS_TURN);
`MCM_API_AutoCheckBoxVars(DD_DEPLOY_IS_FREE_ACTION);
`MCM_API_AutoCheckBoxVars(DD_DEPLOY_ENDS_TURN);

`MCM_API_AutoCheckBoxVars(COUNT_DEAD_SOLDIERS);
`MCM_API_AutoCheckBoxVars(COUNT_CAPTURED_SOLDIERS);
`MCM_API_AutoCheckBoxVars(COUNT_UNCONSCIOUS_SOLDIERS);
`MCM_API_AutoCheckBoxVars(COUNT_BLEEDING_OUT_SOLDIERS);

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

`MCM_API_AutoSliderFns(DD_OVER_SQUAD_SIZE_OFFSET,, 1);
`MCM_API_AutoSliderFns(DD_SOLDIER_SELECT_DELAY_TURNS_FLAT,, 1);
`MCM_API_AutoSliderFns(DD_SOLDIER_SELECT_DELAY_TURNS_PER_UNIT,, 1);
`MCM_API_AutoSliderFns(DD_AFTER_DEPLOY_COOLDOWN,, 1);
`MCM_API_AutoSliderFns(DD_MISSION_START_DELAY_TURNS,, 1);
`MCM_API_AutoSliderFns(DEPLOY_CAST_RANGE_TILES,, 1);
`MCM_API_AutoCheckBoxFns(SQUAD_MUST_SEE_TILE, 1);
`MCM_API_AutoCheckBoxFns(DD_SOLDIER_SELECT_IS_FREE_ACTION, 1);
`MCM_API_AutoCheckBoxFns(DD_SOLDIER_SELECT_ENDS_TURN, 1);
`MCM_API_AutoCheckBoxFns(DD_DEPLOY_IS_FREE_ACTION, 1);
`MCM_API_AutoCheckBoxFns(DD_DEPLOY_ENDS_TURN, 1);

`MCM_API_AutoCheckBoxFns(COUNT_DEAD_SOLDIERS, 1);
`MCM_API_AutoCheckBoxFns(COUNT_CAPTURED_SOLDIERS, 1);
`MCM_API_AutoCheckBoxFns(COUNT_UNCONSCIOUS_SOLDIERS, 1);
`MCM_API_AutoCheckBoxFns(COUNT_BLEEDING_OUT_SOLDIERS, 1);

event OnInit(UIScreen Screen)
{
	`MCM_API_Register(Screen, ClientModCallback);
}

//Simple one group framework code
simulated function ClientModCallback(MCM_API_Instance ConfigAPI, int GameMode)
{
	local MCM_API_SettingsPage Page;
	local MCM_API_SettingsGroup Group;

	LoadSavedSettings();
	Page = ConfigAPI.NewSettingsPage(ModName);
	Page.SetPageTitle(PageTitle);
	Page.SetSaveHandler(SaveButtonClicked);
	Page.EnableResetButton(ResetButtonClicked);

	Group = Page.AddGroup('Group', GroupHeader);

	// "Soldier Selection Options"
	`MCM_API_AutoAddSLider(GROUP, DD_MISSION_START_DELAY_TURNS, 0, 99, 1);
	`MCM_API_AutoAddSLider(GROUP, DD_SOLDIER_SELECT_DELAY_TURNS_FLAT, 0, 99, 1);
	`MCM_API_AutoAddSLider(GROUP, DD_SOLDIER_SELECT_DELAY_TURNS_PER_UNIT, 0, 99, 1);

	`MCM_API_AutoAddCheckBox(Group, DD_SOLDIER_SELECT_IS_FREE_ACTION, DD_SOLDIER_SELECT_IS_FREE_ACTION_ChangeHandler);	
	`MCM_API_AutoAddCheckBox(Group, DD_SOLDIER_SELECT_ENDS_TURN);	
	Group.GetSettingByName('DD_SOLDIER_SELECT_ENDS_TURN').SetEditable(!DD_SOLDIER_SELECT_IS_FREE_ACTION); 

	`MCM_API_AutoAddSLider(GROUP, DD_OVER_SQUAD_SIZE_OFFSET, 0, 99, 1);
	`MCM_API_AutoAddCheckBox(Group, COUNT_DEAD_SOLDIERS);	
	`MCM_API_AutoAddCheckBox(Group, COUNT_CAPTURED_SOLDIERS);	
	`MCM_API_AutoAddCheckBox(Group, COUNT_UNCONSCIOUS_SOLDIERS);	
	`MCM_API_AutoAddCheckBox(Group, COUNT_BLEEDING_OUT_SOLDIERS);	

	// "Soldier Deployment Options"
	Group = Page.AddGroup('Group_2', GroupHeader2);

	`MCM_API_AutoAddSLider(GROUP, DD_AFTER_DEPLOY_COOLDOWN, 0, 99, 1);
	`MCM_API_AutoAddSLider(GROUP, DEPLOY_CAST_RANGE_TILES, 0, 99, 1);
	`MCM_API_AutoAddCheckBox(Group, SQUAD_MUST_SEE_TILE);	

	`MCM_API_AutoAddCheckBox(Group, DD_DEPLOY_IS_FREE_ACTION, DD_DEPLOY_IS_FREE_ACTION_ChangeHandler);	
	`MCM_API_AutoAddCheckBox(Group, DD_DEPLOY_ENDS_TURN);	
	Group.GetSettingByName('DD_DEPLOY_ENDS_TURN').SetEditable(!DD_DEPLOY_IS_FREE_ACTION); 

	// Misc
	Group = Page.AddGroup('Group_3', GroupHeader3);

	Group.AddLabel('Label_End', EndLabel, EndLabel_Tip);
	
	Page.ShowSettings();
}

simulated function DD_SOLDIER_SELECT_IS_FREE_ACTION_ChangeHandler(MCM_API_Setting _Setting, bool _SettingValue)
{
	DD_SOLDIER_SELECT_IS_FREE_ACTION = _SettingValue;
	_Setting.GetParentGroup().GetSettingByName('DD_SOLDIER_SELECT_ENDS_TURN').SetEditable(!DD_SOLDIER_SELECT_IS_FREE_ACTION); 
}

simulated function DD_DEPLOY_IS_FREE_ACTION_ChangeHandler(MCM_API_Setting _Setting, bool _SettingValue)
{
	`AMLOG("Running");
	`AMLOG(`ShowVar(DD_DEPLOY_IS_FREE_ACTION) @ `ShowVar(_SettingValue));
	DD_DEPLOY_IS_FREE_ACTION = _SettingValue;

	`AMLOG("Set value for DD_DEPLOY_IS_FREE_ACTION:" @ DD_DEPLOY_IS_FREE_ACTION);

	`AMLOG("Setting:" @ _Setting != none @ "Parent group:" @ _Setting.GetParentGroup() @ "Setting by name:" @ _Setting.GetParentGroup().GetSettingByName('DD_DEPLOY_ENDS_TURN'));

	_Setting.GetParentGroup().GetSettingByName('DD_DEPLOY_ENDS_TURN').SetEditable(!DD_DEPLOY_IS_FREE_ACTION);
}

simulated function LoadSavedSettings()
{
	DD_OVER_SQUAD_SIZE_OFFSET = `GETMCMVAR(DD_OVER_SQUAD_SIZE_OFFSET);
	DD_SOLDIER_SELECT_DELAY_TURNS_FLAT = `GETMCMVAR(DD_SOLDIER_SELECT_DELAY_TURNS_FLAT);
	DD_SOLDIER_SELECT_DELAY_TURNS_PER_UNIT = `GETMCMVAR(DD_SOLDIER_SELECT_DELAY_TURNS_PER_UNIT);
	DD_AFTER_DEPLOY_COOLDOWN = `GETMCMVAR(DD_AFTER_DEPLOY_COOLDOWN);
	DD_MISSION_START_DELAY_TURNS = `GETMCMVAR(DD_MISSION_START_DELAY_TURNS);
	DEPLOY_CAST_RANGE_TILES = `GETMCMVAR(DEPLOY_CAST_RANGE_TILES);
	SQUAD_MUST_SEE_TILE = `GETMCMVAR(SQUAD_MUST_SEE_TILE);

	DD_SOLDIER_SELECT_IS_FREE_ACTION = `GETMCMVAR(DD_SOLDIER_SELECT_IS_FREE_ACTION);
	DD_SOLDIER_SELECT_ENDS_TURN = `GETMCMVAR(DD_SOLDIER_SELECT_ENDS_TURN);
	DD_DEPLOY_IS_FREE_ACTION = `GETMCMVAR(DD_DEPLOY_IS_FREE_ACTION);
	DD_DEPLOY_ENDS_TURN = `GETMCMVAR(DD_DEPLOY_ENDS_TURN);

	COUNT_DEAD_SOLDIERS = `GETMCMVAR(COUNT_DEAD_SOLDIERS);
	COUNT_CAPTURED_SOLDIERS = `GETMCMVAR(COUNT_CAPTURED_SOLDIERS);
	COUNT_UNCONSCIOUS_SOLDIERS = `GETMCMVAR(COUNT_UNCONSCIOUS_SOLDIERS);
	COUNT_BLEEDING_OUT_SOLDIERS = `GETMCMVAR(COUNT_BLEEDING_OUT_SOLDIERS);
}

simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	`MCM_API_AutoReset(DD_OVER_SQUAD_SIZE_OFFSET);
	`MCM_API_AutoReset(DD_SOLDIER_SELECT_DELAY_TURNS_FLAT);
	`MCM_API_AutoReset(DD_SOLDIER_SELECT_DELAY_TURNS_PER_UNIT);
	`MCM_API_AutoReset(DD_MISSION_START_DELAY_TURNS);
	`MCM_API_AutoReset(DD_AFTER_DEPLOY_COOLDOWN);
	`MCM_API_AutoReset(SQUAD_MUST_SEE_TILE);
	`MCM_API_AutoReset(DEPLOY_CAST_RANGE_TILES);

	`MCM_API_AutoReset(DD_SOLDIER_SELECT_IS_FREE_ACTION);
	`MCM_API_AutoReset(DD_SOLDIER_SELECT_ENDS_TURN);
	`MCM_API_AutoReset(DD_DEPLOY_IS_FREE_ACTION);
	`MCM_API_AutoReset(DD_DEPLOY_ENDS_TURN);

	`MCM_API_AutoReset(COUNT_DEAD_SOLDIERS);
	`MCM_API_AutoReset(COUNT_CAPTURED_SOLDIERS);
	`MCM_API_AutoReset(COUNT_UNCONSCIOUS_SOLDIERS);
	`MCM_API_AutoReset(COUNT_BLEEDING_OUT_SOLDIERS);
}


simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();
}
