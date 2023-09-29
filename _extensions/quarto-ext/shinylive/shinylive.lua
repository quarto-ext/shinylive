-- # Shinylive package methods
-- Always use `callShinyLive()` to call the shinylive extension.
-- `callPythonShinyLive()` and `callRShinyLive()` should not be used directly. Instead, always use `callShinyLive()`.

-- # py-shinylive and r-shinylive methods
-- info               - Package, version, asset version, and script paths information
-- base-htmldeps      - Quarto html dependencies for the base shinylive integration
-- language-resources - R's resource files for the quarto html dependency named `shinylive`
-- app-resources      - App-specific resource files for the quarto html dependency named `shinylive`

-- ### CLI Interface
-- * `extension info`
--   * Prints information about the extension including:
--     * `version`: The version of the R package
--     * `assets_version`: The version of the web assets
--     * `scripts`: A list of paths scripts that are used by the extension,
--      mainly `codeblock-to-json`
--   * Example
--     ```
--     {
--       "version": "0.1.0",
--       "assets_version": "0.2.0",
--       "scripts": {
--         "codeblock-to-json": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/scripts/codeblock-to-json.js"
--       }
--     }
--     ```
-- * `extension base-htmldeps`
--   * Prints the language agnostic quarto html dependencies as a JSON array.
--     * The first html dependency is the `shinylive` service workers.
--     * The second html dependency is the `shinylive` base dependencies. This
--       dependency will contain the core `shinylive` asset scripts (JS files
--       automatically sourced), stylesheets (CSS files that are automatically
--       included), and resources (additional files that the JS and CSS files can
--       source).
--   * Example
--     ```
--     [
--       {
--         "name": "shinylive-serviceworker",
--         "version": "0.2.0",
--         "meta": { "shinylive:serviceworker_dir": "." },
--         "serviceworkers": [
--           {
--             "source": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive-sw.js",
--             "destination": "/shinylive-sw.js"
--           }
--         ]
--       },
--       {
--         "name": "shinylive",
--         "version": "0.2.0",
--         "scripts": [{
--           "name": "shinylive/load-shinylive-sw.js",
--           "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/load-shinylive-sw.js",
--             "attribs": { "type": "module" }
--         }],
--         "stylesheets": [{
--           "name": "shinylive/shinylive.css",
--           "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/shinylive.css"
--         }],
--         "resources": [
--           {
--             "name": "shinylive/shinylive.js",
--             "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/shinylive.js"
--           },
--           ... # [ truncated ]
--         ]
--       }
--     ]
--     ```
-- * `extension language-resources`
--   * Prints the language-specific resource files as JSON that should be added to the quarto html dependency.
--     * For r-shinylive, this includes the webr resource files
--     * For py-shinylive, this includes the pyodide and pyright resource files.
--   * Example
--     ```
--     [
--       {
--         "name": "shinylive/webr/esbuild.d.ts",
--         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/webr/esbuild.d.ts"
--       },
--       {
--         "name": "shinylive/webr/libRblas.so",
--         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/webr/libRblas.so"
--       },
--       ... # [ truncated ]
--     ]
-- * `extension app-resources`
--   * Prints app-specific resource files as JSON that should be added to the `"shinylive"` quarto html dependency.
--   * Currently, r-shinylive does not return any resource files.
--   * Example
--     ```
--     [
--       {
--         "name": "shinylive/pyodide/anyio-3.7.0-py3-none-any.whl",
--         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/pyodide/anyio-3.7.0-py3-none-any.whl"
--       },
--       {
--         "name": "shinylive/pyodide/appdirs-1.4.4-py2.py3-none-any.whl",
--         "path": "/<ASSETS_CACHE_DIR>/shinylive-0.2.0/shinylive/pyodide/appdirs-1.4.4-py2.py3-none-any.whl"
--       },
--       ... # [ truncated ]
--     ]
--     ```




local hasDoneSetup = { init = false, r = false, python = false }
local versions = { r = nil, python = nil }
local codeblockScript = nil
local appSpecificDeps = {}

-- Python specific method to call py-shinylive
-- @param args: list of string arguments to pass to py-shinylive
-- @param input: string to pipe into to py-shinylive
function callPythonShinylive(args, input)
  -- Try calling `pandoc.pipe('shinylive', ...)` and if it fails, print a message
  -- about installing shinylive python package.
  local res
  local status, err = pcall(
    function()
      res = pandoc.pipe("shinylive", args, input)
    end
  )

  if not status then
    print(err)
    error("Error running 'shinylive' command. Perhaps you need to install the 'shinylive' Python package?")
  end

  return res
end

-- R specific method to call {r-shinylive}
-- @param args: list of string arguments to pass to r-shinylive
-- @param input: string to pipe into to r-shinylive
function callRShinylive(args, input)
  args = { "-e",
    "shinylive:::quarto_ext()",
    table.unpack(args) }

  -- Try calling `pandoc.pipe('Rscript', ...)` and if it fails, print a message
  -- about installing shinylive R package.
  local res
  local status, err = pcall(
    function()
      res = pandoc.pipe("Rscript", args, input)
    end
  )

  if not status then
    print(err)
    error(
      "Error running 'Rscript' command. Perhaps you need to install the 'shinylive' R package?")
  end

  return res
end

-- Returns decoded object
-- @param language: "python" or "r"
-- @param args, input: see `callPythonShinylive` and `callRShinylive`
function callShinylive(language, args, input)
  if input == nil then
    input = ""
  end
  local res
  -- print("Calling " .. language .. " shinylive with args: " .. table.concat(args, " "))
  if language == "python" then
    res = callPythonShinylive(args, input)
  elseif language == "r" then
    res = callRShinylive(args, input)
  else
    error("Unknown language: " .. language)
  end

  -- Remove any unwanted output before the first curly brace or square bracket.
  -- print("res: " .. string.sub(res, 1, math.min(string.len(res), 100)) .. "...")
  local curly_start = string.find(res, "{", 0, true)
  local brace_start = string.find(res, "[", 0, true)
  local min_start
  if curly_start == nil then
    min_start = brace_start
  elseif brace_start == nil then
    min_start = curly_start
  else
    min_start = math.min(curly_start, brace_start)
  end
  if min_start == nil then
    local res_str = res
    if string.len(res) > 100 then
      res_str = string.sub(res, 1, 100) .. "... [truncated]"
    end
    error("Could not find start curly brace or start brace in " .. language .. " shinylive response:\n" .. res_str)
  end
  if min_start > 1 then
    res = string.sub(res, min_start)
  end

  -- Decode JSON object
  local result
  local status, err = pcall(
    function()
      result = quarto.json.decode(res)
    end
  )
  if not status then
    print("JSON string being parsed:")
    print(res)
    print("Error:")
    print(err)
    if language == "python" then
      error("Error decoding JSON response from shinylive.")
    elseif language == "r" then
      error(
        "Error decoding JSON response from shinylive." ..
        "\nIf the `shinylive` R package has been installed," ..
        " please check that no additional output was printed to the console."
      )
    end
  end
  return result
end

-- Do one-time setup for language agnostic html dependencies.
-- This should only be called once per document
-- @param language: "python" or "r"
function ensureInitSetup(language)
  if hasDoneSetup.init then
    return
  end
  hasDoneSetup.init = true

  -- Find the path to codeblock-to-json.ts and save it for later use.
  local infoObj = callShinylive(language, { "extension", "info" })
  -- Store the path to codeblock-to-json.ts for later use
  codeblockScript = infoObj.scripts['codeblock-to-json']
  -- Store the version info for later use
  versions[language] = { version = infoObj.version, assets_version = infoObj.assets_version }

  -- Add language-agnostic dependencies
  local baseDeps = getShinyliveBaseDeps(language)
  for idx, dep in ipairs(baseDeps) do
    quarto.doc.add_html_dependency(dep)
  end

  -- Add ext css dependency
  quarto.doc.add_html_dependency(
    {
      name = "shinylive-quarto-css",
      stylesheets = { "resources/css/shinylive-quarto.css" }
    }
  )
end

-- Do one-time setup for language specific html dependencies.
-- This should only be called once per document
-- @param language: "python" or "r"
function ensureLanguageSetup(language)
  ensureInitSetup(language)

  if hasDoneSetup[language] then
    return
  end
  hasDoneSetup[language] = true

  -- Only get the asset version value if it hasn't been retrieved yet.
  if versions[language] == nil then
    local infoObj = callShinylive(language, { "extension", "info" })
    versions[language] = { version = infoObj.version, assets_version = infoObj.assets_version }
  end
  -- Verify that the r-shinylive and py-shinylive versions match
  if
      (versions.r and versions.python) and
      ---@diagnostic disable-next-line: undefined-field
      versions.r.assets_version ~= versions.python.assets_version
  then
    error(
      "The shinylive R and Python packages must support the same Shinylive Assets version to be used in the same quarto document." ..
      "\nR" ..
      ---@diagnostic disable-next-line: undefined-field
      "\n\tShinylive package version: " .. versions.r.version ..
      ---@diagnostic disable-next-line: undefined-field
      "\n\tSupported ssets version: " .. versions.r.assets_version ..
      "\nPython" ..
      ---@diagnostic disable-next-line: undefined-field
      "\n\tShinylive package version: " .. versions.python.version ..
      ---@diagnostic disable-next-line: undefined-field
      "\n\tSupported ssets version: " .. versions.python.assets_version
    )
  end

  -- Add language-specific dependencies
  local langResources = callShinylive(language, { "extension", "language-resources" })
  for idx, resourceDep in ipairs(langResources) do
    -- No need to check for uniqueness.
    -- Each resource is only be added once and should already be unique.
    quarto.doc.attach_to_dependency("shinylive", resourceDep)
  end
end

function getShinyliveBaseDeps(language)
  -- Relative path from the current page to the root of the site. This is needed
  -- to find out where shinylive-sw.js is, relative to the current page.
  if quarto.project.offset == nil then
    error("The shinylive extension must be used in a Quarto project directory (with a _quarto.yml file).")
  end
  local deps = callShinylive(
    language,
    { "extension", "base-htmldeps", "--sw-dir", quarto.project.offset },
    ""
  )
  return deps
end

return {
  {
    CodeBlock = function(el)
      if not el.attr then
        -- Not a shinylive codeblock, return
        return
      end

      local language
      if el.attr.classes:includes("{shinylive-r}") then
        language = "r"
      elseif el.attr.classes:includes("{shinylive-python}") then
        language = "python"
      else
        -- Not a shinylive codeblock, return
        return
      end
      -- Setup language and language-agnostic dependencies
      ensureLanguageSetup(language)

      -- Convert code block to JSON string in the same format as app.json.
      local parsedCodeblockJson = pandoc.pipe(
        "quarto",
        { "run", codeblockScript },
        el.text
      )
      -- This contains "files" and "quartoArgs" keys.
      local parsedCodeblock = quarto.json.decode(parsedCodeblockJson)

      -- Find Python package dependencies for the current app.
      local appDeps = callShinylive(
        language,
        { "extension", "app-resources" },
        -- Send as piped input to the shinylive command
        quarto.json.encode(parsedCodeblock["files"])
      )

      -- Add app specific dependencies
      for idx, dep in ipairs(appDeps) do
        if not appSpecificDeps[dep.name] then
          appSpecificDeps[dep.name] = true
          quarto.doc.attach_to_dependency("shinylive", dep)
        end
      end

      if el.attr.classes:includes("{shinylive-python}") then
        el.attributes.engine = "python"
        el.attr.classes = pandoc.List()
        el.attr.classes:insert("shinylive-python")
      elseif el.attr.classes:includes("{shinylive-r}") then
        el.attributes.engine = "r"
        el.attr.classes = pandoc.List()
        el.attr.classes:insert("shinylive-r")
      end
      return el
    end
  }
}
