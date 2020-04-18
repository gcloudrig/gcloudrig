#!/usr/bin/env node
require('module-alias/register')
const debug = require('debug')('gcloudrig')
const express = require("express");
const path = require("path");
const { program } = require('commander');

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
  .action(async () => {
    const app = express();
    const port = process.env.PORT || "42500";

    app.set("views", path.join(__dirname, "app/views"));
    app.set("view engine", "pug");
    app.use(express.static(path.join(__dirname, "app/public")));

    app.get("/", (req, res) => {
      res.render("index", { title: "Home" });
    });

    app.listen(port, () => {
      console.log(`Listening to requests on http://localhost:${port}`);
    });
  })

// define setup
program
  .command('setup')
  .action(async () => {
    await require('@actions/setup').apply(null, arguments)
    debug('done')
  })

program.parse(process.argv)
debug(program.opts())