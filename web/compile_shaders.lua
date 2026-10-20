local root = assert(arg[1], "repository root is required")
local output = assert(arg[2], "shader output directory is required")

package.path = root .. "/?.lua;" .. root .. "/?/init.lua;" .. package.path
package.cpath = root .. "/bin/linux64/?.so;" .. package.cpath

require("shader_manager").compile_web_shaders(root, output)
