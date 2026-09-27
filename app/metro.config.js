const { getDefaultConfig } = require("expo/metro-config");

const config = getDefaultConfig(__dirname);

// react-native-web support for the Freebuff web preview.
config.resolver.alias = {
  "react-native$": "react-native-web",
};

module.exports = config;
