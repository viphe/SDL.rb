#!/usr/bin/env ruby -w
# encoding: UTF-8

module SDL4R

  require 'ostruct'
  require 'test/unit'
  require 'sdl4r'
  require 'sdl4r/object_reader'
  require "sdl4r/sdl_test_case"

  class ObjectReaderTest < Test::Unit::TestCase
    include SdlTestCase

    def test_nil
      reader = ObjectReader.new(nil)

      assert_equal nil, reader.node_type
      assert_equal nil, reader.prefix
      assert_equal nil, reader.name

      assert_nil reader.read

      assert_equal nil, reader.node_type
      assert_equal nil, reader.prefix
      assert_equal nil, reader.name
    end

    def test_empty_object
      check_empty_object(Object.new)
    end

    def test_empty_hash
      check_empty_object({})
    end

    def test_empty_array
      check_empty_object([])
    end

    def check_empty_object(empty_object)
      reader = ObjectReader.new(empty_object)

      assert_equal reader, reader.read

      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal SDL4R::ROOT_TAG_NAME, reader.name
      assert_equal false, reader.values?
      assert_equal false, reader.attributes?

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_nil reader.read
    end

    def test_simple_element_with_value
      reader = ObjectReader.new(:a => 1)

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal SDL4R::ROOT_TAG_NAME, reader.name
      assert_equal false, reader.self_closing?

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal 'a', reader.name
      assert_equal true, reader.values?
      assert_equal [1], reader.values
      assert_equal 1, reader.value
      assert_equal [], reader.attributes
      assert_equal false, reader.attributes?
      assert_equal 0, reader.attribute_count
      assert_equal true, reader.self_closing?

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_nil reader.read
    end

    def test_element_with_attribute
      reader = ObjectReader.new(:a => {:b => 'BB'})

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal SDL4R::ROOT_TAG_NAME, reader.name
      assert_equal false, reader.self_closing?

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal 'a', reader.name
      assert_equal false, reader.values?
      assert_equal [], reader.values
      assert_equal nil, reader.value
      assert_equal true, reader.attributes?
      assert_equal [['', 'b', 'BB']], reader.attributes
      assert_equal 1, reader.attribute_count
      assert_equal ['', 'b', 'BB'], reader.attribute_at(0)
      assert_equal 'BB', reader.attribute('', 'b')
      assert_equal nil, reader.attribute('ns', 'b')
      assert_equal true, reader.self_closing?

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_equal reader, reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_nil reader.read
    end

    def test_element_with_value_array
      reader = ObjectReader.new(:a => [nil, :symbol, 123])

      assert_not_nil reader.read
      assert_not_nil reader.read
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'a', reader.name
      assert_equal false, reader.attributes?
      assert_equal [nil, :symbol, 123], reader.values
    end

    def test_element_with_collection1
      reader = ObjectReader.new(:a => [{:b => 123}])

      assert_not_nil reader.read # root
      assert_not_nil reader.read # a
      assert_not_nil reader.read # anonymous with 'b' attribute
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal SDL4R::ANONYMOUS_TAG_NAME, reader.name
      assert_equal false, reader.values?
      assert_equal true, reader.attributes?
      assert_equal 1, reader.attribute_count
      assert_equal [['', 'b', 123]], reader.attributes
    end

    def test_element_with_collection2
      reader = ObjectReader.new(:a => [{:b => 123}, {:b => 123}])

      assert_not_nil reader.read # root
      assert_not_nil reader.read # a
      assert_equal false, reader.self_closing?

      assert_not_nil reader.read # anonymous with 'b' attribute
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal SDL4R::ANONYMOUS_TAG_NAME, reader.name
      assert_equal false, reader.values?
      assert_equal true, reader.attributes?
      assert_equal 1, reader.attribute_count
      assert_equal [['', 'b', 123]], reader.attributes

      assert_not_nil reader.read # anonymous with 'b' attribute
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_not_nil reader.read # second anonymous with 'b' attribute
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal '', reader.prefix
      assert_equal SDL4R::ANONYMOUS_TAG_NAME, reader.name
      assert_equal false, reader.values?
      assert_equal true, reader.attributes?
      assert_equal 1, reader.attribute_count
      assert_equal [['', 'b', 123]], reader.attributes
    end

    def test_open_struct
      o1 = OpenStruct.new
      o1.first_name = "Jack"
      o1.movie = [
          OpenStruct.new(:length => 2.5, :title => "cuckoo", :rating => nil),
          OpenStruct.new(:length => 2, :title => "wolf", :rating => 5)
      ]

      reader = ObjectReader.new(:actor => o1)

      assert_not_nil reader.read # root

      assert_not_nil reader.read # actor
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'actor', reader.name
      assert_equal [['', 'first_name', 'Jack']], reader.attributes
      assert_equal [], reader.values

      assert_not_nil reader.read # movie
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'movie', reader.name

      assert_not_nil reader.read # anonymous
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal SDL4R::ANONYMOUS_TAG_NAME, reader.name
      assert_equal 3, reader.attribute_count
      assert_equal 2.5, reader.attribute(:length)
      assert_equal 'cuckoo', reader.attribute(:title)
      assert_equal nil, reader.attribute(:rating)
      assert_not_nil reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_not_nil reader.read # anonymous
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal SDL4R::ANONYMOUS_TAG_NAME, reader.name
      assert_equal 2, reader.attribute(:length)
      assert_equal 'wolf', reader.attribute(:title)
      assert_equal 5, reader.attribute(:rating)
      assert_not_nil reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_not_nil reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_not_nil reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_not_nil reader.read
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_nil reader.read
      assert_nil reader.read # should consistently return nil from here on
    end

    def test_rewind
      reader = ObjectReader.new(:a => 1, :b => 2)

      assert_not_nil reader.read # root
      assert_not_nil reader.read # a

      assert_equal true, reader.rewindable?

      reader.rewind

      assert_not_nil reader.read # root
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal SDL4R::ROOT_TAG_NAME, reader.name

      assert_not_nil reader.read # a
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'a', reader.name
    end

    def test_object_cycle
      a = OpenStruct.new
      b = OpenStruct.new
      c = OpenStruct.new

      a.b = b
      b.c = c
      c.a = a

      reader = ObjectReader.new(:a => a)

      assert_not_nil reader.read # root

      assert_not_nil reader.read # a
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'a', reader.name
      a_oid = reader.attribute('oid')
      assert_not_nil a_oid, "a.oid"

      assert_not_nil reader.read # b

      assert_not_nil reader.read # c
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'c', reader.name

      assert_not_nil reader.read # reference to a
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'a', reader.name
      assert_equal [['', 'oref', a_oid]], reader.attributes

      assert_not_nil reader.read # cycle should end here
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type
    end

    def test_same_object_twice
      a = OpenStruct.new(:name => 'my name')
      reader = ObjectReader.new(:a1 => a, :a2 => a)

      assert_not_nil reader.read # root

      assert_not_nil reader.read # a1
      assert_equal 'a1', reader.name
      a_oid = reader.attribute('oid')
      assert_not_nil a_oid, "a.oid"

      assert_not_nil reader.read # cycle should end here
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.node_type

      assert_not_nil reader.read # reference to a
      assert_equal AbstractReader::TYPE_ELEMENT, reader.node_type
      assert_equal 'a2', reader.name
      assert_equal [['', 'oref', a_oid]], reader.attributes
    end

    def test_root_twice
      root = OpenStruct.new
      root.a = OpenStruct.new
      root.a.b = root

      reader = ObjectReader.new(root)

      assert_not_nil reader.read # root

      assert_not_nil reader.read # oid element
      assert_equal 'oid', reader.name
      assert_not_nil reader.value
      root_oid = reader.value
      assert_equal AbstractReader::TYPE_END_ELEMENT, reader.read.node_type

      assert_not_nil reader.read # a

      assert_not_nil reader.read # b
      assert_equal 'b', reader.name
      assert_equal root_oid, reader.attribute(:oref)
    end
  end
end