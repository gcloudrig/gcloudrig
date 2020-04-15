# Changelog

[npm history][1]

[1]: https://www.npmjs.com/package/gce-images?activeTab=versions

### [2.1.4](https://www.github.com/googleapis/nodejs-gce-images/compare/v2.1.3...v2.1.4) (2020-01-06)


### Bug Fixes

* add repo metadata ([#183](https://www.github.com/googleapis/nodejs-gce-images/issues/183)) ([a85c7a8](https://www.github.com/googleapis/nodejs-gce-images/commit/a85c7a89b6dbfbfc432c4a298d7910add1dfa66d))
* **build:** run synthtool with new repo name ([#191](https://www.github.com/googleapis/nodejs-gce-images/issues/191)) ([a695c78](https://www.github.com/googleapis/nodejs-gce-images/commit/a695c7879329ebf4765c4b03e0bc4da3ea6a20df))
* **deps:** TypeScript 3.7.0 causes breaking change in typings ([#190](https://www.github.com/googleapis/nodejs-gce-images/issues/190)) ([4f15c1f](https://www.github.com/googleapis/nodejs-gce-images/commit/4f15c1f133346f20d388bf42728e2e91a8745831))

### [2.1.3](https://www.github.com/googleapis/gce-images/compare/v2.1.2...v2.1.3) (2019-09-06)


### Bug Fixes

* use `compute.googleapis.com` as base URI ([#168](https://www.github.com/googleapis/gce-images/issues/168)) ([98c45e5](https://www.github.com/googleapis/gce-images/commit/98c45e5))

### [2.1.2](https://www.github.com/googleapis/gce-images/compare/v2.1.1...v2.1.2) (2019-07-29)


### Bug Fixes

* **deps:** update dependency google-auth-library to v5 ([#161](https://www.github.com/googleapis/gce-images/issues/161)) ([21bc2ed](https://www.github.com/googleapis/gce-images/commit/21bc2ed))

### [2.1.1](https://www.github.com/googleapis/gce-images/compare/v2.1.0...v2.1.1) (2019-06-26)


### Bug Fixes

* **docs:** make anchors work in jsdoc ([#157](https://www.github.com/googleapis/gce-images/issues/157)) ([1312f48](https://www.github.com/googleapis/gce-images/commit/1312f48))

## [2.1.0](https://www.github.com/googleapis/gce-images/compare/v2.0.0...v2.1.0) (2019-06-24)


### Features

* support apiEndpoint override ([#155](https://www.github.com/googleapis/gce-images/issues/155)) ([bb4037f](https://www.github.com/googleapis/gce-images/commit/bb4037f))

## [2.0.0](https://www.github.com/googleapis/gce-images/compare/v1.1.0...v2.0.0) (2019-05-09)


### Bug Fixes

* **deps:** update dependency google-auth-library to v4 ([#143](https://www.github.com/googleapis/gce-images/issues/143)) ([e24ff51](https://www.github.com/googleapis/gce-images/commit/e24ff51))
* remove unused pify dependency ([#138](https://www.github.com/googleapis/gce-images/issues/138)) ([e189506](https://www.github.com/googleapis/gce-images/commit/e189506))
* **deps:** update dependency arrify to v2 ([#130](https://www.github.com/googleapis/gce-images/issues/130)) ([0d6cec3](https://www.github.com/googleapis/gce-images/commit/0d6cec3))


### Build System

* upgrade engines field to >=8.10.0 ([#135](https://www.github.com/googleapis/gce-images/issues/135)) ([5bace32](https://www.github.com/googleapis/gce-images/commit/5bace32))


### BREAKING CHANGES

* upgrade engines field to >=8.10.0 (#135)

## v1.1.0

02-05-2019 15:28 PST

### New Features
- feat: introduce async methods ([#100](https://github.com/googleapis/gce-images/pull/100))

### Dependencies
- fix(deps): update dependency google-auth-library to v3 ([#103](https://github.com/googleapis/gce-images/pull/103))

### Documentation
- docs: add lint/fix example to contributing guide ([#107](https://github.com/googleapis/gce-images/pull/107))
- docs: add samples and sample tests ([#88](https://github.com/googleapis/gce-images/pull/88))

## v1.0.0

Welcome to 1.0! The big feature in this release is the availability of TypeScript types out of the box.  To that end, there is a breaking change:

**BREAKING CHANGE**: The `GCEImages` object must now be instantiated.

#### Old Code
```js
const images = require('gce-images')();
```

#### New Code
```js
const {GCEImages} = require('gce-images');
const images = new GCEImages();
```
======

### New Features
- feat: convert to TypeScript ([#21](https://github.com/GoogleCloudPlatform/gce-images/pull/21))
- fix: improve TypeScript types ([#72](https://github.com/GoogleCloudPlatform/gce-images/pull/72))

### Dependencies
- fix(deps): update dependency google-auth-library to v2 ([#33](https://github.com/GoogleCloudPlatform/gce-images/pull/33))
- chore: drop dependency on got and google-auto-auth ([#23](https://github.com/GoogleCloudPlatform/gce-images/pull/23))

### Documentation

### Internal / Testing Changes
- chore: update CircleCI config ([#71](https://github.com/GoogleCloudPlatform/gce-images/pull/71))
- chore: include build in eslintignore ([#68](https://github.com/GoogleCloudPlatform/gce-images/pull/68))
- chore(deps): update dependency eslint-plugin-node to v8 ([#64](https://github.com/GoogleCloudPlatform/gce-images/pull/64))
- chore: update issue templates ([#63](https://github.com/GoogleCloudPlatform/gce-images/pull/63))
- chore: remove old issue template ([#61](https://github.com/GoogleCloudPlatform/gce-images/pull/61))
- build: run tests on node11 ([#60](https://github.com/GoogleCloudPlatform/gce-images/pull/60))
- chores(build): run codecov on continuous builds ([#55](https://github.com/GoogleCloudPlatform/gce-images/pull/55))
- chore(deps): update dependency typescript to ~3.1.0 ([#57](https://github.com/GoogleCloudPlatform/gce-images/pull/57))
- chore(deps): update dependency eslint-plugin-prettier to v3 ([#58](https://github.com/GoogleCloudPlatform/gce-images/pull/58))
- chores(build): do not collect sponge.xml from windows builds ([#56](https://github.com/GoogleCloudPlatform/gce-images/pull/56))
- chore: update new issue template ([#54](https://github.com/GoogleCloudPlatform/gce-images/pull/54))
- chore: update build config ([#51](https://github.com/GoogleCloudPlatform/gce-images/pull/51))
- Update kokoro config ([#48](https://github.com/GoogleCloudPlatform/gce-images/pull/48))
- Re-generate library using /synth.py ([#45](https://github.com/GoogleCloudPlatform/gce-images/pull/45))
- Update kokoro config ([#44](https://github.com/GoogleCloudPlatform/gce-images/pull/44))
- test: remove appveyor config ([#43](https://github.com/GoogleCloudPlatform/gce-images/pull/43))
- Update CI config ([#42](https://github.com/GoogleCloudPlatform/gce-images/pull/42))
- Enable prefer-const in the eslint config ([#40](https://github.com/GoogleCloudPlatform/gce-images/pull/40))
- Enable no-var in eslint ([#39](https://github.com/GoogleCloudPlatform/gce-images/pull/39))
- Move to the new github org ([#38](https://github.com/GoogleCloudPlatform/gce-images/pull/38))
- Update CI config ([#37](https://github.com/GoogleCloudPlatform/gce-images/pull/37))
- Retry npm install in CI ([#35](https://github.com/GoogleCloudPlatform/gce-images/pull/35))
- Update CI config ([#32](https://github.com/GoogleCloudPlatform/gce-images/pull/32))
- chore(deps): update dependency nyc to v13 ([#31](https://github.com/GoogleCloudPlatform/gce-images/pull/31))
- remove the docs command
- Update the CI config ([#30](https://github.com/GoogleCloudPlatform/gce-images/pull/30))
- test: add a key for CircleCI ([#29](https://github.com/GoogleCloudPlatform/gce-images/pull/29))
- Re-generate library using /synth.py ([#28](https://github.com/GoogleCloudPlatform/gce-images/pull/28))
- chore(deps): update dependency eslint-config-prettier to v3 ([#27](https://github.com/GoogleCloudPlatform/gce-images/pull/27))
- chore: ignore package-lock.json ([#26](https://github.com/GoogleCloudPlatform/gce-images/pull/26))
- chore(deps): lock file maintenance ([#25](https://github.com/GoogleCloudPlatform/gce-images/pull/25))
- chore: update renovate config ([#20](https://github.com/GoogleCloudPlatform/gce-images/pull/20))
- chore: upgrade to es6 ([#24](https://github.com/GoogleCloudPlatform/gce-images/pull/24))
- chore(deps): update dependency mocha to v5 ([#17](https://github.com/GoogleCloudPlatform/gce-images/pull/17))
- fix(deps): update dependency async to v2 ([#18](https://github.com/GoogleCloudPlatform/gce-images/pull/18))
- fix(deps): update dependency google-auto-auth to ^0.10.0 ([#16](https://github.com/GoogleCloudPlatform/gce-images/pull/16))
- Check in synth.py and conform to google node repo standards ([#14](https://github.com/GoogleCloudPlatform/gce-images/pull/14))
- Update renovate.json
- Add renovate.json
- chore: fix the directory structure ([#12](https://github.com/GoogleCloudPlatform/gce-images/pull/12))
- chore: make it OSPO compliant ([#10](https://github.com/GoogleCloudPlatform/gce-images/pull/10))
