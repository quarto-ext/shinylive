local hasDoneShinyliveSetup = false
local codeblockScript = nil


-- Do one-time setup when a Shinylive codeblock is encountered.
function ensureShinyliveSetup()
  if hasDoneShinyliveSetup then
    return
  end
  hasDoneShinyliveSetup = true

  -- Find the path to codeblock-to-json.ts and save it for later use.
  codeblockScript = pandoc.pipe("shinylive", { "codeblock-to-json-path" }, "")
  -- Remove trailing whitespace
  codeblockScript = codeblockScript:gsub("%s+$", "")

  local baseDeps = getShinyliveBaseDeps()
  for idx, dep in ipairs(baseDeps) do
    quarto.doc.addHtmlDependency(dep)
  end

  quarto.doc.addHtmlDependency(
    {
      name = "shinylive-quarto-css",
      stylesheets = {"resources/css/shinylive-quarto.css"}
    }
  )
end


function getShinyliveBaseDeps()
  -- Relative path from the current page to the root of the site. This is needed
  -- to find out where shinylive-sw.js is, relative to the current page.
  local projectOffset = param("project-offset")
  local depJson = pandoc.pipe(
    "shinylive",
    { "base-deps", "--sw-dir", projectOffset },
    ""
  )
  print(depJson)
  local deps = quarto.json.decode(depJson)
  return deps
end


return {
  {
    CodeBlock = function(el)
      if el.attr and el.attr.classes:includes("{shinylive-python}") then
        ensureShinyliveSetup()

        -- Convert code block to JSON string in the same format as app.json.
        local parsedCodeblockJson = pandoc.pipe(
          "deno",
          { "run", codeblockScript },
          el.text
        )

        -- This contains "files" and "quartoArgs" keys.
        local parsedCodeblock = quarto.json.decode(parsedCodeblockJson)

        -- Find Python package dependencies for the current app.
        local appDepsJson = pandoc.pipe(
          "shinylive",
          { "package-deps" },
          quarto.json.encode(parsedCodeblock["files"])
        )

        local appDeps = quarto.json.decode(appDepsJson)

        for idx, dep in ipairs(appDeps) do
          quarto.doc.attachToDependency("shinylive", dep)
        end

        el.attr.classes = pandoc.List()
        el.attr.classes:insert("shinylive-python")
        return el
      end
    end
  }
}
