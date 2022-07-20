// solidity-coverage configuration file.
//
// https://www.npmjs.com/package/solidity-coverage

module.exports = {
  skipFiles: [
    'enums',
    'interfaces',
    'libraries'
  ],
  configureYulOptimizer: false, // causes stack depth failure
  measureStatementCoverage: false,
};
