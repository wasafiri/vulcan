class TrainingSessionNotificationsMailer < ApplicationMailer
  def training_scheduled(training_session)
    @training_session = training_session
    @constituent = training_session.constituent
    @trainer = training_session.trainer

    template = EmailTemplate.find_by!(name: "training_scheduled")
    @subject = template.render_subject(
      {
        constituent_name: @constituent.full_name || "Valued Constituent",
        trainer_name: @trainer.full_name || "Your Trainer",
        scheduled_date: @training_session.scheduled_for.strftime("%B %d, %Y"),
        scheduled_time: @training_session.scheduled_for.strftime("%I:%M %p"),
        application_id: @training_session.application.id
      },
      @trainer
    )

    mail(to: @constituent.email, subject: @subject)
  rescue => e
    Event.create!(
      user: @trainer,
      action: "email_delivery_error",
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: "training_scheduled",
        variables: {
          constituent_name: @constituent.full_name,
          trainer_name: @trainer.full_name,
          scheduled_date: @training_session.scheduled_for.strftime("%B %d, %Y"),
          scheduled_time: @training_session.scheduled_for.strftime("%I:%M %p"),
          application_id: @training_session.application.id
        },
        backtrace: e.backtrace&.first(5)
      }
    )
    raise
  end

  def training_completed(training_session)
    @training_session = training_session
    @constituent = training_session.constituent
    @trainer = training_session.trainer

    template = EmailTemplate.find_by!(name: "training_completed")
    @subject = template.render_subject(
      {
        constituent_name: @constituent.full_name || "Valued Constituent",
        trainer_name: @trainer.full_name || "Your Trainer",
        completion_date: @training_session.completed_at.strftime("%B %d, %Y"),
        application_id: @training_session.application.id
      },
      @trainer
    )

    mail(to: @constituent.email, subject: @subject)
  rescue => e
    Event.create!(
      user: @trainer,
      action: "email_delivery_error",
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: "training_completed",
        variables: {
          constituent_name: @constituent.full_name,
          trainer_name: @trainer.full_name,
          completion_date: @training_session.completed_at.strftime("%B %d, %Y"),
          application_id: @training_session.application.id
        },
        backtrace: e.backtrace&.first(5)
      }
    )
    raise
  end

  def training_cancelled(training_session)
    @training_session = training_session
    @constituent = training_session.constituent
    @trainer = training_session.trainer

    template = EmailTemplate.find_by!(name: "training_cancelled")
    @subject = template.render_subject(
      {
        constituent_name: @constituent.full_name || "Valued Constituent",
        trainer_name: @trainer.full_name || "Your Trainer",
        scheduled_date: @training_session.scheduled_for.strftime("%B %d, %Y"),
        scheduled_time: @training_session.scheduled_for.strftime("%I:%M %p"),
        application_id: @training_session.application.id
      },
      @trainer
    )

    mail(to: @constituent.email, subject: @subject)
  rescue => e
    Event.create!(
      user: @trainer,
      action: "email_delivery_error",
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: "training_cancelled",
        variables: {
          constituent_name: @constituent.full_name,
          trainer_name: @trainer.full_name,
          scheduled_date: @training_session.scheduled_for.strftime("%B %d, %Y"),
          scheduled_time: @training_session.scheduled_for.strftime("%I:%M %p"),
          application_id: @training_session.application.id
        },
        backtrace: e.backtrace&.first(5)
      }
    )
    raise
  end

  def no_show_notification(training_session)
    @training_session = training_session
    @constituent = training_session.constituent
    @trainer = training_session.trainer

    template = EmailTemplate.find_by!(name: "training_no_show")
    @subject = template.render_subject(
      {
        constituent_name: @constituent.full_name || "Valued Constituent",
        trainer_name: @trainer.full_name || "Your Trainer",
        missed_date: @training_session.scheduled_for.strftime("%B %d, %Y"),
        missed_time: @training_session.scheduled_for.strftime("%I:%M %p"),
        application_id: @training_session.application.id
      },
      @trainer
    )

    mail(to: @constituent.email, subject: @subject)
  rescue => e
    Event.create!(
      user: @trainer,
      action: "email_delivery_error",
      user_agent: Current.user_agent,
      ip_address: Current.ip_address,
      metadata: {
        error_message: e.message,
        error_class: e.class.name,
        template_name: "training_no_show",
        variables: {
          constituent_name: @constituent.full_name,
          trainer_name: @trainer.full_name,
          missed_date: @training_session.scheduled_for.strftime("%B %d, %Y"),
          missed_time: @training_session.scheduled_for.strftime("%I:%M %p"),
          application_id: @training_session.application.id
        },
        backtrace: e.backtrace&.first(5)
      }
    )
    raise
  end
end
