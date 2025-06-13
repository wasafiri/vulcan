# frozen_string_literal: true

require 'test_helper'

class ApplicationNoteTest < ActiveSupport::TestCase
  setup do
    @application = create(:application)
    @admin = create(:admin)
  end

  test 'should create a valid application note' do
    note = ApplicationNote.new(
      application: @application,
      admin: @admin,
      content: 'This is a test note',
      internal_only: true
    )
    assert note.valid?
  end

  test 'should require content' do
    note = ApplicationNote.new(
      application: @application,
      admin: @admin,
      internal_only: true
    )
    assert_not note.valid?
    assert_includes note.errors[:content], "can't be blank"
  end

  test 'should require application' do
    note = ApplicationNote.new(
      admin: @admin,
      content: 'This is a test note',
      internal_only: true
    )
    assert_not note.valid?
    assert_includes note.errors[:application], 'must exist'
  end

  test 'should require admin' do
    note = ApplicationNote.new(
      application: @application,
      content: 'This is a test note',
      internal_only: true
    )
    assert_not note.valid?
    assert_includes note.errors[:admin], 'must exist'
  end

  test 'public_notes scope should return only public notes' do
    create(:application_note, :internal, application: @application)
    public_note = create(:application_note, :public, application: @application)

    assert_equal 1, @application.application_notes.public_notes.count
    assert_equal public_note.id, @application.application_notes.public_notes.first.id
  end

  test 'internal_notes scope should return only internal notes' do
    internal_note = create(:application_note, :internal, application: @application)
    create(:application_note, :public, application: @application)

    assert_equal 1, @application.application_notes.internal_notes.count
    assert_equal internal_note.id, @application.application_notes.internal_notes.first.id
  end

  test 'recent_first scope should order notes by created_at desc' do
    older_note = create(:application_note, application: @application, created_at: 2.days.ago)
    newer_note = create(:application_note, application: @application, created_at: 1.day.ago)

    notes = @application.application_notes.recent_first
    assert_equal newer_note.id, notes.first.id
    assert_equal older_note.id, notes.last.id
  end
end
