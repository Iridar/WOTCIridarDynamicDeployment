class X2Action_UnstreamMap extends X2Action;

// Unstreams the specified map as X2Action
// so that it can be safely done after the matinee action completes
// can't be done from withing the matinee action without breaking things for some reason.

var string MapToUnStream;

simulated state Executing
{
Begin:
	`MAPS.RemoveStreamingMapByName(MapToUnStream, false);
	CompleteAction();
}