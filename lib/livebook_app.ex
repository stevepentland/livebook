if Mix.target() == :app do
  defmodule LivebookApp.WxUtils do
    @moduledoc false

    def wxID_EXIT(), do: 5006
    def wxID_OSX_HIDE(), do: 5250

    def fixup_macos_menubar(menubar, app_name) do
      menu = :wxMenuBar.oSXGetAppleMenu(menubar)

      # without this, for some reason setting the title later will make it non-bold
      :wxMenu.getTitle(menu)

      # this is useful in dev, not needed when bundled in .app
      :wxMenu.setTitle(menu, app_name)

      menu
      |> :wxMenu.findItem(wxID_OSX_HIDE())
      |> :wxMenuItem.setItemLabel("Hide #{app_name}\tCtrl+H")

      menu
      |> :wxMenu.findItem(wxID_EXIT())
      |> :wxMenuItem.setItemLabel("Quit #{app_name}\tCtrl+Q")
    end

    def os() do
      case :os.type() do
        {:unix, :darwin} -> :macos
        {:win32, _} -> :windows
      end
    end
  end

  defmodule LivebookApp do
    @moduledoc false

    @wxID_EXIT LivebookApp.WxUtils.wxID_EXIT()

    use GenServer
    require Logger

    def start_link(arg) do
      GenServer.start_link(__MODULE__, arg, name: __MODULE__)
    end

    @impl true
    def init(_) do
      IO.inspect(:init)
      wx = :wx.new()

      menubar = :wxMenuBar.macGetCommonMenuBar()
      IO.inspect(menubar)
      LivebookApp.WxUtils.fixup_macos_menubar(menubar, "Livebook")
      :wxMenuBar.connect(menubar, :command_menu_selected, skip: true)

      {:ok, pid} = LivebookApp.Window.start_link(wx)
      ref = Process.monitor(pid)

      {:ok, %{windows: %{ref => pid}}}
    end

    # This event is triggered when the application is opened for the first time
    @impl true
    def handle_info({:new_file, ''}, state) do
      Livebook.Utils.browser_open(LivebookWeb.Endpoint.access_url())
      {:noreply, state}
    end

    @impl true
    def handle_info({:open_url, 'livebook://' ++ rest}, state) do
      "https://#{rest}"
      |> Livebook.Utils.notebook_import_url()
      |> Livebook.Utils.browser_open()

      {:noreply, state}
    end

    @impl true
    def handle_info({:open_file, path}, state) do
      path
      |> List.to_string()
      |> Livebook.Utils.notebook_open_url()
      |> Livebook.Utils.browser_open()

      {:noreply, state}
    end

    @impl true
    def handle_info({:reopen_app, _}, state) do
      Livebook.Utils.browser_open(LivebookWeb.Endpoint.access_url())
      {:noreply, state}
    end

    @impl true
    def handle_info({:wx, @wxID_EXIT, _, _, _}, _state) do
      System.stop(0)
    end

    @impl true
    def handle_info({:wx, _, _, _, _} = event, state) do
      Logger.debug(inspect(event))
      {:noreply, state}
    end

    @impl true
    def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
      state = update_in(state.windows, &Map.delete(&1, ref))
      {:noreply, state}
    end
  end

  defmodule LivebookApp.Window do
    @moduledoc false

    @behaviour :wx_object

    @wxID_EXIT LivebookApp.WxUtils.wxID_EXIT()

    require Logger

    def start_link(wx) do
      {:wx_ref, _, _, pid} = :wx_object.start_link(__MODULE__, wx, [])
      {:ok, pid}
    end

    def child_spec(init_arg) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [init_arg]},
        restart: :transient
      }
    end

    def windows_connected(url) do
      url
      |> String.trim()
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
      |> windows_to_wx()
    end

    @impl true
    def init(wx) do
      app_name = "Livebook"
      os = LivebookApp.WxUtils.os()

      size = {500, 500}
      frame = :wxFrame.new(wx, -1, app_name, size: size)
      :wxFrame.show(frame)

      if os == :macos do
        fixup_macos_menubar(frame, app_name)
      end

      :wxFrame.connect(frame, :command_menu_selected, skip: true)
      :wxFrame.connect(frame, :close_window, skip: true)

      case os do
        :macos ->
          :wx.subscribe_events()

        :windows ->
          windows_to_wx(System.get_env("LIVEBOOK_URL") || "")
      end

      state = %{frame: frame}
      {frame, state}
    end

    @impl true
    def handle_event({:wx, @wxID_EXIT, _, _, _}, _state) do
      System.stop()
    end

    @impl true
    def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
      {:noreply, state}
    end

    @impl true
    def handle_event(event, state) do
      Logger.debug(inspect(event))
      {:noreply, state}
    end

    # WxeApp attaches event handler to "Quit" menu item that does nothing (to not accidentally bring
    # down the VM). Let's create a fresh menu bar without that caveat.
    defp fixup_macos_menubar(frame, app_name) do
      menubar = :wxMenuBar.new()
      :wxFrame.setMenuBar(frame, menubar)
      LivebookApp.WxUtils.fixup_macos_menubar(menubar, app_name)
    end

    defp windows_to_wx("") do
      send(__MODULE__, {:new_file, ''})
    end

    defp windows_to_wx("livebook://" <> _ = url) do
      send(__MODULE__, {:open_url, String.to_charlist(url)})
    end

    defp windows_to_wx(path) do
      path =
        path
        |> String.replace("\\", "/")
        |> String.to_charlist()

      send(__MODULE__, {:open_file, path})
    end
  end
end
