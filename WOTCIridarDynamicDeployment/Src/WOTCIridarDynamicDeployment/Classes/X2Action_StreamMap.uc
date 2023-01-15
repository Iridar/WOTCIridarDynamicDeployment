class X2Action_StreamMap extends X2Action;

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