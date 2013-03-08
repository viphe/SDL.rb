#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
#
# Simple Declarative Language (SDL) for Ruby
# Copyright 2005 Ikayzo, inc.
#
# This program is free software. You can distribute or modify it under the
# terms of the GNU Lesser General Public License version 2.1 as published by
# the Free Software Foundation.
#
# This program is distributed AS IS and WITHOUT WARRANTY. OF ANY KIND,
# INCLUDING MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, contact the Free Software Foundation, Inc.,
# 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
#++

# Work-around a bug in NetBeans (http://netbeans.org/bugzilla/show_bug.cgi?id=188653)
if ENV["NB_EXEC_EXTEXECUTION_PROCESS_UUID"]
  $:[0] = File.join(File.dirname(__FILE__),'../../lib')
  $:.unshift(File.join(File.dirname(__FILE__),'../../test'))
end

if RUBY_VERSION < '1.9.0'
  $KCODE = 'u'
  require 'jcode'
end

module SDL4R

  require 'fileutils'
  require 'pathname'
  require 'date'
  require 'test/unit'
  
  require 'sdl4r'

  require 'sdl4r/sdl_test_case'

  class SDL4RTest < Test::Unit::TestCase
    include SdlTestCase
    
    # Tag datastructure tests
    TAG = "Tag"
    TAG_WRITE_PARSE = "Tag Write Parse"

    # Basic Types Tests
    STRING_DECLARATIONS = "String Declarations"
    CHARACTER_DECLARATIONS = "Character Declarations"
    NUMBER_DECLARATIONS = "Number Declarations"
    BOOLEAN_DECLARATIONS = "Boolean Declarations"
    NULL_DECLARATION = "Null Declaration"
    DATE_DECLARATIONS = "Date Declarations"
    TIME_SPAN_DECLARATIONS = "Time Span Declarations"
    DATE_TIME_DECLARATIONS = "Date Time Declarations"
    BINARY_DECLARATIONS = "Binary Declarations"

    # Structure Tests
    EMPTY_TAG = "Empty Tag"
    VALUES = "Values"
    ATTRIBUTES = "Attributes"
    VALUES_AND_ATTRIBUTES = "Values and Attributes"
    CHILDREN = "Children"
    NAMESPACES = "Namespaces"


    def assert_tags_equal(expected, actual, message)
      if expected != actual
        assert_equal(expected.to_s, actual.to_s, message)
      end
    end

    # Returns a Pathname giving the location of the specified relative +filename+.
    #
    # +filename+:: path to a file relatively to this source file
    #
    def get_test_sdl_file_path(filename)
      dir = File.dirname(__FILE__)
      return Pathname.new(dir + '/' + filename)
    end

    @@root_basic_types = nil
    @@root_structures = nil

    def setup
      super

      @@root_basic_types ||= SDL4R::read(get_test_sdl_file_path("test_basic_types.sdl"))
      @@root_structures ||= SDL4R::read(get_test_sdl_file_path("test_structures.sdl"))
    end

    ######################################
    # Tag Tests
    ######################################
    def test_tag
      # Test to make sure Tag ignores the order in which attributes are
      # added.
      t1 = Tag.new("test")
      t1.set_attribute("foo", "bar")
      t1.set_attribute("john", "doe")

      t2 = Tag.new("test")
      t2.set_attribute("john", "doe")
      t2.set_attribute("foo", "bar")

      assert_tags_equal(t1, t2, TAG)

      # Making sure tags with different structures are not equal with ==
      t2.value = "item"
      assert_not_equal(t1, t2, TAG)

      t2.remove_value("item")
      t2.set_attribute("another", "attribute")
      assert_not_equal(t1, t2, TAG)

      # Checking attributes namespaces
      t2.set_attribute("name", "bill")
      t2.set_attribute("private", "smoker", true)
      t2.set_attribute("public", "hobby", "hiking")
      t2.set_attribute("private", "nickname", "tubby")

      assert_equal(
        t2.attributes("private"),
        { "smoker" => true, "nickname" => "tubby" },
        "attributes()")
    end

    def test_tag_write_parse_basic_types
      check_tag_write_parse @@root_basic_types
    end

    def test_tag_write_parse_structures
      check_tag_write_parse @@root_structures
    end

    #
    # Does a to_s/parse test on the specified Tag (+root+)
    #
    def check_tag_write_parse(root)
