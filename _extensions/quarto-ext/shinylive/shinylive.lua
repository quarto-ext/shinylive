local needsShinylive = false
local codeblockScript = nil
local baseShinyliveHtmlDeps = nil

-- pathPrefix can be something like "shinylive-dist/". It should have a trailing
-- slash.
function getShinyliveBaseDeps(pathPrefix)
  local dep_json = pandoc.pipe("shinylive", { "base-deps" }, "")
  local dep = quarto.json.decode(dep_json)

  dep["name"] = "shinylive-base"

  -- Ensure that /shinylive-sw.js is included at the top level of the project,
  -- so that it will be copied to docs/shinylive-sw.js.
  local projectOffset = param("project-offset")
  -- Hack to get the path; we'll be able to remove this soon.
  shinylive_sw_js_path = pandoc.pipe(
    "shinylive",
    { "codeblock-to-json-path" },
    ""
  )
  shinylive_sw_js_path = shinylive_sw_js_path:gsub(
    "scripts/codeblock%-to%-json.js%s*$",
    "shinylive-sw.js"
  )

  -- TODO: This should be moved out of this function.
  --       This function should return deps. Also, get base-package-deps here.
  quarto.doc.addHtmlDependency({
    name = "shinylive-serviceworker",
    version = "0.0.1",
    -- Add meta tag to tell load-shinylive-sw.js where to find shinylive-sw.js.
    meta = { ["shinylive:serviceworker_dir"] = projectOffset },
    serviceworkers = {{
      source = shinylive_sw_js_path,
      destination = "/shinylive-sw.js"
    }}
  })
  -- dep["meta"] = { ["shinylive:serviceworker_dir"] = projectOffset }

  return dep
end

function ends_with(str, ending)
  return ending == "" or str:sub(-#ending) == ending
end

-- TODO: Should these functions be local?
function fileExists(path)
  local l = io.open(path, "r")
  local result = l ~= nil
  if result then
    l:close()
  end
  return result
end

-- it's hilarious to me that lua doesn't have a "copy file" function in its stdlib
function copyFile(old_path, new_path)
  print(old_path .. "===")
  print("==========================")
  local old_file = io.open(old_path, "rb")
  local new_file = io.open(new_path, "wb")
  if not old_file or not new_file then
    return false
  end
  while true do
    local block = old_file:read(2^13)
    if not block then break end
    new_file:write(block)
  end
  old_file:close()
  new_file:close()
  return true
end


--------------------------------------------------------------------------------
local baseDep = nil

return {
  {
    Pandoc = function (doc)
      codeblockScript = pandoc.pipe("shinylive", { "codeblock-to-json-path" }, "")
      -- Remove trailing whitespace
      codeblockScript = codeblockScript:gsub("%s+$", "")

      baseDep = getShinyliveBaseDeps("shinylive-dist/")

      return doc
    end
  },
  {
    CodeBlock = function(el)
      if el.attr and el.attr.classes:includes("{shinyapp-py}") then
        needsShinylive = true

        -- Convert code block to JSON string in the same format as app.json.
        local app_json = pandoc.pipe(
          "deno",
          { "run", codeblockScript },
          el.text
        )

        -- Find Python package dependencies for that app.
        local app_deps_json = pandoc.pipe(
          "shinylive",
          { "package-deps" },
          app_json
        )

        local app_deps = quarto.json.decode(app_deps_json)

        -- TODO: Each package should be added as a separate HTML dependency
        -- object, instead of adding to baseDep. However, this will require some
        -- changes to Quarto to allow putting them all into the same directory.
        for idx, dep in ipairs(app_deps) do
          baseDep.resources[#baseDep.resources + 1] = {
            -- TODO: Don't hard code these path - provide from python.
            name = "shinylive/pyodide/" .. dep["resources"][1]["name"],
            path = dep["resources"][1]["path"],
          }
        end

        el.attr.classes = pandoc.List()
        el.attr.classes:insert("pyshiny")
        return el
      end
    end
  },
  {
    Pandoc = function (doc)

      if baseDep ~= nil then
        -- quarto.utils.dump(baseDep)
        quarto.doc.addHtmlDependency(baseDep)

        local base_deps_json = pandoc.pipe("shinylive", { "base-package-deps" }, "")
        local base_deps = quarto.json.decode(base_deps_json)
        for idx, dep in ipairs(base_deps) do
          quarto.doc.addHtmlDependency(dep)
        end

      end
      return doc
    end
  }
}
