class X2DLCInfo_Debug extends X2DownloadableContentInfo;

var config int DeployTypeOverride;

exec function DDOverrideDeploymentType(const int iOverride)
{
	class'X2DLCInfo_Debug'.default.DeployTypeOverride = iOverride;
}

// TODO: Delete this file.