#      puts '========================================'
#      puts root.to_s
#      puts '========================================'

      write_parse_root = Tag.new("test").read(root.to_s).child("root")

      File.open("/tmp/root.sdl", "w") { |io| io.write(root.to_string) }
      File.open("/tmp/root_reparsed.sdl", "w") { |io| io.write(write_parse_root.to_string) }

      assert_tags_equal(root, write_parse_root, "write/parse")
    end

    ######################################
    # Basic Types Tests
    ######################################

    def test_strings
      root = @@root_basic_types

      # Doing String tests...
      # Doing basic tests including new line handling...
      assert_equal(root.child("string1").value, "hello", STRING_DECLARATIONS)
      assert_equal(root.child("string2").value, "hi", STRING_DECLARATIONS)
      assert_equal(root.child("string3").value, "aloha", STRING_DECLARATIONS)
      assert_equal(root.child("string4").value, "hi there", STRING_DECLARATIONS)
      assert_equal(root.child("string5").value, "hi there joe", STRING_DECLARATIONS)
      assert_equal(root.child("string6").value, "line1\nline2", STRING_DECLARATIONS)
      assert_equal(root.child("string7").value, "line1\nline2", STRING_DECLARATIONS)
      assert_equal(root.child("string8").value, "line1\nline2\nline3", STRING_DECLARATIONS)
      assert_equal(
        root.child("string9").value,
        "Anything should go in this line without escapes \\ \\\\ \\n " +
        "\\t \" \"\" ' ''", STRING_DECLARATIONS)
      assert_equal(root.child("string10").value, "escapes \"\\\n\t", STRING_DECLARATIONS)

      # Checking unicode strings...
      assert_equal(root.child("japanese.hello").value, "日本語", STRING_DECLARATIONS)
      assert_equal(root.child("korean.hello").value, "여보세요", STRING_DECLARATIONS)
      assert_equal(root.child("russian.hello").value, "здравствулте", STRING_DECLARATIONS)
        
      # More new line tests...
      assert(root.child("xml").value.index("<text>Hi there!</text>") >= 0, STRING_DECLARATIONS)
      assert_equal(root.child("line_test").value, "\nnew line above and below\n", STRING_DECLARATIONS)
    end

    def test_characters
      root = @@root_basic_types

      assert_equal(root.child("char1").value, 'a', CHARACTER_DECLARATIONS)
      assert_equal(root.child("char2").value, 'A', CHARACTER_DECLARATIONS)
      assert_equal(root.child("char3").value, '\\', CHARACTER_DECLARATIONS)
      assert_equal(root.child("char4").value, "\n", CHARACTER_DECLARATIONS)
      assert_equal(root.child("char5").value, "\t", CHARACTER_DECLARATIONS)
      assert_equal(root.child("char6").value, '\'', CHARACTER_DECLARATIONS)
      assert_equal(root.child("char7").value, '"', CHARACTER_DECLARATIONS)
    end

    def test_characters_unicode
      root = @@root_basic_types

      assert_equal(root.child("char8").value, "日", CHARACTER_DECLARATIONS) # \u65e5
      assert_equal(root.child("char9").value, "여", CHARACTER_DECLARATIONS) # \uc5ec
      assert_equal(root.child("char10").value, "з", CHARACTER_DECLARATIONS) # \u0437
    end

    def test_numbers
      root = @@root_basic_types

      # Testing ints...
      assert_equal(root.child("int1").value, 0, NUMBER_DECLARATIONS)
      assert_equal(root.child("int2").value, 5, NUMBER_DECLARATIONS)
      assert_equal(root.child("int3").value, -100, NUMBER_DECLARATIONS)
      assert_equal(root.child("int4").value, 234253532, NUMBER_DECLARATIONS)

      # Testing longs...
      assert_equal(root.child("long1").value, 0, NUMBER_DECLARATIONS)
      assert_equal(root.child("long2").value, 5, NUMBER_DECLARATIONS)
      assert_equal(root.child("long3").value, 5, NUMBER_DECLARATIONS)
      assert_equal(root.child("long4").value, 3904857398753453453, NUMBER_DECLARATIONS)

      # Testing floats...
      assert_equal(root.child("float1").value, 1, NUMBER_DECLARATIONS)
      assert_equal(root.child("float2").value, 0.23, NUMBER_DECLARATIONS)
      assert_equal(root.child("float3").value, -0.34, NUMBER_DECLARATIONS)

      # Testing doubles..."
      assert_equal(root.child("double1").value, 2, NUMBER_DECLARATIONS)
      assert_equal(root.child("double2").value, -0.234, NUMBER_DECLARATIONS)
      assert_equal(root.child("double3").value, 2.34, NUMBER_DECLARATIONS)

      # Testing decimals (BigDouble in Java)...
      assert_equal(
        root.child("decimal1").value, 0, NUMBER_DECLARATIONS)
      assert_equal(
        root.child("decimal2").value, 11.111111, NUMBER_DECLARATIONS)
      assert_equal(
        root.child("decimal3").value,
        BigDecimal.new('234535.3453453453454345345341242343'),
        NUMBER_DECLARATIONS)
    end

    def test_booleans
      root = @@root_basic_types

      assert_equal(root.child("light-on").value, true, BOOLEAN_DECLARATIONS)
      assert_equal(root.child("light-off").value, false, BOOLEAN_DECLARATIONS)
      assert_equal(root.child("light1").value, true, BOOLEAN_DECLARATIONS)
      assert_equal(root.child("light2").value, false, BOOLEAN_DECLARATIONS)
    end

    def test_null
      root = @@root_basic_types

      assert_equal(root.child("nothing").value, nil, NULL_DECLARATION)
    end
      
    def test_dates
      root = @@root_basic_types

      assert_equal(root.child("date1").value, Date.civil(2005, 12, 31), DATE_DECLARATIONS)
      assert_equal(root.child("date2").value, Date.civil(1882, 5, 2), DATE_DECLARATIONS)
      assert_equal(root.child("date3").value, Date.civil(1882, 5, 2), DATE_DECLARATIONS)
      assert_equal(root.child("_way_back").value, Date.civil(582, 9, 16), DATE_DECLARATIONS)
    end
    
    def test_time_spans
      root = @@root_basic_types

      assert_equal(
        root.child("time1").value, SdlTimeSpan.new(0,12,30,0,0), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time2").value, SdlTimeSpan.new(0,24,0,0,0), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time3").value, SdlTimeSpan.new(0,1,0,0,0), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time4").value, SdlTimeSpan.new(0,1,0,0,0), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time5").value, SdlTimeSpan.new(0,12,30,2,0), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time6").value, SdlTimeSpan.new(0,12,30,23,0), TIME_SPAN_DECLARATIONS)
      assert_equal(
        SdlTimeSpan.new(0,12,30,23,100), root.child("time7").value, TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time8").value, SdlTimeSpan.new(0,12,30,23,120), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time9").value, SdlTimeSpan.new(0,12,30,23,123), TIME_SPAN_DECLARATIONS)

      # Checking time spans with days...
      assert_equal(
        root.child("time10").value, SdlTimeSpan.new(34,12,30,23,100), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time11").value, SdlTimeSpan.new(1,12,30,0,0), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time12").value, SdlTimeSpan.new(5,12,30,23,123), TIME_SPAN_DECLARATIONS)

      # Checking negative time spans...
      assert_equal(
        root.child("time13").value, SdlTimeSpan.new(0,-12,-30,-23,-123), TIME_SPAN_DECLARATIONS)
      assert_equal(
        root.child("time14").value, SdlTimeSpan.new(-5,-12,-30,-23,-123), TIME_SPAN_DECLARATIONS)
    end

    def test_date_times
      root = @@root_basic_types
      local_offset = DateTime.now.offset

      assert_equal(root.child("date_time1").value,
          DateTime.civil(2005,12,31,12,30,0, local_offset), DATE_TIME_DECLARATIONS)
      assert_equal(root.child("date_time2").value,
          DateTime.civil(1882,5,2,12,30,0, local_offset), DATE_TIME_DECLARATIONS)
      assert_equal(root.child("date_time3").value,
          DateTime.civil(2005,12,31,1,0,0, local_offset), DATE_TIME_DECLARATIONS)
      assert_equal(root.child("date_time4").value,
          DateTime.civil(1882,5,2,1,0,0, local_offset), DATE_TIME_DECLARATIONS)
      assert_equal(root.child("date_time5").value,
          DateTime.civil(2005,12,31,12,30,2312.to_r/100, local_offset), DATE_TIME_DECLARATIONS)
      assert_equal(root.child("date_time6").value,
          DateTime.civil(1882,5,2,12,30,23123.to_r/1000, local_offset), DATE_TIME_DECLARATIONS)

      # Checking timezones...
      assert_equal(root.child("date_time7").value,
          DateTime.civil(1882,5,2,12,30,23123.to_r/1000,"JST"), DATE_TIME_DECLARATIONS)
      assert_equal(root.child("date_time8").value,
          DateTime.civil(985,04,11,12,30,23123.to_r/1000,"PST"), DATE_TIME_DECLARATIONS)
    end

    def test_binaries
      root = @@root_basic_types

      assert_equal(SDL4R::SdlBinary("hi"), root.child("hi").value, BINARY_DECLARATIONS)
      assert_equal(
        SDL4R::SdlBinary("hi"), root.child("hi").value, BINARY_DECLARATIONS)
      assert_equal(
        SdlBinary.decode64(
          "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAKnRFWHRDcmVhdGlvbiBUaW1l" +
          "AERpIDQgTXJ6IDIwMDMgMDA6MjQ6MDQgKzAxMDDdSQ6OAAAAB3RJTUUH0wMEAAcllPlrJgAA" +
          "AAlwSFlzAAAK8AAACvABQqw0mAAAAARnQU1BAACxjwv8YQUAAADQSURBVHjaY2CgEDCCyZn/" +
          "3YHkDhL1ejCkM+5kgXJ2zDQmXueShwwMh9+ALWSEGcCQfhZIvHlDnAk8PAwMHBxgJtyAa7bX" +
          "UdT8/cvA8Ps3hP7zB4FBYn/+vGbweqyJaoCmpiaKASDFv35BNMBoZMzwGKKOidJYoNgAuBdm" +
          "naXQgHRKDfgagxD89w8S+iAaFICwGIHFAgjrHUczAByySAaAMEgDLBphhv7/D8EYLgDZhAxA" +
          "mkAKYYbAMMwwDAOQXYDuDXRXgDC6AR7SW8jITNQAACjZgdj4VjlqAAAAAElFTkSuQmCC"
        ),
        root.child("png").value,
        BINARY_DECLARATIONS)
    end

    ######################################
    # Structure Tests (values, attributes, children)
    ######################################

    def test_empty_tag
      root = @@root_structures
      assert_equal(root.child("empty_tag"), Tag.new("empty_tag"), EMPTY_TAG)
    end

    def test_values
      root = @@root_structures
      local_offset = DateTime.now.offset

      assert_equal(root.child("values1").values, ["hi"], VALUES)
      assert_equal(root.child("values2").values, ["hi","ho"], VALUES)
      assert_equal(root.child("values3").values, [1, "ho"], VALUES)
      assert_equal(root.child("values4").values, ["hi",5], VALUES)
      assert_equal(root.child("values5").values, [1,2], VALUES)
      assert_equal(root.child("values6").values, [1,2,3], VALUES)
      assert_equal(
        root.child("values7").values,
        [nil,"foo",false,Date.civil(1980,12,5)],
        VALUES)
      assert_equal(
        root.child("values8").values,
        [nil, "foo", false, DateTime.civil(1980,12,5,12,30,0,local_offset),
          "there", SdlTimeSpan.new(0,15,23,12,234)],
        VALUES)
      assert_equal(
        root.child("values9").values,
        [nil, "foo", false, DateTime.civil(1980,12,5,12,30,0,local_offset),
          "there", DateTime.civil(1989,8,12,15,23,12234.to_r/1000,"JST")],
        VALUES)
      assert_equal(
        root.child("values10").values,
        [nil, "foo", false, DateTime.civil(1980,12,5,12,30,0,local_offset),
          "there", SdlTimeSpan.new(0,15,23,12,234), "more stuff"],
        VALUES)
      assert_equal(
        root.child("values11").values,
        [nil, "foo", false, DateTime.civil(1980,12,5,12,30,0,local_offset),
          "there", SdlTimeSpan.new(123,15,23,12,234), "more stuff here"],
         VALUES)
      assert_equal(root.child("values12").values, [1,3], VALUES)
      assert_equal(root.child("values13").values, [1,3], VALUES)
      assert_equal(root.child("values14").values, [1,3], VALUES)
      assert_equal(root.child("values15").values, [1,2,4,5,6], VALUES)
      assert_equal(root.child("values16").values, [1,2,5], VALUES)
      assert_equal(root.child("values17").values, [1,2,5], VALUES)
      assert_equal(root.child("values18").values, [1,2,7], VALUES)
      assert_equal(root.child("values19").values, [1,3,5,7], VALUES)
      assert_equal(root.child("values20").values, [1,3,5], VALUES)
      assert_equal(root.child("values21").values, [1,3,5], VALUES)
      assert_equal(root.child("values22").values, ["hi","ho","ho",5,"hi"], VALUES)
    end
      
    def test_attributes
      root = @@root_structures

      assert_equal(
        root.child("atts1").attributes, {"name" => "joe"}, ATTRIBUTES)
      assert_equal(root.child("atts2").attributes, {"size" => 5}, ATTRIBUTES)
      assert_equal(
        root.child("atts3").attributes, {"name" => "joe","size" => 5}, ATTRIBUTES)
      assert_equal(
        root.child("atts4").attributes, {"name"=>"joe","size"=>5,"smoker"=>false},
        ATTRIBUTES)
      assert_equal(
        root.child("atts5").attributes, {"name"=>"joe","smoker"=>false}, ATTRIBUTES)
      assert_equal(
        root.child("atts6").attributes, {"name"=>"joe","smoker"=>false}, ATTRIBUTES)
      assert_equal(root.child("atts7").attributes, {"name"=>"joe"}, ATTRIBUTES)
      assert_equal(
        root.child("atts8").attributes,
        {"name"=>"joe","size"=>5,"smoker"=>false,
          "text"=>"hi","birthday"=>Date.civil(1972,5,23)},
        ATTRIBUTES)
      assert_equal(
        root.child("atts9").attribute("key"), SDL4R::SdlBinary("mykey"), ATTRIBUTES)
    end

    def test_values_and_attributes
      root = @@root_structures

      assert_equal(root.child("valatts1").values, ["joe"], VALUES_AND_ATTRIBUTES)
      assert_equal(
        root.child("valatts1").attributes, {"size"=>5}, VALUES_AND_ATTRIBUTES)

      assert_equal(root.child("valatts2").values, ["joe"], VALUES_AND_ATTRIBUTES)
      assert_equal(root.child("valatts2").attributes, {"size"=>5}, VALUES_AND_ATTRIBUTES)

      assert_equal(root.child("valatts3").values, ["joe"], VALUES_AND_ATTRIBUTES)
      assert_equal(root.child("valatts3").attributes, {"size"=>5}, VALUES_AND_ATTRIBUTES)

      assert_equal(root.child("valatts4").values, ["joe"], VALUES_AND_ATTRIBUTES)
      assert_equal(
        root.child("valatts4").attributes,
        {"size"=>5, "weight"=>160, "hat"=>"big"},
        VALUES_AND_ATTRIBUTES)

      assert_equal(
        root.child("valatts5").values, ["joe", "is a\n nice guy"], VALUES_AND_ATTRIBUTES)
      assert_equal(
        root.child("valatts5").attributes,
        {"size"=>5, "smoker"=>false},
        VALUES_AND_ATTRIBUTES)

      assert_equal(
        root.child("valatts6").values, ["joe", "is a\n nice guy"], VALUES_AND_ATTRIBUTES)
      assert_equal(
        root.child("valatts6").attributes,
        {"size"=>5, "house"=>"big and\n blue"},
        VALUES_AND_ATTRIBUTES)

      #####

      assert_equal(
        root.child("valatts7").values, ["joe", "is a\n nice guy"], VALUES_AND_ATTRIBUTES)
      assert_equal(
        root.child("valatts7").attributes,
        {"size"=>5, "smoker"=>false},
        VALUES_AND_ATTRIBUTES)

      assert_equal(
        root.child("valatts8").values, ["joe", "is a\n nice guy"], VALUES_AND_ATTRIBUTES)
      assert_equal(
        root.child("valatts8").attributes,
        {"size"=>5, "smoker"=>false},
        VALUES_AND_ATTRIBUTES)

      assert_equal(
        root.child("valatts9").values,["joe", "is a\n nice guy"], VALUES_AND_ATTRIBUTES)
      assert_equal(
        root.child("valatts9").attributes,
        {"size"=>5, "smoker"=>false},
        VALUES_AND_ATTRIBUTES)
    end

    def test_children
      root = @@root_structures
      parent = root.child("parent")

      assert_equal(parent.children.size, 2, CHILDREN)
      assert_equal(parent.children[1].name, "daughter", CHILDREN)

      grandparent = root.child("grandparent")

      assert_equal(grandparent.children.size, 2, CHILDREN)
      # recursive fetch of children
      assert_equal(grandparent.children(true).size, 6, CHILDREN)
      assert_equal(grandparent.children(true, "son").size, 2, CHILDREN)

      grandparent2 = root.child("grandparent2")
      assert_equal(grandparent2.children(true, "child").size, 5, CHILDREN)
      assert_equal(
        grandparent2.child(true, "daughter").attribute("birthday"),
        Date.civil(1976,04,18),
        CHILDREN)

      files = root.child("files")

      assert_equal(
        ["c:/file1.txt", "c:/file2.txt", "c:/folder"],
        files.children_values("content"),
        CHILDREN)

      matrix = root.child("matrix")

      assert_equal([[1,2,3],[4,5,6]], matrix.children_values("content"), CHILDREN)
    end

    def test_namespaces
      root = @@root_structures
      assert_equal(8, root.children(true, "person", nil).size, NAMESPACES)

      grandparent3 = root.child("grandparent3")

      # get only the attributes for Akiko in the public namespace
      assert_equal(
        {"name"=>"Akiko", "birthday"=>Date.civil(1976,04,18)},
        grandparent3.child(true, "daughter").attributes("public"),
        NAMESPACES)
    end

    def test_validate_identifier
      assert_nothing_raised { SDL4R::validate_identifier('myName') }
      assert_nothing_raised { SDL4R::validate_identifier('my-name') }
      assert_nothing_raised { SDL4R::validate_identifier('my_name') }
      assert_nothing_raised { SDL4R::validate_identifier('_my-name') }
      assert_nothing_raised { SDL4R::validate_identifier('my_name_') }
      assert_nothing_raised { SDL4R::validate_identifier('com.ikayzo.foo') }
      assert_nothing_raised { SDL4R::validate_identifier('com.ikayzo.foo$1') }
      
      if SDL4R::supports_unicode_identifiers?
        assert_nothing_raised { SDL4R::validate_identifier('まName') }
        assert_nothing_raised { SDL4R::validate_identifier('myNäme') }
        assert_nothing_raised { SDL4R::validate_identifier('なまえ') }
      end

      assert_raise ArgumentError do SDL4R::validate_identifier('1myName') end
      assert_raise ArgumentError do SDL4R::validate_identifier('$myName') end
      assert_raise ArgumentError do SDL4R::validate_identifier('.myName') end
      assert_raise ArgumentError do SDL4R::validate_identifier('my Name') end
      assert_raise ArgumentError do SDL4R::validate_identifier(' myName') end
      assert_raise ArgumentError do SDL4R::validate_identifier('myName ') end
    end

    def test_coerce_or_fail
      # Most basic types are considered to be tested in other tests (like ParserTest)
      tag = Tag.new "tag1"
      assert_raise ArgumentError do tag.add_value(Object.new) end
      assert_raise ArgumentError do tag.add_value([1, 2, 3]) end
      assert_raise ArgumentError do tag.add_value({"a" => "b"}) end

      # check translation of Rational
      tag.add_value(Rational(3, 10))
      assert_equal [0.3], tag.values
    end

    def test_format_times
      # Using DateTime
      date = DateTime.civil(1989, 11, 13, 14, 15, 37)
      assert_equal "1989/11/13 14:15:37", SDL4R::format(date)

      date = DateTime.civil(1989, 11, 13, 14, 15, 37, Rational(-5, 24))
      assert_equal "1989/11/13 14:15:37-GMT-05:00", SDL4R::format(date)

      date = DateTime.civil(1989, 11, 13, 14, 15, 37055.to_r/1000)
      assert_equal "1989/11/13 14:15:37.055", SDL4R::format(date)

      date = DateTime.civil(1989, 11, 13, 14, 15, 37055.to_r/1000, Rational(6, 24))
      assert_equal "1989/11/13 14:15:37.055-GMT+06:00", SDL4R::format(date)

      # Using Time
      time = Time.gm(1989, 11, 13, 14, 15, 37)
      assert_equal "1989/11/13 14:15:37", SDL4R::format(time)

      time = Time.gm(1989, 11, 13, 14, 15, 37, 55000)
      assert_equal "1989/11/13 14:15:37.055", SDL4R::format(time)
    end

    # Date parsing tests using Time rather than DateTime
    def test_time
      SDL4R::use_datetime = false
      begin
         # no timezone
        root = SDL4R::read("tag1 1998/05/12 12:34:56.768")
        assert_kind_of Time, root.child.value
        assert_equal_date_time Time.local(1998, 05, 12, 12, 34, 56, 768000), root.child.value

        root = SDL4R::read("tag1 1998/05/12 12:34:56.768-UTC")
        assert_equal_date_time Time.utc(1998, 05, 12, 12, 34, 56, 768000), root.child.value

        root = SDL4R::read("tag1 1998/05/12 12:34:56.768-JST")
        assert_equal_date_time Time.xmlschema("1998-05-12T12:34:56.768-07:00"), root.child.value

        root = SDL4R::read("tag1 1998/05/12 12:34:56.768-GMT-01:00")
        assert_equal_date_time Time.xmlschema("1998-05-12T12:34:56.768-01:00"), root.child.value
       
      ensure
        SDL4R::use_datetime = true
      end
    end
    
    def test_format_strings
      assert_equal '""', SDL4R::format("")
      assert_equal '"a"', SDL4R::format("a")
      assert_equal '"ab"', SDL4R::format("ab")
    end
  end
end