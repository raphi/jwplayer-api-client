# frozen_string_literal: true

require 'uri'
require 'digest'
require 'jwplayer/api/client/version'

module JWPlayer
  module API
    class Client
      ALLOWED_KEYS = [:format, :key, :nonce, :timestamp]
      IGNORED_KEYS = [:host, :scheme, :secret, :signature, :version]
      ESCAPE_REGEX = /[^a-z0-9\-\.\_\~]/i # http://oauth.net/core/1.0/#encoding_parameters

      attr_reader :params, :options

      def initialize(args = {})
        @options = {
            host:    'api.jwplatform.com',
            scheme:  'https',
            version: :v1,
            key:     ENV['JWPLAYER_API_KEY'],
            secret:  ENV['JWPLAYER_API_SECRET'],
            format:  :json
        }.merge(args)

        [:key, :secret].each do |key|
          if options[key].nil? || options[key].empty?
            raise ArgumentError, "Missing :#{key} parameter or 'JWPLAYER_API_#{key.upcase}' ENV variable"
          end
        end
      end

      def signed_uri(path, params = {})
        @params              = params
        @options[:nonce]     = rand.to_s[2..9]
        @options[:timestamp] = Time.now.to_i.to_s
        @uri                 = URI.join(URI::Generic.build(@options), [@options[:version], '/'].join, path)
        @uri.query           = signed_attributes
        @uri.normalize!
        @uri
      end

      def signed_url(path, params = {})
        signed_uri(path, params).to_s
      end

      private

      #
      # API signature generation
      # https://developer.jwplayer.com/jw-platform/reference/v1/authentication.html#api-signature-generation
      #

      def attributes
        matching_keys, extra_keys = options.keys.partition { |key| ALLOWED_KEYS.include?(key) }
        extra_keys                -= IGNORED_KEYS

        raise ArgumentError, "#{self.class}: Unknown extra option keys\n [#{extra_keys.map(&:inspect).join(', ')}]" unless extra_keys.empty?

        matching_keys.map { |key| [:"api_#{key}", options[key]] }
      end

      def signed_attributes
        salted_params = salted_params(normalized_params)
        signature     = signature(salted_params)

        to_query((params.to_a + attributes.to_a).push([:api_signature, signature]))
      end

      def normalized_params
        to_query(signature_params)
      end

      def signature_params
        sorted_params(params.to_a + attributes.to_a)
      end

      #
      # Steps 1 and 2
      # 1. All text parameters converted to UTF-8 encoding
      # 2. All text parameters URL-encoded
      #
      def escape(value)
        URI.escape(value.to_s, ESCAPE_REGEX)
      end

      #
      # Step 3
      # 3. Parameters are sorted based on their encoded names. Sort order is lexicographical byte value ordering
      #
      def sorted_params(params)
        params.sort
      end

      #
      # Step 4
      # 4. Parameters are concatenated together into a single query string
      #
      def to_query(params)
        params.map { |key, value| [key, escape(value)].join('=') }.join('&')
      end

      #
      # Step 5
      # The secret is added and SHA-1 digest is calculated
      # Secret is added to the end of the SBS
      #
      def salted_params(query_string)
        query_string + options[:secret].to_s
      end

      #
      # Step 6
      # The calculated SHA-1 HEX digest
      #
      def signature(token)
        Digest::SHA1.hexdigest(token)
      end
    end
  end
end
