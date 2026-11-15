--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

-- Non-blocking UI exports. The import calls them. The invoking resource owns the layer,
-- so a resource can never answer or close another resource's layers.

local Layers = UgLib.Internal.Layers
local Exports = UgLib.Internal.Protocol.Exports

local RESOURCE = GetCurrentResourceName()

---@return string
local function owner()
    return GetInvokingResource() or RESOURCE
end

exports(Exports.Open, function(id, kind, payload, options)
    return Layers.Open(owner(), id, kind, payload, options)
end)

exports(Exports.Update, function(id, payload)
    return Layers.Update(owner(), id, payload)
end)

exports(Exports.Close, function(id, reason)
    return Layers.Close(owner(), id, reason or UgLib.Enums.CloseReason.Closed)
end)
