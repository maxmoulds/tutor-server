module Api::V1

  # Represents the information that a user should be able to view about their profile
  class BootstrapDataRepresenter < ::Roar::Decorator

    include ::Roar::JSON

    property :user,
             extend: Api::V1::UserRepresenter,
             readable: true,
             writeable: false,
             getter: ->(*) { self }

    property :accounts_api_url,
             readable: true,
             writeable: false,
             getter: ->(*) {
               OpenStax::Utilities.generate_url(
                 OpenStax::Accounts.configuration.openstax_accounts_url, "api"
               )
             }

    property :accounts_profile_url,
             readable: true,
             writeable: false,
             getter: ->(*) {
               OpenStax::Utilities.generate_url(
                 OpenStax::Accounts.configuration.openstax_accounts_url, "profile"
               )
             }


    property :hypothesis_api_url,
             readable: true,
             writeable: false,
             getter: -> (*) {
                 Rails.application.secrets['hypothesis']['api_url']

             }

    property :hypothesis_sidebar_app_url,
             readable: true,
             writeable: false,
             getter: -> (*) {
                 Rails.application.secrets['hypothesis']['sidebar_app_url']
             }

    property :hypothesis_client_url,
             readable: true,
             writeable: false,
             getter: -> (*) {
                 Rails.application.secrets['hypothesis']['client_url']
             }

    property :hypothesis_authority,
             readable: true,
             writeable: false,
             getter: -> (*) {
                 Rails.application.secrets['hypothesis']['authority']
             }

    property :hypothesis_embed_url,
             readable: true,
             writeable: false,
             getter: -> (*) {
                 Rails.application.secrets['hypothesis']['embed_url']
             }

    property :hypothesis_client_id,
             readable: true,
             writable: false,
             getter: -> (*) {
                 Rails.application.secrets['hypothesis']['client_id']
             }


    property :errata_form_url,
             readable: true,
             writeable: false,
             getter: ->(*) { Rails.application.secrets['openstax']['osweb']['errata_form_url'] }

    property :tutor_api_url,
             readable: true,
             writeable: false,
             getter: ->(user_options:, **) { user_options[:tutor_api_url] }


    property :payments, writeable: false, readable: true, getter: ->(*) {
      {
        is_enabled: Settings::Payments.payments_enabled,
        js_url: OpenStax::Payments::Api.embed_js_url,
        base_url: Rails.application.secrets['openstax']['payments']['url'],
        product_uuid: Rails.application.secrets['openstax']['payments']['product_uuid']
      }
    }

    property :flash,
             readable: true,
             writeable: false,
             getter: ->(user_options:, **) { user_options[:flash] },
             schema: {
               required: false,
               description: "A hash of messages the backend would like the frontend to show. " +
                            "Inner keys include `success`, `notice`, `alert`, `error` and point " +
                            "to the message.  These keys can be interpreted as referring to " +
                            "Bootstrap `success`, `info`, `warning`, and `danger` alert stylings."
             }

    property :ui_settings,
             readable: true,
             writeable: false

    collection :courses,
               extend: Api::V1::CourseRepresenter,
               readable: true,
               writeable: false,
               getter: ->(*) { CollectCourseInfo[user: self] }
  end
end
