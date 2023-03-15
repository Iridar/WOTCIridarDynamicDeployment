//  FILE:    Help.uc
//  AUTHOR:  Iridar  --  20/04/2022
//  PURPOSE: Helper class for static functions and script snippet repository.     
//---------------------------------------------------------------------------------------

class Help extends Object abstract;

// Event triggered after Deployment is complete. 
var privatewrite name DDEventName;
var privatewrite name UnitEvacedValue;
var privatewrite name DynamicDeploymentValue;

// Only units with this value will appear on UIChooseUnits screen.
// This for selecting which soldiers should remain in Skyranger in Squad Select.
// Also used to mark soldiers evaced during the mission so they can be redeployed.
static final function MarkUnitForDynamicDeployment(XComGameState_Unit UnitState, const bool bDeploy, optional XComGameState UseGameState)
{
	// Record and check specific mission state ObjectID so that mods that use infiltration mechanics allow DDing soldiers
	// only on missions they actually left to infiltrate.
	SetUnitValue(default.DynamicDeploymentValue, `XCOMHQ.MissionRef.ObjectID, UnitState, UseGameState, !bDeploy);
}
static final function bool IsUnitMarkedForDynamicDeployment(const XComGameState_Unit UnitState)
{
	local UnitValue UV;

	return UnitState.GetUnitValue(default.DynamicDeploymentValue, UV) && `XCOMHQ.MissionRef.ObjectID == UV.fValue;
}


static final function PutSkyrangerOnCooldown(const int iCooldown, optional XComGameState UseGameState, optional bool bDeploymentAbilitiesOnly)
{
	local XComGameState			NewGameState;
	local XComGameState_Player	PlayerState;
	local XComGameStateHistory	History;

	if (UseGameState != none)
	{
		foreach UseGameState.IterateByClassType(class'XComGameState_Player', PlayerState)
		{
			if (PlayerState.GetTeam() == eTeam_XCom)
			{
				PutSkyrangerOnCooldownInternal(PlayerState, iCooldown, bDeploymentAbilitiesOnly);
				return;
			}
		}

		History = `XCOMHISTORY;
		foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
		{
			if (PlayerState.GetTeam() == eTeam_XCom)
			{
				PlayerState = XComGameState_Player(UseGameState.ModifyStateObject(PlayerState.Class, PlayerState.ObjectID));
				PutSkyrangerOnCooldownInternal(PlayerState, iCooldown, bDeploymentAbilitiesOnly);
				return;
			}
		}
	}
	else
	{
		foreach History.IterateByClassType(class'XComGameState_Player', PlayerState)
		{
			if (PlayerState.GetTeam() == eTeam_XCom)
			{
				NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(GetFuncName() @ iCooldown);
				PlayerState = XComGameState_Player(UseGameState.ModifyStateObject(PlayerState.Class, PlayerState.ObjectID));
				PutSkyrangerOnCooldownInternal(PlayerState, iCooldown, bDeploymentAbilitiesOnly);
				`GAMERULES.SubmitGameState(NewGameState);
				return;
			}
		}
	}
}

static private function PutSkyrangerOnCooldownInternal(XComGameState_Player PlayerState, const int iCooldown, bool bDeploymentAbilitiesOnly)
{
	if (PlayerState.GetCooldown('IRI_DynamicDeployment_Select') < iCooldown) 
		PlayerState.SetCooldown('IRI_DynamicDeployment_Select', iCooldown);

	if (PlayerState.GetCooldown('IRI_DynamicDeployment_Deploy') < iCooldown) 
		PlayerState.SetCooldown('IRI_DynamicDeployment_Deploy', iCooldown);

	if (PlayerState.GetCooldown('IRI_DynamicDeployment_Deploy_Spark') < iCooldown) 
		PlayerState.SetCooldown('IRI_DynamicDeployment_Deploy_Spark', iCooldown);

	if (PlayerState.GetCooldown('IRI_DynamicDeployment_Deploy_Uplink') < iCooldown) 
		PlayerState.SetCooldown('IRI_DynamicDeployment_Deploy_Uplink', iCooldown);

	if (bDeploymentAbilitiesOnly)
		return;

	if (PlayerState.GetCooldown('Evac') < iCooldown) 
		PlayerState.SetCooldown('Evac', iCooldown);

	if (PlayerState.GetCooldown(class'CHHelpers'.static.GetPlaceEvacZoneAbilityName()) < iCooldown) 
		PlayerState.SetCooldown(class'CHHelpers'.static.GetPlaceEvacZoneAbilityName(), iCooldown);
}

