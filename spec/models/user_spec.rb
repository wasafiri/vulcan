# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'encrypted uniqueness validations' do
    let(:user_attributes) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john@example.com',
        phone: '555-123-4567',
        password: 'password123',
        type: 'Users::Constituent',
        hearing_disability: true
      }
    end

    describe 'email uniqueness' do
      it 'validates uniqueness of encrypted email' do
        # Create first user
        User.create!(user_attributes)

        # Try to create second user with same email
        user2 = User.new(user_attributes.merge(phone: '555-999-8888'))

        expect(user2).not_to be_valid
        expect(user2.errors[:email]).to include('has already been taken')
      end

      it 'allows dependent users to share guardian email when flag is set' do
        # Create guardian user
        User.create!(user_attributes.merge(type: 'Users::Constituent'))

        # Create dependent user with same email but skip validation flag
        dependent = User.new(user_attributes.merge(
                               phone: '555-999-8888',
                               skip_contact_uniqueness_validation: true
                             ))

        expect(dependent).to be_valid
      end
    end

    describe 'phone uniqueness' do
      it 'validates uniqueness of encrypted phone' do
        # Create first user
        User.create!(user_attributes)

        # Try to create second user with same phone
        user2 = User.new(user_attributes.merge(email: 'jane@example.com'))

        expect(user2).not_to be_valid
        expect(user2.errors[:phone]).to include('has already been taken')
      end

      it 'allows dependent users to share guardian phone when flag is set' do
        # Create guardian user
        User.create!(user_attributes.merge(type: 'Users::Constituent'))

        # Create dependent user with same phone but skip validation flag
        dependent = User.new(user_attributes.merge(
                               email: 'dependent@example.com',
                               skip_contact_uniqueness_validation: true
                             ))

        expect(dependent).to be_valid
      end
    end

    describe 'database constraint enforcement' do
      it 'relies on database unique constraints as backup' do
        # This test verifies that database constraints catch duplicates
        # even if validation is bypassed
        User.create!(user_attributes)

        # Try to insert duplicate directly (bypassing validation)
        expect do
          User.create!(user_attributes.merge(phone: '555-999-8888'), validate: false)
        end.to raise_error(ActiveRecord::RecordNotUnique)
      end
    end
  end

  describe 'system_user method' do
    it 'creates system user with encrypted email' do
      system_user = User.system_user

      expect(system_user).to be_persisted
      expect(system_user.email).to eq('system@example.com')
      expect(system_user.type).to eq('Users::Administrator')
      expect(system_user).to be_admin
    end

    it 'returns existing system user if already created' do
      # Clear memoization
      User.instance_variable_set(:@system_user, nil)

      user1 = User.system_user
      user2 = User.system_user

      expect(user1.id).to eq(user2.id)
    end
  end
end
