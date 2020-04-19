// // const _ = require('lodash')
// const { start } = require('./googleapi')
// window.gapi_onload = start
const $ = require('jquery');
const googleapi = require('./googleapi')

const $signin = $('#google-signin')
const $signout = $('#google-signout')
const $projects = $('select#gcp-projects')
const $services = $('ul#gcp-services')

window.$ = window.jQuery = $;

async function updateServicesList() {
  $services.empty();
  const currentProjectId = $projects.val();
  const services = await googleapi.listServices(currentProjectId);
  services.forEach(service => {
    const $li = $('<li>')
    $li.text(service.serviceName)
    $services.append($li)
  })
}

async function updateProjectsList () {
  $projects.empty()
  const projects = await googleapi.listProjects();
  projects.forEach(project => {
    const $option = $('<option>')
    $option.text(`${project.name} [${project.projectId}]`)
    $option.data(project)
    $option.val(project.projectId)
    $projects.append($option)
  });
  $projects.removeAttr('disabled').trigger('change')
}

function main() {
  googleapi.events.on('isSignedIn', function (isSignedIn) {
    if (isSignedIn) {
      $signin.attr('disabled', true).hide()
      $signout.removeAttr('disabled').show()
    } else {
      $signin.removeAttr('disabled').show()
      $signout.attr('disabled', true).hide()
    }
  })

  // bind elems
  $signin.on('click', googleapi.signIn)
  $signout.on('click', googleapi.signOut)
  $projects.on('change', updateServicesList)

  // initialise (async)
  googleapi.init()

  // render projects on every signin
  googleapi.events.on('isSignedIn', updateProjectsList)

}

main()