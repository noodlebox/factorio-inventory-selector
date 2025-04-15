# Inventory Selector (a mod for Factorio)

When machines have multiple inventories, restrict inserter access to a specific one (or grant access to one typically inaccessible). Avoid common pitfalls of confusing fuel, ingredients, and cargo:

- Platforms waiting on a bumbling swarm of logistic bots to prepare deliveries of blue circuits as inserters sit tragically idle beside a silo?
- Finding train fuel in exciting new places after a quick stop at the wrong depot?
- Biochambers in your goldfish farm burning legendary fish food?

*Never again!*

## What does this mod do?

Inventory Selector adds new configuration settings to inserters (or any machine supporting a drop location), allowing them to restrict their interaction with other entities to a specific inventory type. The choice of inventories available will depend on the type of entity connected, with some of these portable across a variety of targets using a set of *unified inventory types*. Inserters may also be configured to access inventories normally inaccessible to them, allowing such interactions as removing items from input slots, or adding and removing modules from any kind of machine.

## Notable Use Cases

### Loading Rocket Components onto Rockets

Some people would like to use inserters to load rockets. Why? Easy as it is to turn off your brain and use bots to automate away the fun of solving logistic challenges, you may have never even considered loading rocket cargo with inserters. We've all watched in frustration as launches are routinely delayed by single straggling logistic bots, all because it thought better to stop for a quick charge along the way and all the ports near the silo were just *too crowded* for its liking. In contrast, inserters allow rockets to be pre-loaded with commonly requested materials, ready for launch the instant a request for it appears.

Despite the potential advantages of pre-loading rockets, the viability of this approach in the base game is unfortunately limited severely by inserter logic when so many inventories are made available to them. Inserters are smart enough not to continue dumping ingredients for rocket parts into a silo, as this is the most common mode of interaction for inserters here. Unfortunately, this leaves them *completely incapable* of loading rockets with those same ingredients. These are some of the most important materials to automate with space logistics. As Aquilo is unable to assemble rockets from ice and self-sufficient space-based production of these materials is likely a ways off from your initial arrival, it will almost certainly depend on a steady supply of these crucial components from other planets, which can only be loaded by logistic bots in the base game. This mod remedies this shortcoming by allowing inserters direct access to a rocket's cargo slots, avoiding any conflict with the ingredients used by the silo for producing rocket parts (whether modded or otherwise).

### Ambiguous Inputs

A similar conflict exists when a crafting machine consumes fuel of the same type as an ingredient required by a recipe it produces. In these cases, you may find it burning expensive ingredients (quality sadly providing no bonus to fuel energy value) instead of the cheap and abundantly available fuel intended. Worse, once the slot has been filled by the misappropriated ingredients, inserters will continue to merge items into the existing stack inside the machine, essentially locking out the intended fuel until manual intervention in most cases. Although this has been mostly mitigated by support for filters in these fuel slots added in 2.0.44, that solution may not fit every use case, with this mod providing an alternative approach.

### Automated Module Reconfiguration

In the base game, only beacons allow their modules to be handled by inserters. This mod allows inserters to insert and remove modules in *any* machine with module slots. This can be useful in setups that dynamically adjust recipes based on demand, where some of those recipes may not support Quality or Productivity. Modules could also be configured to meet specific resource or power demands as well, maintaining peak efficiency in changing environments.

### Vehicle Interactions

Inserters directed towards either open space or rails will connect to different entities as those entities move into position. In these cases, the inserter will attempt to map the chosen inventory type to an analogous one in the arriving entity (fuel, main, ammo, etc.), allowing implementation of generic fuel and ammo depots without the risk of an unfiltered cargo wagon greedily hoarding 40 stacks of fuel, as well as preventing generic unloading depots from snatching fuel away from locomotives.

## How does it work?

This mod uses the Proxy Container entity type added in Factorio 2.0.38, to implement this custom inserter logic behind the scenes. Invisible proxy containers are created at each interaction locations of an inserter. The inserter is set to target this proxy container, and this proxy container is configured to target a specific inventory on the inserter's original target. When this setting is disabled, the proxy container is simply removed, automatically restoring default inserter behavior. This allows this mod to be safely added or removed from a running game at any time. Blueprints including configured inserters will store that configuration using portable tags, as opposed to including any custom entities.

## Known Issues

A limitation imposed by the current implementation is that, when active, only a single inventory type may be made accessible at a time for each side of an inserter. It is not possible to "forbid" a specific inventory type while allowing all others. The only way to access multiple inventories simultaneously with a single inserter is through its default behavior. Care must be taken to avoid accidentally locking out completely all interaction with less visible output inventories provided by certain machines, where the existence of these specialized outputs is usually hidden by the "smart" default behavior of inserters. Some valid use cases exist, though restriction to specific *input* inventories will generally provide the most reliable benefit above base-game functionality.

