class X2DLCInfo_WOTCIridarDynamicDeployment extends X2DownloadableContentInfo;

var private config(DynamicDeployment) array<name> CharTemplatesSkipDDAnimSet;


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


static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{
	local XComGameState_DynamicDeployment	DDObject;
	local XComGameState_HeadquartersXCom	XComHQ;
	local XComGameState_Unit				UnitState;
	local int								ItemIndex;
	local int								i;

	`AMLOG("Running");

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment', true));
	if (DDObject == none)
	{
		DDObject = XComGameState_DynamicDeployment(StartGameState.CreateNewStateObject(class'XComGameState_DynamicDeployment'));
	}
	else
	{
		DDObject = XComGameState_DynamicDeployment(StartGameState.ModifyStateObject(DDObject.Class, DDObject.ObjectID));
		DDObject.DeselectAllUnits();
	}

	if (!class'Help'.static.IsDynamicDeploymentAllowed())
		return;
	
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

// If we know for sure DD won't be available on a certain mission, add a sitrep for player information.
// Sitrep has no gameplay effects.
static function PostSitRepCreation(out GeneratedMissionData GeneratedMission, optional XComGameState_BaseObject SourceObject)
{
	local array<name> ExcludedMissions;

	// Prevent affecting TQL / Multiplayer / Main Menu
	If (`HQGAME  == none || `HQPC == None || `HQPRES == none)
		return;

	if (!class'Help'.static.IsDynamicDeploymentUnlocked())
		return;

	ExcludedMissions = `GetConfigArrayName("IRI_DD_MissionsDisallowDeployment");
	if (ExcludedMissions.Find(GeneratedMission.Mission.MissionName) != INDEX_NONE)
	{
		GeneratedMission.SitReps.AddItem('IRI_DD_NoDeploymentSitRep');
		return;
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


static function bool AbilityTagExpandHandler_CH(string InString, out string OutString, Object ParseObj, Object StrategyParseOb, XComGameState GameState)
{
	switch (InString)
	{

	case "IRI_DD_AerialScout_PerUnitRadius_Tiles":
	case "IRI_DD_TakeAndHold_DurationTurns":
	case "IRI_DD_TakeAndHold_DefenseBonus":
	case "IRI_DD_TakeAndHold_AimBonus":
	case "IRI_DD_HitGroundRunning_MobilityBonus":
		OutString = DDColor(`GetConfigInt(InString));
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
