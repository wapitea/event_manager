defmodule EventManager.Handler do
  @moduledoc """
  An event message is defined with the following format :

  ```
  %{event: "event_name", payload: "data"}
  ```
  The payload data can be any of type (integer, float, Map ...).
  """

  @callback subscriptions() :: any

  require Logger

  defmacro __using__(_) do
    quote do
      Module.register_attribute(__MODULE__, :subscribe, accumulate: true, persist: true)
      @behaviour EventManager.Handler

      unquote(__MODULE__).subscriptions()
    end
  end

  defmacro subscriptions do
    quote do
      def subscriptions() do
        __MODULE__.__info__(:attributes)
        |> Keyword.get_values(:subscribe)
        |> Enum.map(fn event_def ->
          case event_def do
            [event_name] ->
              [event: event_name, callback: String.to_existing_atom("on_#{event_name}")]

            other ->
              other
          end
        end)
      end
    end
  end

  @spec modules([atom()]) :: [atom()]
  def modules(app) do
    :application.get_key(app, :modules)
    |> elem(1)
    |> Enum.filter(fn module ->
      behaviours =
        module.module_info(:attributes)
        |> Keyword.get_values(:behaviour)
        |> List.flatten()

      __MODULE__ in behaviours
    end)
  end

  @spec map_events([atom()]) :: map()
  def map_events(modules) do
    modules
    |> Enum.map(fn module ->
      case Code.ensure_loaded(module) do
        {:module, _} ->
          Enum.map(
            module.subscriptions(),
            &{Keyword.get(&1, :event), module, Keyword.get(&1, :callback)}
          )

        {:error, reason} ->
          Logger.error(
            "[#{__MODULE__}] Error when trying to add #{module} to EventManager (#{reason})."
          )

          []
      end
    end)
    |> List.flatten()
    |> Enum.group_by(fn {event, _module, _callback} -> event end, fn {_event, module, callback} ->
      {module, callback}
    end)
  end
end
