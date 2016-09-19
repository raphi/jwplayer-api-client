# JWPlayer::API::Client [![Build Status](https://travis-ci.org/raphi/jwplayer-api-client.svg?branch=master)](https://travis-ci.org/raphi/jwplayer-api-client)

This gem aims to easily sign JWPlayer Platform API URLs according to the documentation: https://developer.jwplayer.com/jw-platform/reference/v1/authentication.html
It is not intended to actually send the request but simply to generate the correctly signed URL. An example at the end of this documentation is provided though.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'jwplayer-api-client'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install jwplayer-api-client

## Usage

To get started, instantiate a new client:

```ruby
irb> client = JWPlayer::API::Client.new(key: 'y0c6CFQ5', secret: 'YZWQ1SfmpFYEfW9kiR1QerRF')
=> #<JWPlayer::API::Client:0x007fb6909e0158 @options={:host=>"api.jwplatform.com", :scheme=>"https", :version=>:v1, :key=>"y0c6CFQ5", :secret=>"YZWQ1SfmpFYEfW9kiR1QerRF", :format=>:json}>
```

If you have previously set `JWPLAYER_API_KEY` and `JWPLAYER_API_SECRET` ENV variables, you can simply do:
 
```ruby
irb> client = JWPlayer::API::Client.new
=> #<JWPlayer::API::Client:0x007fb6909e0158 @options={:host=>"api.jwplatform.com", :scheme=>"https", :version=>:v1, :key=>"y0c6CFQ5", :secret=>"YZWQ1SfmpFYEfW9kiR1QerRF", :format=>:json}>
```

`JWPlayer::API::Client.new()` accepts the following optional parameters:

| Name      | Default                               | Description |
|-----------|---------------------------------------|-------------| 
| key       | ENV['JWPLAYER_API_KEY']               | JWPlayer Platform API key
| secret    | ENV['JWPLAYER_API_SECRET']            | JWPlayer Platform API secret
| host      | 'api.jwplatform.com'                  | API host
| scheme    | 'https'                               | API scheme
| version   | :v1                                   | API version
| format    | :json                                 | API response format
| timestamp | current time                          | API UNIX timestamp used against replay-attacks
| nonce     | automatically generated for each call | 8 digit random number
See https://developer.jwplayer.com/jw-platform/reference/v1/call_syntax.html for more information.

Then, you can get a signed uri or signed url like this:

```ruby
irb> client.signed_uri('videos/create')
=> #<URI::Generic https://api.jwplatform.com/v1/videos/create?api_format=json&api_key=y0c6CFQ5&api_nonce=36581160&api_signature=95c92965a690119b086e40e37c2bb9d9ef6d3781&api_timestamp=1462808317>

irb> client.signed_url('videos/create')
=> "https://api.jwplatform.com/v1/videos/create?api_format=json&api_key=y0c6CFQ5&api_nonce=36581160&api_signature=95c92965a690119b086e40e37c2bb9d9ef6d3781&api_timestamp=1462808317"
```

And with query parameters:

```ruby
irb> client.signed_url('videos/create', title: 'My Super Video', description: 'This is cool')
=> "https://api.jwplatform.com/v1/videos/create?api_format=json&api_key=y0b9GFQ3&api_nonce=36581160&api_signature=4b2e1d7c6aeda3c87e634300563159a5ba99b661&api_timestamp=1462808317&description=This%20is%20cool&title=My%20Super%20Video"
```

### IRL example

Create a video reference in your JWPlayer Dashboard and get the `media_id`:

```ruby
require 'typhoeus'

data = {
  author:        'Raphaël',
  date:          Date.new(2002,03,04).to_time.to_i,
  description:   'Yet Another Keynote',
  title:         'Apple Keynote',
  sourceformat:  :m3u8,
  sourcetype:    :url,
  sourceurl:     'http://qthttp.apple.com.edgesuite.net/1010qwoeiuryfg/sl.m3u8'
}

# Call JWPlayer /videos/create API https://developer.jwplayer.com/jw-platform/reference/v1/methods/videos/create.html
jw_client  = JWPlayer::API::Client.new
signed_url = jw_client.signed_url('videos/create', data)
response   = Typhoeus.post(signed_url)
json       = JSON.parse(response.body)
media_id   = json.dig('video', 'key')
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/raphi/jwplayer-api-client. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

