# frozen_string_literal: true

require "test_helper"

return unless RUBY_ENGINE == "jruby"

module Oxc
  class JrubyBackendTest < Minitest::Spec
    test "loads the packaged Rust shared library" do
      assert File.file?(Native.library_path)
      assert_equal VERSION, Backend.version
      assert_equal "0.152.0", Backend.oxc_version
    end

    test "retains the native backend's string checks" do
      assert_raises(TypeError) { Backend.parse(nil, "{}") }
      assert_raises(ArgumentError) { Backend.parse("foo()\0", "{}") }
    end
  end
end
