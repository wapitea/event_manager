defmodule EventManager do
  @moduledoc """
  The event manager dispatches events to subscribers and
  adds some syntactic sugar as well as helpers on top of elixir's Registry.

  It can also help reduce code complexity and lib coupling.
  """

  @registry_name EventManagerRegistry

  require Logger
  alias EventManager.Handler

  @doc """
  Start the registry and register static subscriptions.

  `opts` accepts :

  - `:apps`: The application name that you want to use in the EventManager.

  E.g

      iex> EventManager.start_link(apps: [MyApp])
  """
  def start_link(opts) do
    Registry.start_link(keys: :duplicate, name: EventManager.get_registry_name())
    start_subscriptions(Keyword.get(opts, :apps))
  end

  @doc """
  Subscribe to an event.

  You can subscribe to an event by using the `@subscribe` attribute.
  To use it, first you must use `EventManager.Handler`.

  E.g.

    ```elixir
    defmodule MyApp do
      use EventManager.Handler

      @subscribe "event_1"
      def on_event_1(pid, payload) do
        # business logic
      end

      @subscribe event: "event_2", callback: "my_callback"
      def my_callback(pid, payload) do
        # business logic
      end
    end
    ```

  > `pid` is the id of the process that subscribes to the event.
  > `payload` is the data that has been dispatched.

  You can also subscribe dynamically (during runtime) using this function directly.

  E.g

      iex> EventManager.subscribe("event_name", {MyApp, :callback})
      :ok

  """
  @spec subscribe(String.t(), {atom, atom | String.t()}) :: :ok | :error
  def subscribe(event, {module, callback}) when is_bitstring(callback) do
    subscribe(event, {module, String.to_atom(callback)})
  end

  def subscribe(event, {module, callback}) do
    cond do
      :error == module |> Code.ensure_loaded() |> elem(0) ->
        Logger.error("[#{__MODULE__}] Module #{module} doesn't exist.")
        :error

      !Keyword.has_key?(module.__info__(:functions), callback) ->
        Logger.error(
          "[#{__MODULE__}] There is no callback \"#{callback}\" in module \"#{module}\"."
        )

        :error

      true ->
        Registry.register(@registry_name, event, {module, callback})
    end
  end

  @doc """
  Unsubsribe from the specified event.

  It can be very useful for async systems that are used by multiple PIDs for example.
  It's higly recommended that you only use it for dynamic subscriptions (see `EventManager.subscribe/2`)

  > It will only unsubscribe the event for the calling PID.

  E.g.

      iex> EventManager.unsubscribe("my_event_name")
  """
  @spec unsubscribe(String.t()) :: :ok
  def unsubscribe(event) do
    Registry.unregister(@registry_name, event)
  end

  @doc """
  Dispatch my event to every registered subscriber.

  The dispatch function will call all Modules/functions that have subscribed to the dispatch event.
  You can also add some data useful for managing the event in callbacks.

  For example, if you want to dispatch an event when a new user is created, it could be
  nice to send the user in the event payload.

  E.g.

      iex> user = %{id: 1234, name: "Foo Bar", email: "foo@bar.com"}
      iex> EventManager.dispatch("user_created", %{user: user})
      iex> EventManager.dispatch("user_created", user)

  Basically you can send whatever you want as a payload.
  """
  @spec dispatch(String.t(), any) :: :ok
  def dispatch(event_name, event_data) do
    Logger.info(fn -> "[#{__MODULE__}] Dispatch event \"#{event_name}\"" end)

    Registry.dispatch(@registry_name, event_name, fn state ->
      for {pid, {module, callback}} <- state do
        apply(module, callback, [pid, event_data])
      end
    end)
  end

  @doc """
  Start subscriptions.

  This function is automatically called if you use `EventManager.start_link/1`,
  but it's nice to know that you can call it manually depending on your needs.

  E.g.
      iex> EventManager.start_link([MyApp])
  """
  @spec start_subscriptions([atom]) :: {:ok, pid}
  def start_subscriptions(apps) do
    Logger.info("Start subscriptions ...")

    Enum.each(apps, fn app ->
      Handler.modules(app)
      |> Handler.map_events()
      |> register_subscriptions()
    end)

    {:ok, self()}
  end

  @doc false
  def register_subscriptions(mapped_modules) do
    Enum.each(mapped_modules, fn {event_name, subscribers} ->
      for {module, callback} <- subscribers do
        Logger.debug(
          "Add subscriber for \"#{module}\" (callback: #{callback}) for event \"#{event_name}\"."
        )

        subscribe(event_name, {module, callback})
      end
    end)
  end

  @doc """
  Return the registry name used by `EventManager`.
  """
  def get_registry_name(), do: @registry_name
end
