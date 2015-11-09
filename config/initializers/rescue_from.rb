require 'openstax_rescue_from'

secrets = Rails.application.secrets

OpenStax::RescueFrom.configure do |config|
  config.raise_exceptions = Rails.application.config.consider_all_requests_local

  config.app_name = 'Tutor'
  config.app_env = secrets.environment_name
  config.contact_name = secrets.exception['contact_name']

  # config.notifier = ExceptionNotifier

  # config.html_error_template_path = 'errors/any'
  # config.html_error_template_layout_name = 'application'

  # config.email_prefix = "[#{app_name}] (#{app_env}) "
  config.sender_address = secrets.exception['sender']
  config.exception_recipients = secrets.exception['recipients']
end

# OpenStax::RescueFrom.register_exception('ExampleException',
#                                         status: :not_found,
#                                         notify: true,
#                                         extras: ->(e) { {} })
#
OpenStax::RescueFrom.register_exception('InvalidTeacherJoinToken',
                                        message: 'You are trying to join a class as a teacher, but the information you provided is either out of date or does not correspond to an existing course.',
                                        status: :not_found,
                                        notify: false)

OpenStax::RescueFrom.register_exception('UserAlreadyCourseTeacher',
                                        message: 'You are already a teacher of this course.',
                                        status: :not_found,
                                        notify: false)
