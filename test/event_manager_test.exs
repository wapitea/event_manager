defmodule EventManagerTest do
  use ExUnit.Case, async: false
  use EventManager.Handler

  setup_all do
    EventManager.start_link(apps: [])

    [__MODULE__]
    |> EventManager.Handler.map_events()
    |> EventManager.register_subscriptions()

    :ok
  end

  test "dynamic subscription to `test` event" do
    EventManager.subscribe("dynamic_subscription", {__MODULE__, :dynamic_callback})

    assert Registry.lookup(EventManager.get_registry_name(), "dynamic_subscription") == [
             {self(), {__MODULE__, :dynamic_callback}}
           ]
  end

  test "static subscription to `test2` event" do
    subscriber =
      Registry.lookup(EventManager.get_registry_name(), "static_subscription")
      |> List.first()
      |> elem(1)

    assert subscriber == {__MODULE__, :static_callback}
  end

  test "handle event" do
    payload = %{data: "data_test", pid: self()}

    EventManager.dispatch("static_subscription", payload)
    assert_receive {:callback_executed, payload}, 500
  end

  def dynamic_callback(pid, payload) do
    send(pid, {:callback_executed, payload})
  end

  @subscribe event: "static_subscription", callback: "static_callback"
  def static_callback(_pid, payload) do
    send(payload.pid, {:callback_executed, payload})
  end
end
