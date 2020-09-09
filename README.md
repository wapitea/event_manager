# EventManager

![Master status](https://github.com/wapitea/event_manager/workflows/Elixir%20CI/badge.svg?branch=master)

Official documentation: [hexdocs](https://hexdocs.pm/event_manager).


EventManager help you to manager subscriptions to specific event. Thanks to this lib
reduce couple become easy.

Inspired by the `EventDispatcher` package from Symfony Framework and adapte for 
functionnal programming.

## Installation

```elixir
def deps do
  [
    {:event_manager, "~> 0.1.0"}
  ]
end
```

Before using the lib you must register it using `EventManager.start_link/1` that
accept a keyword opts. In this keyword you can define `apps` that define all apps
that could use the `@subscribe` attribute.

For example, you can start it using a Supervisor.
``` elixir
children = [%{
  id: EventManager,
  start: {EventManager, :start_link, [[apps: [:manager]]]}
}]

opts = [strategy: :one_for_one, name: Manager.Supervisor]
Supervisor.start_link(children, opts)
```

## Quickstart

In this quickstart we'll define a mailing system that send an email when a new user
is created. In this example, we supposed you already know ecto and define user schema.

First, let's create a module that will handle the event `user_created` that will be 
dispatch we a new user is created. This module will send an email when the `user_created`
event is dispatched.

``` elixir
defmodule Mail do
  use EventManager.Handler
  
  # ... other functions
  
  @subscribe "user_created"
  def on_user_created(_pid, user) do 
    Mail.send_welcome(user)
  end
end
```

The `on_user_created` function will be call each time we dispatch the event `user_created`.
We assume that we'll send the `user` as event's parameter.

When using @subsribe event_name the system will call the function `on_#{event_name}` as default
callback.

Then, we'll create an `User` module with a `create/1` function. This function will dispatch an 
`user_created` event when the user has been inserted into the database.

``` elixir
defmodule User do
  # ... ecto schema and changeset (according to ecto)

  def create(user_params) do
    user = %__MODULE__{}
    |> changeset(user_params)
    |> MyApp.Repo.insert()
    
    with {:ok, _} <- user do
      EventManager.dispatch("user_created", user)
    end
    
    user
  end
end
```

## Subscribers

There is 2 way to register a subscriber.

- Dynamically 

```elixir
EventManager.subscribe("event_name", {MyApp, :callback})
```

- Staticly

```elixir
@subscribe "event_name"` or `@subscribe event: "event_name", callback: :function_name`
```

> In case you only user `@subscribe "event_name"`, the callback's name will be `on_event_name`.

Module that use static subscription must use the module `EventManager.Handler`. Using this module will
define a function call `subscriptions/0` that return the list of subscribed event. It will also registry
automatically your callback for the specified event.