This mod currently handles large numbers of disconnected inserters poorly, and performance may suffer in more extreme cases. This is also true for inserters connected to vehicles under manual control, as these also require active polling to track the presence of valid targets. These are usable in smaller numbers, but this contrasts significantly with the performance of inserters connected to static entities or vehicles under automatic control, which permit far more efficient event-driven implementations. Circuit-controlled entities may also negatively impact performance for similar reasons, as the current implementation is relatively naive. Optimizations are likely possible for these (and other cases), once their performance impacts are better understood with further testing. If you notice any unexpected degradation in performance outside of these situations, please report them either as an issue here or on the mod portal.

## Inventory Types

This mod attempts to unify many types of inventories across all kinds of entities into a few common categories:

### Main

These are inventories that are typically unfiltered by default, though some may support configurable filters by slot. They typically provide inert storage for items, freely allowing them to be inserted or removed, in some cases allowing a bar to limit slots available for automated insertion. These include the main inventories of chests as well as vehicle trunks.

### Ingredient

Machines that support recipe-based crafting use this inventory to hold the items consumed by their recipes. Assembler-style entities filter these slots depending on the chosen recipe, while furnace-style entities automatically choose their recipe based on the items present here. In the base game, these entities (with the exception of laboratories) typically support only insertion except in the case of spoiled ingredients that are no longer valid for their slots. Spoiled items may be moved to the "Waste" inventory. Items no longer required after a change in recipe are moved to the "Dump" inventory instead.

### Product

Crafting machines place the items produced by their recipes into these slots. In the base game, inserters typically only remove items from these slots.

### Fuel

Many entity types support burners, consuming items for their energy value to provide power either to themselves or the connected electric network. These inventories include the slots for fuel in burner variants of a wide variety of entities, vehicle fuel slots, nuclear fuel for reactors, and food slots in biochambers.

### Byproduct

Some entities that consume fuel produce direct byproducts of that consumption, such as depleted fuel cells in nuclear reactors. Those are placed in the slots of these inventories.

### Ammo

These are inventories that are used to store ammunition consumed by turrets and vehicle guns when firing, normally filtered to allow only valid ammunition and allowing both insertion and removal of items.

## Special Inventory Types

Some inventories implement specialized behavior and are often not well-suited to interaction via inserters in the base game. This mod makes some styles of interaction with these more viable in a variety of situations:

### Rocket

The rocket inventory is unique to the rocket silo, being the only kind of inventory limited by weight. This is the inventory used to hold the cargo to be launched into space. It is unfiltered, but its usage is also notably hindered in the base game by the ambiguity in handling insertion of items that are valid ingredients for rocket parts. This mod provides a workaround for this limitation by providing direct access to this inventory when necessary.

### Module

This is a special inventory type which is used to hold modules that modify machine behavior across a wide variety of entities. In the base game, these are generally only managed manually, and (with the exception of beacons) do not permit automated interaction by inserters. Using this mod, inserters may be configured to access this inventory, allowing automated management of any machine's modules.

### Logistic Trash

These are secondary inventories often found on entities with a "Main" storage inventory, usually containing items in excess of configured maximums for logistic requests. In rocket silos, these slots are filled by the items removed from the Rocket inventory when a launch preparation is interrupted. These inventories are typically inaccessible to inserters, with items transferred here automatically from other inventories, and removed automatically by logistic bots in the surrounding logistic network (or in the case of space platform hubs, dropped via cargo pod to the planet below).

### Waste

Certain entities support a special output inventory for spoiled items, removed from other inventories automatically when the spoiled result no longer is valid in those slots. These inventories generally expand automatically as needed, and do not handle item insertion well.

### Dump

These slots are used by various crafting machines when items become invalid as a result of a recipe change, rather than as a result of spoilage. These items are placed into a dynamically expanded inventory (which similarly does not support insertion) to be removed so that the machine may continue to operate with the new recipe.

### Robot

This is an inventory type unique to roboports, used to store construction and logistic robots.

### Material

This is the other unique inventory type of roboports, used to store repair packs used by construction robots.

## Mod Compatibility

Other mods may implement their own control logic for these features (or integrate them into their own custom GUIs) using this mod's remote interfaces. The main control API supports getting and setting configuration values for these added features, and a passthrough API provides an alternative to `drop_target` and `pickup_target` on LuaEntity, allowing equivalent read and write interaction without disrupting or being disrupted by this mod's implementation.

Mods implementing custom entities whose inventories may be used differently than their base game counterparts may register a set of remapping rules for those inventories. A trivial example of this is provided for the "limbo" chest in `script/limbo.lua`, mapping all named inventories to the `"main"` inventory, with the `"closed"` usage hint to indicate to GUIs that it should not be considered typically interactable, while still acting as a technically "valid" target for any inventory selection.

Convenience wrappers around these remote interfaces are provided in the `api/` directory, suitable for direct `require` by other mods. This mod's own default GUI (implemented in `gui/gui.lua`) serves as a usage example for all three of these interfaces.
