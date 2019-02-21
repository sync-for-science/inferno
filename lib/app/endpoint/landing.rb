# frozen_string_literal: true

module Inferno
  class App
    class Endpoint
      # Home provides a Sinatra endpoint for accessing Inferno.
      # Home serves the index page and landing page
      class Landing < Endpoint

        set :prefix, '/'

        # Return the index page of the application
        get '/' do
          redirect BASE_PATH
        end

        get '/landing/?' do
          # Custom landing page intended to be overwritten for branded deployments
          erb :landing
        end
      end
    end
  end
end