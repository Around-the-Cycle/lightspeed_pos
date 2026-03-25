# frozen_string_literal: true

require_relative 'collection'
require_relative 'account'

module Lightspeed
  class Accounts < Lightspeed::Collection
    def base_path
      '/Account'
    end

    def account
      first_loaded || first
    end

    def page(url: nil, per_page: PER_PAGE, params: {})
      # turns out lightspeed doesn't respect pagination for accounts.
      # so page(1) is identical to page(0).
      # they should be different, thus.
      # if someone has more than 100 store accounts, well, good for them.
      url ? [] : super
    end
  end
end
