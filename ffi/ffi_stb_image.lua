local ffi = require 'ffi'

ffi.cdef[[
typedef unsigned char stbi_uc;

// ======= Image Reading =======
stbi_uc *stbi_load(const char *filename, int *x, int *y, int *comp, int req_comp);
stbi_uc *stbi_load_from_memory(const stbi_uc *buffer, int len, int *x, int *y, int *comp, int req_comp);
const char *stbi_failure_reason(void);
void stbi_image_free(void *retval_from_stbi_load);
int stbi_info_from_memory(const stbi_uc *buffer, int len, int *x, int *y, int *comp);
]]
local function ffi_tryload(name)
    -- Let the OS loader search by bare name first
    local ok, lib = pcall(ffi.load, name)
    if ok then
        return lib
    end

    -- Prepare candidate basenames to try in cpath patterns
    local bases = {name}
    if not name:match("^lib") then
        bases[#bases + 1] = "lib" .. name
    else
        bases[#bases + 1] = (name:gsub("^lib", "")) -- also try without the prefix
    end

    -- helper
    local function iter_cpath()
        local i = 0
        local entries = {}
        for p in string.gmatch(package.cpath or "", "[^;]+") do
            i = i + 1
            entries[i] = p
        end
        local n = 0
        return function()
            n = n + 1
            return entries[n]
        end
    end

    -- Walk package.cpath patterns
    for pat in iter_cpath() do
        for _, base in ipairs(bases) do
            local candidate
            if pat:find("%?") then
                candidate = (pat:gsub("%%", "%%%%")):gsub("%?", base) -- escape % for gsub safety
            end
			local ok, lib = pcall(ffi.load, candidate)
			if ok then
				return lib
			end
        end
    end

    error(("ffi_tryload: failed to load '%s' via ffi.load and package.cpath"):format(name))
end
local stbi = {}
local lib = ffi_tryload("libstb_image")
stbi = setmetatable({}, {
    __index = function(t, k)
        return lib['stbi_'..k]
    end,
})

return stbi
