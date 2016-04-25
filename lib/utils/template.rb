require 'erb'
require 'ostruct'

module InstanceAgent
  module Utils
    module Template

      # define a context for the rendering of the template
      class TemplateContext < OpenStruct
        def get_binding
          binding
        rescue => e
          raise RuntimeError, "Couldn't generate context for template with #{params}. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end
      end

      # renders ERB templates given a custom context. Initialize a instance and call render() with the parameters
      # that should be passed down to the template at rendering time
      #    Renderer('/path/to/template.erb').render(:param1 => value1, :param2 => value2, ...)
      #
      # the params can be addressed in the template by name i.e. <%= param1 %>
      class Renderer
        def initialize(erb)
          raise "Failed to generate template, missing target." if erb.nil? || !File.exist?(erb)

          @erb = ERB.new(File.new(erb).read)
        rescue => e
          raise "Couldn't generate template from #{erb}. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end

        def render(params)
          @erb.result(TemplateContext.new(params).get_binding)
        rescue => e
          raise "Couldn't generate template with parametes \"#{params.inspect}\". #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end
      end

    end
  end
end
