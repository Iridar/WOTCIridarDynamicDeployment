class X2DLCInfo_WOTCIridarDynamicDeployment extends X2DownloadableContentInfo;

var private config(DynamicDeployment) array<name> CharTemplatesSkipDDAnimSet;


/// Start Issue #409
/// <summary>
/// Called from XComGameState_Unit:GetEarnedSoldierAbilities
/// Allows DLC/Mods to add to and modify a unit's EarnedSoldierAbilities
/// Has no return value, just modify the EarnedAbilities out variable array
/// </summary>
/// HL-Docs: feature:ModifyEarnedSoldierAbilities; issue:409; tags:
/// This allows mods to add to or otherwise modify earned abilities for units.
/// For example, the Officer Pack can use this to attach learned officer abilities to the unit.
///
/// Note: abilities added this way will **not** be picked up by `XComGameState_Unit::HasSoldierAbility()`
///
/// Elements of the `EarnedAbilities` array are structs of type `SoldierClassAbilityType`.
/// Each element has the following parameters:
///  * AbilityName - template name of the ability that should be added to the unit.
///  * ApplyToWeaponSlot - inventory slot of the item that this ability should be attached to.
/// Being attached to the correct item is critical for abilities that rely on the source item, 
/// for example abilities that deal damage of the weapon they are attached to.
/// * UtilityCat - used only if `ApplyToWeaponSlot = eInvSlot_Utility`. Optional. 
/// If specified, the ability will be initialized for the unit when they enter tactical combat 
/// only if they have a weapon with the specified weapon category in one of their utility slots.
///
///```unrealscript
/// local SoldierClassAbilityType NewAbility;
///
/// NewAbility.AbilityName = 'PrimaryWeapon_AbilityTemplateName';
/// NewAbility.ApplyToWeaponSlot = eInvSlot_Primary;
///
/// EarnedAbilities.AddItem(NewAbility);
///
/// NewAbility.AbilityName = 'UtilityItem_AbilityTemplateName';
/// NewAbility.ApplyToWeaponSlot = eInvSlot_Utility;
/// NewAbility.UtilityCat = 'UtilityItemWeaponCategory';
///
/// EarnedAbilities.AddItem(NewAbility);
///```
static function ModifyEarnedSoldierAbilities(out array<SoldierClassAbilityType> EarnedAbilities, XComGameState_Unit UnitState)
{
	local DDUnlockStruct DDUnlock;

	foreach class'UIArmory_DynamicDeployment'.default.DDUnlocks(DDUnlock)
	{
		if (class'Help'.static.IsDDAbilityUnlocked(UnitState, DDUnlock.Ability.AbilityName))
		{
			EarnedAbilities.AddItem(DDUnlock.Ability);
		}
	}
}
/// End Issue #409

static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_DynamicDeployment	DDObject;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Unit				UnitState;
	local int								ItemIndex;
	local int								i;

	`AMLOG("Running");

	DDObject = XComGameState_DynamicDeployment(StartGameState.CreateNewStateObject(class'XComGameState_DynamicDeployment'));

	foreach StartGameState.IterateByClassType(class'XComGameState_HeadquartersXCom', XComHQ)
	{
		`AMLOG("Found XComHQ...");
		for (i = XComHQ.Squad.Length - 1; i >= 0; i--)
		{
			UnitState = XComGameState_Unit(StartGameState.GetGameStateForObjectID(XComHQ.Squad[i].ObjectID));
			if (UnitState == none)
				continue;
				
			`AMLOG("Looking at soldier:" @ UnitState.GetFullName());

			if (class'Help'.static.IsUnitMarkedForDynamicDeployment(UnitState))
			{
				// During the mission, only these units will be potentially selectable for DD.
				DDObject.AddEligibleUnitID(UnitState.ObjectID);

				// Autoselect deployable units so they can be deployed from mission start without having to select them manually every time.
				DDObject.ToggleUnitSelection(UnitState.ObjectID);

				`AMLOG("Removing Dynamic Deployment unit from squad:" @ UnitState.GetFullName());

				for (ItemIndex = 0; ItemIndex < UnitState.InventoryItems.Length; ++ItemIndex)
				{
					StartGameState.PurgeGameStateForObjectID(UnitState.InventoryItems[ItemIndex].ObjectID);
				}

				StartGameState.PurgeGameStateForObjectID(UnitState.ObjectID);
				XComHQ.Squad.Remove(i, 1);
			}
		}
		break;
	}
}

