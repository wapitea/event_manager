# EventManager

![Master status](https://github.com/wapitea/event_manager/workflows/Elixir%20CI/badge.svg?branch=master)

Official documentation: [hexdocs](https://hexdocs.pm/event_manager).


The event manager helps you manage subscriptions to specific events. Thanks to this lib,
you'll be able to easily reduce coupling.

Inspired by the `EventDispatcher` package from Symfony Framework and adapted for 
functionnal programming.

## Installation

```elixir
def deps do
  [
    {:event_manager, "~> 0.1.0"}
  ]
end
```

Before using the lib you first have to register it using `EventManager.start_link/1`, which
also accepts a keyword opts for options. Inside your options, you can specify all the `apps` that
can use the `@subscribe` attribute.

Here's an example using a Supervisor:
``` elixir
children = [%{
  id: EventManager,
  start: {EventManager, :start_link, [[apps: [:manager]]]}
}]

opts = [strategy: :one_for_one, name: Manager.Supervisor]
Supervisor.start_link(children, opts)
```

## Quickstart

In this quickstart we'll define a mailing system that sends an email when a new user
is created. In this example, we assume you know Ecto basics and how to define a user schema.

First, let's create a module that will handle the `user_created` event, that will be 
dispatched when a new user is created.

This module will send an email when the `user_created` event is dispatched.

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

The `on_user_created` function will be called each time we dispatch the event `user_created`.
We assume that `user` will be sent as the event's parameter.

When using @subsribe event_name the system will call the function `on_#{event_name}` as the default
callback.

Then, we'll create a `User` module with the `create/1` function. This function will dispatch a 
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

There are 2 ways to register a subscriber.

- Dynamically 

```elixir
EventManager.subscribe("event_name", {MyApp, :callback})
```

- Staticly

```elixir
@subscribe "event_name"` or `@subscribe event: "event_name", callback: :function_name`
```

> In case you only use `@subscribe "event_name"`, the callback's name will be `on_event_name`.

Modules that use static subscriptions must use the module `EventManager.Handler`. Using this module will
define a function called `subscriptions/0` that returns the list of subscribed events. It will also register
your callback automatically for the specified event.
