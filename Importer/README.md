# Classic Terrain Importer
Scripts for porting classic terrain into modern Roblox places. 

> [!WARNING]
> These scripts require a Roblox place file containing terrain that was **not** converted to smooth terrain. You must have a place file containing classic terrain open inside of an older version of Roblox Studio (preferably a 2014 build). Additionally, the imported terrain from these scripts do not support changes while the game is running (i.e. adding/removing voxels).

## How to
1. Obtain an old version of Roblox Studio (preferably a 2014 build).
2. Open the place file containing classic terrain in old studio.
3. Run the `ExportTerrain.lua` script by following the instructions inside of it.
4. Open another place file in modern Roblox Studio that you want to import the terrain into.
5. Run the `ImportTerrain.lua` script by following the instructions inside of it.

## Texture Sources
If necessary, all of the textures used by the importer are available in the [`Textures/Split`](./Textures/Split/) folder. Additionally, the original diffuse texture used by studio is available in the [`Textures`](./Textures) folder (converted to a PNG), although this is not used by the importer.