static event OnPostTemplatesCreated()
{
	AddGTSUnlock('IRI_DynamicDeployment_GTS_Unlock');
	PatchCharTemplates();
}

static private function AddGTSUnlock(const name UnlockName)
{
	local X2StrategyElementTemplateManager StratMgr;
	local X2FacilityTemplate Template;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();

	Template = X2FacilityTemplate(StratMgr.FindStrategyElementTemplate('OfficerTrainingSchool'));
	Template.SoldierUnlockTemplates.AddItem(UnlockName);
}

static private function PatchCharTemplates()
{
	local X2CharacterTemplateManager	CharMgr;
	local X2CharacterTemplate			CharTemplate;
	local X2DataTemplate				DataTemplate;
	local XComContentManager			ContentMgr;
	local AnimSet						DDAnimSet_Spark;
	local AnimSet						DDAnimSet;

	ContentMgr = `CONTENT;
	DDAnimSet = AnimSet(ContentMgr.RequestGameArchetype("IRIDynamicDeployment.Anims.AS_JetPacks"));
	DDAnimSet_Spark = AnimSet(ContentMgr.RequestGameArchetype("IRIDynamicDeployment.Anims.AS_JetPacks_Spark"));
	CharMgr = class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager();

	foreach CharMgr.IterateTemplates(DataTemplate)
	{
		CharTemplate = X2CharacterTemplate(DataTemplate);
		if (!CharTemplate.bIsSoldier)	
			continue;

		if (default.CharTemplatesSkipDDAnimSet.Find(CharTemplate.DataName) != INDEX_NONE)
			continue;

		if (class'Help'.static.IsCharTemplateSparkLike(CharTemplate))
		{	
			CharTemplate.AdditionalAnimSets.AddItem(DDAnimSet_Spark);
		}
		else
		{
			CharTemplate.AdditionalAnimSets.AddItem(DDAnimSet);
		}
	}
}


static function string DLCAppendSockets(XComUnitPawn Pawn)
{
	local XComGameState_Unit		UnitState;
	local array<SkeletalMeshSocket> NewSockets;

	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(Pawn.ObjectID));
	if (UnitState == none || !UnitState.IsSoldier())
		return "";

	if (class'Help'.static.IsCharTemplateSparkLike(UnitState.GetMyTemplate()))
	{
		NewSockets.AddItem(CreateSocket('IRI_DD_DeployFlare', 'LHand', 12.676726f, 2.216607f, 3.509641f, 0, 0, 0));
	}
	else 
	{
		NewSockets.AddItem(CreateSocket('IRI_DD_DeployFlare', 'GrenadeClip', 0, 0, 0, 0, 0, 0));
	}

	Pawn.Mesh.AppendSockets(NewSockets, true);
	return "";
}
static private function SkeletalMeshSocket CreateSocket(const name SocketName, const name BoneName, optional const float X, optional const float Y, optional const float Z, optional const float dRoll, optional const float dPitch, optional const float dYaw, optional float ScaleX = 1.0f, optional float ScaleY = 1.0f, optional float ScaleZ = 1.0f)
{
	local SkeletalMeshSocket NewSocket;

	NewSocket = new class'SkeletalMeshSocket';
    NewSocket.SocketName = SocketName;
    NewSocket.BoneName = BoneName;

    NewSocket.RelativeLocation.X = X;
    NewSocket.RelativeLocation.Y = Y;
    NewSocket.RelativeLocation.Z = Z;

    NewSocket.RelativeRotation.Roll = dRoll * DegToUnrRot;
    NewSocket.RelativeRotation.Pitch = dPitch * DegToUnrRot;
    NewSocket.RelativeRotation.Yaw = dYaw * DegToUnrRot;

	NewSocket.RelativeScale.X = ScaleX;
	NewSocket.RelativeScale.Y = ScaleY;
	NewSocket.RelativeScale.Z = ScaleZ;
    
	return NewSocket;
}




exec function DDGiveUnlockToSelectedUnit(const name DDUnlock)
{
	local UIArmory							Armory;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;
	
	Armory = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));
	if (Armory == none)
	{
		class'Helpers'.static.OutputMsg("No unit selected, go to Armory.");
		return;
	}

	UnitRef = Armory.GetUnitRef();
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (UnitState == none)
	{
		class'Helpers'.static.OutputMsg("No unit selected, go to Armory.");
		return;
	}
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Adding DD Unlock");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

	UnitState.SetUnitFloatValue(class'Help'.static.GetAbilityUnitValue(DDUnlock), 1.0f, eCleanup_Never);

	class'Helpers'.static.OutputMsg("Attempting to add DD unlock:" @ DDUnlock);

	`GAMERULES.SubmitGameState(NewGameState);

	Armory.PopulateData();
}

