if Mix.target() == :app do
  defmodule WxUtils do
    @moduledoc false

    defmacro wxID_ANY(), do: -1
    defmacro wxID_CLOSE(), do: 5001
    defmacro wxID_NEW(), do: 5002
    defmacro wxID_EXIT(), do: 5006
    defmacro wxID_OSX_HIDE(), do: 5250

    def os() do
      case :os.type() do
        {:unix, :darwin} -> :macos
        {:win32, _} -> :windows
      end
    end

    def put_mac_global_menubar(wx, menubar) do
      frame = :wxFrame.new(wx, -1, "", size: {0, 0}, style: 0)
      :wxFrame.setMenuBar(frame, menubar)
      :wxFrame.show(frame)
    end

    def menubar(app_name, menus) do
      menubar = :wxMenuBar.new()
      if os() == :macos, do: fixup_macos_menubar(menubar, app_name)

      for {title, items} <- menus do
        menu = :wxMenu.new()

        for item <- items do
          case item do
            title when is_binary(title) ->
              :wxMenu.append(menu, wxID_ANY(), title)

            {title, options} ->
              id = Keyword.get(options, :id, wxID_ANY())
              :wxMenu.append(menu, id, title)
          end
        end

        true = :wxMenuBar.append(menubar, menu, title)
      end

      menubar
    end

    defp fixup_macos_menubar(menubar, app_name) do
      menu = :wxMenuBar.oSXGetAppleMenu(menubar)

      menu
      |> :wxMenu.findItem(wxID_OSX_HIDE())
      |> :wxMenuItem.setItemLabel("Hide #{app_name}\tCtrl+H")

      menu
      |> :wxMenu.findItem(wxID_EXIT())
      |> :wxMenuItem.setItemLabel("Quit #{app_name}\tCtrl+Q")
    end
  end

  defmodule LivebookApp do
    @moduledoc false

    use GenServer
    import WxUtils

    def start_link(arg) do
      GenServer.start_link(__MODULE__, arg, name: __MODULE__)
    end

    def menubar do
      menubar("Livebook", [
        {"File",
         [
           "Open in Browser\tctrl+o",
           {"New Window\tctrl+shift+n", id: wxID_NEW()},
           {"Close Window\tctrl+w", id: wxID_CLOSE()}
         ]}
      ])
    end

    def new_window(options) do
      GenServer.call(__MODULE__, {:new_window, options})
    end

    @impl true
    def init(_) do
      wx = :wx.new()
      :wx.subscribe_events()

      if os() == :macos do
        menubar = menubar()
        :wxMenuBar.findItem(menubar, wxID_CLOSE()) |> :wxMenuItem.enable(enable: false)
        put_mac_global_menubar(wx, menubar)
        :wxMenuBar.connect(menubar, :command_menu_selected, skip: true)
      end

      state = handle_new_window(%{wx: wx, windows: %{}}, position: {50, 50})
      {:ok, state}
    end

    @impl true
    def handle_call({:new_window, options}, _from, state) do
      state = handle_new_window(state, options)
      {:reply, :ok, state}
    end

    @impl true
    def handle_info({:wx, wxID_EXIT(), _, _, _}, _state) do
      System.stop(0)
    end

    @impl true
    def handle_info({:wx, wxID_NEW(), _, _, _}, state) do
      state = handle_new_window(state, [])
      {:noreply, state}
    end

    @impl true
    def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
      state = update_in(state.windows, &Map.delete(&1, ref))
      {:noreply, state}
    end

    @impl true
    def handle_info(event, state) do
      IO.inspect(event)
      {:noreply, state}
    end

    defp handle_new_window(state, options) do
      {:ok, pid} = LivebookApp.Window.start_link([wx: state.wx] ++ options)
      ref = Process.monitor(pid)
      update_in(state.windows, &Map.put(&1, ref, pid))
    end
  end

  defmodule LivebookApp.Window do
    @moduledoc false
    @behaviour :wx_object

    import WxUtils

    def start_link(options) do
      {:wx_ref, _, _, pid} = :wx_object.start_link(__MODULE__, options, [])
      {:ok, pid}
    end

    def child_spec(init_arg) do
      %{
        id: __MODULE__,
        start: {__MODULE__, :start_link, [init_arg]},
        restart: :transient
      }
    end

    @impl true
    def init(options) do
      wx = Keyword.fetch!(options, :wx)
      position = Keyword.get(options, :position)

      app_name = "Livebook"
      size = {1000, 600}
      frame_options = [size: size]
      frame_options = if position, do: [pos: position] ++ frame_options, else: frame_options
      f = :wxFrame.new(wx, -1, app_name, frame_options)
      mb = LivebookApp.menubar()
      :wxFrame.setMenuBar(f, mb)
      :wxFrame.connect(f, :close_window, skip: true)
      :wxMenuBar.connect(mb, :command_menu_selected, skip: true)
      :wxFrame.show(f)
      url = LivebookWeb.Endpoint.access_url()
      # url = "http://livebeats.fly.dev"
      # url = "http://localhost:4001/dashboard/home"
      # url = "https://elixir-lang.org"
      webview = :wxWebView.new(f, -1, url: url, size: size)
      :wxWebView.connect(webview, :webview_title_changed)
      state = %{frame: f}
      {f, state}
    end

    @impl true
    def handle_event({:wx, wxID_EXIT(), _, _, _}, _state) do
      System.stop(0)
    end

    @impl true
    def handle_event({:wx, wxID_NEW(), _, _, _}, state) do
      {x, y} = :wxWindow.getPosition(state.frame)
      LivebookApp.new_window(position: {x + 25, y + 25})
      {:noreply, state}
    end

    @impl true
    def handle_event({:wx, wxID_CLOSE(), _, _, _}, state) do
      :wxFrame.close(state.frame)
      {:noreply, state}
    end

    @impl true
    def handle_event({:wx, _, _, _, {:wxClose, :close_window}}, state) do
      {:noreply, state}
    end

    @impl true
    def handle_event({:wx, _, _, _, {:wxWebView, :webview_title_changed, title, _, _, _}}, state) do
      :wxFrame.setTitle(state.frame, title)
      {:noreply, state}
    end

    @impl true
    def handle_event(event, state) do
      IO.inspect(event)
      {:noreply, state}
    end
  end
end
