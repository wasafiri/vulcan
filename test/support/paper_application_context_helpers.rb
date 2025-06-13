module PaperApplicationContextHelpers
  def setup_paper_application_context
    Thread.current[:paper_application_context] = true
    Current.paper_context = true
    Current.skip_proof_validation = true
  end

  def teardown_paper_application_context
    Thread.current[:paper_application_context] = nil
    Current.reset
  end

  # For tests that need the context for the entire test class
  def self.included(base)
    base.class_eval do
      def setup_paper_context_if_needed
        setup_paper_application_context if respond_to?(:needs_paper_context?) && needs_paper_context?
      end

      def teardown_paper_context_if_needed
        teardown_paper_application_context if respond_to?(:needs_paper_context?) && needs_paper_context?
      end
    end
  end
end 