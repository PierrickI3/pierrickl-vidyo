require 'spec_helper'
describe 'vidyo' do

  context 'with defaults for all parameters' do
    it { should contain_class('vidyo') }
  end
end
