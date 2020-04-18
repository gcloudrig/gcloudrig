#!/usr/bin/env node
require('module-alias/register')
const debug = require('debug')('gcloudrig')
const { program } = require('commander')
const app = require('./app')

// init
debug('init');
program.version('0.0.1');

// globals
program
  .name('gcloudrig')
  .option('--project <project>', 'The Google Cloud Platform project name to use.  (See https://cloud.google.com/sdk/gcloud/reference#--project)')

// serve
program
  .command('serve')
  .action(app.serve)

// // define setup
// program
//   .command('setup')
//   .action(async function () {
//     await setup.apply(null, arguments)
//     debug('done')
//   })

program.parse(process.argv)
debug(program.opts())