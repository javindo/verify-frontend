require 'user_errors'

module UserSession
  def set_journey_hint(idp_entity_id)
    cookies.encrypted[CookieNames::VERIFY_FRONT_JOURNEY_HINT] = { entity_id: idp_entity_id }.to_json
  end

  def selected_evidence
    selected_answer_store.selected_evidence
  end

  def selected_answer_store
    @selected_answer_store ||= SelectedAnswerStore.new(session)
  end

  def ensure_session_eidas_supported
    txn_supports_eidas = session[:transaction_supports_eidas]
    unless txn_supports_eidas
      something_went_wrong('Transaction does not support Eidas', :forbidden)
    end
  end

  def store_locale_in_cookie
    cookies.signed[CookieNames::VERIFY_LOCALE] = {
        value: I18n.locale,
        httponly: true,
        secure: Rails.configuration.x.cookies.secure
    }
  end

  def current_transaction_simple_id
    session[:transaction_simple_id]
  end

  def current_transaction
    @current_transaction ||= RP_DISPLAY_REPOSITORY.fetch(current_transaction_simple_id)
  end

  def loa2_transactions_list
    Display::Rp::TransactionFilter.new.filter_by_loa(transactions_list, 'LEVEL_2')
  end

  def loa1_transactions_list
    Display::Rp::TransactionFilter.new.filter_by_loa(transactions_list, 'LEVEL_1')
  end

  def transactions_list
    DATA_CORRELATOR.correlate(Display::Rp::TransactionsProxy.new(API_CLIENT).transactions)
  end

  def validate_session
    validation = SESSION_VALIDATOR.validate(cookies, session)
    unless validation.ok?
      logger.info(validation.message)
      render_error(validation.type, validation.status)
    end
  end

  def set_locale
    I18n.locale = params[:locale] || I18n.default_locale
  end

private

  def is_loa2?
    session['requested_loa'] == 'LEVEL_2'
  end

  def is_loa1?
    session['requested_loa'] == 'LEVEL_1'
  end

  def for_viewable_idp(entity_id)
    matching_idp = current_identity_providers.detect { |idp| idp.entity_id == entity_id }
    idp = IDENTITY_PROVIDER_DISPLAY_DECORATOR.decorate(matching_idp)
    if idp.viewable?
      yield idp
    else
      logger.error 'Unrecognised IdP simple id'
      render_not_found
    end
  end

  def select_viewable_idp(entity_id)
    for_viewable_idp(entity_id) do |decorated_idp|
      session[:selected_idp] = decorated_idp.identity_provider
      yield decorated_idp
    end
  end

  def report_to_analytics(action_name)
    ANALYTICS_REPORTER.report(request, action_name)
  end

  def current_identity_providers
    SESSION_PROXY.get_idp_list(session[:verify_session_id]).idps
  end

  def selected_identity_provider
    IdentityProvider.from_session(session.fetch(:selected_idp))
  end
end
