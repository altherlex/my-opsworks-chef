# taken from ActiveSupport - MIT licensed
unless Hash.new.respond_to?(:symbolize_keys!)
  class Hash
    def symbolize_keys!
      keys.each do |key|
        self[(key.to_sym rescue key) || key] = delete(key)
      end
      self
    end

    def symbolize_keys
      dup.symbolize_keys!
    end
  end
end

