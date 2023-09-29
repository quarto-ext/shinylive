local hasDoneShinyliveSetup = false
local hasDoneSetup = { init = false, r = false, python = false }
local versions = { r = nil, python = nil }
local codeblockScript = nil
local appSpecificDeps = {}

-- Try calling `pandoc.pipe('shinylive', ...)` and if it fails, print a message
-- about installing shinylive python package.
function callPythonShinylive(args, input)
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

-- Try calling `pandoc.pipe('Rscript', ...)` and if it fails, print a message
-- about installing shinylive R package.
function callRShinylive(args, input)
  args = { "-e",
    "shinylive:::quarto_ext()",
    table.unpack(args) }
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

function ensureLanguageSetup(language)
  ensureInitSetup(language)

  if hasDoneSetup[language] then
    return
  end
  hasDoneSetup[language] = true

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
        quarto.doc.attach_to_dependency("shinylive", dep)
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
