# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "irb"
gem "maxitest", "~> 7.0"
gem "rake", "~> 13.0"
gem "rubocop", "~> 1.21"

gem "ffi", "~> 1.17", platforms: :jruby

install_if -> { RUBY_ENGINE != "jruby" } do
  gem "rake-compiler", "~> 1.2"
  gem "rake-compiler-dock", "~> 1.9"
  gem "rbs-inline", require: false
  gem "rb_sys", "~> 0.9"
  gem "steep", require: false
end
