# gce-images
> Get a list of globally available Google Compute Engine images

```sh
$ npm install gce-images
```
```js
const {GCEImages} = require('gce-images');

// Create a client (see below for more about authorization)
const images = new GCEImages();

images.getAll((err, images) => {
/*
  images = {
    centos: {
      [
        {
          kind: 'compute#image',
          selfLink: 'https://compute.googleapis.com/compute/v1/projects/centos-cloud/global/images/centos-6-v20150710',
          id: '2223645373384728207',
          creationTimestamp: '2015-07-13T13:32:32.483-07:00',
          name: 'centos-6-v20150710',
          description: 'CentOS, CentOS, 6.6, x86_64 built on 2015-07-10',
          sourceType: 'RAW',
          rawDisk: [Object],
          status: 'READY',
          archiveSizeBytes: '1133229966',
          diskSizeGb: '10'
        },
        // ...
    },
    coreos: {
      // ...
    },
    debian: {
      // ...
    },
    redhat: {
      // ...
    },
    opensuse: {
      // ...
    },
    suse: {
      // ...
    },
    ubuntu: {
      // ...
    }
  };
*/
});
```

#### Get the latest image for a specific OS

```js
images.getLatest('ubuntu', (err, image) => {
/*
  image = {
    kind: 'compute#image',
    selfLink: 'https://compute.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1504-vivid-v20150616a',
    id: '6610082300127119636',
    creationTimestamp: '2015-06-17T02:03:55.825-07:00',
    name: 'ubuntu-1504-vivid-v20150616a',
    description: 'Canonical, Ubuntu, 15.04, amd64 vivid image built on 2015-06-16',
    sourceType: 'RAW',
    rawDisk: { source: '', containerType: 'TAR' },
    status: 'READY',
    archiveSizeBytes: '806558757',
    diskSizeGb: '10',
    licenses: [
      'https://compute.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/licenses/ubuntu-1504-vivid'
    ]
  }
*/
});
```

#### Get the latest image for a specific OS from your project

```js
images.getLatest('your-project-id-or-name/ubuntu', (err, image) => {
/*
  image = {
    kind: 'compute#image',
    selfLink: 'https://compute.googleapis.com/compute/v1/projects/your-project-id-or-name/global/images/ubuntu-1504-vivid-v20150616a',
    id: '6610082300127119636',
    creationTimestamp: '2015-06-17T02:03:55.825-07:00',
    name: 'ubuntu-1504-vivid-v20150616a',
    description: 'Canonical, Ubuntu, 15.04, amd64 vivid image built on 2015-06-16',
    sourceType: 'RAW',
    rawDisk: { source: '', containerType: 'TAR' },
    status: 'READY',
    archiveSizeBytes: '806558757',
    diskSizeGb: '10',
    licenses: [
      'https://compute.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/licenses/ubuntu-1504-vivid'
    ]
  }
*/
});
```

#### Get the latest image for a specific version of an OS

```js
images.getLatest('ubuntu-1404', (err, image) => {
/*
  image = {
    kind: 'compute#image',
    selfLink: 'https://compute.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images/ubuntu-1410-utopic-v20150625',
    id: '7075003915689987469',
    creationTimestamp: '2015-07-09T10:46:10.424-07:00',
    name: 'ubuntu-1410-utopic-v20150625',
    description: 'Canonical, Ubuntu, 14.10, amd64 utopic image built on 2015-06-25',
    sourceType: 'RAW',
    rawDisk: { source: '', containerType: 'TAR' },
    status: 'READY',
    archiveSizeBytes: '752874399',
    diskSizeGb: '10',
    licenses: [
      'https://compute.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/licenses/ubuntu-1410-utopic'
    ]
  }
*/
});
```

#### Get a map of OS names to their project's api URL

