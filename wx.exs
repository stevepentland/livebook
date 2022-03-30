wx = :wx.new()
f = :wxFrame.new(wx, -1, "Yo", size: {0, 0})
:wxFrame.show(f)

mb = :wxMenuBar.new()
:wxFrame.setMenuBar(f, mb)
m = :wxMenuBar.oSXGetAppleMenu(mb)

# IO.inspect(:wxMenuBar.getMenuCount(mb))

IO.inspect(:wxMenu.getTitle(m))
:wxMenu.setTitle(m, "Yo")
IO.inspect(:wxMenu.getTitle(m))
# mb = :wxFrame.getMenuBar(f)
# IO.inspect(:wxMenuBar.getLabelTop(mb, 0))
# :wxMenuBar.setMenuLabel(mb, 1, "Yo")

:wxMenu.connect(m, :command_menu_selected, skip: true)

receive do
  event ->
    IO.inspect(event)
end
