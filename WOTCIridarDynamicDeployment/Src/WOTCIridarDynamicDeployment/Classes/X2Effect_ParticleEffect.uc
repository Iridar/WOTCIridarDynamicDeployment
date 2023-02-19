class X2Effect_ParticleEffect extends X2Effect;

// Used by Uplink Deployment to play a particle effect at the center of the deployment area.

simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationActionMetadata ActionMetadata, const name EffectApplyResult)
{
	local X2Action_PlayEffect PlayEffectAction;
	local XComGameStateContext_Ability AbilityContext;

	if (EffectApplyResult == 'AA_Success')
	{
		AbilityContext = XComGameStateContext_Ability(VisualizeGameState.GetContext());

		PlayEffectAction = X2Action_PlayEffect( class'X2Action_PlayEffect'.static.AddToVisualizationTree(ActionMetadata, AbilityContext, false, ActionMetadata.LastActionAdded));
		PlayEffectAction.EffectName = "FX_Battle_Scanner.P_Battle_Scanner_Burst";
		PlayEffectAction.EffectLocation = AbilityContext.InputContext.TargetLocations[0];
	}
	super.AddX2ActionsForVisualization(VisualizeGameState, ActionMetadata, EffectApplyResult);
}
