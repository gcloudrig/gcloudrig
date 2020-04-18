const {google} = require('googleapis')
const debug = require('debug')('lib:googleapi')
const inquirer = require('inquirer')

const cloudresourcemanager = google.cloudresourcemanager('v1')
const serviceusage = google.serviceusage('v1')
const cloudbilling = google.cloudbilling('v1')
const scopes = ['https://www.googleapis.com/auth/cloud-platform']


debug('init')

var _authClient;

/**
 * returns an auth client for google api usage, creating one if nessessary
 */
async function getAuthClient() {
  if (!_authClient) {
    try {

      // see if auth *just works* (e.g. running in a privileged environment)
      _authClient = await google.auth.getClient({ scopes: scopes })

    } catch (err) {
      
      // fall back to copy/paste oauth
      _authClient = new google.auth.OAuth2({
        clientId: '797884169954-8cuid8qiflhn2uum47c8qjnnau6tpnh6.apps.googleusercontent.com',
        redirectUri: 'urn:ietf:wg:oauth:2.0:oob'
      })
      const url = _authClient.generateAuthUrl({ access_type: 'online', scope: scopes });

      // fob 'em off to google
      var ui = new inquirer.ui.BottomBar();
      ui.updateBottomBar(`Visit the following URL to authorise gcloudrig and obtain an authorisation code:

        ${url}

      `)

      // wait for the auth code
      const answers = await inquirer.prompt({
        type: 'input',
        name: 'authorizationCode',
        message: `Visit  and paste the auth code here`
      })

      // set credentials
      const {tokens} = await _authClient.getToken(answers.authorizationCode)
      _authClient.setCredentials(tokens)

    }

    debug('auth.getClient')
  }

  return _authClient
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
