// Run after Expo prebuild. Never persist passwords in generated Gradle files.
const fs = require('node:fs');
const path = require('node:path');

function configureRelease(source) {
  const marker = 'signingConfig signingConfigs.debug';
  if (source.split(marker).length !== 3) {
    throw new Error('Unexpected Expo signing template; refusing to publish a debug-signed release');
  }
  const signing = `signingConfigs {
        release {
            storeFile file(System.getenv("KEYSTORE_PATH"))
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEY_PASSWORD")
        }`;
  if (!source.includes('signingConfigs {')) throw new Error('Missing signing configuration');
  source = source.replace('signingConfigs {', signing);
  const index = source.lastIndexOf(marker);
  return source.slice(0, index) + 'signingConfig signingConfigs.release' + source.slice(index + marker.length);
}

if (require.main === module) {
  for (const name of ['KEYSTORE_PATH', 'KEYSTORE_PASSWORD', 'KEY_ALIAS', 'KEY_PASSWORD']) {
    if (!process.env[name]) throw new Error(`Missing ${name}: release signing is required`);
  }
  if (!path.isAbsolute(process.env.KEYSTORE_PATH) || !fs.existsSync(process.env.KEYSTORE_PATH)) {
    throw new Error('KEYSTORE_PATH must point to an existing absolute keystore path');
  }
  const file = path.resolve('android/app/build.gradle');
  fs.writeFileSync(file, configureRelease(fs.readFileSync(file, 'utf8')));
}
module.exports = { configureRelease };
