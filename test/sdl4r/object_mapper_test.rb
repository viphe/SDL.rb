#!/usr/bin/env ruby -w
# encoding: UTF-8

module SDL4R

  require 'ostruct'
  require 'test/unit'
  require 'sdl4r'
  require 'sdl4r/object_mapper'
  require "sdl4r/sdl_test_case"

  class ObjectMapperTest < Test::Unit::TestCase
    include SdlTestCase

    def collect_each_property(object)

      object_mapper = ObjectMapper.new

      object_mapper.start_recording
      object_mapper.each_property(object) {}
      object_mapper.stop_recording

      properties = []
      object_mapper.each_property(object) { |*args|
        properties.push(args)
      }

      properties.sort! { |a,b| a[1] <=> b[1] }
      properties
    end

    # Class used for serialization tests
    # a is a private instance variable
    # b has a read accessor
    # c has read/write accessors
    # d has read/write accessors and the read accessor can take an optional parameter
    # e has read/write accessors and the read accessor takes a parameter (not a real accessor, then)
    class SerializeA

      def initialize(a, b, c, d, e)
        @a = a
        @b = b
        @c = c
        @d = d
        @e = e
      end

      attr_reader :b

      def c
        @c + 1
      end

      attr_writer :c

      def d(x = 0)
        @d + 1
      end

      attr_writer :d

      def e(x)
        @e + 1
      end

      attr_writer :e

    end

    def test_each_property
      assert_equal [], collect_each_property(nil)

      assert_equal [], collect_each_property([])
      assert_equal(
          [
              ['', SDL4R::ANONYMOUS_TAG_NAME, 1, :element],
              ['', SDL4R::ANONYMOUS_TAG_NAME, 2, :element],
              ['', SDL4R::ANONYMOUS_TAG_NAME, 3, :element]
          ],
          collect_each_property([1, 2, 3])
      )

      # Hashes (attributes)
      assert_equal [], collect_each_property({})
      assert_equal [['', 'name', 'Robert', :attribute]], collect_each_property('name' => 'Robert')
      assert_equal [['', 'name', 'Robert', :attribute]], collect_each_property(:name => 'Robert')
      assert_equal [['', 'name', :Robert, :attribute]], collect_each_property(:name => :Robert)
      assert_equal [['', 'age', 67, :attribute]], collect_each_property('age' => 67)
      assert_equal(
        [['', 'age', 67, :attribute], ['', 'name', 'Robert', :attribute]],
        collect_each_property('name' => 'Robert', 'age' => 67))

      # Hashes (elements)
      object = Object.new
      assert_equal [['', 'o', object, :element]], collect_each_property('o' => object)
      assert_equal [['', 'numbers', [1, 2, 3], :element]], collect_each_property(:numbers => [1, 2, 3])
      assert_equal [['', 'o', [], :element]], collect_each_property('o' => [])
      assert_equal [['', 'o', [object], :element]], collect_each_property('o' => [object])
      assert_equal [['', 'o', [123, object], :element]], collect_each_property('o' => [123, object])

      # OpenStruct
      open_struct = OpenStruct.new
      assert_equal [], collect_each_property(open_struct)

      open_struct.name = 'Robert'
      assert_equal [['', 'name', 'Robert', :attribute]], collect_each_property(open_struct)

      open_struct.o = object
      assert_equal [['', 'name', 'Robert', :attribute], ['', 'o', object, :element]], collect_each_property(open_struct)

      open_struct.o = nil
      assert_equal [['', 'name', 'Robert', :attribute], ['', 'o', nil, :attribute]], collect_each_property(open_struct)

      # Regular object
      serializeA = SerializeA.new(1, 2, 3, 4, 5)
      assert_equal(
          [
              ['', 'a', 1, :attribute],
              ['', 'b', 2, :attribute],
              ['', 'c', 4, :attribute],
              ['', 'd', 5, :attribute],
              ['', 'e', 5, :attribute],
          ],
          collect_each_property(serializeA)
      )
    end
  end
end