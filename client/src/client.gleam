import gleam/http as ghttp
import gleam/order.{Lt}
import views/loaded

import birl
import lustre
import lustre/element as e
import lustre_http as http

import model.{
  type Model, type Msg, Loading, Login, LoginModel, ValidateSessionCheck,
}
import shared_model.{type Credentials, Credentials}
import util/effect as ef
import util/local_storage
import util/prim
import util/site
import views/err
import views/loading
import views/login
import views/settings

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

fn init(_) {
  let now = birl.now()
  let login_state = Login(LoginModel(Credentials("", ""), False))

  // Load session from local storage.
  use session <- ef.then(
    login_state,
    local_storage.get("session", shared_model.session_info_decoder()),
  )
  // Check session validity.
  use <- ef.check(login_state, birl.compare(now, session.expires_at) == Lt)

  // Try to see if session is still valid.
  let request =
    site.request_with_authorization(
      site.base_url() <> "/api/user/check_session",
      ghttp.Get,
      session.session_id,
    )
  #(
    Loading(session),
    http.send(request, http.expect_anything(ValidateSessionCheck)),
  )
}

fn update(model: Model, msg: Msg) {
  use <- prim.visit(login.update(model, msg))
  use <- prim.visit(err.update(model, msg))
  use <- prim.visit(loading.update(model, msg))
  use <- prim.visit(loaded.update(model, msg))
  use <- prim.visit(settings.update(model, msg))

  ef.just(model)
}

pub fn view(model: Model) {
  use <- prim.visit(login.view(model))
  use <- prim.visit(err.view(model))
  use <- prim.visit(loading.view(model))
  use <- prim.visit(loaded.view(model))
  use <- prim.visit(settings.view(model))

  e.none()
}
