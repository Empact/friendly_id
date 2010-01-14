# encoding: utf-8
require File.dirname(__FILE__) + '/test_helper'

class SluggedModelTest < Test::Unit::TestCase

  context "A slugged model with default FriendlyId options" do

    setup do
      Post.friendly_id_options = FriendlyId::DEFAULT_OPTIONS.merge(:method => :name, :use_slug => true)
      @post = Post.new :name => "Test post", :published => true
      @post.save!
    end

    teardown do
      Post.delete_all
      Person.delete_all
      Place.delete_all
      Slug.delete_all
    end

    should "have friendly_id options" do
      assert_not_nil Post.friendly_id_options
    end

    should "have a slug" do
      assert_not_nil @post.slug
    end

    should "be findable by its friendly_id" do
      assert Post.find(@post.friendly_id)
    end

    should "be findable by its regular id" do
      assert Post.find(@post.id)
    end

    should "be findable by its regular id as a string" do
      assert Post.find(@post.id.to_s)
    end

    should "be findable by its instance" do
      assert Post.find(@post)
    end

    should "not be findable by its id if looking for something else" do
      assert_raises ActiveRecord::RecordNotFound do
        Post.find("#{@post.id}-i-dont-exists")
      end
    end

    should "generate slug text" do
      post = Post.new :name => "Test post"
      assert_not_nil post.slug_text
    end

    should "respect finder conditions" do
      assert_raises ActiveRecord::RecordNotFound do
        Post.find(@post.friendly_id, :conditions => "1 = 2")
      end
    end

    context "when the friendly_id text is reserved" do
      should "fail validation" do
        person = Post.new(:name => "new")
        assert !person.save
        assert_equal ['Name can not be "new"'], person.errors.full_messages
      end

      should "validate the latest slug when there are multiple versions" do
        person = Post.new(:name => "Something")
        assert person.save
        assert !person.update_attributes(:name => "new")
        assert_equal ['Name can not be "new"'], person.errors.full_messages
      end
    end

    context "when the friendly_id text is an empty string" do
      should "fail validation" do
        person = Post.new(:name => "")
        assert !person.save
        assert_equal ['Name can not be ""'], person.errors.full_messages
      end

      should "validate the latest slug when there are multiple versions" do
        person = Post.new(:name => "Something")
        assert person.save
        assert !person.update_attributes(:name => "")
        assert_equal ['Name can not be ""'], person.errors.full_messages
      end
    end

    should "fails validation if the friendly_id text is nil" do
      person = Post.new(:name => nil)
      assert !person.save
      assert_equal ['Name can not be ""'], person.errors.full_messages
    end

    should "raise an error if the normalized friendly id becomes blank" do
      person = Post.new(:name => "-.-")
      assert !person.save
      assert_equal ['Name can not be "-.-"'], person.errors.full_messages
    end

    should "not make a new slug unless the friendly_id method value has changed" do
      @post.published = !@post.published
      @post.save!
      assert_equal 1, @post.slugs.size
    end

    should "make a new slug if the friendly_id method value has changed" do
      @post.name = "Changed title"
      @post.save!
      assert_equal 2, @post.slugs.size
    end

    should "have a slug sequence of 1 by default" do
      assert_equal 1, @post.slug.sequence
    end

    should "increment sequence for duplicate slug names" do
      @post2 = Post.create! :name => @post.name
      assert_equal 2, @post2.slug.sequence
    end

    should "have a friendly_id that terminates with -- and the slug sequence if the sequence is greater than 1" do
      @post2 = Post.create! :name => @post.name
      assert_match(/--2\z/, @post2.friendly_id)
    end

    should "allow datetime columns to be used as slugs" do
      assert Event.create(:name => "Test", :event_date => DateTime.now)
    end

    should "not strip diacritics" do
      post = Post.new(:name => "¡Feliz año!")
      assert_match(/#{'ñ'}/, post.slug_text)
    end

    should "not convert to ASCII" do
      post = Post.new(:name => "katakana: ゲコゴサザシジ")
      assert_equal "katakana-ゲコゴサザシジ", post.slug_text
    end

    should "allow the same friendly_id across models" do
      district = District.create!(:name => @post.name)
      assert_equal district.friendly_id, @post.friendly_id
    end

    should "truncate slug text longer than the max length" do
      post = Post.new(:name => "a" * (Post.friendly_id_options[:max_length] + 1))
      assert_equal post.slug_text.length, Post.friendly_id_options[:max_length]
    end

    should "truncate slug in 'right way' when slug is unicode" do
      post = Post.new(:name => "ё" * 100 + 'ю' *(Post.friendly_id_options[:max_length] - 100 + 1))
      assert_equal post.slug_text.mb_chars[-1], 'ю'
    end

    should "be able to reuse an old friendly_id without incrementing the sequence" do
      old_title = @post.name
      old_friendly_id = @post.friendly_id
      @post.name = "A changed title"
      @post.save!
      @post.name = old_title
      @post.save!
      assert_equal old_friendly_id, @post.friendly_id
    end

    should "allow eager loading of slugs" do
      assert_nothing_raised do
        Post.find(@post.friendly_id, :include => :slugs)
      end
    end

    # This emulates a fairly common issue where id's generated by fixtures are very high.
    should "continue to admit very large ids" do
      Person.connection.execute("INSERT INTO people (id, name) VALUES (2147483647, 'Joe Schmoe')")
      assert Person.find(2147483647)
    end

    context "and configured to strip diacritics" do
      setup do
        Post.friendly_id_options = Post.friendly_id_options.merge(:strip_diacritics => true)
      end

      should "strip diacritics from Roman alphabet based characters" do
        post = Post.new(:name => "¡Feliz año!")
        assert_no_match(/#{'ñ'}/, post.slug_text)
      end

      should "raise an error if the friendly_id text is an empty string" do
        person = Post.new(:name => "")
        assert !person.save
        assert_equal ['Name can not be ""'], person.errors.full_messages
      end

      should "fails validation if the friendly_id text is nil" do
        person = Post.new(:name => nil)
        assert !person.save
        assert_equal ['Name can not be ""'], person.errors.full_messages
      end

    end

    context "and configured to convert to ASCII" do
      setup do
        Post.friendly_id_options = Post.friendly_id_options.merge(:strip_non_ascii => true)
      end

      should "strip non-ascii characters" do
        post = Post.new(:name => "katakana: ゲコゴサザシジ")
        assert_equal "katakana", post.slug_text
      end
    end

    context "that uses a custom table name" do
      should "support normal CRUD operations" do
        assert thing = Place.create!(:name => "a name")
        thing.name = "a new name"
        assert thing.save!
        assert thing.destroy
      end
    end

    context "when found using its friendly_id" do
      setup do
        @post = Post.find(@post.friendly_id)
      end

      should "indicate that it was found using the friendly_id" do
        assert @post.found_using_friendly_id?
      end

      should "not indicate that it has a better id" do
        assert !@post.has_better_id?
      end

      should "not indicate that it was found using its numeric id" do
        assert !@post.found_using_numeric_id?
      end

      should "have a finder slug" do
        assert_not_nil @post.finder_slug
      end

    end

    context "when found using its regular id" do
      setup do
        @post = Post.find(@post.id)
      end

      should "indicate that it was not found using the friendly id" do
        assert !@post.found_using_friendly_id?
      end

      should "indicate that it has a better id" do
        assert @post.has_better_id?
      end

      should "indicate that it was found using its numeric id" do
        assert @post.found_using_numeric_id?
      end

      should "not have a finder slug" do
        assert_nil @post.finder_slug
      end

    end

    context "when found using an outdated friendly id" do
      setup do
        old_id = @post.friendly_id
        @post.name = "Title changed"
        @post.save!
        @post = Post.find(old_id)
      end

      should "indicate that it was found using a friendly_id" do
        assert @post.found_using_friendly_id?
      end

      should "indicate that it has a better id" do
        assert @post.has_better_id?
      end

      should "not indicate that it was found using its numeric id" do
        assert !@post.found_using_numeric_id?
      end

      should "should have a finder slug different from its default slug" do
        assert_not_equal @post.slug, @post.finder_slug
      end

    end

    context "when table does not exist" do
      should "not raise an error when doing friendly_id setup" do
        assert_nothing_raised do
          Question.has_friendly_id :title, :use_slug => true
        end
      end
    end

    context "when using an array as the find argument" do

      setup do
        @post2 = Post.create!(:name => "another post", :published => true)
      end

      should "return results when passed an array of non-friendly ids" do
        assert_equal 2, Post.find([@post.id, @post2.id]).size
      end

      should "return results when passed an array of friendly ids" do
        assert_equal 2, Post.find([@post.friendly_id, @post2.friendly_id]).size
      end

      should "return results when searching using a named scope" do
        assert_equal 2, Post.published.find([@post.id, @post2.id]).size
      end

      should "return results when passed a mixed array of friendly and non-friendly ids" do
        assert_equal 2, Post.find([@post.friendly_id, @post2.id]).size
      end

      should "return results when passed an array of non-friendly ids, of which one represents a record with multiple slugs" do
        @post2.update_attributes(:name => 'another post [updated]')
        assert_equal 2, Post.find([@post.id, @post2.id]).size
      end

      should "indicate that the results were found using a friendly_id" do
        @posts = Post.find [@post.friendly_id, @post2.friendly_id]
        @posts.each { |p| assert p.found_using_friendly_id? }
      end

      should "raise an error when all records are not found" do
        assert_raises(ActiveRecord::RecordNotFound) do
          Post.find([@post.friendly_id, 'non-existant-slug-record'])
        end
      end

      should "allow eager loading of slugs" do
        assert_nothing_raised do
          Post.find([@post.friendly_id, @post2.friendly_id], :include => :slugs)
        end
      end

    end

  end

end
