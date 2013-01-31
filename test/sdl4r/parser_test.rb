#!/usr/bin/env ruby -w
# encoding: UTF-8

#--
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

  require 'rubygems'
  require 'bigdecimal'
  require 'test/unit'

  require "sdl4r/tag"
  
  require 'sdl4r/sdl_test_case'

  class ParserTest < Test::Unit::TestCase
    include SdlTestCase

    def test_empty
      root = Tag.new("root")
      root.read("")
      root.children(false) { fail("no child expected") }
    end

    def test_one_tag_alone
      # Tag without namespace
      tag1 = parse_one_tag1("tag1")
      assert_equal("tag1", tag1.name, "name" )
      assert_equal("", tag1.namespace, "namespace" )

      assert_equal(0, tag1.values.size, "values")
      assert_equal(0, tag1.attributes.size, "attributes")

      # Tag with namespace
      tag1 = SDL4R::read("ns1:tag1").child("ns1", "tag1")
      assert_equal("tag1", tag1.name, "name" )
      assert_equal("ns1", tag1.namespace, "namespace" )
    end

    def test_tag_with_one_value
      tag1 = parse_one_tag1("tag1 1")
      assert_not_nil(tag1, "tag1")
      assert_equal(1, tag1.value, "value")
    end

    def test_tag_with_two_values
      tag1 = parse_one_tag1("tag1 1 \"abc\"")
      assert_not_nil(tag1, "tag1")
      values = tag1.values
      assert_equal(1, values[0], "1st value")
      assert_equal("abc", values[1], "2nd value")
    end

    def test_tag_with_double_quote_string_values
      tag1 = parse_one_tag1("tag1 \"abc\" \"d\\\ne\\\nf\" \"g\\\n  \t hi\"")
      assert_not_nil(tag1, "tag1")
      values = tag1.values
      assert_equal("abc", values[0], "values[0]")
      assert_equal("def", values[1], "values[1]")
      assert_equal("ghi", values[2], "values[2]")
    end

    def test_tag_with_back_quote_string_values
      tag1 = parse_one_tag1(
        "tag1 `abc` \"d`e`f\" `g\"h\"i` `j\\k+l` `m\\\nn\\\r\n \t o\r`")
      assert_not_nil(tag1, "tag1")
      values = tag1.values
      assert_equal("abc", values[0], "values[0]")
      assert_equal("d`e`f", values[1], "values[1]")
      assert_equal("g\"h\"i", values[2], "values[2]")
      assert_equal("j\\k+l", values[3], "values[3]")
      assert_equal("m\\\nn\\\n \t o\r", values[4], "values[4]")
    end

    def test_tag_with_base64_values
      tag1 = parse_one_tag1(
        <<EOS
tag1 [V2VsY29tZSB0byB0aGUgY3J1ZWwgd29ybGQu] [
    SG9wZSB5
    b3UnbGwg
    ZmluZCB5
    b3VyIHdh
    eS4=
]
EOS
        )
      assert_not_nil(tag1, "tag1")
      values = tag1.values
      assert_equal(SDL4R::SdlBinary("Welcome to the cruel world."), values[0], "values[0]")
      assert_equal(SDL4R::SdlBinary("Hope you'll find your way."), values[1], "values[1]")
    end

    def test_tag_with_one_attribute
      tag1 = parse_one_tag1("tag1 attr1=99")
      assert_not_nil(tag1, "tag1")

      values = tag1.values
      assert(values.empty?, "value count")

      attributes = tag1.attributes
      assert_equal(1, attributes.size, "attribute count")
      assert_equal(99, attributes["attr1"], "attr1")

      # check the parsing with line continuations
      tag1 = parse_one_tag1("tag1\\\nattr1=\\\n99")
      assert_not_nil(tag1, "tag1")
      assert_equal(99, tag1.attribute("attr1"), "attr1")
    end

    def test_tag_with_attributes
      tag1 = parse_one_tag1(
        "tag1 attr1=\"99\" ns:attr2=[QmVhdXR5IGlzIG5vdCBlbm91Z2gu]")
      assert_not_nil(tag1, "tag1")

      attributes = tag1.attributes
      assert_equal(2, attributes.size, "attribute count")
      assert_equal("99", attributes["attr1"], "attr1")
      assert_equal(SDL4R::SdlBinary("Beauty is not enough."), attributes["ns:attr2"], "attr2")
    end
    
    def test_date
      tag1 = parse_one_tag1("tag1 2005/12/05")
      date = tag1.value
      assert_equal(Date.civil(2005, 12, 5), date, "date value")

      # check negative years
      tag1 = parse_one_tag1("tag1 -145/12/23");
      date = tag1.value
      assert_equal(Date.civil(-145, 12, 23), date, "negative year")
    end

    def test_time_span
      tag1 = parse_one_tag1(
        "tag1 time=12:23:56 short_time=00:12:32.423" +
        " long_time=30d:15:23:04.023 before=-00:02:30")
      assert_equal(
        SdlTimeSpan.new(0, 12, 23, 56),
        tag1.attribute("time"),
        "time");
      assert_equal(
        SdlTimeSpan.new(0, 0, 12, 32, 423),
        tag1.attribute("short_time"),
        "short_time");
      assert_equal(
        SdlTimeSpan.new(30, 15, 23, 4, 23),
        tag1.attribute("long_time"),
        "long_time");
      assert_equal(
        SdlTimeSpan.new(0, 0, -2, -30),
        tag1.attribute("before"),
        "before");
    end
    
    def test_date_time
      tag1 = parse_one_tag1(
        "tag1 date1=2008/06/01 12:34" +
        " date2=1999/12/31 23:59:58" +
        " date3=2000/05/01 12:01:35.997" +
        " date4=2015/12/05 14:12:23.345-JST" +
        " date5=1414/05/12 03:00:01.107-UTC-04" +
        " date6=1807/11/11 22:28:13.888-GMT-08:30")
      assert_equal(
        local_civil_date(2008, 6, 1, 12, 34),
        tag1.attribute("date1"),
        "date1");
      assert_equal(
        local_civil_date(1999, 12, 31, 23, 59, 58),
        tag1.attribute("date2"),
        "date2");
      assert_equal_date_time(
        local_civil_date(2000, 5, 1, 12, 1, Rational(35997, 1000)),
        tag1.attribute("date3"),
        "date3");
      assert_equal(
        local_civil_date(2015, 12, 5, 14, 12, Rational(23345, 1000), Rational(9, 24)),
        tag1.attribute("date4"),
        "date4");
      assert_equal(
        local_civil_date(1414, 5, 12, 3, 0, Rational(1107, 1000), Rational(-4, 24)),
        tag1.attribute("date5"),
        "date5");
      assert_equal(
        local_civil_date(1807, 11, 11, 22, 28, Rational(13888, 1000), Rational(-85, 240)),
        tag1.attribute("date6"),
        "date6");

      tag1 = parse_one_tag1("tag1 2008/06/01 5d:12:34") # not a datetime: a date + a timespan
      assert_equal Date.civil(2008, 6, 1), tag1.values[0]
      assert_equal SdlTimeSpan.new(5, 12, 34), tag1.values[1]

      # Check that the timezone is correct when and where day saving time is in use
