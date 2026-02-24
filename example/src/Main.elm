port module Main exposing (main)

import AppUrl exposing (AppUrl)
import Browser
import Dict
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput)
import Json.Decode as Decode
import Json.Encode as Encode
import Navigation as Nav
import Url


port navCmd : Nav.CommandPort msg


port onNavEvent : Nav.EventPort msg



-- MAIN


main : Program String Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Nav.onEvent onNavEvent GotNavigationEvent



-- MODEL


type Page
    = Home
    | Wizard WizardStep
    | About
    | NotFound


type WizardStep
    = Step1
    | Step2
    | Step3


type alias WizardData =
    { name : String
    , color : String
    }


type alias Model =
    { page : Page
    , wizardData : WizardData
    , counter : Int
    }


init : String -> ( Model, Cmd Msg )
init locationHref =
    ( { page =
            Url.fromString locationHref
                |> Maybe.map (AppUrl.fromUrl >> route)
                |> Maybe.withDefault NotFound
      , wizardData = { name = "", color = "" }
      , counter = 0
      }
    , Cmd.none
    )



-- ROUTING


route : AppUrl -> Page
route appUrl =
    case appUrl.path of
        [] ->
            Home

        [ "wizard" ] ->
            Wizard Step1

        [ "about" ] ->
            About

        _ ->
            NotFound



-- UPDATE


type Msg
    = GotNavigationEvent Nav.Event
    | NavigateTo AppUrl
    | GoBack Int
    | GoForward Int
    | GoToWizardStep WizardStep
    | IncrementCounter
    | SetName String
    | SetColor String


wizardStepToInt : WizardStep -> Int
wizardStepToInt step =
    case step of
        Step1 ->
            1

        Step2 ->
            2

        Step3 ->
            3


intToWizardStep : Int -> WizardStep
intToWizardStep n =
    case n of
        2 ->
            Step2

        3 ->
            Step3

        _ ->
            Step1


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NavigateTo appUrl ->
            ( model, Nav.pushUrl navCmd appUrl )

        GoBack n ->
            ( model, Nav.back navCmd n )

        GoForward n ->
            ( model, Nav.forward navCmd n )

        GotNavigationEvent event ->
            let
                page =
                    route event.appUrl

                wizardStep =
                    Decode.decodeValue (Decode.field "wizardStep" Decode.int) event.state
                        |> Result.toMaybe

                adjusted =
                    case ( page, wizardStep ) of
                        ( Wizard _, Just step ) ->
                            Wizard (intToWizardStep step)

                        _ ->
                            page
            in
            ( { model | page = adjusted }, Cmd.none )

        GoToWizardStep step ->
            ( model
            , Nav.pushState navCmd
                (Encode.object [ ( "wizardStep", Encode.int (wizardStepToInt step) ) ])
            )

        IncrementCounter ->
            let
                newCounter =
                    model.counter + 1
            in
            ( { model | counter = newCounter }
            , Nav.replaceUrl navCmd
                { path = [ "about" ]
                , queryParameters = Dict.empty
                , fragment = Just (String.fromInt newCounter)
                }
            )

        SetName name ->
            let
                data =
                    model.wizardData
            in
            ( { model | wizardData = { data | name = name } }, Cmd.none )

        SetColor color ->
            let
                data =
                    model.wizardData
            in
            ( { model | wizardData = { data | color = color } }, Cmd.none )



-- VIEW


view : Model -> Html Msg
view model =
    div []
        [ viewNav
        , viewPage model
        ]


viewNav : Html Msg
viewNav =
    nav []
        [ p []
            [ text "Go back or forward: "
            , button [ onClick (GoBack 2) ] [ text "<<" ]
            , text " "
            , button [ onClick (GoBack 1) ] [ text "<" ]
            , text " "
            , button [ onClick (GoForward 1) ] [ text ">" ]
            , text " "
            , button [ onClick (GoForward 2) ] [ text ">>" ]
            ]
        , p []
            [ navLink (AppUrl.fromPath []) "Home"
            , text " | "
            , navLink (AppUrl.fromPath [ "wizard" ]) "Wizard"
            , text " | "
            , navLink (AppUrl.fromPath [ "about" ]) "About"
            ]
        ]


navLink : AppUrl -> String -> Html Msg
navLink appUrl label =
    a [ href (AppUrl.toString appUrl), onClickPreventDefault (NavigateTo appUrl) ]
        [ text label ]


onClickPreventDefault : msg -> Attribute msg
onClickPreventDefault msg =
    Html.Events.preventDefaultOn "click"
        (Decode.succeed ( msg, True ))


viewPage : Model -> Html Msg
viewPage model =
    case model.page of
        Home ->
            viewHome

        Wizard step ->
            viewWizard step model.wizardData

        About ->
            viewAbout model.counter

        NotFound ->
            h2 [] [ text "Page not found" ]


viewHome : Html Msg
viewHome =
    div []
        [ h1 [] [ text "Home" ]
        , p [] [ text "Welcome! This is a minimal Elm SPA using Browser.element with port-based URL navigation." ]
        , p [] [ text "Try the Wizard to see multi-step navigation with browser back button support." ]
        ]


viewWizard : WizardStep -> WizardData -> Html Msg
viewWizard step data =
    case step of
        Step1 ->
            div []
                [ h1 [] [ text "Wizard - Step 1" ]
                , p [] [ text "What is your name?" ]
                , input [ type_ "text", value data.name, onInput SetName, placeholder "Enter your name" ] []
                , p [] [ button [ onClick (GoToWizardStep Step2) ] [ text "Next →" ] ]
                ]

        Step2 ->
            div []
                [ h1 [] [ text "Wizard - Step 2" ]
                , p [] [ text "Pick a color:" ]
                , label []
                    [ input [ type_ "radio", name "color", value "red", checked (data.color == "red"), onInput SetColor ] []
                    , text " Red"
                    ]
                , label []
                    [ input [ type_ "radio", name "color", value "green", checked (data.color == "green"), onInput SetColor ] []
                    , text " Green"
                    ]
                , label []
                    [ input [ type_ "radio", name "color", value "blue", checked (data.color == "blue"), onInput SetColor ] []
                    , text " Blue"
                    ]
                , p []
                    [ button [ onClick (GoToWizardStep Step1) ] [ text "← Back" ]
                    , text " | "
                    , button [ onClick (GoToWizardStep Step3) ] [ text "Next →" ]
                    ]
                ]

        Step3 ->
            div []
                [ h1 [] [ text "Wizard - Step 3" ]
                , p [] [ text "Summary:" ]
                , ul []
                    [ li [] [ text ("Name: " ++ data.name) ]
                    , li [] [ text ("Color: " ++ data.color) ]
                    ]
                , p []
                    [ button [ onClick (GoToWizardStep Step2) ] [ text "← Back" ]
                    , text " | "
                    , button [ onClick (GoToWizardStep Step1) ] [ text "Start Over" ]
                    ]
                ]


viewAbout : Int -> Html Msg
viewAbout counter =
    div []
        [ h1 [] [ text "About" ]
        , p [] [ text "This app demonstrates port-based URL navigation with Browser.element and the lydell/elm-app-url package." ]
        , p []
            [ text ("Counter: " ++ String.fromInt counter ++ " ")
            , button [ onClick IncrementCounter ] [ text "+1" ]
            ]
        , p [] [ text "When clicking on the above button, the URL updates via replaceState without triggering a page update." ]
        ]
