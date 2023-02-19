//  FILE:    Help.uc
//  AUTHOR:  Iridar  --  20/04/2022
//  PURPOSE: Helper class for static functions and script snippet repository.     
//---------------------------------------------------------------------------------------

class Help extends Object abstract;

// Event triggered after Deployment is complete. 
var privatewrite name DDEventName;

static final function int GetDeploymentType()
{
	if (ShouldUseTeleportDeployment())
	{
		return `eDT_TeleportBeacon;
	}
	if (IsUndergroundPlot())
	{
		return `eDT_SeismicBeacon;
	}
	return `eDT_Flare;
}

static final function bool ShouldUseDigitalUplink(const XComGameState_Unit SourceUnit)
{
	return IsDDAbilityUnlocked(SourceUnit, 'IRI_DDUnlock_DigitalUplink');
}

// Teleport deployment has a different visualization, but also different rules:
// no concealment break for spark-like units, no Aerial Scout.
static private function bool ShouldUseTeleportDeployment()
{
	return `XCOMHQ.IsTechResearched(`GetConfigName("IRI_DD_TechRequiredToUnlockTeleport"));
}

// Different deployment visualization is used on underground plots
static final function bool IsUndergroundPlot()
{
	local XComGameState_BattleData	BattleData;
	local XComGameState_MissionSite MissionSite;
	local XComGameStateHistory		History;

	History = `XCOMHISTORY;
	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData', true));
	if (BattleData != none)
	{
		MissionSite = XComGameState_MissionSite(History.GetGameStateForObjectID(BattleData.m_iMissionID));
		if (MissionSite != none)
		{
			switch (MissionSite.GeneratedMission.Plot.strType)
			{
				case "Tunnels_Sewer":
				case "Tunnels_Subway":
				case "Stronghold":
					return true;
				default:
					break;
			}
		}
	}
	return false;
}

static final function SetGlobalCooldown(const name AbilityName, const int Cooldown, const int SourcePlayerID, optional XComGameState UseGameState)
{
	local XComGameState			NewGameState;
	local XComGameStateHistory	History;
	local XComGameState_Player	PlayerState;

	History = `XCOMHISTORY;
	PlayerState = XComGameState_Player(History.GetGameStateForObjectID(SourcePlayerID));
	if (PlayerState == none)
		return;

	if (UseGameState != none)
	{
		PlayerState = XComGameState_Player(UseGameState.ModifyStateObject(PlayerState.Class, PlayerState.ObjectID));
		PlayerState.SetCooldown(AbilityName, Cooldown);
	}
	else
	{	
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(AbilityName @ "set global cooldown:" @ Cooldown);
		PlayerState = XComGameState_Player(NewGameState.ModifyStateObject(PlayerState.Class, PlayerState.ObjectID));
		PlayerState.SetCooldown(AbilityName, Cooldown);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

static final function bool IsUnitEligibleForDDAbilities(const XComGameState_Unit UnitState)
{
	local array<name> ExclusionList;

	ExclusionList = `GetConfigArrayName("IRI_DD_SoldierClasses_DisallowDD", true);
	if (ExclusionList.Find(UnitState.GetSoldierClassTemplateName()) != INDEX_NONE)
		return false;

	ExclusionList = `GetConfigArrayName("IRI_DD_CharacterTemplates_DisallowDD", true);
	if (ExclusionList.Find(UnitState.GetMyTemplateName()) != INDEX_NONE)
		return false;

	return UnitState.IsSoldier();
}

static final function bool IsUnitEligibleForDynamicDeployment(const XComGameState_Unit UnitState)
{
	// Unit will still be in squad if they were evacuated.
	// So disallow only units that were not evacuated that are in squad.
	if (!UnitState.bRemovedFromPlay && `XCOMHQ.Squad.Find('ObjectID', UnitState.ObjectID) != INDEX_NONE) return false;
	if (!IsUnitEligibleForDDAbilities(UnitState)) return false;
	//if (UnitState.IsDead()) return false; // Checked by CanGoOnMission()
	if (!UnitState.CanGoOnMission()) return false;

	return true;
}

// Spark-like units use a different skyranger drop / underground drop animation,
// and use a different set of DD unlocks.
static final function bool IsCharTemplateSparkLike(const X2CharacterTemplate CharTemplate)
{
	local array<name> NameList;

	NameList = `GetConfigArrayName("IRI_DD_SoldierClasses_SparkLike", true);
	if (NameList.Find(CharTemplate.DataName) != INDEX_NONE)
		return true;

	NameList = `GetConfigArrayName("IRI_DD_CharacterTemplates_NOT_SparkLike", true);
	if (NameList.Find(CharTemplate.DataName) != INDEX_NONE)
		return false;

	return CharTemplate.UnitSize == 1 && CharTemplate.UnitHeight == 3;
}

static final function name GetAbilityUnitValue(const name AbilityName)
{
	return name("IRI_" $ AbilityName $ "_JPUnlock");
}

// Whether a unit has a DD Unlock is stored as a unit value,
// ability itself is added to the unit in ModifyEarnedAbilities in X2DLCInfo.
static final function bool IsDDAbilityUnlocked(const XComGameState_Unit UnitState, const name AbilityName)
{
	local UnitValue UV;
	
	return UnitState.GetUnitValue(GetAbilityUnitValue(AbilityName), UV);
}

// --------------------

static final function bool IsModActive(name ModName)
{
    local XComOnlineEventMgr    EventManager;
    local int                   Index;

    EventManager = `ONLINEEVENTMGR;

    for (Index = EventManager.GetNumDLC() - 1; Index >= 0; Index--) 
    {
        if (EventManager.GetDLCNames(Index) == ModName) 
        {
            return true;
        }
    }
    return false;
}

static final function bool AreModsActive(const array<name> ModNames)
{
	local name ModName;

	foreach ModNames(ModName)
	{
		if (!IsModActive(ModName))
		{
			return false;
		}
	}
	return true;
}


static final function string GetLocalizedString(const coerce string StringName)
{
	return Localize("Help", StringName, "WOTCIridarDynamicDeployment");
}

defaultproperties
{
	DDEventName = "IRI_DynamicDeployment_Triggered_Event"
}