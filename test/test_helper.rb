# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

ENV["RAILS_ENV"] ||= "test"

require_relative "simplecov_helper"
require "minitest/autorun"
require "minitest/mock"
require "rails"
require "recording_studio_publishable"
