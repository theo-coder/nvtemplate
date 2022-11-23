local Path = require("plenary.path")
local wildcard = require("nvtemplate.deps.wildcard_pattern")

local function print_r(arr, indentLevel)
    local str = ""
    local indentStr = "#"

    if (indentLevel == nil) then
        print(print_r(arr, 0))
        return
    end

    for i = 0, indentLevel do
        indentStr = indentStr .. "\t"
    end

    for index, value in pairs(arr) do
        if type(value) == "table" then
            str = str .. indentStr .. index .. ": \n" .. print_r(value, (indentLevel + 1))
        else
            str = str .. indentStr .. index .. ": " .. value .. "\n"
        end
    end
    return str
end

local M = {}
local opts = {}

local fb_utils = require("telescope._extensions.file_browser.utils")
local action_state = require("telescope.actions.state")
local fb_actions = setmetatable({}, {
    __index = function(_, k)
        error("Key does not exist for 'fb_actions': " .. tostring(k))
    end,
})
local os_sep = Path.path.sep

local get_target_dir = function(finder)
    local entry_path
    if finder.files == false then
        local entry = action_state.get_selected_entry()
        entry_path = entry and entry.value -- absolute path
    end
    return finder.files and finder.path or entry_path
end

local create = function(file, finder)
    if not file then
        return
    end
    if file == "" or (finder.files and file == finder.path .. os_sep) or
        (not finder.files and file == finder.cwd .. os_sep) then
        fb_utils.notify("actions.create",
            { msg = "Please enter a valid file or folder name!", level = "WARN", quiet = finder.quiet })
        return
    end
    file = Path:new(file)
    if file:exists() then
        fb_utils.notify("actions.create", { msg = "Selection already exists!", level = "WARN", quiet = finder.quiet })
        return
    end
    if not fb_utils.is_dir(file.filename) then
        file:touch { parents = true }
    else
        Path:new(file.filename:sub(1, -2)):mkdir { parents = true }
    end
    return file
end

local replaceMatchingPattern = function(patt, path)
    if patt == "${FILENAME}" then return path:match("^.+/(.+)$"):match("^[^.]*")
    else return patt
    end
end

local fillFileWithTemplate = function(path, template)
    local file = io.open(path, "w")

    if file == nil then return 0 end

    if type(template) == "table" then
        for _, line in pairs(template) do
            local patt = "${[^}]+}"
            if string.find(line, patt) then
                line = string.gsub(line, patt, replaceMatchingPattern(string.sub(line, string.find(line, patt)), path))
            end
            file:write(line, "\n")
        end
    else
        file:write(template)
    end

    io.close(file)
end

local onDidCreateFiles = function(path)
    local snippets = opts.snippets
    local templates = opts.templates

    if (snippets == nil) then return 0 end
    if (templates == nil) then return 0 end

    for _, snippet in pairs(snippets) do
        local pattern = wildcard.from_wildcard(snippet["pattern"])
        if string.match(path, pattern) then
            local template = templates[snippet["template"]]
            if (template == nil) then return 0 end

            fillFileWithTemplate(path, template)

            for _,child in pairs(snippet.childs) do
                local template = templates[child["template"]]
                if (template == nil) then return 0 end

                local filename = child["name"]
                local patt = "${[^}]+}"
                if filename:find(patt) then
                    filename = filename:gsub(patt, replaceMatchingPattern(filename:sub(filename:find(patt)), path))
                end

                fillFileWithTemplate(path:sub(path:find(".*(/)")) .. filename, template)
            end
        end
    end
end

fb_actions.create = function(bufnr)
    local current_picker = action_state.get_current_picker(bufnr)
    local finder = current_picker.finder

    local default = get_target_dir(finder) .. os_sep
    vim.ui.input({ prompt = "Insert the file name: ", default = default, completion = "file" }, function(input)
        vim.cmd [[ redraw ]]
        local file = create(input, finder)
        if file then
            local path = file:absolute()
            path = file:is_dir() and path:sub(1, -2) or path

            onDidCreateFiles(input)

            fb_utils.selection_callback(current_picker, path)
            current_picker:refresh(finder, { reset_prompt = true, multi = current_picker._multi })
        end
    end)
end

M.handle = fb_actions.create
M.setup = function(setup_opts)
    opts = setup_opts
end

return M