exec function DDRemoveUnlockFromSelectedUnit(const name DDUnlock)
{
	local UIArmory							Armory;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	local XComGameState						NewGameState;
	
	Armory = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));
	if (Armory == none)
	{
		class'Helpers'.static.OutputMsg("No unit selected, go to Armory.");
		return;
	}

	UnitRef = Armory.GetUnitRef();
	UnitState = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
	if (UnitState == none)
	{
		class'Helpers'.static.OutputMsg("No unit selected, go to Armory.");
		return;
	}
	
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("Removing DD Unlock");
	UnitState = XComGameState_Unit(NewGameState.ModifyStateObject(class'XComGameState_Unit', UnitState.ObjectID));

	UnitState.ClearUnitValue(class'Help'.static.GetAbilityUnitValue(DDUnlock));

	class'Helpers'.static.OutputMsg("Attempting to remove DD unlock:" @ DDUnlock);

	`GAMERULES.SubmitGameState(NewGameState);

	Armory.PopulateData();
}

// If we know for sure DD won't be available on a certain mission, add a sitrep for player information.
// Sitrep has no gameplay effects.
static function PostSitRepCreation(out GeneratedMissionData GeneratedMission, optional XComGameState_BaseObject SourceObject)
{
	local array<name> ExcludedMissions;

	// Prevent affecting TQL / Multiplayer / Main Menu
	If (`HQGAME  == none || `HQPC == None || `HQPRES == none)
		return;

	if (!`XCOMHQ.HasSoldierUnlockTemplate('IRI_DynamicDeployment_GTS_Unlock'))
		return;

	ExcludedMissions = `GetConfigArrayName("IRI_DD_MissionsDisallowDeployment");
	if (ExcludedMissions.Find(GeneratedMission.Mission.MissionName) != INDEX_NONE)
	{
		GeneratedMission.SitReps.AddItem('IRI_DD_NoDeploymentSitRep');
		return;
	}
}



static function bool AbilityTagExpandHandler_CH(string InString, out string OutString, Object ParseObj, Object StrategyParseOb, XComGameState GameState)
{
	switch (InString)
	{

	case "IRI_DD_AerialScout_PerUnitRadius_Tiles":
	case "IRI_DD_TakeAndHold_DurationTurns":
	case "IRI_DD_TakeAndHold_DefenseBonus":
	case "IRI_DD_TakeAndHold_AimBonus":
	case "IRI_DD_HitGroundRunning_MobilityBonus":
		OutString = DDColor(`GetConfigInt(name(InString)));
		return true;

	// ----------------------------------------------------------------------------------------------------------------------
	default:
		break;
	}

	return false;
}

static private function string DDColor(coerce string strInput)
{
	return "<font color='#00ffb4'>" $ strInput $ "</font>"; // mint green
}
