class X2Action_DeployGremlin extends X2Action;

// Plays the first part of Gremlin/Bit Evac animation backwards to simulate them flying from above.

var vector MoveLocation;

var private CustomAnimParams AnimParams;
var private AnimNodeSequence PlayingSequence;

//------------------------------------------------------------------------------------------------

event bool BlocksAbilityActivation()
{
	return false;
}

//------------------------------------------------------------------------------------------------
simulated state Executing
{
Begin:
	UnitPawn.EnableRMA(true, true);
	UnitPawn.EnableRMAInteractPhysics(true);

	AnimParams.AnimName = 'HL_EvacStart';
	AnimParams.PlayRate = -1.0f;	// play in reverse
	AnimParams.BlendTime = 0;		// Prevent greamlin rubberbanding at the start of the animation

	// This will ensure the cosmetic unit ends up where we want.
	// Not sure what kind of automagic makes this work even though only the first part of animation is played
	// but it just werks, no janky gremlin movement, so good enuff fur mich.
	AnimParams.DesiredEndingAtoms.Add(1);
	AnimParams.DesiredEndingAtoms[0].Scale = 1.0f;
	AnimParams.DesiredEndingAtoms[0].Translation = MoveLocation;

	PlayingSequence = UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(AnimParams);

	// Play for 1.75 seconds, then stop.
	Sleep(1.75f);
	PlayingSequence.StopAnim();

	CompleteAction();
}
