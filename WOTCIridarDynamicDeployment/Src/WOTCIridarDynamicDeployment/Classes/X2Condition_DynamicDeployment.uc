class X2Condition_DynamicDeployment extends X2Condition

function bool CanEverBeValid(XComGameState_Unit SourceUnit, bool bStrategyCheck)
{
	local GeneratedMissionData MissionData;
	local GeneratedMissionData EmptyData;
	local XComGameState_HeadquartersXCom XComHQ;
	local array<name> ExcludedMissions;
	local array<name> TeleportMissions;

	XComHQ = `XCOMHQ;

	MissionData = XComHQ.GetGeneratedMissionData(XComHQ.MissionRef.ObjectID);
	if (MissionData != EmptyData)
	{
		// Can't use DD on certain missions at all.
		ExcludedMissions = `GetConfigArrayName("IRI_DD_MissionsDisallowDeployment", true);
		if (ExcludedMissions.Find(MissionData.Mission.MissionName) != INDEX_NONE)
		{
			return false;
		}
		
		// On some missions, can use only teleport DD
		TeleportMissions = `GetConfigArrayName("IRI_DD_MissionsAllowTeleportOnly", true);
		if (TeleportMissions.Find(MissionData.Mission.MissionName) != INDEX_NONE && class'Help'.static.GetDeploymentType() != `eDT_TeleportBeacon)
		{
			return false;
		}
	}
	return SourceUnit.GetSoldierRank() >= `GetConfigInt("IRI_DD_MinRank");
}
