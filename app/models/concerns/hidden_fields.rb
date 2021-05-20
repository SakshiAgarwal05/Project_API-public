module HiddenFields
  def self.included(receiver)
    receiver.extend(ClassMethods)

    def serializable_hash(options = {})
      options[:except] = Array(options[:except])

      if options[:force_except]
        options[:except].concat Array(options[:force_except])
      else
        options[:except].concat(self.class::HIDDEN_FIELDS || [])
      end
      super(options)
    end

    receiver::HIDDEN_FIELDS.each do |field|
      define_method field do
        raise NoMethodError
      end

      define_method "#{field}=" do |value|
        raise NoMethodError
      end
    end

    def attributes
      super.reject { |key, object| self.class::HIDDEN_FIELDS.include?(key.to_sym) }
    end
  end
end

module ClassMethods
  def self.included(receiver)
    def columns
      super.reject { |x| self::HIDDEN_FIELDS.include?(x.name.to_sym) }
    end

    def columns_hash
      super.reject { |key, object| self::HIDDEN_FIELDS.include?(key.to_sym) }
    end

    def yaml_encoder
      result = super
      default_types = result.instance_variable_get(:@default_types).
        reject { |key, object| self::HIDDEN_FIELDS.include?(key.to_sym) }

      result.instance_variable_set(:@default_types, default_types)
      result
    end
  end
end
