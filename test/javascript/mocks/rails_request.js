// Mock for @rails/request.js
export class FetchRequest {
  constructor(method, url, options = {}) {
    this.method = method
    this.url = url
    this.options = options
  }

  async perform() {
    // This will be mocked in individual tests
    return { ok: true, status: 200 }
  }
}

export class FetchResponse {
  constructor(response) {
    this.response = response
  }
}

export class RequestInterceptor {
  // Mock implementation
}

// Mock functions
export const destroy = jest.fn()
export const get = jest.fn()
export const patch = jest.fn()
export const post = jest.fn()
export const put = jest.fn() 