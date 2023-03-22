Created by Iridar

More info here: https://www.patreon.com/Iridar

// Note: cooking maps breaks the SPARK deployment for some reason.

-------

Sitreps:
Airborne Insertion:  Begin the mission with a single Resistance Militia spotter. All XCOM units are deployed via Dynamic Deployment.
Extraction Team: After the objective is completed, XCOM may deploy up to two additional soldiers near the evac zone. (Appears on fixed evac missions)
All In: XCOM can drop reinforcements to replace lost soldiers until they have no units remaining. (Appears on Leviathan and Chosen Avenger Defence)
Resistance Airfield - once per mission, call resistance paratroopers.

---

[WOTC] Dynamic Deployment by Iridar

Adds the Dynamic Deployment unlock to Guerilla Tactics School that allows XCOM to deploy selected squad members after a mission has begun.

By default, soldiers can be selected for Dynamic Deployment (DD) in three locations:[list]
[*] In Squad Select, there will be a checkbox under each soldier. It will control if the soldier should use DD for this mission.
[*] In the Armory screen for individual soldiers, there will be a Dynamic Deployment button with a checkbox. It will control if this soldier should use DD whenever possible. In practice, it means the mod will just try to mark the checkbox on Squad Select whenever this soldier is added to the squad.
[*] When you click Launch Mission in Squad Select, there will be a final Dynamic Deployment screen, which will let you control which units use DD on this mission.[/list]

If you find any of these methods to be inconvenient or intrusive, you can disable them in Mod Config Menu.

Once on the mission, any soldier can use the Dynamic Deployment ability to designate a deployment location, ending the soldier's turn and deploying the rest of the squad. 

You are effectively paying with one soldier's actions to deploy a part of the squad in a potentially advantageous position.

[h1]DEPLOYMENT UPGRADES[/h1]

The mentioned Dynamic Deployment button in the armory will take you to a screen where you can purchase Dynamic Deployment upgrade unlocks for each individual soldier for a modest price in Ability Points.

For example, [b]Precision Drop[/b] upgrade allows picking the exact deployment location inside the deployment area for this soldier.

Other mods can potentially add more upgrades through config.

[h1]CONCEALMENT RULES[/h1]
Using Dynamic Deployment will break squad concelament, unless the soldier using the Deployment has the [b]Digital Uplink[/b] unlock, in which case the concealment will not be broken, unless the units are deployed into enemy field of vision.

Soldiers with Phantom and other similar perks will enter concealment when deployed.

[h1]EVAC INTERACTIONS[/h1]

You cannot call for evac or evacuate soldiers on the same turn you used Dynamic Deployment.

Similarly, you cannot use Dynamic Deployment on the same turn you placed an evac zone or evacuated a soldier.

When using the [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1823265096][WOTC] Request Evac[/url][/b] mod, Dynamic Deployment will be unavailable while you're waiting for Skyranger to arrive for Evac.

[h1]COMPATIBILITY[/h1]

The Dynamic Deployment in the [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1576958692][WOTC] Jet Packs[/url][/b] mod is disabled if you use these two mods together.

The mod includes deployment animations for regular soldiers and SPARK-like units, but not playable aliens or other exotic units.

Other than that, the mod should be compatible with anything and everything, including infiltration mods like [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2683996590]Long War of the Chosen[/url][/b] or [b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2567230730][WOTC] Covert Infiltration[/url][/b].

[h1]REQUIREMENTS[/h1]
[list][*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=1134256495]X2 WOTC Community Highlander[/url][/b] is required.
[*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=2363075446][WOTC] Iridar's Template Master - Core[/url][/b] is required.
[*][b][url=https://steamcommunity.com/sharedfiles/filedetails/?id=667104300][WotC] Mod Config Menu[/url][/b] is supported, but not a hard requirement.[/list]

[h1]CONFIGURATION[/h1]

The mod is highly configurable via Mod Config Menu and various configuration files in:
[code]..\steamapps\workshop\content\268500\2950736651\Config\[/code]

[h1]KNOWN ISSUES[/h1][list]
[*] For the sake of compatibility with Infiltration mods, the mark that a soldier should by deployed Dynamically is tied to the specific mission ID they embark on, which means Dynamic Deployment will not be available on missions that have tactical-to-tactical transfers, such as Chosen Stronghold Assault.
[*] If units are marked for Dynamic Deployment, but are never actually deployed, they will not have their HP from armor during Skyranger walkoff. Cosmetic issue only.
[*] If any enemy pods are activated on the same turn you have used Dynamic Deployment, they will scamper without their cutscene intro.
[*] When calling for DD in a cramped location in a city map, there's a chance the Skyranger will clip through a building.
[*] If your squad is killed or otherwise incapacitated before you use Dynamic Deployment, the mission will end right then and there.[/list]

[h1]CREDITS[/h1]

Music in the video: Martin D'Alesio - Fortunate XCOM
Voice acting in the video: Amphibibro 

Please support me on [b][url=https://patreon.com/Iridar]Patreon[/url][/b] if you require tech support, have a suggestion for a feature, or simply wish to help me create more awesome mods.