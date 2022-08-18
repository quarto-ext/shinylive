local needsShinylive = false
local codeblockScript = nil

return {
  {
    Pandoc = function (doc)
      -- Check if we need to copy things to the right place whatever it is
      -- ln -s ~/Library/Caches/shiny/shinylive/shinylive-0.0.2dev _extensions/quarto-ext/shinylive/shinylive
      codeblockScript = quarto.utils.resolvePath("shinylive-dist/scripts/codeblock-to-json.js")
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
        local p = io.popen("python3 -c 'import importlib; sl = importlib.import_module(\"_extensions.quarto-ext.shinylive.shinylive-dist.scripts.shinylive\"); sl._copy_pyodide_deps(\"tmp_json.json\", \"docs\")'", "w")
        p:close()

        os.remove(temp_codeblock_file)
        os.remove(temp_json_file)

        el.attr.classes = pandoc.List()
        el.attr.classes:insert("pyshiny")
        return el
      end
    end
  },
  {
    Meta = function(meta)
      if needsShinylive then
        quarto.doc.addHtmlDependency({
          name = "shinylive",
          stylesheets = {
            'resources/css/shinylive-quarto.css'
            -- '/shinylive/shinylive.css',
          },
          -- scripts = {
          --   { path = '/shinylive/load-serviceworker.js', attribs =  {type = "module" }},
          --   { path = '/serviceworker.js', attribs =  {type = "module" }},
          -- }
          -- These scripts are part of the Shinylive distribution. They
          head = [[
            <script src="./shinylive/load-serviceworker.js" type="module"></script>
            <script src="./shinylive/jquery.min.js"></script>
            <script src="./shinylive/jquery.terminal/js/jquery.terminal.min.js"></script>
            <link
              href="./shinylive/jquery.terminal/css/jquery.terminal.min.css"
              rel="stylesheet"
            />
            <link rel="stylesheet" href="./shinylive/shinylive.css" />
            <script src="./shinylive/run-python-blocks.js" type="module"></script>
          ]]
        })
      end
    end
  }
}
