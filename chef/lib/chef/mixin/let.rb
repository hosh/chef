class Chef
  module Mixin
    module Let


      module ClassMethods
        # Imported from https://github.com/rspec/rspec-core/blob/1004353d32229ad43c95717450f057444f6e8f3c/lib/rspec/core/let.rb
        def let(name, &block)
          define_method(name) do
            __memoized.fetch(name) {|k| __memoized[k] = instance_eval(&block) }
          end
        end
      end

      private

      def __memoized
        @__memoized ||= {}
      end
    end
  end
end