# FIXME: neither DateTime/Date nor Time seem to handle zones and DST correctly.
#      tag1 = parse_one_tag1("tag1 2001/01/01 12:00:00-CET") # winter time
#      assert_equal(local_civil_date(2001, 01, 01, 12, 0, 0, Rational(1, 24)), tag1.value)
#      tag1 = parse_one_tag1("tag1 2001/07/01 12:00:00-CET") # summer time
#      assert_equal(local_civil_date(2001, 01, 01, 12, 0, 0, Rational(2, 24)), tag1.value)
    end

    def test_numbers
      tag1 = parse_one_tag1(
        "tag1 123 3000000000 456l 789L 123.45f 67.8F" +
          " 910.11 12.13d 1415.16D 171.8BD 1.920bd 12345678901234567890BD -13.05")
      values = tag1.values
      assert_equal(123, values[0])
      assert_equal(3000000000, values[1])
      assert_equal(456, values[2])
      assert_equal(789, values[3])
      assert_equal(123.45, values[4])
      assert_equal(67.8, values[5])
      assert_equal(910.11, values[6])
      assert_equal(12.13, values[7])
      assert_equal(1415.16, values[8])
      assert_equal(BigDecimal("171.8"), values[9])
      assert_equal(BigDecimal("1.920"), values[10])
      assert_equal(BigDecimal("12345678901234567890"), values[11])
      assert_equal(-13.05, values[12])

      assert_raise SdlParseError do
        parse_one_tag1("tag1 123.2.2")
      end
      assert_raise SdlParseError do
        parse_one_tag1("tag1 123.2e")
      end
      assert_raise SdlParseError do
        parse_one_tag1("tag1 +-123.2")
      end
    end

    def test_booleans
      tag1 = parse_one_tag1("tag1 b1=true b2=false b3=on b4=off")
      assert_equal(true, tag1.attribute("b1"))
      assert_equal(false, tag1.attribute("b2"))
      assert_equal(true, tag1.attribute("b3"))
      assert_equal(false, tag1.attribute("b4"))
    end

    def test_null
      tag1 = parse_one_tag1("tag1 null attr1=null")
      values = tag1.values
      assert_equal(1, values.size)
      assert_equal(nil, values[0])
      assert_equal(nil, tag1.attribute("attr1"))
      assert(tag1.has_attribute?("attr1"))
    end

    def test_comments
      root = Tag.new("root")
      root.read(
              <<EOS
tag1 123
#tag2 456
tag3 789
--tag4 012
tag5 345
//tag6 678
tag7 901
/*tag8 234
tag9 567*/
tag10 890
EOS
      )
      children = root.children
      assert_equal(5, children.size, "children count")
      assert_equal(123, root.child("tag1").value)
      assert_nil(root.child("tag2"))
      assert_equal(789, root.child("tag3").value)
      assert_nil(root.child("tag4"))
      assert_equal(345, root.child("tag5").value)
      assert_nil(root.child("tag6"))
      assert_equal(901, root.child("tag7").value)
      assert_nil(root.child("tag8"))
      assert_nil(root.child("tag9"))
      assert_equal(890, root.child("tag10").value)
    end

    def test_double_quote_strings
      root = SDL4R::read(
<<EOS
tag1 "cheese and cherry jam"
tag2 "cheese and \\
      cherry jam"
tag3 "cheese \\
      and \\
      cherry jam"
tag4 "Did you say this soup was \\"good\\"?"
tag5 "Even my dog wouldn't\\thave\\tit!"
tag6 "\\"\\t\\r\\n\\\\"
tag7 equation="is not x=y*z" color="blue \\
                                    and yellow"
EOS
      )

      assert_equal "cheese and cherry jam", root.child("tag1").value, "double-quote string"
      assert_equal(
        "cheese and cherry jam", root.child("tag2").value, "continued double-quote string")
      assert_equal(
        "cheese and cherry jam", root.child("tag3").value, "continued double-quote string")
      assert_equal(
        'Did you say this soup was "good"?', root.child("tag4").value, "escaped quotes")
      assert_equal(
        "Even my dog wouldn't\thave\tit!", root.child("tag5").value, "escaped tabs")
      assert_equal "\"\t\r\n\\", root.child("tag6").value, "escaped white spaces"
      assert_equal "is not x=y*z", root.child("tag7").attribute("equation")
      assert_equal "blue and yellow", root.child("tag7").attribute("color")
    end

    def test_characters
      root = SDL4R::read "tag1 ' ' 'a' '\\\\' '\\t' '\\n' '\\r'"
      assert_equal [" ", "a", "\\", "\t", "\n", "\r"], root.child("tag1").values

      assert_raise SdlParseError do
        SDL4R::read "tag1 '"
      end
      assert_raise SdlParseError do
        SDL4R::read "tag1 'a"
      end
      assert_raise SdlParseError do
        SDL4R::read "tag1 'abc'"
      end
      assert_raise SdlParseError do
        SDL4R::read "tag1 ''"
      end
      assert_raise SdlParseError do
        SDL4R::read "tag1 '\\'"
      end
      assert_raise SdlParseError do
        SDL4R::read "tag1 '\\"
      end

      if SDL4R::supports_unicode_identifiers?
        kanji = SDL4R::read("kanji '日'").child
        assert_equal "日", kanji.value
      end
    end

    def test_backquote_strings
      root = SDL4R::read <<EOS