static final function int GetDeploymentType()
{
	if (class'X2DLCInfo_Debug'.default.DeployTypeOverride != 0)
	{
		return class'X2DLCInfo_Debug'.default.DeployTypeOverride - 1;
	}
	if (IsUndergroundPlot())
	{
		return `eDT_SeismicBeacon;
	}
	return `eDT_Flare;
}


static final function MarkUnitEvaced(XComGameState_Unit UnitState, optional XComGameState UseGameState)
{
	SetUnitValue(default.UnitEvacedValue, 1.0f, UnitState, UseGameState);
}
static final function bool IsUnitEvaced(const XComGameState_Unit UnitState)
{
	local UnitValue UV;

	return UnitState.GetUnitValue(default.UnitEvacedValue, UV);
}

static private function SetUnitValue(const name UnitValueName, const float fValue, XComGameState_Unit UnitState, optional XComGameState UseGameState, optional const bool bClearValue)
{
	local XComGameState_Unit	NewUnitState;
	local XComGameState			NewGameState;

	if (UseGameState != none)
	{
		NewUnitState = XComGameState_Unit(UseGameState.GetGameStateForObjectID(UnitState.ObjectID));
		if (NewUnitState == none)
		{	
			NewUnitState = XComGameState_Unit(UseGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
		}
		if (bClearValue)
		{
			NewUnitState.ClearUnitValue(UnitValueName);
		}
		else
		{
			NewUnitState.SetUnitFloatValue(UnitValueName, fValue, eCleanup_BeginTactical);
		}
	}
	else
	{
		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Mark evaced unit:" @ UnitState.GetFullName());
		UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(UnitState.Class, UnitState.ObjectID));
		if (bClearValue)
		{
			UnitState.ClearUnitValue(UnitValueName);
		}
		else
		{
			UnitState.SetUnitFloatValue(UnitValueName, fValue, eCleanup_BeginTactical);
		}
		`GAMERULES.SubmitGameState(NewGameState);
	}
}

	
static final function bool ShouldUseDigitalUplink(const XComGameState_Unit SourceUnit)
{
	return IsDDAbilityUnlocked(SourceUnit, 'IRI_DDUnlock_DigitalUplink');
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
	local XComGameState_Player	PlayerState;

	if (UseGameState != none)
	{
		PlayerState = XComGameState_Player(UseGameState.GetGameStateForObjectID(SourcePlayerID));
		if (PlayerState == none)
		{
			PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(SourcePlayerID));
			if (PlayerState == none) return;

			PlayerState = XComGameState_Player(UseGameState.ModifyStateObject(PlayerState.Class, PlayerState.ObjectID));
			PlayerState.SetCooldown(AbilityName, Cooldown);
		}
		else
		{
			PlayerState.SetCooldown(AbilityName, Cooldown);
		}
	}
	else
	{
		PlayerState = XComGameState_Player(`XCOMHISTORY.GetGameStateForObjectID(SourcePlayerID));
		if (PlayerState == none) return;

		NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(AbilityName @ "set global cooldown:" @ Cooldown);
		PlayerState = XComGameState_Player(NewGameState.ModifyStateObject(PlayerState.Class, PlayerState.ObjectID));
		PlayerState.SetCooldown(AbilityName, Cooldown);
		`GAMERULES.SubmitGameState(NewGameState);
	}
}


static final function SetDynamicDeploymentCooldown(const int Cooldown, const int SourcePlayerID, optional XComGameState UseGameState)
{
	SetGlobalCooldown('IRI_DynamicDeployment_Select', Cooldown, SourcePlayerID, UseGameState);
	SetGlobalCooldown('IRI_DynamicDeployment_Deploy', Cooldown, SourcePlayerID, UseGameState);
	SetGlobalCooldown('IRI_DynamicDeployment_Deploy_Spark', Cooldown, SourcePlayerID, UseGameState);
	SetGlobalCooldown('IRI_DynamicDeployment_Deploy_Uplink', Cooldown, SourcePlayerID, UseGameState);
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
	return name("IRI_DD_Unlock_" $ AbilityName);
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
	DDEventName = "IRI_DD_Triggered_Event"
	UnitEvacedValue = "IRI_DD_UnitEvaced_Value"	
	DynamicDeploymentValue = "IRI_DD_UnitMark_Value"
}
