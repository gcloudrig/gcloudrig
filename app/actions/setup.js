const _ = require('lodash')
const Compute = require('@google-cloud/compute')
const { listProjects, listEnabledServiceApis, getBillingInfo, enableServiceApi } = require('@lib/googleapi')
const inquirer = require('inquirer')
const debug = require('debug')('actions:setup')

let options = {};

async function selectGceProject() {
  var projects = await listProjects()
  var answers = await inquirer.prompt([{
    type: 'list',
    name: 'project',
    message: 'Choose a project',
    choices: _.chain(projects)
      .map(project => ({
        value: project,
        name: `${project.name} [${project.projectId}]`,
        short: `${project.projectId}`
      }))
      .value()
  }])
  return answers.project
}

async function verifyBillingEnabled() {
  const billingInfo = await getBillingInfo(options.project.projectId)
  if (billingInfo.billingEnabled == true) {
    debug(`Project "${options.project.name}" is using billing account ${billingInfo.billingAccountName}`)
  } else {
    console.error(`
==============================
Oops! The project "${options.project.name} [${options.project.projectId}]" isn't linked to a billing account.

Organise billing for this project using the following link, then rerun "gcloudrig setup" again and choose the same project.
https://console.cloud.google.com/billing?project=${options.project.projectId}
==============================
    `)
  }
  debug(billingInfo)
  return billingInfo.billingEnabled
}

async function enableRequiredServiceApis() {
  const enabledServices = _.map(await listEnabledServiceApis(options.project.projectId), 'config.name')
  const requiredServices = [
    'compute.googleapis.com',
    'logging.googleapis.com'
  ]
  const missingServices = _.without(requiredServices, ...enabledServices)
  debug('missing services', missingServices)

  var questions = _.map(missingServices, service => ({
    type: 'confirm',
    name: `${service.replace(/\./g, '#')}`,
    message: `The "${service}" service API is not enabled. Enable it now?`
  }))
  var answers = _.mapKeys(await inquirer.prompt(questions), (confirmation, service) => service.replace(/#/g, '.'))

  // enable any apis they asked for, ignore the others
  Promise.all(_.map(answers, async (confirmation, service) => {
    if (confirmation) {
      debug(`enabling api ${service}`)
      return enableServiceApi(options.project.projectId, service)
    }
  }))
}



// BUSINESS END
module.exports = async (opts) => {  
  options = opts;

  // make 'em pick or create a project
  if (!options.project) {
    options.project = await selectGceProject();
  }

  // bail if billing isn't enabled
  if (!await verifyBillingEnabled()) {
    return
  }

  await enableRequiredServiceApis()
}