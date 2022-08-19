local needsShinylive = false
local codeblockScript = nil
local baseShinyliveHtmlDeps = nil

-- pathPrefix can be something like "shinylive-dist/". It should have a trailing
-- slash.
function getShinyliveBaseDeps(pathPrefix)
  local p = io.popen("python3 -c 'import importlib; sl = importlib.import_module(\"_extensions.quarto-ext.shinylive.shinylive-dist.scripts.shinylive\"); sl._shinylive_base_deps()'", "r")

  local dep_json = p:read("*a")
  p:close()
  local dep = quarto.json.decode(dep_json)

  dep["name"] = "shinylive-base"

  -- Ensure that /serviceworker.js is included at the top level of the project,
  -- so that it will be copied to docs/serviceworker.js.
  local projectOffset = param("project-offset")
  if not fileExists(projectOffset .. "/serviceworker.js") then
    copyFile(
      quarto.utils.resolvePath("shinylive-dist/serviceworker.js"),
      projectOffset .. "/serviceworker.js"
    )
  end
  -- Add meta tag to tell load-serviceworker.js where to find serviceworker.js.
  quarto.doc.addHtmlDependency({
    name = "shinylive-serviceworker",
    version = "0.0.1",
    meta = { ["shinylive:serviceworker_dir"] = projectOffset }
  })

  -- for idx, filename in ipairs(filenames)
  -- do
  --   if ends_with(filename, "load-serviceworker.js") then
  --     dep.scripts[#dep.scripts + 1] = {
  --       name = filename,
  --       path = pathPrefix .. filename,
  --       attribs = {
  --         type = "module"
  --       }
  --     }
  --   else
  --     dep.resources[#dep.resources + 1] = {
  --       -- `name` is something like "shinylive/shinylive.js". This is where the
  --       -- file will end up inside of docs/site_libs/quarto-contrib/shinylive/
  --       name = filename,
  --       -- `path` is the source path to the file, relative to
  --       -- _extensions/quarto-ext/shinylive/
  --       path = pathPrefix .. filename
  --     }
  --   end

  --   -- if ends_with(filename, ".css") then
  --   --   dep.stylesheets[#dep.stylesheets + 1] = filename
  --   -- elseif ends_with(filename, ".js") then
  --   --   dep.scripts[#dep.scripts + 1] = filename
  --   -- else
  --   --   dep.resources[#dep.resources + 1] = filename
  --   -- end
  -- end

  quarto.utils.dump(dep)

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
  print(old_path)
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

return {
  {
    Pandoc = function (doc)
      -- Check if we need to copy things to the right place whatever it is
      -- ln -s ~/Library/Caches/shiny/shinylive/shinylive-0.0.2dev _extensions/quarto-ext/shinylive/shinylive
      codeblockScript = quarto.utils.resolvePath("shinylive-dist/scripts/codeblock-to-json.js")

      local baseDep = getShinyliveBaseDeps("shinylive-dist/")
      quarto.doc.addHtmlDependency(baseDep)

      return doc
    end
  },
  {
    CodeBlock = function(el)
      if el.attr and el.attr.classes:includes("{shinyapp-py}") then
        needsShinylive = true

        -- Save code block contents to a temp file.
        -- TODO: Make sure temp file is cleaned up even if an error occurs.
        -- tempfile = os.tmpname()
        -- print(tempfile)
        temp_codeblock_file = "tmp_codeblock.txt"
        f = io.open(temp_codeblock_file, "w")
        f:write(el.text)
        f:close()

        temp_json_file = "tmp_json.json"
        local p = io.popen(
          "deno run --allow-read --allow-write " .. codeblockScript .. " " ..
          temp_codeblock_file .. " " .. temp_json_file,"w")
        p:close()

        -- Run `shiny static` with these contents
        -- local p = io.popen("python3 -c 'import importlib; sl = importlib.import_module(\"_extensions.quarto-ext.shinylive.shinylive-dist.scripts.shinylive\"); sl._copy_pyodide_deps(\"tmp_json.json\", \"docs\")'", "r")
        -- local file_list = p:read("*a")
        -- p:close()

        -- print("-------------------")
        -- print(file_list)
        -- print("-------------------")


        os.remove(temp_codeblock_file)
        os.remove(temp_json_file)

        el.attr.classes = pandoc.List()
        el.attr.classes:insert("pyshiny")
        return el
      end
    end
  -- },
  -- {
  --   Meta = function(meta)
  --     if needsShinylive then
  --       quarto.doc.addHtmlDependency({
  --         name = "shinylive",
  --         stylesheets = {
  --           'resources/css/shinylive-quarto.css'
  --           -- '/shinylive/shinylive.css',
  --         },
  --         -- scripts = {
  --         --   { path = '/shinylive/load-serviceworker.js', attribs =  {type = "module" }},
  --         --   { path = '/serviceworker.js', attribs =  {type = "module" }},
  --         -- }
  --         -- These scripts are part of the Shinylive distribution. They
  --         head = [[
  --           <script src="./shinylive/load-serviceworker.js" type="module"></script>
  --           <script src="./shinylive/jquery.min.js"></script>
  --           <script src="./shinylive/jquery.terminal/js/jquery.terminal.min.js"></script>
  --           <link
  --             href="./shinylive/jquery.terminal/css/jquery.terminal.min.css"
  --             rel="stylesheet"
  --           />
  --           <link rel="stylesheet" href="./shinylive/shinylive.css" />
  --           <script src="./shinylive/run-python-blocks.js" type="module"></script>
  --         ]]
  --       })
  --     end
  --   end
  }
}
