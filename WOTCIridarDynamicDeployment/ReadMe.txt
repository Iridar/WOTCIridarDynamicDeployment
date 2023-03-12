X2ModBuildCommon v1.2.1 successfully installed. 
Edit .scripts\build.ps1 if you want to enable cooking. 
 
Enjoy making your mod, and may the odds be ever in your favor. 
 
Created with Enhanced Mod Project Template v1.0 
 
Get news and updates here: 
https://github.com/Iridar/EnhancedModProjectTemplate 


Intro script: a small squad is stuck in trench warfare against superior enemy force, idle suppression shots flying everywhere. 
Officer yells: "Jenkins, go for a flank!"
Jenking goes for a flank, heroically pulls another enemy pod, gets shot and dies. 
The squad is under even more fire.
Officer (with an implied facepalm in his voice) yells into the radio: "We need reinforcements!"

Next very brief shot: soldiers running into Skyranger. Then the camera shows the Skyranger flying by.\
We see the interior of the Skyranger with soldiers sitting inside (standard loadscreen)
Some funny text could replace the mission briefing.
Fortunate Son starts playing. 
Camera shows several shots of the Skyranger flying by, including through a Lost city.

Finally skyranger arrives (I might be able to find a fitting Firebrand audio cue), the officer throws the deploy flare, and reinforcements drop in,
looking all bossy in 'Nam-esque cosmetics.
Fade out, end. Approximate video length: one minute.
Required voicelines:

- Jenkins, go for a flank! (commanding)
- We need reinforcements (frustrated)

 in idle suppression, one of them goes for a flank, pulls a pod, gets shot, 
squad is getting hammered even more. 

Officer yells: we need reinforcements!

Investigate the reality of making a "soldiers running towards skyranger with sirens blasting" cinematic when soldiers are chosen
as well as "show deployed soldiers" matinee (would need MCM toggle probably)

// Cooking maps breaks the SPARK deployment for some reason.

// TODO: Mod description
// TODO: Test everything with redscreens and check logs

Three ways to designate which soldiers remain in Skyranger:

1. Via DD unlock that can be toggled on and off.
2. Via UIScreen that shows up when clicking "start mission"
3. Via checkbox under each unit.

2 and 3 must be togglable in MCM for compatibility.



TODO: Think what to do about teleport deployment if the evacced units are in Skyranger -- Teleport deployment needs to be a separate ability

add one turn minimum delay after selecting soldiers so you don't get instant reinforcements with paratrooper sodleirs'

make a uiscreen for selecting which soldiers will remain in skyranger upon deployment

Fix new UIChooseUnits breaking line text when using extended personnel info.

TODO: What happens if you select reinforcements, then request evac? skyranger is here, it should be able to both evac and drop reinforcements.
Oh right, you shoudl be able to drop reinforcements once skyraner arrives. this needs to be tested.

Make DD Select unavailable if there are no soldiers in Skyranger and there's an evac zone

Check if evac zone is actually removed with Request Evac mod --> it does not.

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


