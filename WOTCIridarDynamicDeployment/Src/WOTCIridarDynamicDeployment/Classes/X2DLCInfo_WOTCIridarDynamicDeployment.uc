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
		NewSockets.AddItem(CreateSocket('IRI_DD_DigitalUplink', 'Inven_R_Hand', 0, 0, 0, 0, 0, 0));
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