const { promisify } = require("util");
const fs = require("fs");
const mkdirp = require("mkdirp");
const zlib = require("zlib");
const request = require("request");
const AWS = require("aws-sdk");

const file_exists = async (path) => {
  // If the file doesn't exist, fs.access will throw.
  try {
    await promisify(fs.access)(path, fs.constants.R_OK);
    return true;
  } catch (err) {
    return false;
  }
}

const memoize_on_disk = async (path, fn) => {
  // FIXME technically needs in-process de-duping to make sure there aren't 2 competitors for the
  // same file, or it's technically a race condition.

  if (await file_exists(path)) {
    return await promisify(fs.readFile)(path, 'utf-8');

  } else {
    const results = await fn();
    await promisify(fs.writeFile)(path, results, 'utf-8');
    return results;
  }
}

/******/

const load_compiler_by_hash = exports.load_compiler_by_hash = async (build_hash, options = {}) => {
  // try to load the code from a cache on disk
  // FIXME should have an option to not memoize

  await promisify(mkdirp)('./compiler-blobs');

  const bundle_code = await memoize_on_disk(`compiler-blobs/${build_hash}.js.gz`, async () => {

    if (options.silent === false) {
      console.log("Compiler bundle not cached yet; downloading it from s3...")
    }

    // download the bundle from S3
    const S3 = new AWS.S3({
      accessKeyId: process.env['AWS_ACCESS_KEY_ID'],
      secretAccessKey: process.env['AWS_SECRET_ACCESS_KEY'],
      region: "us-east-1",
      params: { Bucket: "commit-blobs" }
    });
    const bundle_gz_data = await S3.getObject({Key: `${build_hash}.js.gz`}).promise();
    const bundle_data = await promisify(zlib.unzip)(bundle_gz_data.Body);
    return bundle_data.toString();
  });

  // turn the code into a function
  const compiler = eval(bundle_code);

  return compiler;
};

const get_deployed_version_hash = exports.get_deployed_version_hash = async () => {
  // FIXME: const version_txt = await (await fetch("https://pagedraw.firebaseapp.com/version.txt")).text();
  const version_txt = await new Promise((resolve, reject) => {
    request("https://static-pagedraw.surge.sh/version.txt", (err, _, body) => {
      if (err) return reject(err);
      return resolve(body);
    });
  });

  return version_txt.trim();
}

const load_currently_deployed_compiler = exports.load_currently_deployed_compiler = async (options = {}) => {
  const deployed_version = await get_deployed_version_hash();
  return await load_compiler_by_hash(deployed_version, options);
}
