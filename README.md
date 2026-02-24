# elm-url-navigation-port

Port-based SPA navigation for Elm's `Browser.element`.

Use this instead of `Browser.application` when you need URL routing in embedded Elm apps, micro-frontends, or any context where you want full control over history management.
I would often suggest staying on `Browser.element` for its simplicity and flexibility, as well as its better compatibility with external libraries and browser extensions.
As a bonus, this package enables pushing state objects to the browser history API, allowing for more complex navigation patterns, such as multi-step wizards not changing the url.

Note: The browser's History API only accepts same-origin URLs. This package uses `AppUrl` from [lydell/elm-app-url](https://github.com/lydell/elm-app-url) to represent navigation targets, which produce relative URL strings by construction — always same-origin.

## Installation

**Elm side:**

```sh
elm install mpizenberg/elm-url-navigation-port
```

**JS side:**

```sh
npm install elm-url-navigation-port
```

## Setup

### 1. Declare ports in your Elm app

```elm
port module Main exposing (main)

import Navigation as Nav

port navCmd : Nav.CommandPort msg
port onNavEvent : Nav.EventPort msg
```

### 2. Wire them up in JavaScript

```html
<script type="module">
  import * as Navigation from "elm-url-navigation-port";

  const app = Elm.Main.init({
    node: document.getElementById("app"),
    flags: location.href,
  });

  Navigation.init({
    navCmd: app.ports.navCmd,
    onNavEvent: app.ports.onNavEvent,
  });
</script>
```

### 3. Use in your Elm code

```elm
import AppUrl exposing (AppUrl)
import Navigation as Nav

-- Subscribe to navigation events
subscriptions : Model -> Sub Msg
subscriptions _ =
    Nav.onEvent onNavEvent GotNavigationEvent

-- Navigate
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NavigateTo appUrl ->
            ( model, Nav.pushUrl navCmd appUrl )

        GotNavigationEvent event ->
            ( { model | page = route event.appUrl }, Cmd.none )
```

## Four navigation patterns

### 1. Page navigation — `pushUrl`

Standard SPA navigation. Creates a history entry and notifies Elm of the new URL. The browser back button works via `popstate`.

```elm
Nav.pushUrl navCmd (AppUrl.fromPath [ "about" ])
```

### 2. State-based navigation — `pushState`

Push a state object without changing the URL. Useful for wizard steps or tab flows that should support the back button but don't need distinct URLs.

```elm
Nav.pushState navCmd
    (Encode.object [ ( "wizardStep", Encode.int 2 ) ])
```

On back-button press, the state object arrives in `event.state`. Decode it in your `GotNavigationEvent` handler:

```elm
GotNavigationEvent event ->
    let
        step =
            Decode.decodeValue (Decode.field "wizardStep" Decode.int) event.state
                |> Result.withDefault 1
    in
    ( { model | page = Wizard (intToStep step) }, Cmd.none )
```

### 3. History traversal — `back` / `forward`

Navigate backward or forward through the session history, like the browser's back and forward buttons. Supports jumping multiple steps at once.

```elm
Nav.back navCmd 1     -- go back one page
Nav.back navCmd 2     -- go back two pages
Nav.forward navCmd 1  -- go forward one page
Nav.forward navCmd 2  -- go forward two pages
```

The existing `popstate` listener handles the resulting navigation event automatically — no extra wiring needed.

### 4. Cosmetic URL update — `replaceUrl`

Update the URL bar without creating a history entry and **without notifying Elm**. The model stays the source of truth. Use this for display or shareability (e.g. fragments, counters).

```elm
Nav.replaceUrl navCmd
    { path = [ "about" ]
    , queryParameters = Dict.empty
    , fragment = Just (String.fromInt counter)
    }
```

## Flags

Configure your server to always serve your root `index.html` file whatever the actual url that was provided to your server.
On cloud platforms providing static servers, such as Cloudflare Pages, there is usually an option for this.
Then pass `location.href` as a flag so Elm can route the initial page:

```elm
main : Program String Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }

init : String -> ( Model, Cmd Msg )
init locationHref =
    ( { page =
            Url.fromString locationHref
                |> Maybe.map (AppUrl.fromUrl >> route)
                |> Maybe.withDefault NotFound
      }
    , Cmd.none
    )
```

## Link clicks

Prevent default on internal links to avoid full page reloads:

```elm
import AppUrl exposing (AppUrl)
import Json.Decode as Decode

navLink : AppUrl -> String -> Html Msg
navLink appUrl label =
    a [ href (AppUrl.toString appUrl), onClickPreventDefault (NavigateTo appUrl) ]
        [ text label ]

onClickPreventDefault : msg -> Attribute msg
onClickPreventDefault msg =
    Html.Events.preventDefaultOn "click"
        (Decode.succeed ( msg, True ))
```

## Example

See the [`example/`](https://github.com/mpizenberg/elm-url-navigation-port/tree/main/example) directory for a working demo that exercises all four navigation patterns, including back/forward buttons.

## Nav.Event

The `Nav.Event` type contains:

- `appUrl : AppUrl` — the parsed URL (path, query parameters, fragment)
- `state : Decode.Value` — the history state object, or `null` if none was set

The decoder fails if `location.href` is not a valid URL, which should never happen in normal browser navigation.
