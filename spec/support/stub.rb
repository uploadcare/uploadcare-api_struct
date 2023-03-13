module Support
  module Stub
    def stub_api(root, params = {})
      ApiStruct::Settings.configure do |config|
        config.endpoints = { stub_api: { root:, params: } }
      end
    end
  end
end
