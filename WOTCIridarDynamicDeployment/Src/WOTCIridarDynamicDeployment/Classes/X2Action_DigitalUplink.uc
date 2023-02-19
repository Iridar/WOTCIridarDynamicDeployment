class X2Action_DigitalUplink extends X2Action_Hack;

simulated function SetupScreenMaterial()
{
	local MaterialInstanceConstant ScreenMaterial;

	// set the movie to render to the hack screen
	ScreenMaterial = MaterialInstanceConstant(GremlinLCD.GetMaterial(0));

	if( ScreenMaterial != None )
	{
		ScreenMaterial.SetTextureParameterValue('Diffuse', HackMovie.RenderTexture);
	}
}

defaultproperties
{
	DelayAfterHackCompletes=0
	bSkipUIInput = true

	//SourceBeginAnim = "HL_HackStartA"
	//SourceLoopAnim = "HL_HackLoopA"
	//SourceEndAnim = "HL_HackStopA"
}