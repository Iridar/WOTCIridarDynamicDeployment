class X2UnifiedProjectile_DynamicDeployment extends X2UnifiedProjectile;

// Custom version of the projectile archetype. Two new things:
// 1. Make grenade path trajectory start from the specific socket on the soldier's body.
// Otherwise it defaulted to something else, could be gun_fire on primary weapon, or could be unit's center mass, not sure.
// 2. Use different projectile elements depending on the deployment type.

/*
This file has to be in a separate script package, because otherwise the chain gets broken somewhere along the path of 
Perk Content Archetype -> Weapon Archetype -> Projectile Archetype
and then the script package gets thrown out by the engine during the game load under particular circumstances (when running a mod with an XComContent.ini with the following header:
[XComGame . XComContentManager]

This is a completely bizarre bug that makes no sense and took ages to track down, much thanks to the patience of Knight of the NSFW and Xymanek (Astral Descend).
*/

//A projectile instance's time has come - create the particle effect and start updating it in Tick
function FireProjectileInstance(int Index)
{		
	//Hit location and hit location modifying vectors
	local Vector SourceLocation;
	local Vector HitLocation;
	local Vector HitNormal;
	local Vector AimLocation;
	local Vector TravelDirection;
	local Vector TravelDirection2D;
	local float DistanceTravelled;	
	local Vector ParticleParameterDistance;
	local Vector ParticleParameterTravelledDistance;
	local Vector ParticleParameterTrailDistance;
	local EmitterInstanceParameterSet EmitterParameterSet; //The parameter set to use for the projectile
	local float SpreadScale;
	local Vector SpreadValues;
	local XGUnit TargetVisualizer;
	local XComGameState_Ability AbilityState;
	local X2AbilityTemplate AbilityTemplate;
	local bool bAllowSpread;
	local array<ProjectileTouchEvent> OutTouchEvents;
	local float HorizontalSpread, VerticalSpread, SpreadLerp;
	local XKeyframe LastGrenadeFrame, LastGrenadeFrame2;
	local Vector GrenadeImpactDirection;
	local TraceHitInfo GrenadeTraceInfo;
	local XComGameState_Unit ShooterState;

	local SkeletalMeshActorSpawnable CreateSkeletalMeshActor;
	local XComAnimNodeBlendDynamic tmpNode;
	local CustomAnimParams AnimParams;
	local AnimSequence FoundAnimSeq;
	local AnimNodeSequence PlayingSequence;

	local float TravelDistance;
	local bool bDebugImpactEvents;
	local bool bCollideWithUnits;

	// Variables for Issue #10
	local XComLWTuple Tuple;

	//local ParticleSystem AxisSystem;
	//local ParticleSystemComponent PSComponent;

	ShooterState = XComGameState_Unit( `XCOMHISTORY.GetGameStateForObjectID( SourceAbility.InputContext.SourceObject.ObjectID ) );
	AbilityState = XComGameState_Ability( `XCOMHISTORY.GetGameStateForObjectID( AbilityContextAbilityRefID ) );
	AbilityTemplate = AbilityState.GetMyTemplate( );
	
	SetupAim( Index, AbilityState, AbilityTemplate, SourceLocation, AimLocation);


	if (SourceAbility.IsResultContextMiss()) 
	{
		`LOG("Firing missed projectile at:" @ StoredInputContext.TargetLocations[0],, 'WOTCMoreSparkWeapons');
		AimLocation = StoredInputContext.TargetLocations[0];
	}

	bProjectileFired = true;

	//Calculate the travel direction for this projectile
	TravelDirection = AimLocation - SourceLocation;
	TravelDistance = VSize(TravelDirection);
	TravelDirection2D = TravelDirection;
	TravelDirection2D.Z = 0.0f;
	TravelDirection2D = Normal(TravelDirection2D);
	TravelDirection = Normal(TravelDirection);
	
	//If spread values are set, apply them in this block
	bAllowSpread = !Projectiles[Index].ProjectileElement.bTriggerHitReact;

	if(bAllowSpread && Projectiles[Index].ProjectileElement.ApplySpread)
	{
		//If the hit was a critical hit, tighten the spread significantly
		switch (AbilityContextHitResult)
		{
			case eHit_Crit: SpreadScale = Projectiles[Index].ProjectileElement.CriticalHitScale;
				break;
			case eHit_Miss: SpreadScale = Projectiles[Index].ProjectileElement.MissShotScale;
				break;
			default:
				if (AbilityTemplate.bIsASuppressionEffect)
				{
					SpreadScale = Projectiles[Index].ProjectileElement.SuppressionShotScale;
				}
				else
				{
					SpreadScale = 1.0f;
				}
		}

		if (TravelDistance >= Projectiles[Index].ProjectileElement.LongRangeDistance)
		{
			HorizontalSpread = Projectiles[Index].ProjectileElement.LongRangeSpread.HorizontalSpread;
			VerticalSpread = Projectiles[Index].ProjectileElement.LongRangeSpread.VerticalSpread;
		}
		else
		{
			SpreadLerp = TravelDistance / Projectiles[Index].ProjectileElement.LongRangeDistance;

			HorizontalSpread = SpreadLerp * Projectiles[ Index ].ProjectileElement.LongRangeSpread.HorizontalSpread + 
				(1.0f - SpreadLerp) * Projectiles[ Index ].ProjectileElement.ShortRangeSpread.HorizontalSpread;
			VerticalSpread = SpreadLerp * Projectiles[ Index ].ProjectileElement.LongRangeSpread.VerticalSpread + 
				(1.0f - SpreadLerp) * Projectiles[ Index ].ProjectileElement.ShortRangeSpread.VerticalSpread;
		}

		HorizontalSpread *= SpreadScale;
		VerticalSpread *= SpreadScale;

		// convert from full angle spread to half angle spread for the rand computation
		HorizontalSpread /= 2.0f;
		VerticalSpread /= 2.0f;

		// convert from angle measurements to radians
		HorizontalSpread *= DegToRad;
		VerticalSpread *= DegToRad;

		//Apply the spread values - lookup into the precomputed random spread table
		SpreadValues = RandomSpreadValues[ Projectiles[ Index ].VolleyIndex ].SpreadValues[ Projectiles[ Index ].MultipleProjectileIndex ];

		// Randomize the travel direction based on the spread table and scalars
		TravelDirection = VRandCone3( TravelDirection, HorizontalSpread, VerticalSpread, SpreadValues.X, SpreadValues.Y );
	
		//Recalculate aim based on the spread
		AimLocation = SourceLocation + TravelDirection * TravelDistance;
		TravelDirection2D = TravelDirection;
		TravelDirection2D.Z = 0.0f;
		TravelDirection2D = Normal( TravelDirection2D );
	}

	//Build the HitLocation
	bDebugImpactEvents = false;

	if( OrdnanceType != '' )
	{
		//when firing a single projectile, we can just fall back on the targeting path for now, since it would otherwise require re-calculating the trajectory
		Projectiles[Index].GrenadePath = `PRECOMPUTEDPATH;

		Projectiles[Index].GrenadePath.bNoSpinUntilBounce = true;

		//We don't start at the beginning of the path, especially for underhand throws
		Projectiles[Index].AliveTime = FindPathStartTime(Index, SourceLocation);

		HitNormal = -TravelDirection;
		HitLocation = AimLocation;
	}
	else if ((Projectiles[ Index ].ProjectileElement.ReturnsToSource && (AbilityContextHitResult == eHit_Miss)) ||
			 (Projectiles[ Index ].ProjectileElement.bAttachToTarget && (AbilityContextHitResult != eHit_Miss)))
	{
		// if the projectile comes back, only trace out to the aim location and no further		
		`XWORLD.GenerateProjectileTouchList(ShooterState, SourceLocation, AimLocation, OutTouchEvents, bDebugImpactEvents);

		HitLocation = OutTouchEvents[ OutTouchEvents.Length - 1 ].HitLocation;
		HitNormal = OutTouchEvents[OutTouchEvents.Length - 1].HitNormal;
		Projectiles[ Index ].ImpactInfo = OutTouchEvents[ OutTouchEvents.Length - 1 ].TraceInfo;
	}
	else
	{	
		//We want to allow some of the projectiles to go past the target if they don't hit it, so we set up a trace here that will not collide with the target. That way
		//the event list we generate will include impacts behind the target, but only for traveling type projectiles.
		//ranged types should hit the target so that InitialTargetDistance is the distance to the thing being hit.

		bCollideWithUnits = (Projectiles[Index].ProjectileElement.UseProjectileType != eProjectileType_Traveling);

		ProjectileTrace(HitLocation, HitNormal, SourceLocation, TravelDirection, bCollideWithUnits);
		HitLocation = HitLocation + (TravelDirection * 0.0001f); // move us KINDA_SMALL_NUMBER along the direction to be sure and get all the events we want
		`XWORLD.GenerateProjectileTouchList(ShooterState, SourceLocation, HitLocation, OutTouchEvents, bDebugImpactEvents);
		Projectiles[Index].ImpactInfo = OutTouchEvents[OutTouchEvents.Length - 1].TraceInfo;
	}
	
	//Derive the end time from the travel distance and speed if we are not of the grenade type.
	Projectiles[Index].AdjustedTravelSpeed = Projectiles[Index].ProjectileElement.TravelSpeed;      //  initialize to base travel speed
	DistanceTravelled = VSize(HitLocation - SourceLocation);

	//	=======================================================================================================================
	Projectiles[Index].ImpactEvents = StoredInputContext.ProjectileEvents;
	
	
	//Mark this projectile as having been fired
	Projectiles[Index].bFired = true;
	Projectiles[Index].bConstantComplete = false;
	Projectiles[Index].LastImpactTime = 0.0f;

	//Set up the initial source & target location
	Projectiles[Index].InitialSourceLocation = SourceLocation;
	Projectiles[Index].InitialTargetLocation = HitLocation;		
	Projectiles[Index].InitialTargetNormal = HitNormal;
	Projectiles[Index].InitialTravelDirection = TravelDirection;	
	Projectiles[Index].InitialTargetDistance = VSize(AimLocation - Projectiles[Index].InitialSourceLocation);

	TargetVisualizer = XGUnit( `XCOMHISTORY.GetVisualizer( AbilityContextPrimaryTargetID ) );
	if (TargetVisualizer != none)
	{
		Projectiles[Index].VisualizerToTargetOffset = Projectiles[Index].InitialTargetLocation - TargetVisualizer.Location;
	}

	//Create an actor that travels through space using the settings given by the projectile element definition
	if( Projectiles[Index].ProjectileElement.AttachSkeletalMesh == none )
	{
		Projectiles[Index].SourceAttachActor = Spawn(class'DynamicPointInSpace', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));	
		Projectiles[Index].TargetAttachActor = Spawn(class'DynamicPointInSpace', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));

		CreateProjectileCollision(Projectiles[Index].TargetAttachActor);
	}
	else
	{
		Projectiles[Index].SourceAttachActor = Spawn(class'DynamicPointInSpace', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));


		CreateSkeletalMeshActor = Spawn(class'SkeletalMeshActorSpawnable', self, , Projectiles[Index].InitialSourceLocation, rotator(Projectiles[Index].InitialTravelDirection));
		Projectiles[Index].TargetAttachActor = CreateSkeletalMeshActor;
		CreateSkeletalMeshActor.SkeletalMeshComponent.SetSkeletalMesh(Projectiles[Index].ProjectileElement.AttachSkeletalMesh);
		if (Projectiles[Index].ProjectileElement.CopyWeaponAppearance && SourceWeapon.m_kGameWeapon != none)
		{
			SourceWeapon.m_kGameWeapon.DecorateWeaponMesh(CreateSkeletalMeshActor.SkeletalMeshComponent);
		}
		CreateSkeletalMeshActor.SkeletalMeshComponent.SetAnimTreeTemplate(Projectiles[Index].ProjectileElement.AttachAnimTree);
		CreateSkeletalMeshActor.SkeletalMeshComponent.AnimSets.AddItem(Projectiles[Index].ProjectileElement.AttachAnimSet);
		CreateSkeletalMeshActor.SkeletalMeshComponent.UpdateAnimations();

		CreateProjectileCollision(Projectiles[Index].TargetAttachActor);

		// literally, the only thing that sets this variable is AbilityGrenade - Josh
		if (AbilityState.GetMyTemplate().bHideWeaponDuringFire)
			SourceWeapon.Mesh.SetHidden(true);

		if (CreateSkeletalMeshActor.SkeletalMeshComponent.Animations != none)
		{
			tmpNode = XComAnimNodeBlendDynamic(CreateSkeletalMeshActor.SkeletalMeshComponent.Animations.FindAnimNode('BlendDynamic'));
			if (tmpNode != none)
			{
				AnimParams.AnimName = 'NO_Idle';
				AnimParams.Looping = true;
				tmpNode.PlayDynamicAnim(AnimParams);
			}
		}
	}

	// handy debugging helper, just uncomment this and the declarations at the top
	//	AxisSystem = ParticleSystem( DynamicLoadObject( "FX_Dev_Steve_Utilities.P_Axis_Display", class'ParticleSystem' ) );
	//	PSComponent = new(Projectiles[Index].TargetAttachActor) class'ParticleSystemComponent';
	//	PSComponent.SetTemplate(AxisSystem);
	//	PSComponent.SetAbsolute( false, false, false );
	//	PSComponent.SetTickGroup( TG_EffectsUpdateWork );
	//	PSComponent.SetActive( true );
	//	Projectiles[Index].TargetAttachActor.AttachComponent( PSComponent );

	if( Projectiles[Index].GrenadePath != none )
	{
		//Projectiles[Index].GrenadePath.bUseOverrideSourceLocation = true;
		//Projectiles[Index].GrenadePath.OverrideSourceLocation = Projectiles[Index].InitialSourceLocation;
		//
		//Projectiles[Index].GrenadePath.bUseOverrideTargetLocation = true;
		//Projectiles[Index].GrenadePath.OverrideTargetLocation = StoredInputContext.TargetLocations[0];
		AdjustGrenadePath(Projectiles[Index].GrenadePath, ShooterState);

		//	=======================================================================================================================================
		
		Projectiles[Index].GrenadePath.bUseOverrideTargetLocation = false;
		Projectiles[Index].GrenadePath.bUseOverrideSourceLocation = false;
		Projectiles[Index].EndTime = Projectiles[Index].StartTime + Projectiles[Index].GrenadePath.GetEndTime();
		
		if (Projectiles[ Index ].GrenadePath.iNumKeyframes > 1)
		{
			// get the rough direction of travel at the end of the path.  TravelDirection is from the source to the target
			LastGrenadeFrame = Projectiles[ Index ].GrenadePath.ExtractInterpolatedKeyframe( Projectiles[ Index ].GrenadePath.GetEndTime( ) );
			LastGrenadeFrame2 = Projectiles[ Index ].GrenadePath.ExtractInterpolatedKeyframe( Projectiles[ Index ].GrenadePath.GetEndTime( ) - 0.05f );
			if (VSize( LastGrenadeFrame.vLoc - LastGrenadeFrame2.vLoc ) == 0)
			{
				`redscreen("Grenade path with EndTime and EndTime-.05 with the same point. ~RussellA");
			}

			GrenadeImpactDirection = Normal( LastGrenadeFrame.vLoc - LastGrenadeFrame2.vLoc );

			// don't use the projectile trace, because we don't want the usual minimal arming distance and other features of that trace.
			// really just trying to get the actual surface normal at the point of impact.  HitLocation and AimLocation should basically be the same.
			Trace( HitLocation, HitNormal, AimLocation + GrenadeImpactDirection * 5, AimLocation - GrenadeImpactDirection * 5, true, vect( 0, 0, 0 ), GrenadeTraceInfo );
			Projectiles[Index].ImpactInfo = GrenadeTraceInfo;
		}
		else
		{
			// Not enough keyframes to figure out a direction of travel... a straight up vector as a normal should be a reasonable fallback...
			HitNormal.X = 0.0f;
			HitNormal.Y = 0.0f;
			HitNormal.Z = 1.0f;
		}

		Projectiles[ Index ].InitialTargetNormal = HitNormal;
	}


	Projectiles[ Index ].SourceAttachActor.SetPhysics( PHYS_Projectile );
	Projectiles[ Index ].TargetAttachActor.SetPhysics( PHYS_Projectile );

	switch( Projectiles[Index].ProjectileElement.UseProjectileType )
	{
	case eProjectileType_Traveling:
		if( Projectiles[Index].GrenadePath == none ) //If there is a grenade path, we move along that
		{
			Projectiles[Index].TargetAttachActor.Velocity = Projectiles[Index].InitialTravelDirection * Projectiles[Index].AdjustedTravelSpeed;
		}
		break;
	case eProjectileType_Ranged:
	case eProjectileType_RangedConstant:
		Projectiles[Index].SourceAttachActor.Velocity = vect(0, 0, 0);
		Projectiles[Index].TargetAttachActor.Velocity = Projectiles[Index].InitialTravelDirection * Projectiles[Index].AdjustedTravelSpeed;
		break;
	}

	if( Projectiles[Index].ProjectileElement.UseParticleSystem != none )
	{
		EmitterParameterSet = Projectiles[Index].ProjectileElement.DefaultParticleSystemInstanceParameterSet;
		if( bWasHit && Projectiles[Index].ProjectileElement.bPlayOnHit && Projectiles[Index].ProjectileElement.PlayOnHitOverrideInstanceParameterSet != none )
		{
			EmitterParameterSet = Projectiles[Index].ProjectileElement.PlayOnHitOverrideInstanceParameterSet;
		}
		else if( !bWasHit && Projectiles[Index].ProjectileElement.bPlayOnMiss && Projectiles[Index].ProjectileElement.PlayOnMissOverrideInstanceParameterSet != none )
		{
			EmitterParameterSet = Projectiles[Index].ProjectileElement.PlayOnMissOverrideInstanceParameterSet;
		}

		//Spawn the effect
		switch(Projectiles[Index].ProjectileElement.UseProjectileType)
		{
		case eProjectileType_Traveling:
			//For this style of projectile, the effect is attached to the moving point in space
			if( EmitterParameterSet != none )
			{
				Projectiles[Index].ParticleEffectComponent = WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].TargetAttachActor,,,,
					EmitterParameterSet.InstanceParameters);
			}
			else
			{
				Projectiles[Index].ParticleEffectComponent = 
					WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].TargetAttachActor);
			}
			break;
		case eProjectileType_Ranged:
		case eProjectileType_RangedConstant:
			//For this style of projectile, the point in space is motionless
			if( EmitterParameterSet != none )
			{
				Projectiles[Index].ParticleEffectComponent = WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].SourceAttachActor,,,,
					EmitterParameterSet.InstanceParameters);
			}
			else
			{
				Projectiles[Index].ParticleEffectComponent = WorldInfo.MyEmitterPool.SpawnEmitter(Projectiles[Index].ProjectileElement.UseParticleSystem, 
					Projectiles[Index].InitialSourceLocation, 
					rotator(TravelDirection),
					Projectiles[Index].SourceAttachActor);
			}
			break;
		}

		Projectiles[Index].ParticleEffectComponent.SetScale( Projectiles[Index].ProjectileElement.ParticleScale );
		Projectiles[Index].ParticleEffectComponent.OnSystemFinished = OnParticleSystemFinished;

		DistanceTravelled = Min( DistanceTravelled, Projectiles[ Index ].ProjectileElement.MaxTravelDistanceParam );
		//Tells the particle system how far the projectile must travel to reach its target
		ParticleParameterDistance.X = DistanceTravelled;
		ParticleParameterDistance.Y = DistanceTravelled;
		ParticleParameterDistance.Z = DistanceTravelled;
		Projectiles[Index].ParticleEffectComponent.SetVectorParameter('Target_Distance', ParticleParameterDistance);
		Projectiles[Index].ParticleEffectComponent.SetFloatParameter('Target_Distance', DistanceTravelled);

		ParticleParameterDistance.X = DistanceTravelled;
		ParticleParameterDistance.Y = DistanceTravelled;
		ParticleParameterDistance.Z = DistanceTravelled;
		Projectiles[ Index ].ParticleEffectComponent.SetVectorParameter( 'Initial_Target_Distance', ParticleParameterDistance );
		Projectiles[ Index ].ParticleEffectComponent.SetFloatParameter( 'Initial_Target_Distance', DistanceTravelled );

		//Tells the particle system how far we have moved
		ParticleParameterTravelledDistance.X = 0.0f;
		ParticleParameterTravelledDistance.Y = 0.0f;
		ParticleParameterTravelledDistance.Z = 0.0f;
		Projectiles[Index].ParticleEffectComponent.SetVectorParameter('Traveled_Distance', ParticleParameterTravelledDistance);
		Projectiles[Index].ParticleEffectComponent.SetFloatParameter('Traveled_Distance', 0.0f);

		if( Projectiles[Index].ProjectileElement.MaximumTrailLength > 0.0f )
		{
			ParticleParameterTrailDistance.X = 0.0f;
			ParticleParameterTrailDistance.Y = 0.0f;
			ParticleParameterTrailDistance.Z = 0.0f;
			Projectiles[Index].ParticleEffectComponent.SetVectorParameter('Trail_Distance', ParticleParameterTrailDistance);
			Projectiles[Index].ParticleEffectComponent.SetFloatParameter('Trail_Distance', 0.0f);
		}
	}

	`log("********************* PROJECTILE Element #"@self.Name@Index@"FIRED *********************************", , 'DevDestruction');
	`log("StartTime:"@Projectiles[Index].StartTime, , 'DevDestruction');
	`log("EndTime:"@Projectiles[Index].EndTime, , 'DevDestruction');
	`log("InitialSourceLocation:"@Projectiles[Index].InitialSourceLocation, , 'DevDestruction');
	`log("InitialTargetLocation:"@Projectiles[Index].InitialTargetLocation, , 'DevDestruction');
	`log("InitialTravelDirection:"@Projectiles[Index].InitialTravelDirection, , 'DevDestruction');
	`log("Projectile actor location is "@Projectiles[Index].SourceAttachActor.Location, , 'DevDestruction');
	`log("Projectile actor velocity is set to:"@Projectiles[Index].TargetAttachActor.Velocity, , 'DevDestruction');
	`log("******************************************************************************************", , 'DevDestruction');

	if( Projectiles[Index].ProjectileElement.bPlayWeaponAnim )
	{
		AnimParams.AnimName = 'FF_FireA';
		AnimParams.Looping = false;
		AnimParams.Additive = true;

		FoundAnimSeq = SkeletalMeshComponent(SourceWeapon.Mesh).FindAnimSequence(AnimParams.AnimName);
		if( FoundAnimSeq != None )
		{
			//Tell our weapon to play its fire animation
			if( SourceWeapon.AdditiveDynamicNode != None )
			{
				PlayingSequence = SourceWeapon.AdditiveDynamicNode.PlayDynamicAnim(AnimParams);
				PlayingSequences.AddItem(PlayingSequence);
				SetTimer(PlayingSequence.AnimSeq.SequenceLength, false, nameof(BlendOutAdditives), self);
			}
			
		}
	}

	if( Projectiles[Index].ProjectileElement.FireSound != none )
	{
		//Play a fire sound if specified
		// Start Issue #10 Trigger an event that allows to override the default projectile sound
		Tuple = new class'XComLWTuple';
		Tuple.Id = 'ProjectilSoundOverride';
		Tuple.Data.Add(3);

		// The SoundCue to play instead of the AKEvent, used as reference
		Tuple.Data[0].kind = XComLWTVObject;
		Tuple.Data[0].o = none;

		// Projectile Element ObjectArchetype Pathname Parameter
		Tuple.Data[1].kind = XComLWTVString;
		Tuple.Data[1].s = PathName(Projectiles[Index].ProjectileElement.ObjectArchetype);

		// Ability Context Ref Parameter
		Tuple.Data[2].kind = XComLWTVInt;
		Tuple.Data[2].i = AbilityContextAbilityRefID;

		`XEVENTMGR.TriggerEvent('OnProjectileFireSound', Tuple, Projectiles[Index].ProjectileElement, none);
		if (Tuple.Data[0].o != none)
		{
			Projectiles[Index].SourceAttachActor.PlaySound(SoundCue(Tuple.Data[0].o));
		}
		else
		{
			Projectiles[Index].SourceAttachActor.PlayAkEvent(Projectiles[Index].ProjectileElement.FireSound);
		}
		// End Issue #10
	}
}

