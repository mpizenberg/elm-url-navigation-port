module Navigation exposing
    ( CommandPort, EventPort
    , pushUrl, pushUrlWithState, replaceUrl, pushState
    , back, forward
    , Event, decoder, onEvent
    )

{-| Port-based SPA navigation for `Browser.element`.

This module provides helpers for navigating with ports instead of
using `Browser.application`. Your application defines two ports:

    port navCmd : Nav.CommandPort msg

    port onNavEvent : Nav.EventPort msg

Then use [`pushUrl`](#pushUrl), [`replaceUrl`](#replaceUrl), and
[`pushState`](#pushState) to send navigation commands, and
[`onEvent`](#onEvent) to subscribe to navigation events.

Use [`back`](#back) and [`forward`](#forward) to traverse history.

Note: The History API only accepts same-origin URLs.
All navigation commands produce relative URL strings via `AppUrl`,
which are always same-origin by construction.


# Port Types

@docs CommandPort, EventPort


# Commands

@docs pushUrl, pushUrlWithState, replaceUrl, pushState


# History Traversal

@docs back, forward


# Events

@docs Event, decoder, onEvent

-}

import AppUrl exposing (AppUrl)
import Json.Decode as Decode
import Json.Encode as Encode
import Url


{-| Type alias for an outgoing command port.

Declare this in your port module:

    port navCmd : Nav.CommandPort msg

-}
type alias CommandPort msg =
    Encode.Value -> Cmd msg


{-| Type alias for an incoming event port.

Declare this in your port module:

    port onNavEvent : Nav.EventPort msg

-}
type alias EventPort msg =
    (Decode.Value -> msg) -> Sub msg


{-| Navigate to a URL, creating a new history entry.

The JS companion calls `history.pushState(null, "", url)` and
notifies Elm of the new location.

    update msg model =
        case msg of
            NavigateTo appUrl ->
                ( model, Nav.pushUrl navCmd appUrl )

-}
pushUrl : CommandPort msg -> AppUrl -> Cmd msg
pushUrl port_ appUrl =
    port_
        (Encode.object
            [ ( "tag", Encode.string "pushUrl" )
            , ( "url", Encode.string (AppUrl.toString appUrl) )
            ]
        )


{-| Navigate to a URL with a state object, creating a new history entry.

The JS companion calls `history.pushState(state, "", url)` and
notifies Elm with both the new URL and the state. Use this when
you need to attach metadata to a history entry alongside a URL
change (e.g. scroll position, referrer context).

    Nav.pushUrlWithState navCmd
        (AppUrl.fromPath [ "product", "42" ])
        (Encode.object [ ( "scrollY", Encode.int 250 ) ])

-}
pushUrlWithState : CommandPort msg -> AppUrl -> Encode.Value -> Cmd msg
pushUrlWithState port_ appUrl state =
    port_
        (Encode.object
            [ ( "tag", Encode.string "pushState" )
            , ( "url", Encode.string (AppUrl.toString appUrl) )
            , ( "state", state )
            ]
        )


{-| Replace the current URL without creating a history entry.

The JS companion calls `history.replaceState(state, "", url)` and
does **not** notify Elm. Use this for cosmetic URL updates where
the model is the source of truth.

    ( { model | counter = n }
    , Nav.replaceUrl navCmd
        { path = [ "about" ]
        , queryParameters = Dict.empty
        , fragment = Just (String.fromInt n)
        }
    )

-}
replaceUrl : CommandPort msg -> AppUrl -> Cmd msg
replaceUrl port_ appUrl =
    port_
        (Encode.object
            [ ( "tag", Encode.string "replaceUrl" )
            , ( "url", Encode.string (AppUrl.toString appUrl) )
            ]
        )


{-| Push a state object into the history without changing the URL.

The JS companion calls `history.pushState(state, "")` and notifies
Elm with both the URL and the state. Useful for wizard steps or
tab-like flows that should support the back button but don't need
distinct URLs.

    Nav.pushState navCmd
        (Encode.object [ ( "step", Encode.int 2 ) ])

-}
pushState : CommandPort msg -> Encode.Value -> Cmd msg
pushState port_ state =
    port_
        (Encode.object
            [ ( "tag", Encode.string "pushState" )
            , ( "state", state )
            ]
        )


{-| Go back by the given number of steps in session history.

Calls `history.go(-n)`. The existing `popstate` listener handles
the resulting navigation event automatically.

    Nav.back navCmd 1 -- equivalent to pressing the browser Back button

    Nav.back navCmd 2 -- go back two pages

-}
back : CommandPort msg -> Int -> Cmd msg
back port_ n =
    go port_ (negate (abs n))


{-| Go forward by the given number of steps in session history.

Calls `history.go(n)`. The existing `popstate` listener handles
the resulting navigation event automatically.

    Nav.forward navCmd 1 -- equivalent to pressing the browser Forward button

    Nav.forward navCmd 2 -- go forward two pages

-}
forward : CommandPort msg -> Int -> Cmd msg
forward port_ n =
    go port_ (abs n)


go : CommandPort msg -> Int -> Cmd msg
go port_ steps =
    port_
        (Encode.object
            [ ( "tag", Encode.string "go" )
            , ( "steps", Encode.int steps )
            ]
        )


{-| Data sent by the JS companion after a navigation event.

  - `appUrl` — the parsed `AppUrl` (path, query parameters, fragment)
  - `state` — the history state object, or `null` if none was set

-}
type alias Event =
    { appUrl : AppUrl
    , state : Decode.Value
    }


{-| Decode a navigation event from the JS companion.

Decodes the `href` field into an `AppUrl` (failing if the URL is
malformed) and preserves the `state` field as a raw JSON value.

-}
decoder : Decode.Decoder Event
decoder =
    Decode.map2 Event
        (Decode.field "href" Decode.string
            |> Decode.andThen
                (\href ->
                    case Url.fromString href of
                        Just url ->
                            Decode.succeed (AppUrl.fromUrl url)

                        Nothing ->
                            Decode.fail ("Invalid URL: " ++ href)
                )
        )
        (Decode.field "state" Decode.value)


{-| Subscribe to navigation events.

    subscriptions _ =
        Nav.onEvent onNavEvent GotNavigationEvent

-}
onEvent : EventPort msg -> (Event -> msg) -> Sub msg
onEvent port_ toMsg =
    port_
        (\value ->
            case Decode.decodeValue decoder value of
                Ok event ->
                    toMsg event

                Err _ ->
                    -- This should not happen if the JS companion is wired correctly.
                    -- We still produce a msg to avoid silently dropping events.
                    toMsg
                        { appUrl = AppUrl.fromPath []
                        , state = Encode.null
                        }
        )
