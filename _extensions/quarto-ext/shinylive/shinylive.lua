local needsShinylive = false
local codeblockScript = nil
local baseShinyliveHtmlDeps = nil

function getShinyliveBaseDeps()
  local projectOffset = param("project-offset")

  local dep_json = pandoc.pipe("shinylive", { "base-deps", "--sw-dir", projectOffset}, "")
  local deps = quarto.json.decode(dep_json)

  return deps
end

--------------------------------------------------------------------------------

return {
  {
    Pandoc = function (doc)
      codeblockScript = pandoc.pipe("shinylive", { "codeblock-to-json-path" }, "")
      -- Remove trailing whitespace
      codeblockScript = codeblockScript:gsub("%s+$", "")

      local baseDeps = getShinyliveBaseDeps()

      quarto.utils.dump(baseDeps)
      for idx, dep in ipairs(baseDeps) do
        quarto.doc.addHtmlDependency(dep)
      end

      return doc
    end
  },
  {
    CodeBlock = function(el)
      if el.attr and el.attr.classes:includes("{shinyapp-py}") then
        needsShinylive = true

        -- Convert code block to JSON string in the same format as app.json.
        local appJson = pandoc.pipe(
          "deno",
          { "run", codeblockScript },
          el.text
        )

        -- Find Python package dependencies for the current app.
        local appDepsJson = pandoc.pipe(
          "shinylive",
          { "package-deps" },
          appJson
        )

        local appDeps = quarto.json.decode(appDepsJson)

        for idx, dep in ipairs(appDeps) do
          quarto.doc.attachToDependency("shinylive", dep)
        end

        el.attr.classes = pandoc.List()
        el.attr.classes:insert("pyshiny")
        return el
      end
    end
  }
}