private function AdjustGrenadePath(XComPrecomputedPath GrenadePath, XComGameState_Unit SourceUnit)
{
	local XComUnitPawn	UnitPawn;
	local XGunit		UnitVis;
	local vector		SocketLocation;
	local vector		vDif;
	local int			iKeyframes;
	local int			i;
	local float			Alpha;
	local float			PathLength;

	iKeyframes = GrenadePath.iNumKeyframes;

	UnitVis = XGunit(SourceUnit.GetVisualizer());

	UnitPawn = UnitVis.GetPawn();

	UnitPawn.Mesh.GetSocketWorldLocationAndRotation('IRI_DD_DeployFlare', SocketLocation);

	//	Calculate the vector difference between given vector location (shooter's hand) and the current start of the grenade path
	vDif = SocketLocation - GrenadePath.akKeyframes[0].vLoc;

	//	Not sure if flipping these bools is necessary

	//GrenadePath.bUseOverrideSourceLocation = true;
	//GrenadePath.OverrideSourceLocation = GrenadePath.akKeyframes[0].vLoc;
	//
	//GrenadePath.bUseOverrideTargetLocation = true;
	//GrenadePath.OverrideTargetLocation = NewTargetLocation;

	

	//	Cycle through current points of the path.
	for (i = 1; i < iKeyframes; i++)
	{	
		//	This is used to "blend in" the current path point with the desired trajectory.
		//	Basically, the closer we are to the end of the path, the higher is the Alpha value, scaling from 0.0 at the start of the path, to 1.0 at the end of it.
		Alpha = 1 - float(i) / float(iKeyframes);	
		GrenadePath.akKeyframes[i].vLoc += vDif * Alpha;

		//	At the same time, adjust the points used to draw the path spline.
		//	Adjusting the path points themselves might not even be necessary, unless perhaps they're used for targeting validation.
		//	Adjusting the actual trajectory taken by the projectile is done in the X2UnifiedProjectile subclass.
		GrenadePath.kSplineInfo.Points[i].OutVal = GrenadePath.akKeyframes[i].vLoc;
	}	

	//	Once we're done adjusting the spline points, force redraw it.
	PathLength = GrenadePath.akKeyframes[GrenadePath.iNumKeyframes - 1].fTime - GrenadePath.akKeyframes[0].fTime;
	GrenadePath.kRenderablePath.UpdatePathRenderData(GrenadePath.kSplineInfo, PathLength, none, `CAMERASTACK.GetCameraLocationAndOrientation().Location);
}


//Iterate the projectile elements and create the instanced events that will create projectiles
function SetupVolley()
{
	local int VolleyIndex;
	local int ProjectileElementIndex;
	local int MultipleProjectileIndex;
	local int SuppressionRand;
	local X2UnifiedProjectileElement CurrentProjectileElement;
	local ProjectileElementInstance EmptyInstance;
	local int AddProjectileIndex;
	local float StartFireTime;
	local float NextFireTime;	
	local Vector SetSpreadValues;
	local bool PlayFromHit, PlayFromMiss, PlayFromSuppress, IsRightVolley;
	local XComGameState_Ability Ability;
	local X2AbilityTemplate AbilityTemplate;

	StartFireTime = WorldInfo.TimeSeconds;
	NextFireTime = StartFireTime;

	Ability = XComGameState_Ability( `XCOMHISTORY.GetGameStateForObjectID( AbilityContextAbilityRefID ) );
	AbilityTemplate = Ability.GetMyTemplate( );

	if (AbilityTemplate.bIsASuppressionEffect)
	{
		SuppressionRand = `SYNC_RAND( StoredResultContext.ProjectileHitLocations.Length );
		AbilityContextTargetLocation = StoredResultContext.ProjectileHitLocations[SuppressionRand];
	}
	
	for( VolleyIndex = 0; VolleyIndex < VolleyNotify.NumShots; ++VolleyIndex )
	{	
		RandomSpreadValues.Add(1);

		//Iterate the projectile elements, instantiating the individual events of the volley
		for( ProjectileElementIndex = 0; ProjectileElementIndex < ProjectileElements.Length; ++ProjectileElementIndex )
		{
			// ADDED
			// Skip certain projectile elements depending on whether we want to use the smoke flare
			if (class'Help'.static.GetDeploymentType() != ProjectileElementIndex)
			{
				continue;
			}
			// END

			CurrentProjectileElement = ProjectileElements[ProjectileElementIndex];

			// Custom volley notifications should only fire custom projectiles and vis-versa
			if (VolleyNotify.bCustom != CurrentProjectileElement.bIsCustomDefinition)
			{
				continue;
			}
			else if (VolleyNotify.bCustom == true)
			{
				// Custom volley notifications should only fire the projectiles with the same ID
				if (VolleyNotify.CustomID != CurrentProjectileElement.CustomID)
				{
					continue;
				}
			}

			if(!bCosmetic) //Non cosmetic projectiles need to look up what kind of hit they were
			{
				PlayFromHit = (CurrentProjectileElement.bPlayOnHit && bWasHit && !AbilityTemplate.bIsASuppressionEffect);
				PlayFromSuppress = (CurrentProjectileElement.bPlayOnSuppress && bWasHit && AbilityTemplate.bIsASuppressionEffect);
				PlayFromMiss = (CurrentProjectileElement.bPlayOnMiss && !bWasHit);				
			}
			else
			{
				PlayFromHit = true;
				IsRightVolley = true;				
			}

			IsRightVolley = (CurrentProjectileElement.UseOncePerVolleySetting == eOncePerVolleySetting_None || VolleyIndex == 0); //Once per volley elements are only processed for index 0			

			//Only start projectile elements that match the result of this hit, or have the appropriate once per volley settings
			if( (PlayFromHit || PlayFromMiss || PlayFromSuppress) && IsRightVolley) 
			{
				//Projectile elements can specify multiple projectiles, as might be the case with a shotgun blast style of volley
				for( MultipleProjectileIndex = 0; MultipleProjectileIndex < CurrentProjectileElement.ProjectileCount; ++MultipleProjectileIndex )
				{
					//Create a new projectile element instance
					AddProjectileIndex = Projectiles.Length;
					Projectiles.AddItem(EmptyInstance);

					//Configure the instance's fire time
					Projectiles[AddProjectileIndex].ProjectileElement = CurrentProjectileElement;
					Projectiles[AddProjectileIndex].StartTime = NextFireTime;				
					switch(CurrentProjectileElement.UseOncePerVolleySetting)
					{
					case eOncePerVolleySetting_None:	
						//This is the default case, and requires no adjustment
						break;
					case eOncePerVolleySetting_Start:
						Projectiles[AddProjectileIndex].StartTime += CurrentProjectileElement.OncePerVolleyDelay;					
						break;
					case eOncePerVolleySetting_End:
						Projectiles[AddProjectileIndex].StartTime += (VolleyNotify.NumShots * VolleyNotify.ShotInterval) + CurrentProjectileElement.OncePerVolleyDelay;					
						break;
					}

					//We want to make sure that the multiple projectile elements use the same random offsets so that
					//for instance tracers don't end up going in a different direction than the smoke trail.
					Projectiles[AddProjectileIndex].MultipleProjectileIndex = MultipleProjectileIndex;
					Projectiles[AddProjectileIndex].VolleyIndex = VolleyIndex;
					if( RandomSpreadValues[VolleyIndex].SpreadValues.Length <= MultipleProjectileIndex )
					{
						SetSpreadValues.X = `SYNC_FRAND();
						SetSpreadValues.Y = `SYNC_FRAND();
						SetSpreadValues.Z = `SYNC_FRAND(); //Added Z spread value for aoe shots
						RandomSpreadValues[VolleyIndex].SpreadValues.AddItem(SetSpreadValues);
					}
				}
			}
		}

		NextFireTime += VolleyNotify.ShotInterval;
	}
	bSetupVolley = true;
	bFirstShotInVolley = true;
	//if (Projectiles.Length > 0)
	//{
	//	DebugRender( );
	//}
}