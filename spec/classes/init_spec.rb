# encoding: utf-8
require 'spec_helper'
describe 'servicenowfacts' do
  context 'with defaults for all parameters' do
    it { should contain_class('servicenowfacts') }
  end
end
