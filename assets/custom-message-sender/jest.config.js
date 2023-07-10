/** @type {import('ts-jest/dist/types').JestConfigWithTsJest} */
module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  verbose: true,
  resetMocks: true,
  testPathIgnorePatterns: [
    "coverage",
    "dist",
    "node_modules"
  ],
  transform: {
    '^.+\\.ts?$': ['ts-jest', { tsconfig: 'tsconfig.jest.json' }]
  }
};

process.env = Object.assign(process.env, {
  LOG_LEVEL: 'silent',
});
