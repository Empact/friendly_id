require File.dirname(__FILE__) + '/test_helper'

module FriendlyId
  module Test
    module ActiveRecord2

      class ModelWithFriendlyIdFriendlyIdTest < ::Test::Unit::TestCase

        test "should be able to query" do
          subject = ModelWithFriendlyIdFriendlyId.create(:name => 'foo', :age => 30)
          assert_equal "foo-30", subject.friendly_id
          assert_equal subject, ModelWithFriendlyIdFriendlyId.find("foo-30")
        end

      end

    end
  end
end
