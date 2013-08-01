--[[

This module just provides some basic support for using an OO notation for
calling functions on objects.

]]--

local Object = {}

function Object._new(self, obj)
        obj = obj or {}
        setmetatable(obj, self)
        self.__index = self
        return obj
end

return Object
