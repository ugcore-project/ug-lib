--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---Values of the local player kept by `UgLib.Cache`.
---@enum UgCacheKey
UgLib.Enums.CacheKey = {
    Ped = 'ped',
    PlayerId = 'playerId',
    ServerId = 'serverId',
    Coords = 'coords',
    Heading = 'heading',
    Vehicle = 'vehicle',
    Seat = 'seat',
    Weapon = 'weapon',
}

---Asset kinds of `UgLib.Streaming`.
---@enum UgAsset
UgLib.Enums.Asset = {
    Model = 'model',
    AnimDict = 'animDict',
    AnimSet = 'animSet',
    PtfxAsset = 'ptfxAsset',
    TextureDict = 'textureDict',
    ScaleformMovie = 'scaleformMovie',
}
