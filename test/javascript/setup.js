// Import Jest DOM matchers
import '@testing-library/jest-dom';

// Mock document.createElement for canvas
document.createElement.originalFn = document.createElement;

// Add custom matchers
expect.extend({
  toHaveClass(received, className) {
    const pass = received.classList.contains(className);
    if (pass) {
      return {
        message: () => `expected ${received} not to have class "${className}"`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to have class "${className}"`,
        pass: false,
      };
    }
  },
});

// Mock console methods to avoid cluttering test output
global.console = {
  ...console,
  log: jest.fn(),
  error: jest.fn(),
  warn: jest.fn(),
};
