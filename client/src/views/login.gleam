import gleam/http as ghttp
import gleam/option.{type Option, None, Some}

import lustre/attribute as a
import lustre/effect.{type Effect}
import lustre/element as e
import lustre/element/html as eh
import lustre/event as ev
import lustre_http as http

import model.{
  type LoginModel, type Model, type Msg, LoadState, Loading, Login, LoginModel,
  LoginResult, LoginWithEnter, NoOp, PasswordChanged, TryLogin, UsernameChanged,
}
import shared_model.{Credentials} as sm
import util/effect as ef
import util/local_storage as ls
import util/prim
import util/site

fn get_model(model: Model) -> Option(LoginModel) {
  case model {
    Login(lm) -> Some(lm)
    _ -> None
  }
}

/// Update logic for the login view.
pub fn update(model: Model, msg: Msg) -> Option(#(Model, Effect(Msg))) {
  use LoginModel(creds, failed) <- option.then(get_model(model))

  case msg {
    UsernameChanged(username) ->
      ef.just(Login(LoginModel(Credentials(..creds, username:), failed)))
    PasswordChanged(password) ->
      ef.just(Login(LoginModel(Credentials(..creds, password:), failed)))
    LoginWithEnter(key) -> {
      case key {
        "Enter" -> #(model, ef.dispatch(TryLogin))
        _ -> ef.just(model)
      }
    }
    TryLogin -> {
      use <- ef.check(model, creds.username != "" && creds.password != "")
      let base_url = site.base_url()
      #(
        Login(LoginModel(creds, failed: False)),
        http.post(
          base_url <> "/api/user/login",
          sm.encode_credentials(creds),
          http.expect_json(sm.session_info_decoder(), LoginResult),
        ),
      )
    }
    LoginResult(result) -> {
      use session <- prim.try(
        #(Login(LoginModel(creds, True)), ef.focus("username-input", NoOp)),
        result,
      )
      ls.set("session", session, sm.encode_session_info)
      let request =
        site.request_with_authorization(
          site.base_url() <> "/api/simplestate/pi_history",
          ghttp.Get,
          session.session_id,
        )
      #(Loading(session), http.send(request, http.expect_text(LoadState)))
    }
    _ -> ef.just(model)
  }
  |> Some
}

/// View logic for the login view.
pub fn view(model: Model) {
  use LoginModel(creds, failed) <- option.then(get_model(model))

  let error_popup = case failed {
    True ->
      eh.div([a.class("row m-4 alert alert-danger")], [e.text("Login failed.")])
    False -> e.none()
  }

  eh.div([a.class("col container p-4")], [
    eh.div([a.class("row m-4 justify-content-center")], [
      eh.h3([a.class("col-2")], [e.text("Login")]),
    ]),
    error_popup,
    eh.div([a.class("row m-4")], [
      eh.p([a.class("col-4")], [e.text("Username:")]),
      eh.input([
        a.class("col-8"),
        a.id("username-input"),
        a.value(creds.username),
        a.autofocus(True),
        ev.on_input(model.UsernameChanged),
        ev.on_keydown(model.LoginWithEnter),
      ]),
    ]),
    eh.div([a.class("row m-4")], [
      eh.p([a.class("col-4")], [e.text("Password:")]),
      eh.input([
        a.class("col-8"),
        a.type_("password"),
        a.value(creds.password),
        ev.on_input(model.PasswordChanged),
        ev.on_keydown(model.LoginWithEnter),
      ]),
    ]),
    eh.div([a.class("row m-4")], [
      eh.button([a.class("btn btn-primary"), ev.on_click(model.TryLogin)], [
        e.text("Login"),
      ]),
    ]),
  ])
  |> Some
}
