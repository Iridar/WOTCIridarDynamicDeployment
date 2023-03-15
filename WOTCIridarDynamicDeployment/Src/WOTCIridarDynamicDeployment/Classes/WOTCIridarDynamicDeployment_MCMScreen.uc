class WOTCIridarDynamicDeployment_MCMScreen extends Object config(WOTCIridarDynamicDeployment);

var config int VERSION_CFG;

var localized string ModName;
var localized string PageTitle;
var localized string GroupHeader1;
var localized string GroupHeader2;
var localized string GroupHeader3;
var localized string GroupHeader4;

var localized string EndLabel;
var localized string EndLabel_Tip;

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_Includes.uci)

`MCM_API_AutoSliderVars(DEPLOY_CAST_RANGE_TILES);
`MCM_API_AutoCheckBoxVars(SQUAD_MUST_SEE_TILE);
`MCM_API_AutoCheckBoxVars(DD_SOLDIER_SELECT_IS_FREE_ACTION);
`MCM_API_AutoCheckBoxVars(DD_SOLDIER_SELECT_ENDS_TURN);
`MCM_API_AutoCheckBoxVars(DD_DEPLOY_IS_FREE_ACTION);
`MCM_API_AutoCheckBoxVars(DD_DEPLOY_ENDS_TURN);
`MCM_API_AutoCheckBoxVars(DEBUG_LOGGING);

`MCM_API_AutoCheckBoxVars(ENABLE_SOLDIER_LIST_CHECKBOX);
`MCM_API_AutoCheckBoxVars(ENABLE_ARMORY_CHECKBOX);
`MCM_API_AutoCheckBoxVars(ENABLE_LAUNCH_MISSION_SCREEN);

`include(WOTCIridarDynamicDeployment\Src\ModConfigMenuAPI\MCM_API_CfgHelpers.uci)

`MCM_API_AutoSliderFns(DEPLOY_CAST_RANGE_TILES,, 1);
`MCM_API_AutoCheckBoxFns(SQUAD_MUST_SEE_TILE, 1);
`MCM_API_AutoCheckBoxFns(DD_SOLDIER_SELECT_IS_FREE_ACTION, 1);
`MCM_API_AutoCheckBoxFns(DD_SOLDIER_SELECT_ENDS_TURN, 1);
`MCM_API_AutoCheckBoxFns(DD_DEPLOY_IS_FREE_ACTION, 1);
`MCM_API_AutoCheckBoxFns(DD_DEPLOY_ENDS_TURN, 1);
`MCM_API_AutoCheckBoxFns(DEBUG_LOGGING, 1);

`MCM_API_AutoCheckBoxFns(ENABLE_SOLDIER_LIST_CHECKBOX, 1);
`MCM_API_AutoCheckBoxFns(ENABLE_ARMORY_CHECKBOX, 1);
`MCM_API_AutoCheckBoxFns(ENABLE_LAUNCH_MISSION_SCREEN, 1);

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

	// Interface Options

	Group = Page.AddGroup('Group4', GroupHeader4);

	`MCM_API_AutoAddCheckBox(Group, ENABLE_SOLDIER_LIST_CHECKBOX);	
	`MCM_API_AutoAddCheckBox(Group, ENABLE_ARMORY_CHECKBOX);	
	`MCM_API_AutoAddCheckBox(Group, ENABLE_LAUNCH_MISSION_SCREEN);	

	// Deployment Options

	Group = Page.AddGroup('Group1', GroupHeader1);

	`MCM_API_AutoAddSLider(GROUP, DEPLOY_CAST_RANGE_TILES, 0, 99, 1);
	`MCM_API_AutoAddCheckBox(Group, SQUAD_MUST_SEE_TILE);	

	// Action Economy

	Group = Page.AddGroup('Group2', GroupHeader2);

	`MCM_API_AutoAddCheckBox(Group, DD_SOLDIER_SELECT_IS_FREE_ACTION, DD_SOLDIER_SELECT_IS_FREE_ACTION_ChangeHandler);	
	`MCM_API_AutoAddCheckBox(Group, DD_SOLDIER_SELECT_ENDS_TURN);	
	Group.GetSettingByName('DD_SOLDIER_SELECT_ENDS_TURN').SetEditable(!DD_SOLDIER_SELECT_IS_FREE_ACTION); 
	
	`MCM_API_AutoAddCheckBox(Group, DD_DEPLOY_IS_FREE_ACTION, DD_DEPLOY_IS_FREE_ACTION_ChangeHandler);	
	`MCM_API_AutoAddCheckBox(Group, DD_DEPLOY_ENDS_TURN);	
	Group.GetSettingByName('DD_DEPLOY_ENDS_TURN').SetEditable(!DD_DEPLOY_IS_FREE_ACTION); 

	// Misc

	Group = Page.AddGroup('Group3', GroupHeader3);

	`MCM_API_AutoAddCheckBox(Group, DEBUG_LOGGING);	
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
	DEPLOY_CAST_RANGE_TILES = `GETMCMVAR(DEPLOY_CAST_RANGE_TILES);
	SQUAD_MUST_SEE_TILE = `GETMCMVAR(SQUAD_MUST_SEE_TILE);
	DD_SOLDIER_SELECT_IS_FREE_ACTION = `GETMCMVAR(DD_SOLDIER_SELECT_IS_FREE_ACTION);
	DD_SOLDIER_SELECT_ENDS_TURN = `GETMCMVAR(DD_SOLDIER_SELECT_ENDS_TURN);
	DD_DEPLOY_IS_FREE_ACTION = `GETMCMVAR(DD_DEPLOY_IS_FREE_ACTION);
	DD_DEPLOY_ENDS_TURN = `GETMCMVAR(DD_DEPLOY_ENDS_TURN);
	DEBUG_LOGGING = `GETMCMVAR(DEBUG_LOGGING);

	ENABLE_SOLDIER_LIST_CHECKBOX = `GETMCMVAR(ENABLE_SOLDIER_LIST_CHECKBOX);
	ENABLE_LAUNCH_MISSION_SCREEN = `GETMCMVAR(ENABLE_LAUNCH_MISSION_SCREEN);
	ENABLE_ARMORY_CHECKBOX = `GETMCMVAR(ENABLE_ARMORY_CHECKBOX);
}

simulated function ResetButtonClicked(MCM_API_SettingsPage Page)
{
	`MCM_API_AutoReset(SQUAD_MUST_SEE_TILE);
	`MCM_API_AutoReset(DEPLOY_CAST_RANGE_TILES);
	`MCM_API_AutoReset(DD_SOLDIER_SELECT_IS_FREE_ACTION);
	`MCM_API_AutoReset(DD_SOLDIER_SELECT_ENDS_TURN);
	`MCM_API_AutoReset(DD_DEPLOY_IS_FREE_ACTION);
	`MCM_API_AutoReset(DD_DEPLOY_ENDS_TURN);
	`MCM_API_AutoReset(DEBUG_LOGGING);

	`MCM_API_AutoReset(ENABLE_SOLDIER_LIST_CHECKBOX);
	`MCM_API_AutoReset(ENABLE_LAUNCH_MISSION_SCREEN);
	`MCM_API_AutoReset(ENABLE_ARMORY_CHECKBOX);
}


simulated function SaveButtonClicked(MCM_API_SettingsPage Page)
{
	VERSION_CFG = `MCM_CH_GetCompositeVersion();
	SaveConfig();
}
