class X2Action_UnstreamMap extends X2Action;

var string MapToUnStream;

simulated state Executing
{
Begin:
	`MAPS.RemoveStreamingMapByName(MapToUnStream, false);
	CompleteAction();
}