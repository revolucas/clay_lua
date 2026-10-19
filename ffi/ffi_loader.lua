local ffi = require("ffi")

local M = {}

function M.tryload(name)
    local tried = {}
    local ok, library = pcall(ffi.load, name)
    if ok then
        return library
    end
    tried[#tried + 1] = tostring(library)

    local bases = { name }
    if name:match("^lib") then
        bases[#bases + 1] = name:gsub("^lib", "")
    else
        bases[#bases + 1] = "lib" .. name
    end

    for pattern in (package.cpath or ""):gmatch("[^;]+") do
        if pattern:find("%?") then
            for _, base in ipairs(bases) do
                local candidate = pattern:gsub("%?", function() return base end)
                local loaded, handle = pcall(ffi.load, candidate)
                if loaded then
                    return handle
                end
                tried[#tried + 1] = candidate .. ": " .. tostring(handle)
            end
        end
    end

    error(("failed to load native library '%s':\n%s")
        :format(name, table.concat(tried, "\n")), 2)
end

return M
