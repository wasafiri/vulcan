require 'rails_helper'

RSpec.describe BaseService do
  let(:service) { BaseService.new }

  describe '#add_error' do
    it 'adds error message to errors array' do
      service.send(:add_error, 'Test error')
      expect(service.errors).to include('Test error')
    end

    it 'returns false' do
      expect(service.send(:add_error, 'Test error')).to be false
    end
  end

  describe '#log_error' do
    let(:error) { StandardError.new('Test error message') }

    it 'logs error message' do
      expect(Rails.logger).to receive(:error).with("BaseService error: Test error message")
      service.send(:log_error, error)
    end

    it 'includes context if provided' do
      expect(Rails.logger).to receive(:error).with("BaseService error: Test error message | Context: Additional context")
      service.send(:log_error, error, 'Additional context')
    end

    it 'adds error message to errors array' do
      service.send(:log_error, error)
      expect(service.errors).to include('Test error message')
    end

    it 'returns false' do
      expect(service.send(:log_error, error)).to be false
    end
  end
end
