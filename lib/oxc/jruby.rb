# frozen_string_literal: true

require "ffi"
require "rbconfig"

module Oxc
  module Native
    extend FFI::Library

    class Result < FFI::Struct
      layout :value, :pointer,
             :value_len, :size_t,
             :error, :pointer,
             :code, :int
    end

    class << self
      def library_path
        return ENV.fetch("OXC_LIBRARY_PATH") if ENV.key?("OXC_LIBRARY_PATH")

        File.expand_path("../../rust/build/#{host_os}_#{host_arch}/#{library_name}", __dir__)
      end

      private

      def host_arch
        case RbConfig::CONFIG["host_cpu"]
        when /aarch64|arm64/ then "arm64"
        when /x86_64|amd64/ then "amd64"
        else RbConfig::CONFIG["host_cpu"]
        end
      end

      def host_os
        case RbConfig::CONFIG["host_os"]
        when /darwin/ then "darwin"
        when /linux/ then "linux"
        else
          raise LoadError, "oxc does not support JRuby on #{RbConfig::CONFIG["host_os"]}"
        end
      end

      def library_name
        host_os == "darwin" ? "liboxc_ffi.dylib" : "liboxc_ffi.so"
      end
    end

    ffi_lib library_path

    attach_function :oxc_minify, [:string, :string], Result.by_value, blocking: true
    attach_function :oxc_transform, [:string, :string], Result.by_value, blocking: true
    attach_function :oxc_parse, [:string, :string], Result.by_value, blocking: true
    attach_function :oxc_version, [], :pointer
    attach_function :oxc_oxc_version, [], :pointer
    attach_function :oxc_string_free, [:pointer], :void
    attach_function :oxc_result_free, [Result.by_value], :void
  end

  module Backend
    ERROR_CLASSES = {
      1 => OptionError,
      2 => EncodingError,
      3 => TransformError,
      4 => InternalError,
      5 => PanicError,
    }.freeze

    class << self
      def minify(source, options_json)
        call(Native.method(:oxc_minify), source, options_json)
      end

      def transform(source, options_json)
        call(Native.method(:oxc_transform), source, options_json)
      end

      def parse(source, options_json)
        call(Native.method(:oxc_parse), source, options_json)
      end

      def version
        take_string(Native.oxc_version)
      end

      def oxc_version
        take_string(Native.oxc_oxc_version)
      end

      private

      def call(function, source, options_json)
        result = function.call(native_string(source), native_string(options_json))

        unwrap(result)
      end

      def unwrap(result)
        error = result[:error]
        return unwrap_value(result) if error.null?

        message = error.read_string.force_encoding(Encoding::UTF_8)
        error_class = ERROR_CLASSES.fetch(result[:code], InternalError)
        Native.oxc_result_free(result)
        raise error_class, message
      end

      def unwrap_value(result)
        value = result[:value]

        if value.null?
          Native.oxc_result_free(result)
          raise InternalError, "oxc returned no result"
        end

        string = value.read_string_length(result[:value_len]).force_encoding(Encoding::UTF_8)
        Native.oxc_result_free(result)
        string
      end

      def take_string(pointer)
        return if pointer.null?

        pointer.read_string.force_encoding(Encoding::UTF_8)
      ensure
        Native.oxc_string_free(pointer) if pointer && !pointer.null?
      end

      def native_string(value)
        string = String.try_convert(value)
        raise TypeError, "no implicit conversion of #{value.class} into String" unless string
        raise ArgumentError, "string contains null byte" if string.include?("\0")

        string
      end
    end
  end
end
