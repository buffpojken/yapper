module Nanoid
  module Document
    module Callbacks
      extend MotionSupport::Concern

      included do
        class << self
          attr_accessor :before_save_callbacks
          attr_accessor :after_save_callbacks
        end
        self.before_save_callbacks = []
        self.after_save_callbacks = []
      end

      module ClassMethods
        def before_save(method)
          self.before_save_callbacks << method
        end

        def after_save(method)
          self.after_save_callbacks << method
        end
      end

      def run_callback(hook, operation)
        self.class.send("#{hook}_#{operation}_callbacks").each do |method|
          self.send(method)
        end
      end

      def run_callbacks(operation, &block)
        before_result = run_callback('before', operation)
        if before_result
          block.call
        end
        run_callback('after', operation)
      end
    end
  end
end