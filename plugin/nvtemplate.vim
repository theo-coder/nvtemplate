if exists("g:loaded_nvtemplate")
    finish
endif

let g:loaded_nvtemplate = 1

let s:lua_deps_loc = expand("<sfile>:h:r") . "/../lua/nvtemplate/deps"
exe "lua package.path = package.path .. ';" . s:lua_deps_loc . "/lua-?/init.lua'"