```js
images.OS_URLS; // also available on require('gce-images').OS_URLS;
/*
  {
    centos: 'https://compute.googleapis.com/compute/v1/projects/centos-cloud/global/images',
    'container-vm': 'https://compute.googleapis.com/compute/v1/projects/cos-cloud/global/images',
    coreos: 'https://compute.googleapis.com/compute/v1/projects/coreos-cloud/global/images',
    debian: 'https://compute.googleapis.com/compute/v1/projects/debian-cloud/global/images',
    redhat: 'https://compute.googleapis.com/compute/v1/projects/rhel-cloud/global/images',
    opensuse: 'https://compute.googleapis.com/compute/v1/projects/opensuse-cloud/global/images',
    suse: 'https://compute.googleapis.com/compute/v1/projects/suse-cloud/global/images',
    ubuntu: 'https://compute.googleapis.com/compute/v1/projects/ubuntu-os-cloud/global/images',
    windows: 'https://compute.googleapis.com/compute/v1/projects/windows-cloud/global/images'
  }
*/
```

#### Authorization

This module uses [google-auth-library](https://github.com/googleapis/google-auth-library-nodejs) to get the required access token. If you don't meet the **[requirements for automatic authentication](https://github.com/stephenplusplus/google-auto-auth#automatic-if)**, you will need to provide the same configuration object detailed in that readme.

```js
const {GCEImages} = require('gce-images');
const images = new GCEImages({ keyFile: '/Users/stephen/dev/key.json' });

images.getAll((err, images) => {});
images.getLatest('ubuntu', (err, image) => {});
```

<a name="os-names"></a>
#### Accepted OS names

- `centos` (also `centos-cloud`)
- `container-vm` (also `google-containers`)
- `coreos` (also `coreos-cloud`)
- `debian` (also `debian-cloud`)
- `redhat` (also `rhel`, `rhel-cloud`)
- `opensuse` (also `opensuse-cloud`)
- `suse` (also `suse-cloud`)
- `ubuntu` (also `ubuntu-cloud`, `ubuntu-os-cloud`)
- `windows` (also `windows-cloud`)

All accepted names may be suffixed with a version, e.g. `ubuntu-1404`.

### API

#### {GCEImages} = require('gce-images')

##### gceImages.OS_URLS

- Type: `Object`

A map of OS names to their Google APIs public image URL.

#### images = gceImages([authConfig])

##### authConfig

- Type: `Object`

See the above section on Authorization. This object is only necessary if automatic authentication is not available in your environment. See the [google-auto-auth](https://github.com/stephenplusplus/google-auto-auth#authconfig) documentation for the accepted properties.

###### authConfig.authClient

- Type: [`GoogleAuthConfig`](http://gitnpm.com/google-auth-library)
- *Optional*

If you want to re-use an auth client from [google-auto-auth](http://gitnpm.com/google-auto-auth), pass an instance here.

#### images.getAll([options], callback)
#### images.getLatest([options], callback)

##### options

- Optional
- Type: `String` or `Object`

If a string, it is expanded to: `options = { osNames: [**string input**] }`.

If not provided, the default `options` detailed below are used.

###### options.osNames

- Type: `String[]`
- Default: [All](#os-names)

All operating systems you wish to receive image metadata for. See [Accepted OS names](#os-names).

###### options.deprecated

- Type: `Boolean`
- Default: `false`

Include deprecated image metadata in results.

##### callback(err, images)

###### callback.err

- Type: `Error`

An error that occurred during an API request or if no results match the provided OS name or version.

###### callback.images

- Type: `Object` or `Array`

With `getAll`:

If only a single OS is being looked up, you will receive an array of all image metadata objects for that OS.

If multiple OS names were given, you will receive an object keyed by the [OS name](#os-names). Each key will reference an array of metadata objects for that OS.

With `getLatest`:

If only a single OS is being looked up, you will receive its metadata object back.

If multiple OS names were given, you will receive an object keyed by the [OS name](#os-names). Each key will reference a metadata object.
