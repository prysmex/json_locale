# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'json_locale'
require 'debug'

require 'minitest/autorun'
require 'minitest/spec'
require 'minitest/reporters'

Minitest::Reporters.use!
