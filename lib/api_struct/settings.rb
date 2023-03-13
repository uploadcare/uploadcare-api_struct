module ApiStruct
  class Settings
    extend ::Dry::Configurable

    setting :endpoints, default: {}
  end
end
