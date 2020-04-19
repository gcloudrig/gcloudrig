const $ = require('jquery');
const EventEmitter = require('events');

const eventEmitter = new EventEmitter()

function gapiReady() {
  return new Promise((resolve, reject) => {
    function done() {
      resolve()
    }
    if (window.gapi) {
      done()
    } else {
      window.gapi_onload = done
    }
  })
};

function gapiLoad(libraries) {
  return new Promise((resolve, reject) => {
    gapi.load(libraries, resolve)
  })
}

exports.init = async function ready() {
  await gapiReady()
  await gapiLoad('client:auth2')
  await gapi.client.init({
    apiKey: "AIzaSyDqPub9jY4Nv0rXqKN_rNOk_YaLDUs6rTo",
    clientId: "797884169954-dc8j5v4r7mf37u75kk5lgo58elolhr91.apps.googleusercontent.com",
    scope: "https://www.googleapis.com/auth/cloud-platform",
    discoveryDocs: [
      "https://cloudresourcemanager.googleapis.com/$discovery/rest?version=v1",
      "https://servicemanagement.googleapis.com/$discovery/rest?version=v1"
    ]
  })

  eventEmitter.emit('isSignedIn', gapi.auth2.getAuthInstance().isSignedIn.get())

  gapi.auth2.getAuthInstance().isSignedIn.listen((isSignedIn) => {
    eventEmitter.emit('isSignedIn', isSignedIn)
  })
}

exports.signIn = function() {
  gapi.auth2.getAuthInstance().signIn({
    prompt: "select_account"
  })
}

exports.signOut = async function() {
  await gapi.auth2.getAuthInstance().signOut()
  gapi.auth2.getAuthInstance().disconnect()
}

exports.listProjects = async function() {
  let projects = []
  let response = {}
  do {
    response = await gapi.client.cloudresourcemanager.projects.list()
    projects = projects.concat(response.result.projects)
  } while (response.result.nextPageToken);
  return projects;
}

exports.listServices = async function(projectId) {
  let services = []
  let response = {}
  do {
    response = await gapi.client.servicemanagement.services.list({
      consumerId: `project:${projectId}`      
    })
    services = services.concat(response.result.services)
  } while (response.result.nextPageToken);
  return services;
}

exports.events = eventEmitter;


// gapi.client.cloudresourcemanager.projects.list()