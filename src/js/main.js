// // const _ = require('lodash')
// const { start } = require('./googleapi')
// window.gapi_onload = start
const $ = require('jquery');

const { gapiReady, signin, signout, authInstance } = require('./googleapi')

window.gapiReady = gapiReady


function updateSigninStatus() {
  if (isSignedIn) {
  } else {
  }
}


async function main() {
  const $btn_signin = $('#google-signin');
  const $btn_signout = $('#google-signout');

  $btn_signin.click(signin).hide();
  $btn_signout.click(signout).hide();

  await gapiReady()

  authInstance().isSignedIn.listen(() => {
    if (isSignedIn) {
      $btn_signin.hide()
      $btn_signout.show()
    } else {
      $btn_signin.show()
      $btn_signout.hide()
    }
  })

}

$(document).ready(main);