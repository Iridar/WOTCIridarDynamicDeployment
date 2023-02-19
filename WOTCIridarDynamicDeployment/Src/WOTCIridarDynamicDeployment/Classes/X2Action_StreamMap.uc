class X2Action_StreamMap extends X2Action;

// The goal of this X2Action is to let the game load the specified map "in the background"
// without freezing the game
// does it accomplish this goal? nobody knows lol

var string	MapToStream;
var vector	MapLocation;
var rotator	MapRotation;

simulated state Executing
{
Begin:
	`MAPS.AddStreamingMap(MapToStream, MapLocation, MapRotation, false).bForceNoDupe = true;

	//`AMLOG("Begin loading map" @ MapToStream);

	while (!`MAPS.IsStreamingComplete())
	{
		//`AMLOG("Loading map...");
		sleep(0.0f);
	}

	//`AMLOG("Finished loading");

	CompleteAction();
}