winfile `c:\\directory\\myfile.xls`
talk `I said "something"`
xml `
<product>
   <shoes color="blue"/>
</product>
`
regex `\\w+\\.suite\\(\\)`
EOS

      assert_equal "c:\\directory\\myfile.xls", root.child("winfile").value
      assert_equal 'I said "something"', root.child("talk").value
      assert_equal(
        "\n<product>\n   <shoes color=\"blue\"/>\n</product>\n", root.child("xml").value)
      assert_equal "\\w+\\.suite\\(\\)", root.child("regex").value
    end

    def test_sub_tags
      root = SDL4R::read <<EOS
wax {
}
steack {
  bees {
    monopoly {
    }
  }
  goat_cheese
  truck {
    cathedral
  }
}
peanut.butter
EOS

      expected = Tag.new("root") do
        new_child("wax")
        new_child("steack") do
          new_child("bees") do
            new_child("monopoly")
          end
          new_child("goat_cheese")
          new_child("truck") do
            new_child("cathedral")
          end
        end
        new_child("peanut.butter")
      end

      assert_equal expected, root
    end

    def test_identifiers
      root = SDL4R::read("my_ns:my_tag my_ns2:my_attr=-13.8")

      assert_equal "my_ns", root.child.namespace
      assert_equal "my_tag", root.child.name
      assert_equal({ "my_ns2:my_attr" => -13.8 }, root.child.attributes)

      root = SDL4R::read("_my_ns:_my_tag _my_ns2:_my_attr=-13.8")
      assert_equal "_my_ns", root.child.namespace
      assert_equal "_my_tag", root.child.name
      assert_equal({ "_my_ns2:_my_attr" => -13.8 }, root.child.attributes)

      root = SDL4R::read("my.ns:my.tag my.ns2:my.attr=-13.8")
      assert_equal "my.ns", root.child.namespace
      assert_equal "my.tag", root.child.name
      assert_equal({ "my.ns2:my.attr" => -13.8 }, root.child.attributes)

      root = SDL4R::read("my$ns:my$tag my$ns2:my$attr=-13.8")
      assert_equal "my$ns", root.child.namespace
      assert_equal "my$tag", root.child.name
      assert_equal({ "my$ns2:my$attr" => -13.8 }, root.child.attributes)

      if SDL4R::supports_unicode_identifiers?
        root = SDL4R::read("京都:アイスクリーム 京都:味=`いちご`")
        assert_equal "京都", root.child.namespace
        assert_equal "アイスクリーム", root.child.name
        assert_equal({ "京都:味" => 'いちご' }, root.child.attributes)
      end
    end

    def test_empty_block
      tag1 = parse_one_tag1("tag1 {\n}")
      assert_equal [], tag1.values
      assert_equal({}, tag1.attributes)
      assert_equal [], tag1.children

      tag1 = parse_one_tag1("tag1 {}")
      assert_equal [], tag1.values
      assert_equal({}, tag1.attributes)
      assert_equal [], tag1.children
    end

    def test_anonymous_tags
      tag = SDL4R::read('123').child
      assert_equal "", tag.namespace
      assert_equal "content", tag.name
      assert_equal [123], tag.values
      assert_equal({}, tag.attributes)

      tag = SDL4R::read('123 attr=456').child
      assert_equal "", tag.namespace
      assert_equal "content", tag.name
      assert_equal [123], tag.values
      assert_equal({"attr" => 456}, tag.attributes)

      tag = SDL4R::read('"abc"').child
      assert_equal "", tag.namespace
      assert_equal "content", tag.name
      assert_equal ["abc"], tag.values
      assert_equal({}, tag.attributes)

      tag = SDL4R::read('`abc`').child
      assert_equal "", tag.namespace
      assert_equal "content", tag.name
      assert_equal ["abc"], tag.values
      assert_equal({}, tag.attributes)

      tag = SDL4R::read("'\\\\'").child
      assert_equal "", tag.namespace
      assert_equal "content", tag.name
      assert_equal ["\\"], tag.values
      assert_equal({}, tag.attributes)

      assert_raise SDL4R::SdlParseError do SDL4R::read("attr=123") end

      # Anonymous tags inside tags
      tag = SDL4R::read(<<-EOS).child
      files {
        "/home/s-austin/price.txt"
        `/home/spiderman/tarantula_porn.avi` size="200Mb"
      }
      EOS

      child = tag.child
      assert_equal '', child.namespace
      assert_equal 'content', child.name
      assert_equal ["/home/s-austin/price.txt"], child.values

      child = tag.children[1]
      assert_equal '', child.namespace
      assert_equal 'content', child.name
      assert_equal ["/home/spiderman/tarantula_porn.avi"], child.values
    end

    def test_parse_error
      # WARNING: the line and col of an error is not accurate science. The goal here is to point to
      # coordinates that are useful to the user.
      # For example, if we have a string literal spanning over several lines, some errors could be
      # pointing to the start or to the end without too much ambiguity.
      # Consequently, feel free to change the coordinates, if a change in the implementation
      # modifies the x/y of the error and they still make sense.
      assert_error_xy "=", 1, 1
      assert_error_xy "tag1 xyz", 1, 9
      assert_error_xy "tag1 \\\nxyz", 2, 4
      assert_error_xy "tag1 \\\n   xyz", 2, 7
      
      source = <<EOS
-- my comment
=
EOS
      assert_error_xy source, 2, 1

      source = <<EOS
murder_plot 123 \\
      weight=456 \\
      * \\
      length=789
EOS
      assert_error_xy source, 3, 7

      assert_error_xy 'tag1 "text\\"', 1, 13

      source = <<EOS
murder_plot "abcd\\
      efghij\\
      kl\\
      mnopq
EOS
      assert_error_xy source, 4, 13
    end

    private

    def assert_error_xy source, expected_line, expected_pos
      error = get_parse_error_or_fail source
      begin
        assert_equal expected_line, error.line, "line"
        assert_equal expected_pos, error.position, "position"
      rescue
        puts "Expected error: #{error}"
        puts error.backtrace
        raise $!
      end
    end

    def get_parse_error_or_fail source
      begin
        SDL4R::read source

      rescue
        return $! if $!.is_a? SdlParseError
        raise Test::Unit::AssertionFailedError, "was expecting a SdlParseError"
      end
    end

    def parse_one_tag1(text)
      root = SDL4R::read(text)
      tag1 = root.child("tag1")
      assert_not_nil(tag1, "tag1")
      assert_equal 1, root.child_count, "only 1 tag expected"
      return tag1
    end
  end
end