--[[

    ug-lib - https://github.com/ugcore-project
    Copyright (C) 2026 UgCore Framework & Contributors
    Licensed under the GNU General Public License. See LICENSE for details.

]] --

---@meta

---@alias UgLibConfigType 'string'|'number'|'integer'|'boolean'|'table'

---Where a resolved value came from, lowest to highest precedence.
---@alias UgLibConfigSource 'default'|'file'|'convar'

---@class UgLibConfigOption
---@field key string camelCase
---@field type UgLibConfigType
---@field default any MUST pass its own validation
---@field description string
---@field values? any[] allowed values
---@field aliases? table<any, any> accepted values replaced before checks, such as `[true] = 'on'` (also used for convars)
---@field min? number minimum number, string length or table entry count
---@field max? number maximum number, string length or table entry count
---@field validate? fun(value: any): boolean, string?

---Owner files merge per key. Every value replicates to clients.
---@class UgLibConfigDefinition
---@field options UgLibConfigOption[]

---@class UgLibConfigEntry
---@field name string
---@field definition UgLibConfigDefinition
---@field values table<string, any>? resolved values, nil until loaded
---@field sources table<string, UgLibConfigSource>? per key, nil until loaded
---@field file 'generated'|'loaded'|'failed'? state of the owner file, nil until loaded
