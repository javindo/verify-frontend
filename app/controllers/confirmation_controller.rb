require 'user_session'
require 'user_errors'

class ConfirmationController < ApplicationController
  include UserSession
  include UserErrors

  before_action { @hide_feedback_link = true }
  layout 'slides'

  def index
    selected_idp = session.fetch(:selected_idp)
    @idp_name = IDENTITY_PROVIDER_DISPLAY_DECORATOR.decorate(IdentityProvider.from_session(selected_idp)).display_name
    @transaction_name = current_transaction.name

    if is_loa1?
      render :confirmation_LOA1
    else
      render :confirmation_LOA2
    end
  end
end
