require 'rails_helper'

RSpec.describe MedicalCertificationEmailJob, type: :job do
  include ActiveJob::TestHelper

  let(:constituent) { create(:constituent) }
  let(:application) do 
    create(:application, 
      user: constituent,
      medical_provider_name: "Dr. Smith",
      medical_provider_email: "drsmith@example.com",
      medical_provider_phone: "555-555-5555"
    )
  end
  let(:timestamp) { Time.current.iso8601 }

  describe '#perform' do
    context 'when successful' do
      it 'delivers the email' do
        expect(MedicalProviderMailer).to receive_message_chain(:request_certification, :deliver_now)
        
        subject.perform(application_id: application.id, timestamp: timestamp)
      end

      it 'logs success message' do
        allow(MedicalProviderMailer).to receive_message_chain(:request_certification, :deliver_now)
        expect(Rails.logger).to receive(:info).with(/Processing medical certification email/)
        expect(Rails.logger).to receive(:info).with(/Successfully sent medical certification email/)
        
        subject.perform(application_id: application.id, timestamp: timestamp)
      end
    end

    context 'when email delivery fails' do
      before do
        allow(MedicalProviderMailer).to receive_message_chain(:request_certification, :deliver_now)
          .and_raise(Net::SMTPError.new("SMTP error"))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to send certification email/)
        expect(Rails.logger).to receive(:error) # For the backtrace

        begin
          subject.perform(application_id: application.id, timestamp: timestamp)
        rescue Net::SMTPError
          # Expected to raise
        end
      end

      it 'retries on SMTP errors' do
        expect(MedicalCertificationEmailJob.retries_on).to include(Net::SMTPError)
      end
    end

    context 'when application not found' do
      it 'handles the error gracefully' do
        expect(Rails.logger).to receive(:error).with(/Failed to send certification email/)
        expect(Rails.logger).to receive(:error) # For the backtrace

        begin
          subject.perform(application_id: 999999, timestamp: timestamp)
        rescue ActiveRecord::RecordNotFound
          # Expected to raise
        end
      end
    end
  end
end
