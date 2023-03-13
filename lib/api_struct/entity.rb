module ApiStruct
  class Entity < SimpleDelegator
    extend Extensions::DryMonads
    extend Extensions::ApiClient

    class << self
      def entity_attributes
        @entity_attributes ||= []
      end

      def attr_entity(*attrs, &)
        entity_attributes.concat attrs

        attrs.each do |attr|
          define_entity_attribute_getter(attr, &)
          define_entity_attribute_setter(attr)
        end
      end

      def entities?(attr, options)
        entity_attributes << attr.to_sym
        define_method attr.to_s do
          self.class.collection(entity[attr], options[:as])
        end
      end
      alias has_entities entities?

      def entity?(attr, options)
        entity_attributes << attr.to_sym
        define_method attr.to_s do
          return unless entity[attr]
          self.class.convert_to_entity(entity[attr], options[:as])
        end
      end
      alias has_entity entity?

      def collection(entities, entity_type = self)
        Collection.new(entities, entity_type)
      end

      def convert_to_entity(item, entity_type = self)
        raise EntityError, "#{entity_type} must be inherited from base_entity" unless entity_type < ApiStruct::Entity
        entity_type.new(item)
      end

      private

      def define_entity_attribute_getter(attr)
        define_method attr.to_s do
          block_given? ? yield(entity[attr]) : entity[attr]
        end
      end

      def define_entity_attribute_setter(attr)
        define_method "#{attr}=" do |value|
          entity[attr] = value
        end
      end
    end

    attr_reader :entity, :entity_status

    # rubocop:disable Style/OptionalBooleanParameter
    def initialize(entity, entity_status = true)
      raise EntityError, "#{entity} must be Hash" unless entity.is_a?(Hash)
      @entity = Hashie::Mash.new(extract_attributes(entity))
      @entity_status = entity_status
      __setobj__(@entity)
    end
    # rubocop:enable Style/OptionalBooleanParameter

    def success?
      entity_status == true
    end

    def failure?
      entity_status == false
    end

    private

    def extract_attributes(attributes)
      formatted_attributes = attributes.map { |name, value| [format_name(name), value] }.to_h
      formatted_attributes.select { |key, _value| self.class.entity_attributes.include?(key.to_sym) }
    end

    def format_name(name)
      Dry::Inflector.new.underscore(name).to_sym
    end
  end

  class EntityError < StandardError; end
end
