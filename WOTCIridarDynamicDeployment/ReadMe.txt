X2ModBuildCommon v1.2.1 successfully installed. 
Edit .scripts\build.ps1 if you want to enable cooking. 
 
Enjoy making your mod, and may the odds be ever in your favor. 
 
 
Created with Enhanced Mod Project Template v1.0 
 
Get news and updates here: 
https://github.com/Iridar/EnhancedModProjectTemplate 



MV_RunFwd_StopStandA
ParticleSystem'IRIDynamicDeployment.PFX.PS_Teleport'
IRI_DD_TeleportDeployment

// If teleport is available, we're not tied to Skyranger.
	if (class'Help'.static.ShouldUseTeleportDeployment())
		return ELR_NoInterrupt;

// Cooking maps breaks the SPARK deployment for some reason.

// TODO: Localization
// TODO: Modpreview
// TODO: Mod description
// TODO: comments
// TODO: debug console commands for removing and adding DD unlocks

// Polish MCM
// More Stuff configurable, if there is anything

Allow DD on missions with fixed evac?
XComGameState_EvacZone.bMissionPlaced, toggle in MCM, may or may not work with Request Evac

TODO: Disable DD on Avenger Defense mission and waterworld. 


Sitreps:
Airborne Insertion:  Begin the mission with a single Resistance Militia spotter. All XCOM units are deployed via Dynamic Deployment.
Extraction Team: After the objective is completed, XCOM may deploy up to two additional soldiers near the evac zone. (Appears on fixed evac missions)
All In: XCOM can drop reinforcements to replace lost soldiers until they have no units remaining. (Appears on Leviathan and Chosen Avenger Defence)
Resistance Airfield - once per mission, call resistance paratroopers.



[WOTC] Request Evac
https://steamcommunity.com/sharedfiles/filedetails/?id=1823265096


[WOTC] Dynamic Deployment by Iridar

Allows XCOM to select and deploy soldiers during tactical missions. You start the mission without a full squad, and then deploy the remaining soldiers after the mission starts.

Dynamic Deployment needs to be unlocked in Guerilla Tactics School. To do that, you will require a soldier of Sergeant rank or above, and only soldiers at Sergeant rank or above can call in Dynamic Deployment during the mission.

First, you select which soldiers to deploy. Then, after several turns of delay, you can select the deployment area. Soldiers will then parachute into random locations inside the deployment area.

As a balancing measure, the delay between selecting soldiers and being able to deploy them is equal to the number of soldiers you selected. 

For example, if you select just one soldier, you will be able to deploy them on the next turn. 

Also, you cannot call in Dynamic Deployment on the first turn of the mission or right after calling for Evac.

[h1]DEPLOYMENT UPGRADES[/h1]

The mod allows purchasing upgrades for Dynamic Deployment for individual soldiers on the new screen, which can be accessed in the Armory. These upgrades usually cost Ability Points. 

For example, [b]Precision Drop[/b] upgrade allows picking the exact deployment location inside the deployment area for this soldier.

Other mods can potentially add more upgrades through config.

[h1]CONCEALMENT RULES[/h1]
[list][*] If squad concealment has not been broken by the time Dynamic Deployment is called, then the deployed soldiers will also enter squad concealment, unless you deploy them within enemies' detection radius.
[*] Soldiers with Phantom and other similar perks will enter concealment when deployed.
[*] SPARKs, [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1452700934]MEC Troopers[/url][/b] and other similar units will forcibly break squad concealment when deployed, but you can purchase the "Whisper" Jets individual deployment upgrade for them to prevent that.[/list]

[h1]DYNAMIC REINFORCEMENTS[/h1]

Normally, Dynamic Deployment allows deploying soldiers only until you have a full squad. Unconscious, killed or captured units still count. 

You can toggle this behavior in Mod Config Menu, which will allow replacing lost soldiers with Dynamic Deplyoment.

[h1]COMPATIBILITY[/h1]

The Dynamic Deployment in the [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1576958692][WOTC] Jet Packs[/url][/b] mod is disabled if you use these two mods together.

The mod includes deployment animations for regular soldiers and SPARK-like units, but not playable aliens or other exotic units.

Other than that, the mod should be compatible with anything and everything. 

However, there may be balancing concerns. For example, Dynamic Deployment lets you bypass infiltration time when using mods like [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2683996590]Long War of the Chosen[/url][/b] or [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2567230730][WOTC] Covert Infiltration[/url][/b]. I don't plan to address that.

[h1]REQUIREMENTS[/h1]
[list][*][b]]url=https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495]X2 WOTC Community Highlander[/url][/b] is required.
[*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=667104300][WotC] Mod Config Menu[/url][/b] is supported, but not a hard requirement.

[h1]CONFIGURATION[/h1]

The mod is highly configurable via Mod Config Menu and various configuration files in:
[code]..\steamapps\workshop\content\268500\2849922249\Config\[/code]

[h1]COMPANION MODS[/h1]

The screen for picking soldiers to deploy is compatible with these mods, and I recommend you pick them up, if you haven't already:[list]
[*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2832773856][WOTC] Detailed Soldier Lists Redux[/url][/b]
[*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1458945379][WOTC] Extended Personnel Info[/url][/b][/list]

[h1]CREDITS[/h1]

Please support me on [b][url=https://patreon.com/Iridar]Patreon[/url][/b] if you require tech support, have a suggestion for a feature, or simply wish to help me create more awesome mods.


