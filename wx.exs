wx = :wx.new()
f = :wxFrame.new(wx, -1, "Demo", size: {500, 500})

mb =
  MenuBar.new([
    {"File",
     [
       "Open in Browser\tctrl+o",
       "New Window\tctrl+n",
       "Close Window\tctrl+n"
     ]}
  ])

:wxFrame.setMenuBar(f, mb)
:wxFrame.show(f)
:wxMenuBar.connect(mb, :command_menu_selected, skip: true)

receive do
  event ->
    IO.inspect(event)
end
