class CleanupProofsJob < ApplicationJob
  def perform
    Application.where(status: :archived)
              .where("updated_at < ?", 30.days.ago)
              .find_each do |application|
        application.purge_proofs
      end
  end
end
