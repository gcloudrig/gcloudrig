'use strict';
const browserify = require('browserify');
const gulp = require('gulp');
const source = require('vinyl-source-stream');
const buffer = require('vinyl-buffer');
const terser = require('gulp-terser');
const sourcemaps = require('gulp-sourcemaps');
const log = require('gulplog');
const gpug = require('gulp-pug');
const ghPages = require('gulp-gh-pages');
const watchify = require('watchify');
const _ = require('lodash');
const clean = require('gulp-clean');
const through = require('through2');
const browsersync = require('browser-sync');

/* globals */
const paths = {
  dist: "./dist",
  src: "./src"
}

// const _wb = watchify(browserify(_.assign({}, watchify.args, {
//   entries: [`${paths.src}/js/main.js`],
//   debug: true,
// })));

const _wb = browserify({
  entries: [`${paths.src}/js/main.js`],
  debug: true,
});

const _bs = browsersync.create()

const _tc = {}

/* private tasks */
function cleanup() {
  return gulp.src(`${paths.dist}`, {read: false, allowEmpty: true} )
    .pipe(clean())
}

function copy() {
  return gulp.src([
    `${paths.src}/**`,
    `!${paths.src}/**/*.js`,
    `!${paths.src}/**/*.pug`
  ], {since: gulp.lastRun(pug)})
  .pipe(gulp.dest([`${paths.dist}/`], { overwrite: true }))
  .pipe(_bs.stream());
}

function js() {
  return _wb.bundle()
    .on('error', log.error)
    .pipe(source(`main.js`))
    .pipe(buffer())
    .pipe(sourcemaps.init({loadMaps: true}))
    .pipe(terser({
      compress: false,
      mangle: false,
      output: {
        beautify: true
      }
    }))
    .pipe(sourcemaps.write('./'))
    .pipe(gulp.dest(`${paths.dist}/js`))
    // HACK - we want watchify because it'll help browserify cache between runs, but we also want the convenience of a native `gulp watch` task.
    // (credit: https://gist.github.com/MadLittleMods/133ac3a8fdeebf6c642c/b092311824ba260cc007dfd88316be7f737cd650#file-watchify-browserify-gulp-recipe-js-L41)
    .pipe(through.obj((vinylFile, encoding, callback) => callback(null, vinylFile), (cb) => {
      // _wb.close();
      _bs.reload();
      cb();
    }))
}

function pug() {
  return gulp.src([`${paths.src}/**/*.pug`])
    .pipe(gpug())
    .pipe(gulp.dest(`${paths.dist}`, { overwrite: true }))
    .pipe(_bs.stream());
}

function deploy() {
  return gulp.src('./dist/**').pipe(ghPages())
}

function watch() {
  return new Promise((resolve, reject) => {
    const watcher = gulp.watch([`${paths.src}/**`], exports.build)
    watcher.on('change', function(path, stats) {
      log.info(`File ${path} was changed`);
    });
    watcher.on('add', function(path, stats) {
      log.info(`File ${path} was added`);
    });
    watcher.on('unlink', function(path, stats) {
      log.info(`File ${path} was removed`);
    });
    process.once('SIGINT', () => {
      watcher.close(); resolve()
    })
  })
}

function serve() {
  return new Promise((resolve, reject) => {
    process.once('SIGINT', () => {
      _bs.exit(); resolve()
    })
    _bs.init({
      server: {
        baseDir: `${paths.dist}`
      }
    })
  })
}

/* public tasks */
exports.build = gulp.parallel(copy, js, pug)
exports.dist = gulp.series(cleanup, exports.build)
exports.develop = gulp.series(cleanup, exports.build, gulp.parallel(watch, serve))