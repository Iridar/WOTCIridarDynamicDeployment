class X2Action_DynamicDeployment extends X2Action_PlayMatinee;

// A version of Skyranger Drop Action

// Input data
var array<XComGameState_Unit>	UnitStates;

// Internal data

var private XComGameState_Unit	UnitState;
var private DeployLocationActor MatineeBaseActor;
var private vector				TargetLocation;
var private int					DropshipSlotCount;
var private array<string>		PossibleMatinees;
var private string				SelectedMatinee;

function Init()
{
	DropshipSlotCount = class'X2Action_DropshipIntro'.default.DropshipSlotCount;
	TargetLocation = XComGameStateContext_Ability(StateChangeContext).InputContext.TargetLocations[0];
	if (UnitStates.Length > DropshipSlotCount)
	{
		UnitStates.Length = DropshipSlotCount;
	}

	super.Init();
	
	SetMatineeLocation(TargetLocation);
	MatineeBaseActor = WorldInfo.Spawn(class'DeployLocationActor', WorldInfo, '', TargetLocation);
	MatineeBases.AddItem(MatineeBaseActor);
}


private function AddUnitsToMatinee()
{
	local array<name> UsedSlots;
	local array<string> IntroPrefixes;
	local string IntroPrefix;
	local int UnitIndex;

	UnitIndex = 1;
	foreach UnitStates(UnitState)
	{
		UsedSlots.AddItem(name(UnitState.GetMyTemplate().strIntroMatineeSlotPrefix $ UnitIndex));
		AddUnitToMatinee(UsedSlots[UsedSlots.Length - 1], UnitState);
		UnitIndex++;
	}
	
	// now set all unused intro slots to none, so that any preview characters in them aren't playing sounds invisibly
	GetAllIntroSlotPrefixes(IntroPrefixes);
	foreach IntroPrefixes(IntroPrefix)
	{
		for (UnitIndex = 1; UnitIndex <= DropshipSlotCount; UnitIndex++)
		{
			if (UsedSlots.Find(name(IntroPrefix $ UnitIndex)) == INDEX_NONE)
			{
				AddUnitToMatinee(name(IntroPrefix $ UnitIndex), none);
			}
		}
	}
}

// Override original to prevent 'accessed none' spam.
function AddUnitToMatinee(name GroupName, XComGameState_Unit GameStateUnit)
{
	if (GameStateUnit == none)
	{
		BindUnitToMatineeGroup(GroupName, none);
		return;
	}

	super.AddUnitToMatinee(GroupName, GameStateUnit);
}

//We never time out
function bool IsTimedOut()
{
	return false;
}

/*
simulated function SelectMatineeByTag(string TagPrefix)
{
	local array<SequenceObject> FoundMatinees;
	local Sequence GameSeq;
	local SeqAct_Interp FoundMatinee;
	local int Index;

	`AMLOG("Looking for matinee:" @ TagPrefix);

	GameSeq = class'WorldInfo'.static.GetWorldInfo().GetGameSequence();
	GameSeq.FindSeqObjectsByClass(class'SeqAct_Interp', true, FoundMatinees);

	// randomize the list and take the first one that matches.
	FoundMatinees.RandomizeOrder();
	`AMLOG("Found this many matinees:" @ FoundMatinees.Length);

	Matinees.Length = 0;


	for (Index = 0; Index < FoundMatinees.length; Index++)
	{
		FoundMatinee = SeqAct_Interp(FoundMatinees[Index]);
		if(FoundMatinee != none && FoundMatinee.BaseMatineeComment == "" && Instr(FoundMatinee.ObjComment, TagPrefix,, true) == 0)
		{
			`AMLOG("Found matinee:" @ FoundMatinee.ObjComment);
			Matinees.AddItem(FoundMatinee);
			break;
		}
	}

	// add any layered auxiallary matinees from mods
	for (Index = 0; Index < FoundMatinees.length; Index++)
	{
		FoundMatinee = SeqAct_Interp(FoundMatinees[Index]);
		if (FoundMatinee.BaseMatineeComment == TagPrefix)
		{
			`AMLOG("Found layered matinee:" @ FoundMatinee.ObjComment @ FoundMatinee.BaseMatineeComment);
			Matinees.AddItem(FoundMatinee);
		}
	}


	if (Matinees.Length == 0)
	{
		`Redscreen("X2Action_PlayMatinee::SelectMatineeByTag(): Could not find Matinee for tag " $ TagPrefix);
		return;
	}
}*/


private function GetAllIntroSlotPrefixes(out array<string> IntroPrefixes)
{
	local X2DataTemplate DataTemplate;
	local X2CharacterTemplate CharacterTemplate;

	foreach class'X2CharacterTemplateManager'.static.GetCharacterTemplateManager().IterateTemplates(DataTemplate, none)
	{
		CharacterTemplate = X2CharacterTemplate(DataTemplate);
		if(CharacterTemplate != none 
			&& CharacterTemplate.strIntroMatineeSlotPrefix != ""
			&& IntroPrefixes.Find(CharacterTemplate.strIntroMatineeSlotPrefix) == INDEX_NONE)
		{
			IntroPrefixes.AddItem(CharacterTemplate.strIntroMatineeSlotPrefix);
		}
	}
}

simulated state Executing
{
	simulated event BeginState(name PrevStateName)
	{
		super.BeginState(PrevStateName);
		
		`BATTLE.SetFOW(false);
	}

	simulated event EndState(name NextStateName)
	{
		super.EndState(NextStateName);

		`BATTLE.SetFOW(true);
	}


Begin:

	AddUnitsToMatinee();

	PossibleMatinees.AddItem("DDIntro B1");
	PossibleMatinees.AddItem("DDIntro B2");
	PossibleMatinees.AddItem("DDIntro B3");
	PossibleMatinees.AddItem("DDIntro B4");
	PossibleMatinees.AddItem("DDIntro B5");
	SelectedMatinee = PossibleMatinees[Rand(PossibleMatinees.Length)];
	
	SelectMatineeByTag(SelectedMatinee);
	PlayMatinee();

	do
	{
		Sleep(0.0f);
	}
	until (Matinees.Length == 0 || MatineeSkipped); // the matinee list will be cleared when they are finished

	EndMatinee();


	CompleteAction();
}

function CompleteAction()
{	
	super.CompleteAction();

	MatineeBaseActor.Destroy();

	// Shaky Cam happens if you unstream maps here lol
	//`MAPS.RemoveStreamingMapByName("CIN_SkyrangerIntros", false);
	//if (bAtLeastOneUnitIsSparkLike)
	//{
	//	`MAPS.RemoveStreamingMapByName("CIN_SkyrangerIntros_Spark", false);
	//}
}

DefaultProperties
{
	bRebaseNonUnitVariables=false
}