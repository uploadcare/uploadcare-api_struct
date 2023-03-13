module ApiStruct
  class Client
    DEFAULT_HEADERS = {
      'Accept': 'application/json',
      'Content-Type': 'application/json'
    }
    URL_OPTION_REGEXP = %r{/:([a-z_]+)}.freeze

    attr_reader :client

    # rubocop:disable Style/MissingRespondToMissing
    def self.method_missing(method_name, *args, &)
      endpoints = Settings.config.endpoints
      return super unless endpoints.keys.include?(method_name)

      define_method(:api_root) { endpoints[method_name][:root] }
      define_method(:default_params) { endpoints[method_name][:params] || {} }
      define_method(:default_path) { first_arg(args) }

      define_method(:headers) do
        endpoints[method_name][:headers]
      end
    end
    # rubocop:enable Style/MissingRespondToMissing

    HTTP_METHODS = %i[get post patch put delete].freeze

    HTTP_METHODS.each do |http_method|
      define_method http_method do |*args, **options|
        options[:params] = default_params.merge(options[:params] || {})
        wrap client.send(http_method, build_url(args, options), options)
      rescue HTTP::ConnectionError => e
        failure(body: e.message, status: :not_connected)
      end
    end

    def initialize
      api_settings_exist
      client_headers = headers || DEFAULT_HEADERS
      @client = HTTP::Client.new(headers: client_headers)
    end

    private

    def wrap(response)
      response.status < 300 ? success(response) : failure(response)
    end

    def success(response)
      body = response.body.to_s
      result = !body.empty? ? JSON.parse(body, symbolize_names: true) : nil
      Dry::Monads::Result::Success.call(result)
    end

    def failure(response)
      result = ApiStruct::Errors::Client.new(response)
      Dry::Monads::Result::Failure.call(result)
    end

    def first_arg(args)
      args.first.to_s
    end

    def build_url(args, options)
      suffix = to_path(args)
      prefix = to_path(options.delete(:prefix))
      path = to_path(options.delete(:path) || default_path)

      replace_optional_params(to_path(api_root, prefix, path, suffix), options)
    end

    def to_path(*args)
      Array(args).reject { |o| o.respond_to?(:empty?) ? o.empty? : !o }.join('/')
    end

    def replace_optional_params(url, options)
      url.gsub(URL_OPTION_REGEXP) do
        value = options.delete(::Regexp.last_match(1).to_sym)
        value ? "/#{value}" : ''
      end
    end

    def api_settings_exist
      return if respond_to?(:api_root)
      raise "\nSet api configuration for #{self.class}."
    end
  end
end
