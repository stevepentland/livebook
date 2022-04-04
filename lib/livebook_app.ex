if Mix.target() == :app do
  defmodule LivebookApp.WxUtils do
    @moduledoc false

    def wxID_ANY(), do: -1
    def wxID_CLOSE(), do: 5001
    def wxID_NEW(), do: 5002
    def wxID_EXIT(), do: 5006
    def wxID_OSX_HIDE(), do: 5250

    def os() do
      case :os.type() do
        {:unix, :darwin} -> :macos
        {:win32, _} -> :windows
      end
    end

    def put_mac_global_menubar(wx, menubar) do
      # Let's create a "fake" frame to attach the global menubar to.
      # A nicer solution would use `:wxMenuBar.macSetCommonMenuBar(mb)`
      # but unfortunately the order of menus is mangled, e.g. instead of
      # `<App> | File | Window` we get `<App> | Window | File`.
      frame = :wxFrame.new(wx, -1, "", size: {0, 0}, style: 0)
      :wxFrame.setMenuBar(frame, menubar)
      :wxFrame.show(frame)
      menubar
    end

    def new_menubar(app_name, menus) do
      menubar = :wxMenuBar.new()
      if os() == :macos, do: fixup_macos_menubar(menubar, app_name)

      for {title, items} <- menus do
        menu = :wxMenu.new()

        for item <- items do
          case item do
            title when is_binary(title) ->
              :wxMenu.append(menu, -1, title)

            {title, options} ->
              {id, options} = Keyword.pop(options, :id, wxID_ANY())
              item = :wxMenu.append(menu, id, title)

              Enum.each(options, fn
                {:enabled, true} -> :ok
                {:enabled, false} -> :wxMenuItem.enable(item, enable: false)
              end)
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

    @wxID_NEW LivebookApp.WxUtils.wxID_NEW()
    @wxID_CLOSE LivebookApp.WxUtils.wxID_CLOSE()
    @wxID_EXIT LivebookApp.WxUtils.wxID_EXIT()

    use GenServer

    def start_link(arg) do
      GenServer.start_link(__MODULE__, arg, name: __MODULE__)
    end

    def new_menubar(type \\ :regular) do
      LivebookApp.WxUtils.new_menubar("Livebook", [
        {"File",
         [
           "Open in Browser\tctrl+o",
           {"New Window\tctrl+n", id: @wxID_NEW},
           {"Close Window\tctrl+w", id: @wxID_CLOSE, enabled: type == :regular}
         ]}
      ])
    end

    def new_window(options \\ []) do
      GenServer.call(__MODULE__, {:new_window, options})
    end

    @impl true
    def init(_) do
      wx = :wx.new()
      :wx.subscribe_events()

      if LivebookApp.WxUtils.os() == :macos do
        menubar = new_menubar(:global)
        LivebookApp.WxUtils.put_mac_global_menubar(wx, menubar)
        :wxMenuBar.connect(menubar, :command_menu_selected, skip: true)
      end

      state = handle_new_window(%{wx: wx, windows: %{}}, [])
      {:ok, state}
    end

    # # This event is triggered when the application is opened for the first time
    # @impl true
    # def handle_info({:new_file, ''}, state) do
    #   Livebook.Utils.browser_open(LivebookWeb.Endpoint.access_url())
    #   {:noreply, state}
    # end

    # @impl true
    # def handle_info({:open_url, 'livebook://' ++ rest}, state) do
    #   "https://#{rest}"
    #   |> Livebook.Utils.notebook_import_url()
    #   |> Livebook.Utils.browser_open()

    #   {:noreply, state}
    # end

    # @impl true
    # def handle_info({:open_file, path}, state) do
    #   path
    #   |> List.to_string()
    #   |> Livebook.Utils.notebook_open_url()
    #   |> Livebook.Utils.browser_open()

    #   {:noreply, state}
    # end

    # @impl true
    # def handle_info({:reopen_app, _}, state) do
    #   # Livebook.Utils.browser_open(LivebookWeb.Endpoint.access_url())
    #   {:noreply, state}
    # end

    @impl true
    def handle_call({:new_window, options}, _from, state) do
      state = handle_new_window(state, options)
      {:reply, :ok, state}
    end

    @impl true
    def handle_info({:wx, @wxID_EXIT, _, _, _}, _state) do
      System.stop(0)
    end

    @impl true
    def handle_info({:wx, @wxID_NEW, _, _}, state) do
      state = handle_new_window(state, [])
      {:noreply, state}
    end

    @impl true
    def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
      state = update_in(state.windows, &Map.delete(&1, ref))
      {:noreply, state}
    end

    @impl true
    def handle_info(_event, state) do
      # IO.inspect(event)
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

    @wxID_NEW LivebookApp.WxUtils.wxID_NEW()
    @wxID_EXIT LivebookApp.WxUtils.wxID_EXIT()

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

      size = {1300, 1000}
      frame_options = [size: size]
      frame_options = if position, do: [pos: position] ++ frame_options, else: frame_options
      frame = :wxFrame.new(wx, -1, app_name, frame_options)
      menubar = LivebookApp.new_menubar()
      :wxFrame.setMenuBar(frame, menubar)

      url = LivebookWeb.Endpoint.access_url()
      # url = "https://elixir-lang.org"
      webview = :wxWebView.new(frame, -1, url: url, size: size)
      :ok = :wxWebView.connect(webview, :webview_navigating)
      :ok = :wxWebView.connect(webview, :webview_navigated)
      :ok = :wxWebView.connect(webview, :webview_loaded)
      :ok = :wxWebView.connect(webview, :webview_error)
      :ok = :wxWebView.connect(webview, :webview_newwindow)
      :ok = :wxWebView.connect(webview, :webview_title_changed)

      :wxFrame.show(frame)
      :wxFrame.connect(frame, :command_menu_selected, skip: true)
      :wxFrame.connect(frame, :close_window, skip: true)
      state = %{frame: frame}
      {frame, state}
    end

    @impl true
    def handle_event({:wx, @wxID_EXIT, _, _, _}, _state) do
      System.stop(0)
    end

    @impl true
    def handle_event({:wx, @wxID_NEW, _, _, _}, state) do
      {x, y} = :wxWindow.getPosition(state.frame)
      LivebookApp.new_window(position: {x + 50, y + 50})
      {:noreply, state}
    end

    @impl true
    def handle_event({:wx, _, _, _, {:wxClose, :close_window}} = event, state) do
      IO.inspect(event)
      {:noreply, state}
    end

    @impl true
    def handle_event(
          {:wx, _, _, _, {:wxWebView, :webview_title_changed, title, _, _, _}} = event,
          state
        ) do
      IO.inspect(event)
      :wxFrame.setTitle(state.frame, title)
      {:noreply, state}
    end

    @impl true
    def handle_event(event, state) do
      IO.inspect(event)
      {:noreply, state}
    end

    # def windows_connected(url) do
    #   url
    #   |> String.trim()
    #   |> String.trim_leading("\"")
    #   |> String.trim_trailing("\"")
    #   |> windows_to_wx()
    # end

    # defp windows_to_wx("") do
    #   send(__MODULE__, {:new_file, ''})
    # end

    # defp windows_to_wx("livebook://" <> _ = url) do
    #   send(__MODULE__, {:open_url, String.to_charlist(url)})
    # end

    # defp windows_to_wx(path) do
    #   path =
    #     path
    #     |> String.replace("\\", "/")
    #     |> String.to_charlist()

    #   send(__MODULE__, {:open_file, path})
    # end
  end
end
