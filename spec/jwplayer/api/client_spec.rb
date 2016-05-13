require 'cgi'
require 'spec_helper'

describe JWPlayer::API::Client do
  API_KEY    = 'XOqEAfxj'
  API_SECRET = 'uA96CFtJa138E2T5GhKfngml'
  API_PATH   = 'videos/list'

  let(:client) { JWPlayer::API::Client.new(key: API_KEY, secret: API_SECRET) }

  it 'has a version number' do
    expect(JWPlayer::API::Client::VERSION).not_to be nil
  end

  describe '::new' do
    context 'without any parameters' do
      it 'should raise an error' do
        expect { JWPlayer::API::Client.new }.to raise_error(ArgumentError)
        expect { JWPlayer::API::Client.new(key: API_KEY) }.to raise_error(ArgumentError)
        expect { JWPlayer::API::Client.new(secret: API_SECRET) }.to raise_error(ArgumentError)
      end

      context 'with JWPLAYER_API_* ENV variables' do
        it 'should not raise an error' do
          ENV['JWPLAYER_API_KEY']    = API_KEY
          ENV['JWPLAYER_API_SECRET'] = API_SECRET

          expect { JWPlayer::API::Client.new }.not_to raise_error
        end
      end
    end

    context 'with JWPlayer credentials' do
      it 'should have default values' do
        expect(client.options[:host]).to eql('api.jwplatform.com')
        expect(client.options[:scheme]).to eql('https')
        expect(client.options[:version]).to eql(:v1)
        expect(client.options[:key]).to eql(API_KEY)
        expect(client.options[:secret]).to eql(API_SECRET)
        expect(client.options[:format]).to eql(:json)
      end

      it 'should allow default values to be overrided' do
        opts = {
            key:     API_KEY,
            secret:  API_SECRET,
            host:    'www.myownhost.com',
            scheme:  'http',
            version: 'v42',
            format:  :xml
        }

        client = JWPlayer::API::Client.new(opts)

        expect(client.options[:host]).to eql(opts[:host])
        expect(client.options[:scheme]).to eql(opts[:scheme])
        expect(client.options[:version]).to eql(opts[:version])
        expect(client.options[:format]).to eql(opts[:format])
      end
    end
  end

  #
  # Data examples, parameters and expected responses taken from:
  # https://developer.jwplayer.com/jw-platform/reference/v1/authentication.html
  #
  describe 'internal signing method' do
    let(:client) { JWPlayer::API::Client.new(key: API_KEY, secret: API_SECRET, format: :xml, scheme: 'http') }
    let(:params) {
      [
          [:api_format, :xml],
          [:api_key, 'XOqEAfxj'],
          [:api_nonce, 80684843],
          [:api_timestamp, 1237387851],
          [:text, 'démo']
      ]
    }

    describe '#attributes' do
      it 'should return a correct subset of attributes' do
        expect(client.send(:attributes).to_h.keys).to contain_exactly(:api_key, :api_format)
      end

      context 'with an extra unknown attribute' do
        let(:client) { JWPlayer::API::Client.new(key: API_KEY, secret: API_SECRET, extra: :forbidden) }

        it 'should raise an error if provided with unknown attributes' do
          expect { client.signed_uri(API_PATH) }.to raise_error(ArgumentError)
        end
      end
    end

    describe '#escape (steps 1 & 2)' do
      it 'should encode URL parameters' do
        expect(client.send(:escape, 'démo')).to eql('d%C3%A9mo')
      end
    end

    describe '#sorted_params (step 3)' do
      it 'should sort params based on their encoded names' do
        expect(client.send(:sorted_params, params.shuffle)).to eql([
                                                                       [:api_format, :xml],
                                                                       [:api_key, 'XOqEAfxj'],
                                                                       [:api_nonce, 80684843],
                                                                       [:api_timestamp, 1237387851],
                                                                       [:text, 'démo']
                                                                   ])
      end
    end

    describe '#to_query (step 4)' do
      it 'should generate a correct query string' do
        expect(client.send(:to_query, params)).to eql('api_format=xml&api_key=XOqEAfxj&api_nonce=80684843&api_timestamp=1237387851&text=d%C3%A9mo')
      end
    end

    describe '#salted_params (step 5)' do
      it 'should append salt at the end of the query string' do
        query_string = 'api_format=xml&api_key=XOqEAfxj&api_nonce=80684843&api_timestamp=1237387851&text=d%C3%A9mo'

        expect(client.send(:salted_params, query_string)).to eql('api_format=xml&api_key=XOqEAfxj&api_nonce=80684843&api_timestamp=1237387851&text=d%C3%A9mouA96CFtJa138E2T5GhKfngml')
      end
    end

    describe '#signature (step 6)' do
      it 'should return a correct SHA-1 HEX digest' do
        token = 'api_format=xml&api_key=XOqEAfxj&api_nonce=80684843&api_timestamp=1237387851&text=d%C3%A9mouA96CFtJa138E2T5GhKfngml'

        expect(client.send(:signature, token)).to eql('fbdee51a45980f9876834dc5ee1ec5e93f67cb89')
      end
    end

    describe 'all steps' do
      it 'should generate a correctly signed URL' do
        allow(client).to receive(:options) { { key: API_KEY, secret: API_SECRET, format: :xml, nonce: '80684843', timestamp: '1237387851' } }

        signed_uri = client.signed_uri(API_PATH, text: 'démo')
        result_uri = URI.parse('http://api.jwplatform.com/v1/videos/list?text=d%C3%A9mo&api_nonce=80684843&api_timestamp=1237387851&api_format=xml&api_signature=fbdee51a45980f9876834dc5ee1ec5e93f67cb89&api_key=XOqEAfxj')

        expect(signed_uri.host).to eql(result_uri.host)
        expect(signed_uri.path).to eql(result_uri.path)
        expect(signed_uri.scheme).to eql(result_uri.scheme)
        expect(CGI.parse(signed_uri.query).sort).to eql(CGI.parse(result_uri.query).sort)
      end
    end
  end

  describe '#signed_uri' do
    let(:params) { CGI.parse(uri.query) }
    let(:uri) { client.signed_uri(API_PATH) }

    it 'should returns an <URI>' do
      expect(uri).to be_a(URI::Generic)
    end

    it 'should generate random nonce each time called' do
      second_params = CGI.parse(client.signed_uri(API_PATH).query)

      expect(params['api_nonce']).to_not eql(second_params['api_nonce'])
    end

    describe '.href' do
      it 'should have a secure scheme' do
        expect(uri.scheme).to eql('https')
      end

      it 'should have jwplayer platform default host' do
        expect(uri.host).to eql('api.jwplatform.com')
      end
    end

    describe '.path' do
      it 'should have the API version' do
        expect(uri.path).to include('v1')
      end

      it 'should allow to override the relative path' do
        uri = client.signed_uri('/v42/this_is_non_sense')

        expect(uri.path).not_to include('v1')
        expect(uri.path).to include('v42')
      end
    end

    describe '.parameters' do
      it 'should have a JSON default format' do
        expect(params).to have_key('api_format')
        expect(params['api_format'].first).to eql('json')
      end

      it 'nonce must be 8 digits' do
        expect(/^\d{8}$/ === params['api_nonce'].first).to be_truthy
      end

      it 'has the required query parameters' do
        expect(
            [:api_key, :api_timestamp, :api_nonce, :api_signature].all? { |key| params.has_key?(key.to_s) }
        ).to be_truthy
      end

      it 'does not include forbidden parameters' do
        expect(
            [:api_secret, :secret, :api_host, :host, :api_scheme, :scheme].all? { |key| !params.has_key?(key.to_s) }
        ).to be_truthy
      end
    end

    context 'with extra query parameters' do
      let(:uri) { client.signed_uri(API_PATH, text: 'démo') }

      it 'should includes the given extra parameters' do
        expect(params).to have_key('text')
      end
    end
  end

  describe '#signed_url' do
    let(:url) { client.signed_url(API_PATH) }

    it 'should returns a <String>' do
      expect(url).to be_a(String)
    end

    it 'should returns a valid URL' do
      expect(url).to match(/\A#{URI::regexp(['http', 'https'])}\z/)
    end
  end
end
