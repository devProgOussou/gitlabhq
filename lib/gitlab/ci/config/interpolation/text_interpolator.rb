# frozen_string_literal: true

module Gitlab
  module Ci
    class Config
      module Interpolation
        ##
        # Performs CI config file interpolation and either returns the interpolated result or interpolation errors.
        #
        class TextInterpolator
          attr_reader :errors

          def initialize(config, input_args, variables)
            @config = config
            @input_args = input_args.to_h
            @variables = variables
            @errors = []
            @interpolated = false
          end

          def valid?
            errors.none?
          end

          def to_result
            @result
          end

          def error_message
            # Interpolator can have multiple error messages, like: ["interpolation interrupted by errors", "unknown
            # interpolation key: `abc`"] ?
            #
            # We are joining them together into a single one, because only one error can be surfaced when an external
            # file gets included and is invalid. The limit to three error messages combined is more than required.
            #
            errors.first(3).join(', ')
          end

          def interpolate!
            return errors.concat(config.errors) unless config.valid?

            if inputs_without_header?
              return errors.push(
                _('Given inputs not defined in the `spec` section of the included configuration file'))
            end

            return @result ||= config.content unless config.header

            return errors.concat(header.errors) unless header.valid?
            return errors.concat(inputs.errors) unless inputs.valid?
            return errors.concat(context.errors) unless context.valid?
            return errors.concat(template.errors) unless template.valid?

            @interpolated = true

            @result ||= template.interpolated
          end

          def interpolated?
            @interpolated
          end

          private

          attr_reader :config, :input_args, :variables

          def inputs_without_header?
            input_args.any? && !config.header
          end

          def header
            @header ||= Header::Root.new(config.header).tap do |header|
              header.key = 'header'

              header.compose!
            end
          end

          def content
            @content ||= config.content
          end

          def spec
            @spec ||= header.inputs_value
          end

          def inputs
            @inputs ||= Inputs.new(spec, input_args)
          end

          def context
            @context ||= Context.new({ inputs: inputs.to_hash }, variables: variables)
          end

          def template
            @template ||= TextTemplate.new(content, context)
          end
        end
      end
    end
  end
end
