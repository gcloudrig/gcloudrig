const {google} = require('googleapis')
const debug = require('debug')('lib:googleapi')

const cloudresourcemanager = google.cloudresourcemanager('v1')
const serviceusage = google.serviceusage('v1')
const cloudbilling = google.cloudbilling('v1')

var authClient;

debug('init')

async function getAuthClient() {
  if (!authClient) {
    authClient = await google.auth.getClient({
      scopes: [
        'https://www.googleapis.com/auth/cloud-platform',
        'https://www.googleapis.com/auth/cloud-platform.read-only'
      ],
    })
    debug('auth.getClient')
  }
  return authClient
}

exports.listProjects = async () => {
  const result = await cloudresourcemanager.projects.list({
    auth: await getAuthClient()
  })
  debug('cloudresourcemanager.projects.list')
  return result.data.projects;
}

exports.listEnabledServiceApis = async (projectId) => {
  const parent = `projects/${projectId}`
  const result = await serviceusage.services.list({
    parent: parent,
    auth: await getAuthClient(),
    filter: 'state:ENABLED'
  })
  debug('serviceusage.services.list', parent)
  return result.data.services;
}

exports.getBillingInfo = async (projectId) => {
  const name = `projects/${projectId}`
  const result = await cloudbilling.projects.getBillingInfo({
    name: name,
    auth: await getAuthClient(),
  })
  debug('cloudbilling.projects.getBillingInfo', name)
  return result.data;
}

exports.enableServiceApi = async (projectId, service) => {
  const name = `projects/${projectId}/services/${service}`
  const result = await serviceusage.services.enable({
    name: name,
    auth: await getAuthClient(),
  })
  debug('serviceusage.services.enable', name)
  return result.data;
}
