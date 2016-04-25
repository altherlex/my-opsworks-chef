module AWS

  class CharlieInstanceService

    # @private
    class Request < Core::Http::Request
      include Core::Signature::Version4

      def service
        'CharlieInstanceService'
      end

    end

  end
end