require 'rails_helper'

RSpec.describe Applications::MedicalCertificationService do
  let(:constituent) { create(:constituent) }
  let(:application) do 
    create(:application, 
      user: constituent,
      medical_provider_name: "Dr. Smith",
      medical_provider_email: "drsmith@example.com",
      medical_provider_phone: "555-555-5555"
    )
  end
  let(:admin) { create(:admin) }
  let(:service) { described_class.new(application: application, actor: admin) }

  describe '#request_certification' do
    context 'when successful' do
      it 'updates the certification status' do
        expect { service.request_certification }.to change {
          application.reload.medical_certification_status
        }.to('requested')
      end

      it 'updates the certification requested timestamp' do
        expect { service.request_certification }.to change {
          application.reload.medical_certification_requested_at
        }.from(nil)
      end

      it 'increments the request count' do
        expect { service.request_certification }.to change {
          application.reload.medical_certification_request_count
        }.by(1)
      end

      it 'creates a notification' do
        expect { service.request_certification }.to change(Notification, :count).by(1)
      end

      it 'returns true' do
        expect(service.request_certification).to be true
      end
    end

    context 'when missing medical provider email' do
      let(:application) { create(:application, user: constituent, medical_provider_email: nil) }

      it 'returns false' do
        expect(service.request_certification).to be false
      end

      it 'adds an error message' do
        service.request_certification
        expect(service.errors).to include('Medical provider email is required')
      end

      it 'does not update the application' do
        expect { service.request_certification }.not_to change {
          application.reload.medical_certification_status
        }
      end
    end

    context 'when notification creation fails' do
      before do
        allow(Notification).to receive(:create!).and_raise(StandardError.new('Notification error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to create notification/)
        service.request_certification
      end

      it 'continues processing' do
        expect(service.request_certification).to be true
      end

      it 'still updates the certification status' do
        expect { service.request_certification }.to change {
          application.reload.medical_certification_status
        }.to('requested')
      end
    end

    context 'when email delivery fails' do
      before do
        allow(MedicalProviderMailer).to receive_message_chain(:request_certification, :deliver_now)
          .and_raise(StandardError.new('Email error'))
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Failed to send email/)
        service.request_certification
      end

      it 'still returns true to continue the process' do
        expect(service.request_certification).to be true
      end

      it 'still updates the certification status' do
        expect { service.request_certification }.to change {
          application.reload.medical_certification_status
        }.to('requested')
      end
    end
  end
end
