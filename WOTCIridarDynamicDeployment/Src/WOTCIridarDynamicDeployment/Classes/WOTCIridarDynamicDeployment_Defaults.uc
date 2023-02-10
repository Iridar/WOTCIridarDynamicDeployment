class WOTCIridarDynamicDeployment_Defaults extends object config(WOTCIridarDynamicDeployment_DEFAULT);

var config int VERSION_CFG;

var config int DD_OVER_SQUAD_SIZE_OFFSET;
var config int DD_MISSION_START_DELAY_TURNS;
var config int DD_AFTER_DEPLOY_COOLDOWN;
var config int DD_SOLDIER_SELECT_DELAY_TURNS_FLAT;
var config int DD_SOLDIER_SELECT_DELAY_TURNS_PER_UNIT;
var config bool SQUAD_MUST_SEE_TILE;
var config int DEPLOY_CAST_RANGE_TILES;
var config bool DD_SOLDIER_SELECT_IS_FREE_ACTION;
var config bool DD_SOLDIER_SELECT_ENDS_TURN;
var config bool DD_DEPLOY_IS_FREE_ACTION;
var config bool DD_DEPLOY_ENDS_TURN;

var config bool COUNT_DEAD_SOLDIERS;
var config bool COUNT_CAPTURED_SOLDIERS;
var config bool COUNT_UNCONSCIOUS_SOLDIERS;
var config bool COUNT_BLEEDING_OUT_SOLDIERS;
var config bool COUNT_EVACED_SOLDIERS;
