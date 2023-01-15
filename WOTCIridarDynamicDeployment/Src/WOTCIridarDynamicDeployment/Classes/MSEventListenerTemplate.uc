class MSEventListenerTemplate extends X2EventListenerTemplate;

// Hack in here to start the actor as early as possible in tactical game
// Unfortunately, have to do it this way, if I spawn the actor in the X2Action, it has no effect.
function RegisterForEvents()
{
	`XCOMGAME.Spawn(class'WOTCIridarDynamicDeployment.DD_DropShipMatinee_Actor');
}