defmodule EventManager do
  @moduledoc """
  The event manager dispatches events to subscribers.
  It can help you a lot to reduce your code complexity and reduce lib coupeling.

  It simply use elixir's Registry and add some syntax sugar and helpers in top of it.
  """

  @registry_name EventManagerRegistry

  require Logger
  alias EventManager.Handler

  @doc """
  Start the registry and register static subscriptions.

  `opts` accepts :

  - `:apps`: Application name that you want to use in EventManager.

  E.g

      iex> EventManager.start_link(apps: [MyApp])
  """
  def start_link(opts) do
    Registry.start_link(keys: :duplicate, name: EventManager.get_registry_name())
    start_subscriptions(Keyword.get(opts, :apps))
  end

  @doc """
  Subscribe to an event.

  You can subscribe to an event using `@subscribe` attribute. To be able to use
  this attribute, you must need first to use `EventManager.Handler`.

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

  > `pid` is the process id that subscribe to the event.
  > `payload` is the data that have been dispatched.

  You can also subscribe dynamically (in runtime) using directly this function.

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
  Unsubsribe to the specified event.

  It could be really usefull for async system that is used by multiple PID for example.
  It's higly recommand to use only for dynamic subscription (see `EventManager.subscribe/2`)

  > It will only unsubscribe the event for the PID that call it.

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
  Plus, you can add some data that are useful for manage the event in callbacks.

  For example, if you want to dispatch an event when a new user is created, it could be
  nice to send the user in the event payload.

  E.g.

      iex> user = %{id: 1234, name: "Foo Bar", email: "foo@bar.com"}
      iex> EventManager.dispatch("user_created", %{user: user})
      iex> EventManager.dispatch("user_created", user)

  Basically you can send whatever you want as payload.
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

  This function is automatically call if you use `EventManager.start_link/1`.
  But it's nive to now that you can call it manually depending of your needs.

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
  Return the registry name use by `EventManager`.
  """
  def get_registry_name(), do: @registry_name
end
