// Keep native identity stable across the Flutter → React Native upgrade.
module.exports = ({ config }) => {
  const raw = process.env.ANDROID_VERSION_CODE;
  const versionCode = raw ? Number(raw) : 1;
  if (!Number.isSafeInteger(versionCode) || versionCode < 1 || versionCode > 2100000000) {
    throw new Error('ANDROID_VERSION_CODE must be a positive Android version code');
  }
  return {
    ...config,
    version: process.env.APP_VERSION || config.version,
    android: { ...config.android, versionCode },
  };
};
