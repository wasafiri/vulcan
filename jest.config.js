module.exports = {
  testEnvironment: 'jsdom',
  roots: ['test/javascript'],
  moduleDirectories: ['node_modules', 'app/javascript'],
  moduleNameMapper: {
    '^controllers/(.*)$': '<rootDir>/app/javascript/controllers/$1',
    '^@rails/request\\.js$': '<rootDir>/test/javascript/mocks/rails_request.js'
  },
  setupFilesAfterEnv: ['<rootDir>/test/javascript/setup.js'],
  testPathIgnorePatterns: ['/node_modules/'],
  testMatch: [
    '**/test/javascript/**/*.test.js',
    '**/test/javascript/**/*_test.js'
  ],
  transform: {
    '^.+\\.jsx?$': 'babel-jest'
  },
  transformIgnorePatterns: [
    'node_modules/(?!(@rails/request\\.js)/)'
  ]
};
