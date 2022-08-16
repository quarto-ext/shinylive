return {
  {
    CodeBlock = function (el)
      if el.attr and el.attr.classes:includes("{shinyapp-py}") then
        el.attr.classes = pandoc.List()
        el.attr.classes:insert("pyshiny")
        return el
      end
    end
  }
}
