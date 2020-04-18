const $ = require('jquery');

function gapiLoad(libraries) {
  return new Promise((resolve, reject) => {
    gapi.load(libraries, resolve, reject)
  })
}


/**
* called once gapi global is ready.
* @returns {Promise}
*/
exports.gapiReady = async function ready() {
  await gapiLoad('client:auth2')
  await gapi.client.init({
    apiKey: "AIzaSyDqPub9jY4Nv0rXqKN_rNOk_YaLDUs6rTo",
    clientId: "797884169954-dc8j5v4r7mf37u75kk5lgo58elolhr91.apps.googleusercontent.com",
    scope: "https://www.googleapis.com/auth/cloud-platform",
    discoveryDocs: ["https://cloudresourcemanager.googleapis.com/$discovery/rest?version=v1"]
  })
  .isSignedIn.listen(onSignedIn)
}

exports.authInstance = gapi.auth2.getAuthInstance

exports.signin = function(){
  return gapi.auth2.getAuthInstance().signOut()
}

exports.signout = function(){
  gapi.auth2.getAuthInstance().signOut()
}

exports.onSignin = 



exports.promptGoogleAuth = async function promptGoogleAuth(){

  // listen for sign-in state changes.




  // Handle the initial sign-in state.
  updateSigninStatus(gapi.auth2.getAuthInstance().isSignedIn.get());    
}

// gapi.client.cloudresourcemanager.projects.list()