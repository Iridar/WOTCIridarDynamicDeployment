class DD_DropShipMatinee_Actor extends Actor;

// Used to replace regular "run off skyranger and jump onto a rope" animations during Dynamic Deployment matinee
// with variants where soldiers just run off and jump paratrooper-like.

// TODO: Make the patching run only while DD is playing.

var private int		LatestPatchedStreamingMaps;
var private string	AnimSequencePrefix;
var private string	PatchAnimsetPath;

// TheActor.SetTickIsDisabled(true);
state Patching
{
	Begin:
		Sleep(0.0f);
}

auto state Waiting
{
	Begin:
		while (true)
		{
			if (LatestPatchedStreamingMaps != `MAPS.NumStreamingMaps() && `MAPS.IsStreamingComplete())
			{
				LatestPatchedStreamingMaps = `MAPS.NumStreamingMaps();
				`log("New number of streaming maps:" @ LatestPatchedStreamingMaps,, 'IRITEST');
				PatchAllLoadedMatinees();
			}
			Sleep(0.1f);
		}
}

static final function DD_DropShipMatinee_Actor FindActor()
{
	local DD_DropShipMatinee_Actor TestActor;

	foreach `XWORLDINFO.AllActors(class'DD_DropShipMatinee_Actor', TestActor)
	{
		return TestActor;
	}
}

static function PatchAllLoadedMatinees()
{
	local array<SequenceObject> FoundMatinees;
	local array<string> PackageNames;
	local SequenceObject MatineeObject;
	local Sequence GameSeq;
 
	GameSeq = class'WorldInfo'.static.GetWorldInfo().GetGameSequence();
	GameSeq.FindSeqObjectsByClass(class'SeqAct_Interp', true, FoundMatinees);

	foreach FoundMatinees(MatineeObject)
	{
		ParseStringIntoArray(PathName(MatineeObject), PackageNames, ".", true);

		if (PackageNames[0] == "CIN_SkyrangerIntros")
		{
			PatchSingleMatinee(SeqAct_Interp(MatineeObject));
		}
	}
}

static function PatchSingleMatinee(SeqAct_Interp SeqInterp)
{
	local InterpData Data;
	local InterpGroup Group;
	local InterpTrack Track;
	local InterpTrackAnimControl AnimControl;
	local int KeyIndex;
	local AnimSet PatchAnimset;

	PatchAnimset = AnimSet(`CONTENT.RequestGameArchetype(default.PatchAnimsetPath));

	Data = InterpData(SeqInterp.VariableLinks[0].LinkedVariables[0]);
	
	foreach Data.InterpGroups(Group)
	{
		Group.GroupAnimSets.AddItem(PatchAnimset);

		foreach Group.InterpTracks(Track)
		{
			AnimControl = InterpTrackAnimControl(Track);
			if (AnimControl != none)
			{
				for (KeyIndex = 0; KeyIndex < AnimControl.AnimSeqs.Length; KeyIndex++)
				{
					if (InStr(AnimControl.AnimSeqs[KeyIndex].AnimSeqName, "FastRope_Start") != INDEX_NONE)
					{
						AnimControl.AnimSeqs[KeyIndex].AnimSeqName = 'DD_FastRope_StartA';
					}
				}
			}
		}
	}
}


//***
// Mostly copied from X2Action_DropshipIntro.AddUnitsToMatinee
static function array<UnitToMatineeGroupMapping> GetUnitMapping()
{
	local array<UnitToMatineeGroupMapping>	UnitMapping;
	local UnitToMatineeGroupMapping			NewMapping;
	local int								UnitIndex;
	local XComGameState_Unit				UnitState;
	local array<XComGameState_Unit>			UnitStates;
	local XComGameState_DynamicDeployment	DDObject;

	DDObject = XComGameState_DynamicDeployment(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_DynamicDeployment'));
	UnitStates = DDObject.GetUnitsToDeploy();

	foreach UnitStates(UnitState, UnitIndex)
	{
		if (class'Help'.static.IsCharTemplateSparkLike(UnitState.GetMyTemplate()))
			continue;

		NewMapping.GroupName = name(UnitState.GetMyTemplate().strIntroMatineeSlotPrefix $ (UnitIndex + 1));
		NewMapping.Unit = UnitState;
		UnitMapping.AddItem(NewMapping);

		`AMLOG("Unit:" @ UnitState.GetFullName() @ "Mapping:" @ NewMapping.GroupName);
	}
	return UnitMapping;
}

defaultproperties
{
	AnimSequencePrefix="DD_"
	PatchAnimsetPath="IRIDynamicDeployment.Anims.AS_JetPacks"
}